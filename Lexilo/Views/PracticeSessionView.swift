import SwiftUI

struct PracticeSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LearningStore
    @EnvironmentObject private var speechPlayer: SpeechPlayer
    @State private var queue: [StudyCard] = []
    @State private var index = 0
    @State private var revealed = false
    @State private var completed = 0
    @State private var correctCount = 0
    @State private var loading = true

    private var current: StudyCard? { index < queue.count ? queue[index] : nil }
    private var word: VocabularyItem? { current.flatMap { store.word(for: $0.vocabularyID) } }

    var body: some View {
        ZStack {
            PaperBackground()
            if loading { SwiftUI.ProgressView().tint(LexiloTheme.sage) }
            else if let card = current, let word { study(card: card, word: word) }
            else { completion }
        }
        .task { loadSession() }
    }

    private func loadSession() {
        let dailyGoal = UserDefaults.standard.object(forKey: "dailyGoal") as? Int ?? 10
        queue = store.startSession(limit: max(1, dailyGoal))
        loading = false
        prepareUpcomingAudio()
    }

    private func study(card: StudyCard, word: VocabularyItem) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: { Image(systemName: "xmark").font(.headline).frame(width: 42, height: 42).background(.white.opacity(0.65), in: Circle()) }
                Spacer()
                Text("\(min(index + 1, queue.count)) of \(queue.count)").font(.subheadline.weight(.semibold)).foregroundStyle(LexiloTheme.muted)
                Spacer()
                Color.clear.frame(width: 42, height: 42)
            }
            .foregroundStyle(LexiloTheme.ink).padding(.horizontal, 20).padding(.top, 8)

            SwiftUI.ProgressView(value: Double(index), total: Double(max(queue.count, 1))).tint(LexiloTheme.sage).padding(.horizontal, 24).padding(.top, 12)

            Spacer(minLength: 28)
            Text(card.direction.label.uppercased()).font(.caption.bold()).tracking(1.5).foregroundStyle(LexiloTheme.brass)
            Spacer().frame(height: 22)

            VStack(spacing: 18) {
                if card.direction == .recognition {
                    Text(word.word).font(.lexiloDisplay(48, weight: .medium)).foregroundStyle(LexiloTheme.ink)
                    HStack(spacing: 10) {
                        Text(word.partOfSpeech).italic()
                        Text(word.ipa)
                        Button { speechPlayer.play(word) } label: { Image(systemName: "speaker.wave.2.fill") }
                    }.font(.subheadline).foregroundStyle(LexiloTheme.sage)
                } else {
                    Text(word.conciseDefinition).font(.lexiloDisplay(30, weight: .medium)).multilineTextAlignment(.center).foregroundStyle(LexiloTheme.ink).padding(.horizontal, 8)
                    Text(word.partOfSpeech).font(.subheadline).italic().foregroundStyle(LexiloTheme.sage)
                }

                if revealed {
                    Rectangle().fill(LexiloTheme.brass.opacity(0.35)).frame(width: 44, height: 1).padding(.vertical, 4)
                    if card.direction == .recognition {
                        Text(word.conciseDefinition).font(.title3).multilineTextAlignment(.center).foregroundStyle(LexiloTheme.ink)
                    } else {
                        Text(word.word).font(.lexiloDisplay(43, weight: .medium)).foregroundStyle(LexiloTheme.ink)
                        Text(word.ipa).font(.subheadline).foregroundStyle(LexiloTheme.sage)
                    }
                    ForEach(Array(word.examples.prefix(3)), id: \.self) { example in
                        Text("“\(example)”")
                            .font(.lexiloDisplay(18))
                            .italic()
                            .multilineTextAlignment(.center)
                            .foregroundStyle(LexiloTheme.muted)
                            .padding(.top, 2)
                    }
                } else {
                    Text(card.direction == .recognition ? "Do you know this word?" : "Which word fits this meaning?")
                        .font(.body).foregroundStyle(LexiloTheme.muted).padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 350)
            .padding(26)
            .background(.white.opacity(0.63), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 30).stroke(LexiloTheme.brass.opacity(0.18)) }
            .padding(.horizontal, 20)

            Spacer()
            if revealed { answerButtons(card) } else { revealButton }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: revealed)
    }

    private var revealButton: some View {
        Button { revealed = true } label: {
            Text("Reveal answer").font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 58).background(LexiloTheme.ink, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        }.buttonStyle(PressableScale()).padding(20)
    }

    private func answerButtons(_ card: StudyCard) -> some View {
        HStack(spacing: 12) {
            answerButton("Don’t know", symbol: "xmark", color: LexiloTheme.danger) { answer(card, correct: false) }
            answerButton("Know", symbol: "checkmark", color: LexiloTheme.sage) { answer(card, correct: true) }
        }.padding(20)
    }

    private func answerButton(_ title: String, symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 58).background(color, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        }.buttonStyle(PressableScale())
    }

    private func answer(_ card: StudyCard, correct: Bool) {
        store.answer(cardID: card.id, correct: correct)
        completed += 1
        if correct { correctCount += 1 } else { queue.append(card) }
        revealed = false
        index += 1
        prepareUpcomingAudio()
    }

    private func prepareUpcomingAudio() {
        for card in queue.dropFirst(index).prefix(2) {
            if let word = store.word(for: card.vocabularyID) {
                speechPlayer.prepare(word)
            }
        }
    }

    private var completion: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle().fill(LexiloTheme.sageLight).frame(width: 98, height: 98)
                Image(systemName: "leaf.fill").font(.system(size: 38)).foregroundStyle(LexiloTheme.sage)
            }
            Text("Practice complete").font(.lexiloDisplay(36, weight: .semibold)).foregroundStyle(LexiloTheme.ink)
            Text(completed == 0 ? "You’re all caught up for today." : "You gave \(correctCount) confident answers. The rest will return when they can strengthen your memory.")
                .font(.body).multilineTextAlignment(.center).foregroundStyle(LexiloTheme.muted).padding(.horizontal, 36)
            if completed > 0 {
                HStack(spacing: 32) {
                    completionStat("\(completed)", "Reviewed")
                    Divider().frame(height: 44)
                    completionStat("\(Int(Double(correctCount) / Double(max(completed, 1)) * 100))%", "Recall")
                }.padding(.vertical, 12)
            }
            Spacer()
            Button { dismiss() } label: {
                Text("Back to Today").font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 58).background(LexiloTheme.ink, in: RoundedRectangle(cornerRadius: 19))
            }.buttonStyle(PressableScale()).padding(20)
        }
    }

    private func completionStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) { Text(value).font(.title2.bold()).foregroundStyle(LexiloTheme.ink); Text(label).font(.caption).foregroundStyle(LexiloTheme.muted) }
    }
}
