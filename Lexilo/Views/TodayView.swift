import SwiftUI

enum TodayGreeting {
    static func text(for date: Date, calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 0..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
    }
}

/// Today is the learning surface. The learner sees the prepared set first and
/// can start the quiz at any time from the navigation bar.
struct TodayView: View {
    var body: some View {
        DailyStudyView()
    }
}

struct DailyStudyView: View {
    @EnvironmentObject private var store: LearningStore
    @State private var showingPractice = false

    private var todayWords: [VocabularyItem] {
        guard let set = store.dailyStudySet else { return [] }
        return set.vocabularyIDs.compactMap { store.word(for: $0) }
    }

    private func learnMore() {
        if !store.dailyLearningCompleted() {
            store.completeDailyLearning()
        }
        _ = store.addMoreDailyWords()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                content
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingPractice = true
                    } label: {
                        Text("Quiz")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(LexiloTheme.ink)
                    .disabled(todayWords.isEmpty)
                    .accessibilityLabel("Start quiz")
                    .accessibilityIdentifier("daily-study-start-quiz")
                }
            }
            .task {
                store.ensureDailyStudySet()
            }
            .fullScreenCover(isPresented: $showingPractice) {
                PracticeSessionView(
                    focusVocabularyIDs: Set(todayWords.map(\.id)),
                    allowsLearningExpansion: true
                )
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !store.lexicon.isAvailable {
            ContentUnavailableView(
                "Dictionary unavailable",
                systemImage: "books.vertical",
                description: Text("The bundled Simple English Wiktionary database could not be opened.")
            )
        } else if let set = store.dailyStudySet, !todayWords.isEmpty {
            WordStudyPager(
                title: "Today’s words",
                words: todayWords,
                initialIndex: set.currentIndex,
                finishTitle: "Learn More",
                onIndexChanged: { index in
                    store.updateDailyStudyProgress(index: index)
                },
                onFinish: {
                    learnMore()
                }
            )
        } else {
            VStack(spacing: 14) {
                ProgressView().tint(LexiloTheme.sage)
                Text("Preparing today’s words…")
                    .font(.subheadline)
                    .foregroundStyle(LexiloTheme.muted)
            }
        }
    }

}

/// Reusable, schedule-neutral card browsing. Swiping changes only the local
/// position; the store marks a word as learned only after the final action.
struct WordStudyPager: View {
    @EnvironmentObject private var speechPlayer: SpeechPlayer
    let title: String
    let words: [VocabularyItem]
    let initialIndex: Int
    let finishTitle: String
    let onIndexChanged: (Int) -> Void
    let onFinish: () -> Void
    @State private var index: Int

    init(
        title: String,
        words: [VocabularyItem],
        initialIndex: Int = 0,
        finishTitle: String,
        onIndexChanged: @escaping (Int) -> Void = { _ in },
        onFinish: @escaping () -> Void
    ) {
        self.title = title
        self.words = words
        self.initialIndex = initialIndex
        self.finishTitle = finishTitle
        self.onIndexChanged = onIndexChanged
        self.onFinish = onFinish
        _index = State(initialValue: max(0, min(initialIndex, max(words.count - 1, 0))))
    }

