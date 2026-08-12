import AVFoundation
import CryptoKit
import Foundation

struct KittenVoice: Identifiable, Hashable {
    let id: Int
    let name: String

    static let all: [KittenVoice] = [
        .init(id: 0, name: "Expressive 2 — Male"),
        .init(id: 1, name: "Expressive 2 — Female"),
        .init(id: 2, name: "Expressive 3 — Male"),
        .init(id: 3, name: "Expressive 3 — Female"),
        .init(id: 4, name: "Expressive 4 — Male"),
        .init(id: 5, name: "Expressive 4 — Female"),
        .init(id: 6, name: "Expressive 5 — Male"),
        .init(id: 7, name: "Expressive 5 — Female")
    ]
}

private struct KittenModelPaths: Sendable {
    let model: String
    let voices: String
    let tokens: String
    let espeakData: String

    init?(bundle: Bundle = .main) {
        guard let root = bundle.url(forResource: "KittenVoice", withExtension: "bundle"),
              let model = Self.file("model.fp16.onnx", under: root),
              let voices = Self.file("voices.bin", under: root),
              let tokens = Self.file("tokens.txt", under: root)
        else { return nil }
        let espeakData = root.appending(path: "espeak-ng-data", directoryHint: .isDirectory)
        guard FileManager.default.fileExists(atPath: espeakData.path) else { return nil }
        self.model = model.path
        self.voices = voices.path
        self.tokens = tokens.path
        self.espeakData = espeakData.path
    }

    private static func file(_ name: String, under root: URL) -> URL? {
        let value = root.appending(path: name)
        return FileManager.default.fileExists(atPath: value.path) ? value : nil
    }
}

/// Owns sherpa-onnx's native handle and serializes model creation and inference.
final class KittenSynthesizer: @unchecked Sendable {
    private let lock = NSLock()
    private let paths: KittenModelPaths
    private var tts: OpaquePointer?

    init?(bundle: Bundle = .main) {
        guard let paths = KittenModelPaths(bundle: bundle) else { return nil }
        self.paths = paths
    }

    deinit {
        if let tts { SherpaOnnxDestroyOfflineTts(tts) }
    }

    /// Loads and initializes the ONNX session without synthesizing throwaway audio.
    @discardableResult
    func prewarm() -> Bool {
        lock.withLock { engine() != nil }
    }

    func generateWave(text: String, speakerID: Int, speed: Float) -> Data? {
        lock.withLock {
            guard let tts = engine() else { return nil }

            var generation = SherpaOnnxGenerationConfig()
            generation.silence_scale = 0.15
            generation.speed = speed
            generation.sid = Int32(max(0, min(7, speakerID)))

            let generated = text.withCString { textPointer in
                SherpaOnnxOfflineTtsGenerateWithConfig(tts, textPointer, &generation, nil, nil)
            }
            guard let generated else { return nil }
            defer { SherpaOnnxDestroyOfflineTtsGeneratedAudio(generated) }
            let count = Int(generated.pointee.n)
            guard count > 0, let samples = generated.pointee.samples else { return nil }
            return Self.waveData(
                samples: UnsafeBufferPointer(start: samples, count: count),
                sampleRate: Int(generated.pointee.sample_rate)
            )
        }
    }

    private func engine() -> OpaquePointer? {
        if let tts { return tts }
        tts = paths.model.withCString { model in
            paths.voices.withCString { voices in
                paths.tokens.withCString { tokens in
                    paths.espeakData.withCString { dataDirectory in
                        "cpu".withCString { provider in
                            var kitten = SherpaOnnxOfflineTtsKittenModelConfig()
                            kitten.model = model
                            kitten.voices = voices
                            kitten.tokens = tokens
                            kitten.data_dir = dataDirectory
                            kitten.length_scale = 1.0

                            var modelConfig = SherpaOnnxOfflineTtsModelConfig()
                            modelConfig.kitten = kitten
                            modelConfig.num_threads = 2
                            modelConfig.provider = provider

                            var config = SherpaOnnxOfflineTtsConfig()
                            config.model = modelConfig
                            config.max_num_sentences = 1
                            config.silence_scale = 0.15
                            return SherpaOnnxCreateOfflineTts(&config)
                        }
                    }
                }
            }
        }
        return tts
    }

