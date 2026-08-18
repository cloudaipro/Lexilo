import AVFoundation
import Combine
import Foundation

@MainActor
protocol OfflinePronunciationEngine: AnyObject {
    func prewarm()
    func prepare(_ text: String, locale: String)
    func stop()
    func speak(_ text: String, locale: String)
}

extension OfflinePronunciationEngine {
    func prewarm() {}
    func prepare(_ text: String, locale: String) {}
}

enum PronunciationEngineChoice: String, CaseIterable, Identifiable {
    case appleTTS = "appleTTS"
    case kitten = "kitten"

    static let preferenceKey = "pronunciationEngine"
    static let defaultChoice: Self = .appleTTS

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleTTS: "Apple TTS"
        case .kitten: "Kitten"
        }
    }
}

@MainActor
final class AppleOfflinePronunciationEngine: OfflinePronunciationEngine {
    private let synthesizer = AVSpeechSynthesizer()

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    func speak(_ text: String, locale: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: locale) ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.42
        synthesizer.speak(utterance)
    }
}

@MainActor
final class SpeechPlayer: ObservableObject {
    private let appleEngine: any OfflinePronunciationEngine
    private let kittenEngine: any OfflinePronunciationEngine

    init(
        appleEngine: any OfflinePronunciationEngine = AppleOfflinePronunciationEngine(),
        kittenEngine: any OfflinePronunciationEngine = KittenOfflinePronunciationEngine()
    ) {
        self.appleEngine = appleEngine
        self.kittenEngine = kittenEngine
    }

    // Kept for lightweight callers and tests that inject one recording engine.
    init(offlineEngine: any OfflinePronunciationEngine) {
        self.appleEngine = offlineEngine
        self.kittenEngine = offlineEngine
    }

    func prewarm() {
        guard soundEnabled else { return }
        selectedEngine.prewarm()
    }

    func prepare(_ word: VocabularyItem) {
        guard soundEnabled else { return }
        selectedEngine.prepare(word.word, locale: pronunciationLocale)
    }

    func play(_ word: VocabularyItem) {
        play(word.word)
    }

    func play(_ text: String) {
        guard soundEnabled else { return }
        let spokenText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spokenText.isEmpty else { return }
        stop()
        selectedEngine.speak(spokenText, locale: pronunciationLocale)
    }

    func stop() {
        // Stop both engines so changing the setting cannot leave the previously
        // selected engine speaking or finish an in-flight Kitten generation.
        appleEngine.stop()
        if !(appleEngine === kittenEngine) {
            kittenEngine.stop()
        }
    }

    private var selectedEngine: any OfflinePronunciationEngine {
        switch UserDefaults.standard.string(forKey: PronunciationEngineChoice.preferenceKey) {
        case PronunciationEngineChoice.kitten.rawValue:
            kittenEngine
        default:
            appleEngine
        }
    }

    private var soundEnabled: Bool {
        UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
    }

    private var pronunciationLocale: String {
        UserDefaults.standard.string(forKey: "pronunciationLocale") ?? "en-US"
    }
}
