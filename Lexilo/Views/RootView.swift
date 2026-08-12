import SwiftUI

struct RootView: View {
    @State private var selection = 0
    @State private var widgetPracticeRequested = false

    var body: some View {
        TabView(selection: $selection) {
            TodayView().tag(0).tabItem { Label("Today", systemImage: "sun.max") }
            WordsView().tag(1).tabItem { Label("Words", systemImage: "text.book.closed") }
            ProgressView().tag(2).tabItem { Label("Progress", systemImage: "chart.bar.xaxis") }
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
    }
}
