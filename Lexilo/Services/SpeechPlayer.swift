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
    private let offlineEngine: any OfflinePronunciationEngine

    init(offlineEngine: any OfflinePronunciationEngine = KittenOfflinePronunciationEngine()) {
        self.offlineEngine = offlineEngine
    }

    func prewarm() {
        guard soundEnabled else { return }
        offlineEngine.prewarm()
    }

    func prepare(_ word: VocabularyItem) {
        guard soundEnabled else { return }
        offlineEngine.prepare(word.word, locale: pronunciationLocale)
    }

    func play(_ word: VocabularyItem) {
        play(word.word)
    }

    func play(_ text: String) {
        guard soundEnabled else { return }
        let spokenText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spokenText.isEmpty else { return }
        offlineEngine.stop()
        offlineEngine.speak(spokenText, locale: pronunciationLocale)
    }

    func stop() {
        offlineEngine.stop()
    }

    private var soundEnabled: Bool {
        UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
    }

    private var pronunciationLocale: String {
        UserDefaults.standard.string(forKey: "pronunciationLocale") ?? "en-US"
    }
}
