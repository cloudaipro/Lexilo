import SwiftUI

@main
struct LexiloApp: App {
    @StateObject private var learningStore = LearningStore(reset: CommandLine.arguments.contains("--ui-testing-reset"))
    @StateObject private var speechPlayer = SpeechPlayer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(learningStore)
                .environmentObject(speechPlayer)
                .task { speechPlayer.prewarm() }
        }
    }
}
