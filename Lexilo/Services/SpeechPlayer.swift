import AVFoundation
import Combine

@MainActor
final class SpeechPlayer: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.42
        let accent = UserDefaults.standard.string(forKey: "voiceAccent") == "UK" ? "en-GB" : "en-US"
        utterance.voice = AVSpeechSynthesisVoice(language: accent)
        synthesizer.speak(utterance)
    }
}
