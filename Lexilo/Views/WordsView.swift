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
                    if let learnedWord = store.words.first(where: { $0.lexiconID == entry.id }) {
                        DifficultyIndicator(
                            value: store.averageDifficulty(vocabularyID: learnedWord.id, includePaused: true),
                            measured: store.hasReviewedCard(vocabularyID: learnedWord.id, includePaused: true)
                        )
                    } else {
                        Label("Difficulty measured after adding to learning", systemImage: "gauge.with.dots.needle.67percent")
                            .font(.caption2).foregroundStyle(LexiloTheme.muted)
                    }
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
                DifficultyIndicator(
                    value: store.averageDifficulty(vocabularyID: word.id, includePaused: true),
                    measured: store.hasReviewedCard(vocabularyID: word.id, includePaused: true)
                )
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
        let related = store.cards.filter { $0.vocabularyID == id && !$0.isPaused }
        if related.count >= 2 && related.allSatisfy({ $0.learningState == .mastered }) { return .mastered }
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
                    if let learnedWord = store.words.first(where: { $0.lexiconID == entry.id }) {
                        DifficultyIndicator(
                            value: store.averageDifficulty(vocabularyID: learnedWord.id, includePaused: true),
                            measured: store.hasReviewedCard(vocabularyID: learnedWord.id, includePaused: true)
                        )
                    } else {
                        Label("Difficulty measured after adding to learning", systemImage: "gauge.with.dots.needle.67percent")
                            .font(.caption).foregroundStyle(LexiloTheme.muted)
                    }
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
    @EnvironmentObject private var store: LearningStore
    @EnvironmentObject private var speechPlayer: SpeechPlayer
    let word: VocabularyItem
    let state: LearningState
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
                        StatePill(state: state)
                        Text(currentWord.word).font(.lexiloDisplay(46, weight: .medium)).foregroundStyle(LexiloTheme.ink)
                        Text("\(currentWord.partOfSpeech)  ·  \(currentWord.ipa)").font(.subheadline).foregroundStyle(LexiloTheme.sage)
                    }
                    Divider().overlay(LexiloTheme.brass.opacity(0.4))
                    memoryAxes
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SENSES").font(.caption.bold()).tracking(1.3).foregroundStyle(LexiloTheme.brass)
                        ForEach(currentWord.senses) { sense in senseCard(sense) }
                    }
                    HStack(spacing: 10) { Image(systemName: "arrow.left.arrow.right").foregroundStyle(LexiloTheme.sage); Text("Lexilo practices this word in both directions on separate days.").font(.caption).foregroundStyle(LexiloTheme.muted) }
                }.padding(22)
            }
        }.navigationBarTitleDisplayMode(.inline)
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

    private var memoryAxes: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MEMORY").font(.caption.bold()).tracking(1.3).foregroundStyle(LexiloTheme.brass)
            memoryRow("Understand", value: store.strength(vocabularyID: currentWord.id, direction: .recognition))
            memoryRow("Recall", value: store.strength(vocabularyID: currentWord.id, direction: .recall))
            Divider().overlay(LexiloTheme.brass.opacity(0.18))
            Text("DIFFICULTY").font(.caption.bold()).tracking(1.3).foregroundStyle(LexiloTheme.brass)
            difficultySummaryRow("Understand", direction: .recognition)
            difficultySummaryRow("Recall", direction: .recall)
            Text("Difficulty is card-specific: higher values mean the scheduler has found the direction harder to retain.")
                .font(.caption2).foregroundStyle(LexiloTheme.muted)
        }
        .padding(18).background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 20))
    }

    private func memoryRow(_ title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack { Text(title).font(.subheadline); Spacer(); Text(memoryLabel(value)).font(.caption.bold()).foregroundStyle(LexiloTheme.sage) }
            SwiftUI.ProgressView(value: value).tint(LexiloTheme.sage)
        }
    }

    private func memoryLabel(_ value: Double) -> String {
        value >= 0.9 ? "Strong" : value >= 0.75 ? "Fading" : "Needs recall"
    }

    @ViewBuilder
    private func difficultySummaryRow(_ title: String, direction: CardDirection) -> some View {
        if let value = store.averageDifficulty(vocabularyID: currentWord.id, direction: direction, includePaused: true) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text("\(value.formatted(.number.precision(.fractionLength(1)) )) / 10")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(LexiloTheme.ink)
                Text(store.hasReviewedCard(vocabularyID: currentWord.id, direction: direction, includePaused: true) ? store.difficultyLabel(for: value) : "Baseline")
                    .font(.caption.bold()).foregroundStyle(LexiloTheme.sage)
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
                Menu {
                    if sense.isActive && !sense.isPaused {
                        Button { store.pause(vocabularyID: currentWord.id, senseID: sense.id) } label: { Label("Pause sense", systemImage: "pause") }
                    } else {
                        Button { store.resume(vocabularyID: currentWord.id, senseID: sense.id) } label: { Label("Learn this sense", systemImage: "play") }
                    }
                    Button { store.markWrongSense(vocabularyID: currentWord.id, senseID: sense.id) } label: { Label("Wrong sense", systemImage: "arrow.triangle.branch") }
                    Button { store.markTooEasy(vocabularyID: currentWord.id, senseID: sense.id) } label: { Label("Too easy", systemImage: "forward.end") }
                    Button { store.reportContent(vocabularyID: currentWord.id, senseID: sense.id, reason: "Reported from word detail") } label: { Label("Report content", systemImage: "exclamationmark.bubble") }
                } label: { Image(systemName: "ellipsis.circle").foregroundStyle(LexiloTheme.sage) }
            }
            Text(sense.definition).font(.title3).foregroundStyle(LexiloTheme.ink)
            senseDifficulty(sense)
            if !sense.collocations.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("COMMON PAIRINGS").font(.caption2.bold()).foregroundStyle(LexiloTheme.brass)
                    Text(sense.collocations.joined(separator: "  ·  ")).font(.subheadline).foregroundStyle(LexiloTheme.ink)
                }
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

    private func senseDifficulty(_ sense: LexicalSense) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CARD DIFFICULTY").font(.caption2.bold()).tracking(1).foregroundStyle(LexiloTheme.brass)
            difficultyCardRow(sense: sense, direction: .recognition, title: "Understand")
            difficultyCardRow(sense: sense, direction: .recall, title: "Recall")
        }
        .padding(12)
        .background(.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func difficultyCardRow(sense: LexicalSense, direction: CardDirection, title: String) -> some View {
        if let card = store.card(vocabularyID: currentWord.id, senseID: sense.id, direction: direction) {
            HStack(spacing: 6) {
                Text(title).font(.caption)
                Spacer()
                Text("\(card.difficulty.formatted(.number.precision(.fractionLength(1)))) / 10")
                    .font(.caption.weight(.semibold)).foregroundStyle(LexiloTheme.ink)
                Text(card.lastReviewedDate == nil ? "Baseline" : store.difficultyLabel(for: card.difficulty))
                    .font(.caption2.bold()).foregroundStyle(LexiloTheme.sage)
            }
        } else {
            Text("\(title) · not available yet").font(.caption).foregroundStyle(LexiloTheme.muted)
        }
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

struct DifficultyIndicator: View {
    let value: Double?
    let measured: Bool

    var body: some View {
        if let value {
            Label {
                Text("Difficulty \(value.formatted(.number.precision(.fractionLength(1)))) / 10 · \(measured ? difficultyLabel : "Baseline")")
            } icon: {
                Image(systemName: "gauge.with.dots.needle.67percent")
            }
            .font(.caption2)
            .foregroundStyle(measured ? LexiloTheme.sage : LexiloTheme.muted)
        } else {
            Label("Difficulty unavailable", systemImage: "gauge.with.dots.needle.67percent")
                .font(.caption2).foregroundStyle(LexiloTheme.muted)
        }
    }

    private var difficultyLabel: String {
        if value ?? 5 < 3.5 { return "Easy" }
        if value ?? 5 < 6.5 { return "Moderate" }
        return "Hard"
    }
}
