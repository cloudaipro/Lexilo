import WidgetKit
import SwiftUI

struct WordEntry: TimelineEntry {
    let date: Date
    let word: SeedWord
}

struct WordProvider: TimelineProvider {
    func placeholder(in context: Context) -> WordEntry { WordEntry(date: .now, word: StarterVocabulary.words[0]) }
    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> Void) { completion(placeholder(in: context)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WordEntry>) -> Void) {
        let index = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        let entry = WordEntry(date: .now, word: StarterVocabulary.words[index % StarterVocabulary.words.count])
        let next = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now.addingTimeInterval(86400)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct LexiloWidgetView: View {
    let entry: WordEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack { Text("LEXILO").font(.caption2.bold()).tracking(1.3); Spacer(); Image(systemName: "leaf.fill") }
                .foregroundStyle(Color(red: 0.36, green: 0.51, blue: 0.46))
            Spacer()
            Text(entry.word.word).font(.system(size: 25, weight: .semibold, design: .serif)).foregroundStyle(Color(red: 0.08, green: 0.12, blue: 0.19))
            Text(entry.word.example).font(.caption).lineLimit(2).foregroundStyle(.secondary)
        }
        .containerBackground(Color(red: 0.984, green: 0.969, blue: 0.95), for: .widget)
        .widgetURL(URL(string: "lexilo://practice"))
    }
}

@main
struct LexiloWidget: Widget {
    let kind = "LexiloWord"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WordProvider()) { LexiloWidgetView(entry: $0) }
            .configurationDisplayName("A word to remember")
            .description("A gentle reminder from your learning queue.")
            .supportedFamilies([.systemSmall])
    }
}

