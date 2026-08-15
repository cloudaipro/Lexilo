import SwiftUI

struct WordsView: View {
    @EnvironmentObject private var store: LearningStore
    @State private var search = ""
    @State private var section: WordSection = .myWords

    private enum WordSection: String, CaseIterable, Identifiable {
        case myWords = "My Words"
        case upcoming = "Upcoming"
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

                    learningList
                }
            }
            .navigationTitle("Words")
            .searchable(text: $search, prompt: "Search word or meaning")
        }
    }

    private var learningList: some View {
        List(filtered) { word in
            NavigationLink { WordDetailView(word: word) } label: {
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

    private func state(for id: UUID) -> LearningState {
        let related = store.cards.filter { $0.vocabularyID == id && !$0.isPaused }
        if related.count >= 2 && related.allSatisfy({ $0.learningState == .mastered }) { return .mastered }
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
    @EnvironmentObject private var store: LearningStore
    @EnvironmentObject private var speechPlayer: SpeechPlayer
    let word: VocabularyItem
    @AppStorage("translationEnabled") private var translationEnabled = false
    @State private var editingTranslationFor: UUID?
    @State private var showingTranslationEditor = false
    @State private var translationDraft = ""

    private var currentWord: VocabularyItem { store.word(for: word.id) ?? word }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 14) {
                            Text(currentWord.word).font(.lexiloDisplay(46, weight: .medium)).foregroundStyle(LexiloTheme.ink)
                            Spacer(minLength: 8)
                            Button { speechPlayer.play(currentWord) } label: {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundStyle(LexiloTheme.sage)
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Play pronunciation for \(currentWord.word)")
                        }
                        Text("\(currentWord.partOfSpeech)  ·  \(currentWord.ipa)").font(.subheadline).foregroundStyle(LexiloTheme.sage)
                    }
                    Divider().overlay(LexiloTheme.brass.opacity(0.4))
                    VStack(alignment: .leading, spacing: 12) {
                        Text("MEANINGS").font(.caption.bold()).tracking(1.3).foregroundStyle(LexiloTheme.brass)
                        ForEach(currentWord.senses) { sense in senseCard(sense) }
                    }
                }
                .padding(22)
                .padding(.top, -36)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(LexiloTheme.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showingTranslationEditor) {
            NavigationStack {
                Form {
                    Section("Personal translation") {
                        TextField("Translation", text: $translationDraft, axis: .vertical)
                        Text("English remains the primary definition. Personal translations are labeled and are not presented as reviewed dictionary content.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("Add translation")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingTranslationEditor = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if let senseID = editingTranslationFor {
                                store.updateTranslation(vocabularyID: currentWord.id, senseID: senseID, text: translationDraft)
                            }
                            showingTranslationEditor = false
                        }
                    }
                }
            }
        }
    }

    private func senseCard(_ sense: LexicalSense) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(sense.priority.label.uppercased()).font(.caption2.bold()).tracking(1).foregroundStyle(LexiloTheme.brass)
                    if !sense.usageLabel.isEmpty { Text(sense.usageLabel).font(.caption).italic().foregroundStyle(LexiloTheme.sage) }
                }
                Spacer()
            }
            Text(sense.definition).font(.title3).foregroundStyle(LexiloTheme.ink)
            if !sense.collocations.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("COMMON PAIRINGS").font(.caption2.bold()).foregroundStyle(LexiloTheme.brass)
                    Text(sense.collocations.joined(separator: "  ·  ")).font(.subheadline).foregroundStyle(LexiloTheme.ink)
                }
            }
            if !sense.examples.isEmpty {
                Text("EXAMPLES").font(.caption2.bold()).tracking(1).foregroundStyle(LexiloTheme.brass)
            }
            ForEach(sense.examples.prefix(3), id: \.self) { example in
                HStack(alignment: .top, spacing: 10) {
                    Text("“\(example)”").font(.lexiloDisplay(19)).italic().foregroundStyle(LexiloTheme.ink)
                    Spacer(minLength: 8)
                    spokenTextButton(example, label: "Play example for \(currentWord.word)")
                }
            }
            if translationEnabled {
                if let translation = sense.translation {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("TRANSLATION").font(.caption2.bold()).foregroundStyle(LexiloTheme.brass)
                        Text(translation).foregroundStyle(LexiloTheme.ink)
                        Text(sense.translationProvenance == .reviewed ? "Reviewed by you" : "Personal translation · not yet reviewed")
                            .font(.caption2).foregroundStyle(LexiloTheme.muted)
                        if sense.translationProvenance != .reviewed {
                            Button("Mark as reviewed") { store.confirmTranslation(vocabularyID: currentWord.id, senseID: sense.id) }
                                .font(.caption.weight(.semibold)).foregroundStyle(LexiloTheme.sage)
                        }
                    }
                }
                Button(sense.translation == nil ? "Add personal translation" : "Edit translation") {
                    translationDraft = sense.translation ?? ""
                    editingTranslationFor = sense.id
                    showingTranslationEditor = true
                }.font(.caption.weight(.semibold)).foregroundStyle(LexiloTheme.sage)
            }
            if !sense.isActive || sense.isPaused {
                Label(sense.isPaused ? "Paused" : "Unlocks after the core meaning is strong", systemImage: sense.isPaused ? "pause.circle" : "lock")
                    .font(.caption).foregroundStyle(LexiloTheme.muted)
            }
        }
        .padding(18)
        .background((sense.isActive && !sense.isPaused ? LexiloTheme.sageLight : LexiloTheme.paperDeep).opacity(0.5), in: RoundedRectangle(cornerRadius: 20))
        .opacity(sense.isActive && !sense.isPaused ? 1 : 0.72)
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
