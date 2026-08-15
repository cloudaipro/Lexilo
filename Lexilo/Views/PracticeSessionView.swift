import SwiftUI

struct PracticeSessionView: View {
    let focusVocabularyIDs: Set<UUID>?
    let startWithPracticeAgain: Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LearningStore
    @EnvironmentObject private var speechPlayer: SpeechPlayer
    @State private var queue: [StudyCard] = []
    @State private var index = 0
    @State private var revealed = false
    @State private var completed = 0
    @State private var correctCount = 0
    @State private var loading = true
    @State private var answerText = ""
    @State private var usedHint = false
    @State private var answerWasCorrect: Bool?
    @State private var revealedWithoutAttempt = false
    @State private var presentedAt = Date.now
    @State private var scheduledInterval: Int?
    @State private var reporting = false
    @State private var isExtraPractice = false
    @FocusState private var answerFocused: Bool

    private let recallActionHeight: CGFloat = 72

    private var current: StudyCard? { index < queue.count ? queue[index] : nil }
    private var word: VocabularyItem? { current.flatMap { store.word(for: $0.vocabularyID) } }

    init(focusVocabularyIDs: Set<UUID>? = nil, startWithPracticeAgain: Bool = false) {
        self.focusVocabularyIDs = focusVocabularyIDs
        self.startWithPracticeAgain = startWithPracticeAgain
    }

    var body: some View {
        ZStack {
            PaperBackground()
            if loading { SwiftUI.ProgressView().tint(LexiloTheme.sage) }
            else if let card = current, let word { study(card: card, word: word) }
            else { completion }
        }
        .task { loadSession() }
        .confirmationDialog("What should we review?", isPresented: $reporting, titleVisibility: .visible) {
            if let card = current {
                Button("Definition is confusing") { report(card, reason: "Confusing definition") }
                Button("Example is not helpful") { report(card, reason: "Unhelpful example") }
                Button("Pronunciation or spelling issue") { report(card, reason: "Pronunciation or spelling") }
            }
        }
    }

    private func loadSession() {
        let roundSize = configuredRoundSize
        queue = if startWithPracticeAgain {
            store.practiceAgainCards()
        } else if let focusVocabularyIDs {
            store.startFocusedSession(vocabularyIDs: focusVocabularyIDs, limit: roundSize)
        } else {
            store.startRound(wordCount: roundSize)
        }
        isExtraPractice = startWithPracticeAgain && !queue.isEmpty
        loading = false
        beginCard()
        prepareUpcomingAudio()
    }

