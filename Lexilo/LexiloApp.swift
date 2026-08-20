import AVFoundation
import Foundation
import SwiftUI
import UIKit

@main
struct LexiloApp: App {
    @StateObject private var learningStore: LearningStore
    @StateObject private var speechPlayer = SpeechPlayer()
    @State private var isShowingSplash: Bool

    private let holdsSplashForUITesting: Bool

    init() {
        let arguments = CommandLine.arguments
        let hostedUnitTests = NSClassFromString("XCTestCase") != nil
        let lexicon = hostedUnitTests ? LexiconStore(databaseURL: nil) : nil
        let holdsSplashForUITesting = arguments.contains("--ui-testing-hold-splash")
        let skipsSplashForUITesting = arguments.contains("--ui-testing-reset") && !holdsSplashForUITesting

        self.holdsSplashForUITesting = holdsSplashForUITesting
        _isShowingSplash = State(initialValue: !hostedUnitTests && !skipsSplashForUITesting)
        _learningStore = StateObject(
            wrappedValue: LearningStore(
                reset: arguments.contains("--ui-testing-reset"),
                lexicon: lexicon
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView(allowsOnboardingPresentation: !isShowingSplash)

                if isShowingSplash {
                    LexiloSplashView(playsSound: !holdsSplashForUITesting)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .environmentObject(learningStore)
            .environmentObject(speechPlayer)
            .task {
                // Hosted unit tests instantiate Kitten explicitly. Loading a
                // second model from the host app can terminate the simulator
                // for memory pressure and invalidate its bundled resources.
                guard NSClassFromString("XCTestCase") == nil else { return }
                speechPlayer.prewarm()
            }
            .task {
                guard isShowingSplash, !holdsSplashForUITesting else { return }
                try? await Task.sleep(for: .milliseconds(1_350))
                withAnimation(.easeInOut(duration: 0.42)) {
                    isShowingSplash = false
                }
            }
        }
    }
}

private struct LexiloSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false
    @State private var soundPlayer: AVAudioPlayer?

    let playsSound: Bool

    var body: some View {
        ZStack {
            PaperBackground()

            VStack(spacing: 22) {
                Image("LaunchLogo")
                    .resizable()
                    .antialiased(true)
                    .scaledToFit()
                    .frame(width: 160, height: 160)
                    .shadow(color: LexiloTheme.ink.opacity(0.08), radius: 18, y: 10)
                    .scaleEffect(hasAppeared && !reduceMotion ? 1.018 : 1)
                    .animation(.easeInOut(duration: 0.9).delay(0.05), value: hasAppeared)

                VStack(spacing: 11) {
                    Capsule()
                        .fill(LexiloTheme.brass.opacity(0.72))
                        .frame(width: 38, height: 1)
                        .scaleEffect(x: hasAppeared ? 1 : 0, anchor: .center)

                    Text("Words, remembered.")
                        .font(.lexiloDisplay(17))
                        .tracking(0.7)
                        .foregroundStyle(LexiloTheme.ink.opacity(0.72))
                }
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 5)
                .animation(.easeOut(duration: 0.55).delay(0.26), value: hasAppeared)
            }
            .offset(y: -12)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lexilo. Words, remembered.")
        .accessibilityIdentifier("lexilo-splash")
        .onAppear {
            playSplashSound()

            if reduceMotion {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { hasAppeared = true }
            } else {
                hasAppeared = true
            }
        }
        .onDisappear {
            soundPlayer?.stop()
            soundPlayer = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func playSplashSound() {
        guard playsSound,
              UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true,
              let asset = NSDataAsset(name: "SplashChime")
        else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            let player = try AVAudioPlayer(data: asset.data)
            player.volume = 0.72
            player.prepareToPlay()
            player.play()
            soundPlayer = player
        } catch {
            // A launch sound is an enhancement; startup should remain silent and
            // uninterrupted if the audio route or session is unavailable.
            soundPlayer = nil
        }
    }
}
