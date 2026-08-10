import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: LearningStore
    @State private var showingPractice = false
    @StateObject private var speechPlayer = SpeechPlayer()

    private var completedToday: Int { store.logs.filter { Calendar.current.isDateInToday($0.reviewedAt) }.count }
    private var dueToday: Int { store.sessionCards(limit: 100).count }
    private var goal: Int { UserDefaults.standard.object(forKey: "dailyGoal") as? Int ?? 10 }
    private var progress: Double { min(1, Double(completedToday) / Double(max(goal, 1))) }
    private var streak: Int {
        var result = 0
        var day = Calendar.current.startOfDay(for: .now)
        while true {
            let count = store.logs.filter { Calendar.current.isDate($0.reviewedAt, inSameDayAs: day) }.count
            if count < goal { break }
            result += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return result
    }

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
            .fullScreenCover(isPresented: $showingPractice) { PracticeSessionView() }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.caption.weight(.semibold)).textCase(.uppercase).tracking(1.2).foregroundStyle(LexiloTheme.brass)
                Text("Good evening")
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
                    Text(completedToday >= goal ? "Daily goal complete" : "Your daily practice")
                        .font(.lexiloDisplay(25, weight: .semibold)).foregroundStyle(.white)
                    Text(completedToday >= goal ? "A little practice, remembered longer." : "A focused session chosen for you.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.72))
                }
                Spacer()
                ZStack {
                    Circle().stroke(.white.opacity(0.18), lineWidth: 5)
                    Circle().trim(from: 0, to: progress).stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
                    Text("\(completedToday)/\(goal)").font(.caption.bold()).foregroundStyle(.white)
                }.frame(width: 54, height: 54)
            }
            Button { showingPractice = true } label: {
                HStack {
                    Text(dueToday == 0 ? "Practice again" : "Start practice")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.headline).foregroundStyle(LexiloTheme.ink)
                .padding(.horizontal, 18).frame(height: 54)
                .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }.buttonStyle(PressableScale())
        }
        .padding(22)
        .background(LexiloTheme.ink, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: LexiloTheme.ink.opacity(0.14), radius: 18, y: 10)
    }

    private var detailRow: some View {
        HStack(spacing: 12) {
            stat(value: "\(max(dueToday, 0))", label: "Due today", symbol: "clock")
            stat(value: "\(streak)", label: "Day streak", symbol: "flame")
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

    private var featuredWord: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("A WORD TO KEEP CLOSE").font(.caption2.bold()).tracking(1.4).foregroundStyle(LexiloTheme.brass)
                Spacer()
                Button {
                    speechPlayer.speak("elusive")
                } label: {
                    Image(systemName: "speaker.wave.2")
                        .foregroundStyle(LexiloTheme.sage)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play pronunciation for elusive")
                .accessibilityIdentifier("featured-word-pronunciation")
            }
            Text("elusive").font(.lexiloDisplay(34, weight: .medium)).foregroundStyle(LexiloTheme.ink)
            Text("difficult to find, catch, or achieve").font(.body).foregroundStyle(LexiloTheme.muted)
            Divider().overlay(LexiloTheme.brass.opacity(0.35))
            Text("“The answer remained elusive.”").font(.lexiloDisplay(17)).italic().foregroundStyle(LexiloTheme.ink.opacity(0.82))
        }
        .padding(20).background(LexiloTheme.paperDeep.opacity(0.55), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 22).stroke(LexiloTheme.brass.opacity(0.18)) }
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
