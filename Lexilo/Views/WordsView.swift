import SwiftUI

struct WordsView: View {
    @EnvironmentObject private var store: LearningStore
    @State private var search = ""
    @State private var section: WordSection = .myWords
    @State private var dictionaryResults: [LexiconEntry] = []

    private enum WordSection: String, CaseIterable, Identifiable {
        case myWords = "My Words"
        case upcoming = "Upcoming"
        case dictionary = "Dictionary"
        var id: String { rawValue }
    }

    private var filtered: [VocabularyItem] {
        let source = section == .upcoming ? store.upcomingWords : store.words.filter { $0.introducedAt != nil }
        let words = source.sorted { $0.frequencyRank < $1.frequencyRank }
        return search.isEmpty ? words : words.filter { $0.word.localizedCaseInsensitiveContains(search) || $0.conciseDefinition.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                VStack(spacing: 0) {
                    Picker("Word collection", selection: $section) {
                        ForEach(WordSection.allCases) { item in Text(item.rawValue).tag(item) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 10)

                    if section == .dictionary {
                        dictionaryList
                    } else {
                        learningList
                    }
                }
            }
            .navigationTitle("Words")
            .searchable(text: $search, prompt: "Search word or meaning")
            .onAppear(perform: updateDictionaryResults)
            .onChange(of: search) { _, _ in updateDictionaryResults() }
            .onChange(of: section) { _, _ in updateDictionaryResults() }
        }
    }

    private var learningList: some View {
        List(filtered) { word in
            NavigationLink { WordDetailView(word: word, state: state(for: word.id)) } label: {
                wordRow(word: word, state: state(for: word.id))
            }
            .listRowBackground(Color.white.opacity(0.35))
        }
        .overlay {
            if filtered.isEmpty {
                ContentUnavailableView(section == .upcoming ? "No upcoming words" : "No learned words yet", systemImage: "text.book.closed")
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var dictionaryList: some View {
        List(dictionaryResults) { entry in
            NavigationLink { DictionaryWordDetailView(entry: entry) } label: {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(entry.word).font(.lexiloDisplay(22, weight: .medium)).foregroundStyle(LexiloTheme.ink)
                        Text(entry.partOfSpeech).font(.caption).italic().foregroundStyle(LexiloTheme.sage)
                    }
                    Text(entry.definition).font(.caption).foregroundStyle(LexiloTheme.muted).lineLimit(1)
                }
                .padding(.vertical, 7)
            }
            .listRowBackground(Color.white.opacity(0.35))
        }
        .overlay {
            if !store.lexicon.isAvailable {
                ContentUnavailableView(
                    "Dictionary unavailable",
                    systemImage: "books.vertical",
                    description: Text("The bundled Open English WordNet database could not be opened.")
                )
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func wordRow(word: VocabularyItem, state: LearningState) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(word.word).font(.lexiloDisplay(22, weight: .medium)).foregroundStyle(LexiloTheme.ink)
                    Text(word.partOfSpeech).font(.caption).italic().foregroundStyle(LexiloTheme.sage)
                }
                Text(word.conciseDefinition).font(.caption).foregroundStyle(LexiloTheme.muted).lineLimit(1)
            }
            Spacer()
            StatePill(state: state)
        }
        .padding(.vertical, 7)
    }

    private func updateDictionaryResults() {
        guard section == .dictionary else { return }
        dictionaryResults = store.searchDictionary(search)
    }

    private func state(for id: UUID) -> LearningState {
        let related = store.cards.filter { $0.vocabularyID == id }
        if related.count == 2 && related.allSatisfy({ $0.learningState == .mastered }) { return .mastered }
        if related.contains(where: { $0.learningState != .new }) { return .learning }
        return .new
    }
}

private struct DictionaryWordDetailView: View {
    @EnvironmentObject private var store: LearningStore
    let entry: LexiconEntry
    @State private var added = false

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(entry.word).font(.lexiloDisplay(46, weight: .medium)).foregroundStyle(LexiloTheme.ink)
                    Text("\(entry.partOfSpeech)  ·  \(entry.ipa.isEmpty ? "pronunciation unavailable" : entry.ipa)")
                        .font(.subheadline).foregroundStyle(LexiloTheme.sage)
                    Divider()
                    Text(entry.definition).font(.title3).foregroundStyle(LexiloTheme.ink)
                    ForEach(entry.examples.prefix(3), id: \.self) { example in
                        Text("“\(example)”").font(.lexiloDisplay(19)).italic().foregroundStyle(LexiloTheme.muted)
                    }
                    Button {
                        _ = store.addToLearning(entry)
                        added = true
                    } label: {
                        Label(added ? "Added to learning" : "Add to learning", systemImage: added ? "checkmark" : "plus")
                            .font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 54)
                            .background(LexiloTheme.ink, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .disabled(added)
                }
                .padding(22)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct StatePill: View {
    let state: LearningState
    var body: some View {
        Text(state == .new ? "New" : state == .learning ? "Learning" : "Mastered")
            .font(.caption2.weight(.semibold)).foregroundStyle(state == .mastered ? LexiloTheme.sage : LexiloTheme.brass)
            .padding(.horizontal, 9).padding(.vertical, 5).background((state == .mastered ? LexiloTheme.sageLight : LexiloTheme.paperDeep), in: Capsule())
    }
}

struct WordDetailView: View {
    @EnvironmentObject private var speechPlayer: SpeechPlayer
    let word: VocabularyItem
    let state: LearningState
    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        StatePill(state: state)
                        Text(word.word).font(.lexiloDisplay(46, weight: .medium)).foregroundStyle(LexiloTheme.ink)
                        Text("\(word.partOfSpeech)  ·  \(word.ipa)").font(.subheadline).foregroundStyle(LexiloTheme.sage)
                    }
                    Divider().overlay(LexiloTheme.brass.opacity(0.4))
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MEANING").font(.caption.bold()).tracking(1.3).foregroundStyle(LexiloTheme.brass)
                        HStack(alignment: .top, spacing: 10) {
                            Text(word.conciseDefinition).font(.title3).foregroundStyle(LexiloTheme.ink)
                            Spacer(minLength: 8)
                            spokenTextButton(word.conciseDefinition, label: "Play definition for \(word.word)")
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("IN CONTEXT").font(.caption.bold()).tracking(1.3).foregroundStyle(LexiloTheme.brass)
                        ForEach(Array(word.examples.prefix(3)), id: \.self) { example in
                            HStack(alignment: .top, spacing: 10) {
                                Text("“\(example)”").font(.lexiloDisplay(21)).italic().foregroundStyle(LexiloTheme.ink)
                                Spacer(minLength: 8)
                                spokenTextButton(example, label: "Play example for \(word.word)")
                            }
                        }
                    }.padding(20).background(LexiloTheme.sageLight.opacity(0.52), in: RoundedRectangle(cornerRadius: 20))
                    HStack(spacing: 10) { Image(systemName: "arrow.left.arrow.right").foregroundStyle(LexiloTheme.sage); Text("Lexilo practices this word in both directions on separate days.").font(.caption).foregroundStyle(LexiloTheme.muted) }
                }.padding(22)
            }
        }.navigationBarTitleDisplayMode(.inline)
    }

    private func spokenTextButton(_ text: String, label: String) -> some View {
        Button { speechPlayer.play(text) } label: {
            Image(systemName: "speaker.wave.2.fill")
                .foregroundStyle(LexiloTheme.sage)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
