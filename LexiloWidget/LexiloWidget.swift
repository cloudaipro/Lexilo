import SwiftUI
import WidgetKit

struct WordEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetStudySnapshot
}

struct WordProvider: TimelineProvider {
    func placeholder(in context: Context) -> WordEntry {
        WordEntry(date: .now, snapshot: fallbackSnapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> Void) {
        let date = Date.now
        completion(WordEntry(date: date, snapshot: SharedStudySnapshotStore.load() ?? fallbackSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordEntry>) -> Void) {
        let date = Date.now
        let snapshot = SharedStudySnapshotStore.load() ?? fallbackSnapshot()
        let entry = WordEntry(date: date, snapshot: snapshot)
        let next = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: date)) ?? date.addingTimeInterval(86_400)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func fallbackSnapshot() -> WidgetStudySnapshot {
        return WidgetStudySnapshot(
            vocabularyID: Self.placeholderID,
            word: "Open Lexilo",
            example: "Open the app to prepare your offline learning queue.",
            streak: 0
        )
    }

    static let placeholderID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
}

struct LexiloWidgetView: View {
    let entry: WordEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("LEXILO").font(.caption2.bold()).tracking(1.3)
                Spacer()
                if entry.snapshot.streak > 0 {
                    Text("Day \(entry.snapshot.streak)").font(.caption2.weight(.semibold))
                }
                Image(systemName: "leaf.fill")
            }
            .foregroundStyle(Color(red: 0.36, green: 0.51, blue: 0.46))
            Spacer()
            Text(entry.snapshot.word)
                .font(.system(size: 25, weight: .semibold, design: .serif))
                .foregroundStyle(Color(red: 0.08, green: 0.12, blue: 0.19))
            Text(entry.snapshot.example)
                .font(.caption)
                .lineLimit(2)
                .foregroundStyle(.secondary)
        }
        .containerBackground(Color(red: 0.984, green: 0.969, blue: 0.95), for: .widget)
        .widgetURL(
            entry.snapshot.vocabularyID == WordProvider.placeholderID
                ? URL(string: "lexilo://")
                : URL(string: "lexilo://practice/\(entry.snapshot.vocabularyID.uuidString)")
        )
    }
}

@main
struct LexiloWidget: Widget {
    let kind = "LexiloWord"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WordProvider()) { entry in
            LexiloWidgetView(entry: entry)
        }
        .configurationDisplayName("A word to remember")
        .description("A not-yet-mastered word from your learning queue.")
        .supportedFamilies([.systemSmall])
    }
}
