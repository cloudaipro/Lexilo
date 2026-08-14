import SwiftUI

struct RootView: View {
    @State private var selection = 0
    @State private var widgetPracticeRequested = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        TabView(selection: $selection) {
            TodayView().tag(0).tabItem { Label("Today", systemImage: "sun.max") }
            WordsView().tag(1).tabItem { Label("Words", systemImage: "text.book.closed") }
            ProgressView().tag(2).tabItem { Label("Memory", systemImage: "brain.head.profile") }
            SettingsView().tag(3).tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
        }
        .tint(LexiloTheme.sage)
        .onOpenURL { url in
            guard url.scheme == "lexilo", url.host == "practice" else { return }
            widgetPracticeRequested = true
        }
        .fullScreenCover(isPresented: $widgetPracticeRequested) {
            PracticeSessionView()
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
    @AppStorage("translationEnabled") private var translationEnabled = false
    @AppStorage("translationLanguage") private var translationLanguage = "Spanish"

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(alignment: .leading, spacing: 24) {
                Spacer()
                Image(systemName: "leaf.fill").font(.system(size: 42)).foregroundStyle(LexiloTheme.sage)
                Text("Remember words you can use").font(.lexiloDisplay(40, weight: .semibold)).foregroundStyle(LexiloTheme.ink)
                Text("Lexilo checks both understanding and active recall, then adapts each review to your memory.")
                    .font(.title3).foregroundStyle(LexiloTheme.muted)
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Show first-language support", isOn: $translationEnabled)
                    if translationEnabled {
                        Picker("My first language", selection: $translationLanguage) {
                            ForEach(["Spanish", "Simplified Chinese", "Japanese", "Korean", "French", "German", "Other"], id: \.self) { Text($0) }
                        }
                        Text("English definitions stay primary. Translations stay labeled as personal until you review them; Lexilo does not silently generate translations.")
                            .font(.caption).foregroundStyle(LexiloTheme.muted)
                    }
                }
                .padding(20).background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 22))
                Spacer()
                Button(action: complete) {
                    Text("Begin learning").font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 58)
                        .background(LexiloTheme.ink, in: RoundedRectangle(cornerRadius: 19))
                }.buttonStyle(PressableScale())
            }.padding(24)
        }
    }
}