    private static func waveData(samples: UnsafeBufferPointer<Float>, sampleRate: Int) -> Data {
        let pcm = samples.map { sample -> Int16 in
            let clamped = max(-1, min(1, sample))
            return Int16(clamped * Float(Int16.max))
        }
        let payloadSize = pcm.count * MemoryLayout<Int16>.size
        var data = Data()
        data.append("RIFF".data(using: .ascii)!)
        append(UInt32(36 + payloadSize), to: &data)
        data.append("WAVEfmt ".data(using: .ascii)!)
        append(UInt32(16), to: &data)
        append(UInt16(1), to: &data)
        append(UInt16(1), to: &data)
        append(UInt32(sampleRate), to: &data)
        append(UInt32(sampleRate * 2), to: &data)
        append(UInt16(2), to: &data)
        append(UInt16(16), to: &data)
        data.append("data".data(using: .ascii)!)
        append(UInt32(payloadSize), to: &data)
        pcm.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }

    private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }
}

/// A bounded memory cache backed by a bounded, versioned cache-directory store.
/// Cache keys include all synthesis inputs, so changing voice or speed cannot
/// replay stale audio.
final class KittenAudioCache: @unchecked Sendable {
    static let modelVersion = "kitten-nano-en-v0_2-fp16"

    private let lock = NSLock()
    private let memory = NSCache<NSString, NSData>()
    private let directory: URL
    private let diskFileLimit: Int

    init(directory: URL? = nil, memoryItemLimit: Int = 96, diskFileLimit: Int = 192) {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.directory = directory ?? caches.appending(path: "LexiloKittenAudio-v0_2", directoryHint: .isDirectory)
        self.diskFileLimit = diskFileLimit
        memory.countLimit = memoryItemLimit
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        pruneDiskIfNeeded()
    }

    func key(text: String, speakerID: Int, speed: Float) -> String {
        // Preserve case: acronyms such as "US" and words such as "us" can be
        // pronounced differently and must never share a cached waveform.
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let input = "\(Self.modelVersion)|\(speakerID)|\(speed.bitPattern)|\(normalized)"
        return SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func data(for key: String) -> Data? {
        lock.withLock {
            if let cached = memory.object(forKey: key as NSString) {
                return cached as Data
            }
            let url = fileURL(for: key)
            guard let data = try? Data(contentsOf: url) else { return nil }
            guard Self.isWave(data) else {
                try? FileManager.default.removeItem(at: url)
                return nil
            }
            memory.setObject(data as NSData, forKey: key as NSString, cost: data.count)
            try? FileManager.default.setAttributes([.modificationDate: Date.now], ofItemAtPath: url.path)
            return data
        }
    }

    func store(_ data: Data, for key: String) {
        guard Self.isWave(data) else { return }
        lock.withLock {
            memory.setObject(data as NSData, forKey: key as NSString, cost: data.count)
            try? data.write(to: fileURL(for: key), options: .atomic)
            pruneDiskIfNeededLocked()
        }
    }

    private func fileURL(for key: String) -> URL {
        directory.appending(path: "\(key).wav")
    }

    private static func isWave(_ data: Data) -> Bool {
        // Kitten writes canonical 44-byte PCM WAV files. Checking the complete
        // header keeps a truncated RIFF file from becoming a permanent cache hit.
        guard data.count >= 44 else { return false }
        return data.prefix(4).elementsEqual(Data("RIFF".utf8))
            && data.dropFirst(8).prefix(4).elementsEqual(Data("WAVE".utf8))
            && data.dropFirst(12).prefix(4).elementsEqual(Data("fmt ".utf8))
            && data.dropFirst(36).prefix(4).elementsEqual(Data("data".utf8))
    }

    private func pruneDiskIfNeeded() {
        lock.withLock { pruneDiskIfNeededLocked() }
    }

    private func pruneDiskIfNeededLocked() {
        guard diskFileLimit >= 0,
              let files = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
              ),
              files.count > diskFileLimit
        else { return }

        let oldestFirst = files.sorted {
            let left = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let right = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return left < right
        }
        for file in oldestFirst.prefix(files.count - diskFileLimit) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}

@MainActor
final class KittenOfflinePronunciationEngine: OfflinePronunciationEngine {
    private let fallback: any OfflinePronunciationEngine
    private let synthesizer: KittenSynthesizer?
    private let cache: KittenAudioCache
    private var audioPlayer: AVAudioPlayer?
    private var generationTask: Task<Void, Never>?
    private var preparationTasks: [String: Task<Data?, Never>] = [:]
    private var prewarmTask: Task<Void, Never>?
    private var requestID = UUID()

