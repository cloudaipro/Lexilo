import SwiftUI

struct ProgressView: View {
    @EnvironmentObject private var store: LearningStore

    private var learningWords: Int { Set(store.cards.filter { $0.learningState == .learning }.map(\.vocabularyID)).count }
    private var masteredWords: Int {
        Dictionary(grouping: store.cards, by: \.vocabularyID).values.filter { $0.count == 2 && $0.allSatisfy { $0.learningState == .mastered } }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack(spacing: 12) {
                            metric("\(learningWords)", "Learning")
                            metric("\(masteredWords)", "Mastered")
                        }
                        weeklyPractice
                        recallBalance
                        Text("Mastery requires both recognition and active recall. A familiar-looking word is only halfway learned.")
                            .font(.lexiloDisplay(18)).italic().foregroundStyle(LexiloTheme.muted).padding(.horizontal, 8)
                    }.padding(20)
                }
            }.navigationTitle("Progress")
        }
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value).font(.lexiloDisplay(36, weight: .semibold)).foregroundStyle(LexiloTheme.ink)
            Text(label).font(.subheadline).foregroundStyle(LexiloTheme.muted)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18).background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 20))
    }

    private var weeklyPractice: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("This week").font(.lexiloDisplay(24, weight: .semibold)).foregroundStyle(LexiloTheme.ink)
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(0..<7, id: \.self) { offset in
                    let day = Calendar.current.date(byAdding: .day, value: offset - 6, to: .now)!
                    let count = store.logs.filter { Calendar.current.isDate($0.reviewedAt, inSameDayAs: day) }.count
                    VStack(spacing: 7) {
                        Text(count > 0 ? "\(count)" : "").font(.caption2).foregroundStyle(LexiloTheme.muted)
                        Capsule().fill(count > 0 ? LexiloTheme.sage : LexiloTheme.paperDeep).frame(height: max(10, CGFloat(count) * 6 + 10))
                        Text(day.formatted(.dateTime.weekday(.narrow))).font(.caption2.weight(.semibold)).foregroundStyle(LexiloTheme.muted)
                    }.frame(maxWidth: .infinity)
                }
            }.frame(height: 130, alignment: .bottom)
        }.padding(20).background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 22))
    }

    private var recallBalance: some View {
        let recognition = store.logs.filter { $0.direction == .recognition }
        let recall = store.logs.filter { $0.direction == .recall }
        return VStack(alignment: .leading, spacing: 17) {
            Text("Recall balance").font(.lexiloDisplay(24, weight: .semibold)).foregroundStyle(LexiloTheme.ink)
            balanceRow("Word → Meaning", logs: recognition)
            balanceRow("Meaning → Word", logs: recall)
        }.padding(20).background(LexiloTheme.paperDeep.opacity(0.55), in: RoundedRectangle(cornerRadius: 22))
    }

    private func balanceRow(_ title: String, logs: [ReviewLog]) -> some View {
        let accuracy = logs.isEmpty ? 0.0 : Double(logs.filter(\.answeredCorrectly).count) / Double(logs.count)
        return VStack(alignment: .leading, spacing: 7) {
            HStack { Text(title).font(.subheadline); Spacer(); Text(logs.isEmpty ? "Not started" : "\(Int(accuracy * 100))%").font(.caption.bold()).foregroundStyle(LexiloTheme.sage) }
            SwiftUI.ProgressView(value: accuracy).tint(LexiloTheme.sage)
        }.foregroundStyle(LexiloTheme.ink)
    }
}