    private var safeIndex: Int {
        max(0, min(index, max(words.count - 1, 0)))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.lexiloDisplay(29, weight: .semibold))
                        .foregroundStyle(LexiloTheme.ink)
                }
                Spacer(minLength: 12)
                Text("\(safeIndex + 1) of \(words.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LexiloTheme.muted)
                    .accessibilityIdentifier("daily-study-count")
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            SwiftUI.ProgressView(value: Double(safeIndex + 1), total: Double(max(words.count, 1)))
                .tint(LexiloTheme.sage)
                .padding(.horizontal, 20)
                .padding(.top, 14)

            TabView(selection: $index) {
                ForEach(Array(words.enumerated()), id: \.element.id) { item in
                    WordStudyCard(word: item.element, index: item.offset)
                        .tag(item.offset)
                        .padding(.horizontal, 16)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxHeight: .infinity)
            .accessibilityHint("Swipe left for the next word or right for the previous word")

            HStack(spacing: 8) {
                ForEach(words.indices, id: \.self) { itemIndex in
                    Capsule()
                        .fill(itemIndex == safeIndex ? LexiloTheme.sage : LexiloTheme.paperDeep)
                        .frame(width: itemIndex == safeIndex ? 22 : 7, height: 7)
                        .animation(.easeInOut(duration: 0.2), value: safeIndex)
                }
            }
            .padding(.bottom, 12)

            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { index = max(0, safeIndex - 1) }
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 52, height: 52)
                        .foregroundStyle(LexiloTheme.ink)
                        .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(PressableScale())
                .accessibilityLabel("Previous word")
                .accessibilityIdentifier("daily-study-previous")
                .disabled(safeIndex == 0)
                .opacity(safeIndex == 0 ? 0.38 : 1)

                Spacer()

                Button {
                    if safeIndex == words.count - 1 {
                        onFinish()
                    } else {
                        withAnimation(.easeInOut(duration: 0.22)) { index = safeIndex + 1 }
                    }
                } label: {
                    if safeIndex == words.count - 1 && finishTitle == "Learn More" {
                        Label("Learn More", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 136, minHeight: 52)
                            .background(LexiloTheme.ink, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    } else {
                        Image(systemName: safeIndex == words.count - 1 ? "checkmark" : "arrow.right")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(LexiloTheme.ink, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    }
                }
                .buttonStyle(PressableScale())
                .accessibilityLabel(safeIndex == words.count - 1 ? finishTitle : "Next word")
                .accessibilityIdentifier(
                    safeIndex == words.count - 1
                        ? (finishTitle == "Learn More" ? "daily-study-learn-more" : "daily-study-finish")
                        : "daily-study-next"
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .onAppear {
            index = max(0, min(initialIndex, max(words.count - 1, 0)))
            prepareCurrentAudio()
        }
        .onChange(of: index) { _, newValue in
            let clamped = max(0, min(newValue, max(words.count - 1, 0)))
            if clamped != newValue { index = clamped }
            onIndexChanged(clamped)
            prepareCurrentAudio()
        }
        .onChange(of: initialIndex) { _, newValue in
            index = max(0, min(newValue, max(words.count - 1, 0)))
        }
    }

    private func prepareCurrentAudio() {
        guard words.indices.contains(safeIndex) else { return }
        speechPlayer.prepare(words[safeIndex])
    }
}

private struct WordStudyCard: View {
    @EnvironmentObject private var speechPlayer: SpeechPlayer
    let word: VocabularyItem
    let index: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("WORD \(index + 1)")
                            .font(.caption.bold())
                            .tracking(1.4)
                            .foregroundStyle(LexiloTheme.brass)
                        Text(word.word)
                            .font(.lexiloDisplay(45, weight: .medium))
                            .foregroundStyle(LexiloTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                            .allowsTightening(true)
                            .layoutPriority(1)
                        Text([word.partOfSpeech, word.ipa].filter { !$0.isEmpty }.joined(separator: "  ·  "))
                            .font(.subheadline)
                            .foregroundStyle(LexiloTheme.sage)
                    }
                    Spacer(minLength: 10)
                    Button { speechPlayer.play(word) } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.title3)
                            .foregroundStyle(LexiloTheme.sage)
                            .frame(width: 46, height: 46)
                            .background(LexiloTheme.sageLight, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Play pronunciation for \(word.word)")
                    .accessibilityIdentifier("daily-study-pronunciation")
                }

                Divider().overlay(LexiloTheme.brass.opacity(0.35))

                VStack(alignment: .leading, spacing: 8) {
                    Text("MEANING")
                        .font(.caption.bold())
                        .tracking(1.2)
                        .foregroundStyle(LexiloTheme.brass)
                    HStack(alignment: .top, spacing: 10) {
                        Text(word.conciseDefinition)
                            .font(.title3)
                            .foregroundStyle(LexiloTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                        Button { speechPlayer.play(word.conciseDefinition) } label: {
                            Image(systemName: "speaker.wave.2")
                                .foregroundStyle(LexiloTheme.sage)
                                .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Play definition for \(word.word)")
                    }
                }

                if let example = word.examples.first, !example.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("IN CONTEXT")
                            .font(.caption.bold())
                            .tracking(1.2)
                            .foregroundStyle(LexiloTheme.brass)
                        HStack(alignment: .top, spacing: 10) {
                            Text("“\(example)”")
                                .font(.lexiloDisplay(19))
                                .italic()
                                .foregroundStyle(LexiloTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 4)
                            Button { speechPlayer.play(example) } label: {
                                Image(systemName: "speaker.wave.2")
                                    .foregroundStyle(LexiloTheme.sage)
                                    .frame(width: 34, height: 34)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Play example for \(word.word)")
                        }
                    }
                }

            }
            .padding(22)
            .background(.white.opacity(0.73), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(LexiloTheme.brass.opacity(0.16))
            }
            .padding(.vertical, 14)
        }
        .scrollIndicators(.hidden)
    }
}

struct HistoricalStudyView: View {
    @Environment(\.dismiss) private var dismiss
    let words: [VocabularyItem]
    let title: String

    var body: some View {
        ZStack {
            PaperBackground()
            if words.isEmpty {
                ContentUnavailableView("No words to review", systemImage: "text.book.closed")
            } else {
                WordStudyPager(
                    title: title,
                    words: words,
                    finishTitle: "Done",
                    onFinish: { dismiss() }
                )
            }
        }
    }
}
