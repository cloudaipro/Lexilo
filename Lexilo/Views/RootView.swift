import SwiftUI

extension Notification.Name {
    static let lexiloOpenToday = Notification.Name("LexiloOpenToday")
}

struct RootView: View {
    @State private var selection = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        TabView(selection: $selection) {
            TodayView().tag(0).tabItem { Label("Today", systemImage: "sun.max") }
            WordsView().tag(1).tabItem { Label("Words", systemImage: "text.book.closed") }
            HistoryView().tag(2).tabItem { Label("History", systemImage: "calendar") }
            SettingsView().tag(3).tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(LexiloTheme.sage)
        .onOpenURL { url in
            guard url.scheme == "lexilo" else { return }
            guard url.host == nil || url.host == "today" || url.host == "practice" else { return }
            selection = 0
            NotificationCenter.default.post(name: .lexiloOpenToday, object: nil)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasCompletedOnboarding && !CommandLine.arguments.contains("--ui-testing-reset") },
            set: { if !$0 { hasCompletedOnboarding = true } }
        )) {
            OnboardingView { hasCompletedOnboarding = true }
        }
    }
}

private struct OnboardingView: View {
    let complete: () -> Void

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(alignment: .leading, spacing: 24) {
                Spacer()
                Image(systemName: "leaf.fill").font(.system(size: 42)).foregroundStyle(LexiloTheme.sage)
                Text("Remember words you can use").font(.lexiloDisplay(40, weight: .semibold)).foregroundStyle(LexiloTheme.ink)
                Text("Lexilo checks both understanding and active recall, then adapts each review to your memory.")
                    .font(.title3).foregroundStyle(LexiloTheme.muted)
                Spacer()
                Button(action: complete) {
                    Text("Begin learning").font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 58)
                        .background(LexiloTheme.ink, in: RoundedRectangle(cornerRadius: 19))
                }.buttonStyle(PressableScale())
            }.padding(24)
        }
    }
}
