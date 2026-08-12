import Foundation
import SwiftUI

@main
struct LexiloApp: App {
    @StateObject private var learningStore: LearningStore
    @StateObject private var speechPlayer = SpeechPlayer()

    init() {
        let hostedUnitTests = NSClassFromString("XCTestCase") != nil
        let lexicon = hostedUnitTests ? LexiconStore(databaseURL: nil) : nil
        _learningStore = StateObject(
            wrappedValue: LearningStore(
                reset: CommandLine.arguments.contains("--ui-testing-reset"),
                lexicon: lexicon
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(learningStore)
                .environmentObject(speechPlayer)
                .task {
                    // Hosted unit tests instantiate Kitten explicitly. Loading a
                    // second model from the host app can terminate the simulator
                    // for memory pressure and invalidate its bundled resources.
                    guard NSClassFromString("XCTestCase") == nil else { return }
                    speechPlayer.prewarm()
                }
        }
    }
}
