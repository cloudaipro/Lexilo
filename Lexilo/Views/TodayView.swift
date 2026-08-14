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

private enum TodayPracticeLaunch: Int, Identifiable {
    case round
    case practiceAgain
    var id: Int { rawValue }
}

struct TodayView: View {
    @EnvironmentObject private var store: LearningStore
    @EnvironmentObject private var speechPlayer: SpeechPlayer
    @State private var practiceLaunch: TodayPracticeLaunch?
    @AppStorage("newWordLimit") private var configuredRoundSize = 5

    private var completedToday: Int { store.practicedWordCount() }
    private var goal: Int { max(1, configuredRoundSize) }
    private var progress: Double { min(1, Double(completedToday) / Double(max(goal, 1))) }
    private var streak: Int { store.currentStreak(goal: goal) }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        dailyFocus
                        detailRow
                        featuredWord
                        learningNote
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(item: $practiceLaunch) { launch in
                PracticeSessionView(startWithPracticeAgain: launch == .practiceAgain)
            }
        }
        .task(id: store.featuredWord()?.id) {
            if let word = store.featuredWord() { speechPlayer.prepare(word) }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.caption.weight(.semibold)).textCase(.uppercase).tracking(1.2).foregroundStyle(LexiloTheme.brass)
                Text(TodayGreeting.text(for: .now))
                    .accessibilityIdentifier("today-greeting")
                    .font(.lexiloDisplay(34, weight: .medium)).foregroundStyle(LexiloTheme.ink)
            }
            Spacer()
            ZStack {
                Circle().fill(LexiloTheme.sageLight).frame(width: 48, height: 48)
                Image(systemName: "leaf.fill").foregroundStyle(LexiloTheme.sage)
            }
        }
        .padding(.top, 12)
    }

    private var dailyFocus: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(completedToday >= goal ? "Daily round complete" : "Your daily round")
                        .font(.lexiloDisplay(25, weight: .semibold)).foregroundStyle(.white)
                    Text(completedToday >= goal ? "Keep going with another round, or repeat today’s words." : "Start with \(goal) words. Add more when you want.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.72))
                }
                Spacer()
                ZStack {
                    Circle().stroke(.white.opacity(0.18), lineWidth: 5)
                    Circle().trim(from: 0, to: progress).stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
                    Text(completedToday >= goal ? "✓" : "\(completedToday)/\(goal)").font(.caption.bold()).foregroundStyle(.white)
                }.frame(width: 54, height: 54)
            }
            Button { practiceLaunch = .round } label: {
                HStack {
                    Text(completedToday == 0 ? "Start practice" : "Next Round")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.headline).foregroundStyle(LexiloTheme.ink)
                .padding(.horizontal, 18).frame(height: 54)
                .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }.buttonStyle(PressableScale())
                .disabled(!store.lexicon.isAvailable)
            if completedToday > 0 {
                Button { practiceLaunch = .practiceAgain } label: {
                    Label("Practice Again · \(completedToday) words", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.86))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(22)
        .background(LexiloTheme.ink, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: LexiloTheme.ink.opacity(0.14), radius: 18, y: 10)
    }

    private var detailRow: some View {
        HStack(spacing: 12) {
            stat(value: "\(completedToday)", label: "Words today", symbol: "text.book.closed")
            stat(value: "Day \(streak)", label: "Practice streak", symbol: "flame")
        }
    }

    private func stat(value: String, label: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.headline).foregroundStyle(LexiloTheme.brass)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.title3.bold()).foregroundStyle(LexiloTheme.ink)
                Text(label).font(.caption).foregroundStyle(LexiloTheme.muted)
            }
            Spacer()
        }.padding(16).background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var featuredWord: some View {
        if let word = store.featuredWord() {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Text("A WORD TO KEEP CLOSE").font(.caption2.bold()).tracking(1.4).foregroundStyle(LexiloTheme.brass)
                    Spacer()
                    Button {
                        speechPlayer.play(word)
                    } label: {
                        Image(systemName: "speaker.wave.2")
                            .foregroundStyle(LexiloTheme.sage)
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Play pronunciation for \(word.word)")
                    .accessibilityIdentifier("featured-word-pronunciation")
                }
                Text(word.word).font(.lexiloDisplay(34, weight: .medium)).foregroundStyle(LexiloTheme.ink)
                DifficultyIndicator(
                    value: store.averageDifficulty(vocabularyID: word.id, includePaused: true),
                    measured: store.hasReviewedCard(vocabularyID: word.id, includePaused: true)
                )
                HStack(alignment: .top, spacing: 10) {
                    Text(word.conciseDefinition).font(.body).foregroundStyle(LexiloTheme.muted)
                    Spacer(minLength: 8)
                    spokenTextButton(word.conciseDefinition, label: "Play definition for \(word.word)")
                }
                if let example = word.examples.first {
                    Divider().overlay(LexiloTheme.brass.opacity(0.35))
                    HStack(alignment: .top, spacing: 10) {
                        Text("“\(example)”").font(.lexiloDisplay(17)).italic().foregroundStyle(LexiloTheme.ink.opacity(0.82))
                        Spacer(minLength: 8)
                        spokenTextButton(example, label: "Play example for \(word.word)")
                    }
                }
            }
            .padding(20).background(LexiloTheme.paperDeep.opacity(0.55), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 22).stroke(LexiloTheme.brass.opacity(0.18)) }
        } else if !store.lexicon.isAvailable {
            ContentUnavailableView(
                "Dictionary unavailable",
                systemImage: "books.vertical",
                description: Text("The bundled Open English WordNet database could not be opened.")
            )
        }
    }

    private func spokenTextButton(_ text: String, label: String) -> some View {
        Button { speechPlayer.play(text) } label: {
            Image(systemName: "speaker.wave.2.fill")
                .foregroundStyle(LexiloTheme.sage)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var learningNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(LexiloTheme.sage)
            VStack(alignment: .leading, spacing: 3) {
                Text("Two-way recall").font(.subheadline.bold()).foregroundStyle(LexiloTheme.ink)
                Text("You’ll see each word and its meaning on different days—so remembering is real, not a shortcut.")
                    .font(.caption).foregroundStyle(LexiloTheme.muted).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