    init(
        bundle: Bundle = .main,
        cache: KittenAudioCache = KittenAudioCache(),
        fallback: any OfflinePronunciationEngine = AppleOfflinePronunciationEngine()
    ) {
        synthesizer = KittenSynthesizer(bundle: bundle)
        self.cache = cache
        self.fallback = fallback
    }

    func prewarm() {
        guard prewarmTask == nil, let synthesizer else { return }
        prewarmTask = Task {
            _ = await Task.detached(priority: .utility) { synthesizer.prewarm() }.value
        }
    }

    func prepare(_ text: String, locale: String) {
        guard let synthesizer else { return }
        let settings = synthesisSettings
        let key = cache.key(text: text, speakerID: settings.speakerID, speed: settings.speed)
        guard cache.data(for: key) == nil, preparationTasks[key] == nil else { return }

        preparationTasks[key] = Task { [weak self] in
            let wave = await Task.detached(priority: .utility) {
                synthesizer.generateWave(text: text, speakerID: settings.speakerID, speed: settings.speed)
            }.value
            guard let self else { return wave }
            if let wave { self.cache.store(wave, for: key) }
            self.preparationTasks[key] = nil
            return wave
        }
    }

    func stop() {
        requestID = UUID()
        generationTask?.cancel()
        generationTask = nil
        audioPlayer?.stop()
        fallback.stop()
    }

    func speak(_ text: String, locale: String) {
        stop()
        guard let synthesizer else {
            fallback.speak(text, locale: locale)
            return
        }

        let currentRequest = requestID
        let settings = synthesisSettings
        let key = cache.key(text: text, speakerID: settings.speakerID, speed: settings.speed)
        if let wave = cache.data(for: key) {
            play(wave, fallbackText: text, locale: locale)
            return
        }

        let preparationTask = preparationTasks[key]
        generationTask = Task { [weak self] in
            let wave: Data?
            if let preparationTask {
                wave = await preparationTask.value
            } else {
                wave = await Task.detached(priority: .userInitiated) {
                    synthesizer.generateWave(text: text, speakerID: settings.speakerID, speed: settings.speed)
                }.value
            }
            guard let self, !Task.isCancelled, self.requestID == currentRequest else { return }
            guard let wave else {
                self.fallback.speak(text, locale: locale)
                return
            }
            self.cache.store(wave, for: key)
            self.play(wave, fallbackText: text, locale: locale)
        }
    }

    private var synthesisSettings: (speakerID: Int, speed: Float) {
        let speakerID = UserDefaults.standard.object(forKey: "kittenVoiceID") as? Int ?? 1
        let speed = Float(UserDefaults.standard.object(forKey: "kittenSpeechRate") as? Double ?? 1.0)
        return (max(0, min(7, speakerID)), max(0.7, min(1.2, speed)))
    }

    private func play(_ wave: Data, fallbackText: String, locale: String) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(data: wave)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            fallback.speak(fallbackText, locale: locale)
        }
    }
}
