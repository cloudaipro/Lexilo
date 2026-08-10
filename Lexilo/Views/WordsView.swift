import SwiftUI

struct WordsView: View {
    @EnvironmentObject private var store: LearningStore
    @State private var search = ""

    private var filtered: [VocabularyItem] {
        let words = store.words.sorted { $0.frequencyRank < $1.frequencyRank }
        return search.isEmpty ? words : words.filter { $0.word.localizedCaseInsensitiveContains(search) || $0.conciseDefinition.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                List(filtered) { word in
                    NavigationLink { WordDetailView(word: word, state: state(for: word.id)) } label: {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 8) {
                                    Text(word.word).font(.lexiloDisplay(22, weight: .medium)).foregroundStyle(LexiloTheme.ink)
                                    Text(word.partOfSpeech).font(.caption).italic().foregroundStyle(LexiloTheme.sage)
                                }
                                Text(word.conciseDefinition).font(.caption).foregroundStyle(LexiloTheme.muted).lineLimit(1)
                            }
                            Spacer()
                            StatePill(state: state(for: word.id))
                        }.padding(.vertical, 7)
                    }
                    .listRowBackground(Color.white.opacity(0.35))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Words")
            .searchable(text: $search, prompt: "Search word or meaning")
        }
    }

    private func state(for id: UUID) -> LearningState {
        let related = store.cards.filter { $0.vocabularyID == id }
        if related.count == 2 && related.allSatisfy({ $0.learningState == .mastered }) { return .mastered }
        if related.contains(where: { $0.learningState != .new }) { return .learning }
        return .new
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
                        Text(word.conciseDefinition).font(.title3).foregroundStyle(LexiloTheme.ink)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("IN CONTEXT").font(.caption.bold()).tracking(1.3).foregroundStyle(LexiloTheme.brass)
                        Text("“\(word.example)”").font(.lexiloDisplay(21)).italic().foregroundStyle(LexiloTheme.ink)
                    }.padding(20).background(LexiloTheme.sageLight.opacity(0.52), in: RoundedRectangle(cornerRadius: 20))
                    HStack(spacing: 10) { Image(systemName: "arrow.left.arrow.right").foregroundStyle(LexiloTheme.sage); Text("Lexilo practices this word in both directions on separate days.").font(.caption).foregroundStyle(LexiloTheme.muted) }
                }.padding(22)
            }
        }.navigationBarTitleDisplayMode(.inline)
    }
}
