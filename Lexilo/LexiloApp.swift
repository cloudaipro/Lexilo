import SwiftUI

@main
struct LexiloApp: App {
    @StateObject private var learningStore = LearningStore(reset: CommandLine.arguments.contains("--ui-testing-reset"))

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(learningStore)
        }
    }
}
