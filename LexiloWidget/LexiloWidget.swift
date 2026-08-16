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
            definition: "Prepare your offline learning queue in Lexilo.",
            streak: 0
        )
    }

    static let placeholderID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
}

struct LexiloWidgetView: View {
    let entry: WordEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .containerBackground(LexiloWidgetPalette.paper, for: .widget)
            .widgetURL(
                entry.snapshot.vocabularyID == WordProvider.placeholderID
                    ? URL(string: "lexilo://")
                    : URL(string: "lexilo://practice/\(entry.snapshot.vocabularyID.uuidString)")
            )
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemMedium:
            mediumLayout
        default:
            smallLayout
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 8)
            smallWord
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 8)
            Text("Tap to practise")
                .font(.caption2.weight(.medium))
                .foregroundStyle(LexiloWidgetPalette.sage)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var mediumLayout: some View {
        ViewThatFits(in: .vertical) {
            mediumCandidate(
                content: mediumContent,
                wordSize: 24,
                contentFont: .caption
            )
            mediumCandidate(
                content: mediumContent,
                wordSize: 22,
                contentFont: .caption2
            )
            mediumCandidate(
                content: mediumContent,
                wordSize: 21,
                contentFont: .caption2
            )
            mediumCandidate(
                content: mediumCompactContent,
                wordSize: 19,
                contentFont: .caption2
            )
        }
    }

    private func mediumCandidate(content: String, wordSize: CGFloat, contentFont: Font) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            wordText(fontSize: wordSize)
            Text(verbatim: content)
                .font(contentFont)
                .foregroundStyle(.secondary)
                .allowsTightening(true)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mediumContent: String {
        switch entry.snapshot.mediumContent {
        case .definition: return entry.snapshot.definition
        case .example: return entry.snapshot.example
        }
    }

    private var mediumCompactContent: String {
        switch entry.snapshot.mediumContent {
        case .definition: return entry.snapshot.definition
        case .example: return entry.snapshot.shortestExample
        }
    }

    private var smallWord: some View {
        ViewThatFits {
            wordText(fontSize: 25)
            wordText(fontSize: 21)
            wordText(fontSize: 18)
        }
    }

    private func wordText(fontSize: CGFloat) -> some View {
        Text(verbatim: entry.snapshot.word)
            .font(.system(size: fontSize, weight: .semibold, design: .serif))
            .foregroundStyle(LexiloWidgetPalette.ink)
            .allowsTightening(true)
            .minimumScaleFactor(0.7)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var header: some View {
        HStack {
            Text("LEXILO")
                .font(.caption2.bold())
                .tracking(1.3)
            Spacer()
            if entry.snapshot.streak > 0 {
                Text("Day \(entry.snapshot.streak)")
                    .font(.caption2.weight(.semibold))
            }
            Image(systemName: "leaf.fill")
                .font(.caption2)
        }
        .foregroundStyle(LexiloWidgetPalette.sage)
    }
}

private enum LexiloWidgetPalette {
    static let paper = Color(red: 0.984, green: 0.969, blue: 0.95)
    static let ink = Color(red: 0.08, green: 0.12, blue: 0.19)
    static let sage = Color(red: 0.36, green: 0.51, blue: 0.46)
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
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