    private func study(card: StudyCard, word: VocabularyItem) -> some View {
        let sense = store.sense(for: card) ?? word.coreSense
        return VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.headline).frame(width: 42, height: 42).background(.white.opacity(0.65), in: Circle())
                }
                Spacer()
                Text("\(min(index + 1, queue.count)) of \(queue.count)").font(.subheadline.weight(.semibold)).foregroundStyle(LexiloTheme.muted)
                Spacer()
                Menu {
                    Button { pause(card) } label: { Label("Pause this sense", systemImage: "pause.circle") }
                    Button { wrongSense(card) } label: { Label("Wrong sense", systemImage: "arrow.triangle.branch") }
                    if !isExtraPractice {
                        Button { markTooEasy(card) } label: { Label("Too easy", systemImage: "forward.end") }
                    }
                    Divider()
                    Button { reporting = true } label: { Label("Report content", systemImage: "exclamationmark.bubble") }
                } label: {
                    Image(systemName: "ellipsis").font(.headline).frame(width: 42, height: 42).background(.white.opacity(0.65), in: Circle())
                }
                .foregroundStyle(LexiloTheme.ink)
            }
            .foregroundStyle(LexiloTheme.ink).padding(.horizontal, 20).padding(.top, 8)

            SwiftUI.ProgressView(value: Double(index), total: Double(max(queue.count, 1)))
                .tint(LexiloTheme.sage).padding(.horizontal, 24).padding(.top, 12)

            Spacer(minLength: 20)
            Text(isExtraPractice ? "PRACTICE AGAIN · \(card.direction.label.uppercased())" : card.direction.label.uppercased())
                .font(.caption.bold()).tracking(1.5).foregroundStyle(LexiloTheme.brass)
            Spacer().frame(height: 16)

            VStack(spacing: 16) {
                if card.direction == .recognition {
                    recognitionPrompt(word: word, sense: sense)
                } else {
                    productionPrompt(word: word, sense: sense)
                }
            }
            .frame(maxWidth: .infinity, minHeight: card.direction == .recall ? 300 : 380)
            .padding(24)
            .background(.white.opacity(0.63), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 30).stroke(LexiloTheme.brass.opacity(0.18)) }
            .padding(.horizontal, 20)

            Spacer()
            bottomAction(card)
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: revealed)
    }

    @ViewBuilder
    private func recognitionPrompt(word: VocabularyItem, sense: LexicalSense?) -> some View {
        Text(word.word).font(.lexiloDisplay(48, weight: .medium)).foregroundStyle(LexiloTheme.ink)
        HStack(spacing: 10) {
            Text(word.partOfSpeech).italic()
            Text(word.ipa)
            Button { speechPlayer.play(word) } label: { Image(systemName: "speaker.wave.2.fill") }
        }.font(.subheadline).foregroundStyle(LexiloTheme.sage)
        if revealed {
            answerDivider
            spokenPracticeText(sense?.definition ?? word.conciseDefinition, label: "Play definition", font: .title3, color: LexiloTheme.ink)
            feedbackDetails(word: word, sense: sense)
        } else {
            Text("Recall the meaning before revealing it.").font(.body).foregroundStyle(LexiloTheme.muted).padding(.top, 8)
        }
    }

    @ViewBuilder
    private func productionPrompt(word: VocabularyItem, sense: LexicalSense?) -> some View {
        spokenPracticeText(sense?.definition ?? word.conciseDefinition, label: "Play definition", font: .lexiloDisplay(28, weight: .medium), color: LexiloTheme.ink)
        Text(word.partOfSpeech).font(.subheadline).italic().foregroundStyle(LexiloTheme.sage)
        if revealed {
            answerDivider
            HStack(spacing: 8) {
                Image(systemName: answerWasCorrect == true ? "checkmark.circle.fill" : revealedWithoutAttempt ? "eye.fill" : "xmark.circle.fill")
                Text(answerWasCorrect == true ? "Correct" : revealedWithoutAttempt ? "Answer revealed" : "Not quite")
            }
            .font(.headline)
            .foregroundStyle(answerWasCorrect == true ? LexiloTheme.sage : revealedWithoutAttempt ? LexiloTheme.brass : LexiloTheme.danger)
            Text(word.word).font(.lexiloDisplay(42, weight: .medium)).foregroundStyle(LexiloTheme.ink)
            if answerWasCorrect == false && !revealedWithoutAttempt {
                VStack(spacing: 4) {
                    Text("You wrote: \(answerText)").foregroundStyle(LexiloTheme.muted)
                    Text("Expected: \(word.word)").fontWeight(.semibold).foregroundStyle(LexiloTheme.ink)
                }.font(.subheadline)
            }
            feedbackDetails(word: word, sense: sense)
            if isExtraPractice {
                Text("Practice Again does not change your scheduled review.")
                    .font(.caption).foregroundStyle(LexiloTheme.sage).padding(.top, 4)
            } else if let scheduledInterval {
                Text(scheduleExplanation(correct: answerWasCorrect == true, interval: scheduledInterval))
                    .font(.caption).foregroundStyle(LexiloTheme.sage).padding(.top, 4)
            }
        } else {
            TextField("Type the word", text: $answerText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($answerFocused)
                .onSubmit { if !answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { checkProduction(word: word, card: current!) } }
                .font(.title3)
                .padding(16)
                .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).stroke(LexiloTheme.sage.opacity(0.35)) }
            Button {
                usedHint = true
            } label: {
                Label(usedHint ? hint(for: word.word) : "Need a hint?", systemImage: "lightbulb")
                    .font(.caption.weight(.semibold)).foregroundStyle(LexiloTheme.brass)
            }.buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func feedbackDetails(word: VocabularyItem, sense: LexicalSense?) -> some View {
        if !word.ipa.isEmpty {
            HStack(spacing: 8) {
                Text(word.ipa).font(.subheadline).foregroundStyle(LexiloTheme.sage)
                Button { speechPlayer.play(word) } label: { Image(systemName: "speaker.wave.2.fill") }
                    .buttonStyle(.plain).foregroundStyle(LexiloTheme.sage)
            }
        }
        if let example = sense?.examples.first ?? word.examples.first {
            spokenPracticeText("“\(example)”", spokenText: example, label: "Play example", font: .lexiloDisplay(18), color: LexiloTheme.muted, italic: true)
        }
    }

    private var answerDivider: some View {
        Rectangle().fill(LexiloTheme.brass.opacity(0.35)).frame(width: 44, height: 1).padding(.vertical, 2)
    }

    @ViewBuilder
    private func bottomAction(_ card: StudyCard) -> some View {
        if card.direction == .recall {
            if revealed {
                Button { advance() } label: { primaryButtonLabel("Continue", symbol: "arrow.right") }
                    .buttonStyle(PressableScale()).padding(20)
            } else {
                VStack(spacing: 12) {
                    Button { if let word { checkProduction(word: word, card: card) } } label: { primaryButtonLabel("Check", symbol: "checkmark", height: recallActionHeight) }
                        .buttonStyle(PressableScale())
                        .disabled(answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)

                    Button {
                        if let word { revealProductionAnswer(word: word, card: card) }
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle().fill(LexiloTheme.sageLight).frame(width: 56, height: 56)
                                Image(systemName: "eye").font(.system(size: 25, weight: .semibold)).foregroundStyle(LexiloTheme.ink)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Reveal answer").font(.title3.weight(.semibold)).foregroundStyle(LexiloTheme.ink)
                                Text("I don’t know this one yet").font(.caption.weight(.semibold)).foregroundStyle(LexiloTheme.sage)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right").font(.headline.weight(.semibold)).foregroundStyle(LexiloTheme.ink)
                        }
                        .padding(.horizontal, 22)
                        .frame(maxWidth: .infinity, minHeight: recallActionHeight, alignment: .leading)
                        .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(LexiloTheme.ink.opacity(0.14), lineWidth: 1.5) }
                    }
                    .buttonStyle(PressableScale())
                    .accessibilityLabel("Reveal answer")
                    .accessibilityHint("I don't know this one yet")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        } else if revealed {
            HStack(spacing: 12) {
                answerButton("Don’t know", symbol: "xmark", color: LexiloTheme.danger) { answerRecognition(card, correct: false) }
                answerButton("Know", symbol: "checkmark", color: LexiloTheme.sage) { answerRecognition(card, correct: true) }
            }.padding(20)
        } else {
            Button { revealed = true } label: { primaryButtonLabel("Reveal answer", symbol: "eye") }
                .buttonStyle(PressableScale()).padding(20)
        }
    }

    private func primaryButtonLabel(_ title: String, symbol: String, height: CGFloat = 58) -> some View {
        Label(title, systemImage: symbol).font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: height)
            .background(LexiloTheme.ink, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
    }

    private func spokenPracticeText(_ displayedText: String, spokenText: String? = nil, label: String, font: Font, color: Color, italic: Bool = false) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Group { if italic { Text(displayedText).italic() } else { Text(displayedText) } }
                .font(font)
                .multilineTextAlignment(.center)
                .foregroundStyle(color)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            Button { speechPlayer.play(spokenText ?? displayedText) } label: {
                Image(systemName: "speaker.wave.2.fill").font(.subheadline).foregroundStyle(LexiloTheme.sage).frame(width: 32, height: 32)
            }.buttonStyle(.plain).accessibilityLabel(label)
        }.padding(.horizontal, 8)
    }

    private func answerButton(_ title: String, symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 58)
                .background(color, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        }.buttonStyle(PressableScale())
    }

    private func checkProduction(word: VocabularyItem, card: StudyCard) {
        guard !revealed else { return }
        answerFocused = false
        let correct = AnswerEvaluator.isCorrect(answerText, expected: word.word, accepted: word.acceptedAnswers)
        let latency = Date.now.timeIntervalSince(presentedAt)
        if !isExtraPractice {
            scheduledInterval = store.answer(cardID: card.id, correct: correct, response: answerText, responseTime: latency, usedHint: usedHint)
        }
        answerWasCorrect = correct
        completed += 1
        if correct { correctCount += 1 } else { queue.append(card) }
        revealed = true
    }

    private func revealProductionAnswer(word: VocabularyItem, card: StudyCard) {
        guard !revealed else { return }
        answerFocused = false
        let latency = Date.now.timeIntervalSince(presentedAt)
        if !isExtraPractice {
            scheduledInterval = store.answer(cardID: card.id, correct: false, response: nil, responseTime: latency, usedHint: usedHint)
        }
        answerWasCorrect = false
        revealedWithoutAttempt = true
        answerText = ""
        completed += 1
        queue.append(card)
        revealed = true
    }

    private func answerRecognition(_ card: StudyCard, correct: Bool) {
        if !isExtraPractice {
            _ = store.answer(cardID: card.id, correct: correct, responseTime: Date.now.timeIntervalSince(presentedAt))
        }
        completed += 1
        if correct { correctCount += 1 } else { queue.append(card) }
        advance()
    }

    private func markTooEasy(_ card: StudyCard) {
        _ = store.answer(cardID: card.id, correct: true, responseTime: Date.now.timeIntervalSince(presentedAt), tooEasy: true)
        completed += 1
        correctCount += 1
        advance()
    }

    private func pause(_ card: StudyCard) {
        store.pause(vocabularyID: card.vocabularyID, senseID: card.senseID)
        advance()
    }

    private func wrongSense(_ card: StudyCard) {
        store.markWrongSense(vocabularyID: card.vocabularyID, senseID: card.senseID)
        advance()
    }

    private func report(_ card: StudyCard, reason: String) {
        store.reportContent(vocabularyID: card.vocabularyID, senseID: card.senseID, reason: reason)
    }

    private func advance() {
        index += 1
        beginCard()
        prepareUpcomingAudio()
    }

    private func beginCard() {
        revealed = false
        answerText = ""
        usedHint = false
        answerWasCorrect = nil
        revealedWithoutAttempt = false
        scheduledInterval = nil
        presentedAt = .now
        if current?.direction == .recall {
            Task { try? await Task.sleep(for: .milliseconds(250)); answerFocused = true }
        }
    }

    private func hint(for word: String) -> String {
        let first = word.first.map(String.init) ?? "?"
        return "Starts with \(first.uppercased()) · \(word.count) characters"
    }

    private func scheduleExplanation(correct: Bool, interval: Int) -> String {
        correct ? "Correct\(usedHint ? " with a hint" : "") — next review in \(interval) day\(interval == 1 ? "" : "s")." : "Needs recall — it will return tomorrow."
    }

    private func prepareUpcomingAudio() {
        for card in queue.dropFirst(index).prefix(2) {
            if let word = store.word(for: card.vocabularyID) { speechPlayer.prepare(word) }
        }
    }

    private var configuredRoundSize: Int {
        max(1, UserDefaults.standard.object(forKey: "newWordLimit") as? Int ?? 5)
    }

    private func startNextRound() {
        startSession(with: store.startRound(wordCount: configuredRoundSize), practiceAgain: false)
    }

    private func startPracticeAgain() {
        startSession(with: store.practiceAgainCards(), practiceAgain: true)
    }

    private func startSession(with cards: [StudyCard], practiceAgain: Bool) {
        guard !cards.isEmpty else { return }
        queue = cards
        index = 0
        completed = 0
        correctCount = 0
        isExtraPractice = practiceAgain
        beginCard()
        prepareUpcomingAudio()
    }

    private var completion: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle().fill(LexiloTheme.sageLight).frame(width: 98, height: 98)
                Image(systemName: "leaf.fill").font(.system(size: 38)).foregroundStyle(LexiloTheme.sage)
            }
            Text(isExtraPractice ? "Practice Again complete" : "Round complete")
                .font(.lexiloDisplay(36, weight: .semibold)).foregroundStyle(LexiloTheme.ink)
            Text(completionMessage)
                .font(.body).multilineTextAlignment(.center).foregroundStyle(LexiloTheme.muted).padding(.horizontal, 36)
            if completed > 0 {
                HStack(spacing: 32) {
                    completionStat("\(completed)", "Reviewed")
                    Divider().frame(height: 44)
                    completionStat("\(Int(Double(correctCount) / Double(max(completed, 1)) * 100))%", "Recall")
                }.padding(.vertical, 12)
            }
            Spacer()
            VStack(spacing: 12) {
                if !store.roundCards(wordCount: 1).isEmpty {
                    Button { startNextRound() } label: { primaryButtonLabel("Next Round", symbol: "arrow.right") }
                        .buttonStyle(PressableScale())
                }
                if store.practicedWordCount() > 0 {
                    Button { startPracticeAgain() } label: { secondaryButtonLabel("Practice Again", symbol: "arrow.clockwise") }
                        .buttonStyle(PressableScale())
                }
                Button { dismiss() } label: {
                    Label("Back to Today", systemImage: "house")
                        .font(.headline).foregroundStyle(LexiloTheme.muted)
                        .frame(maxWidth: .infinity).frame(height: 48)
                }.buttonStyle(.plain)
            }
            .padding(20)
        }
    }

    private var completionMessage: String {
        guard completed > 0 else { return "No more words are available right now." }
        let todayCount = store.practicedWordCount()
        if isExtraPractice {
            return "You practised today’s \(todayCount) words again. Your scheduled reviews are unchanged."
        }
        return "\(todayCount) word\(todayCount == 1 ? "" : "s") practised today. Add another round or repeat today’s set."
    }

    private func secondaryButtonLabel(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.headline)
            .foregroundStyle(LexiloTheme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(LexiloTheme.ink.opacity(0.16)) }
    }

    private func completionStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.title2.bold()).foregroundStyle(LexiloTheme.ink)
            Text(label).font(.caption).foregroundStyle(LexiloTheme.muted)
        }
    }
}
