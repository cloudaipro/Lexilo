import SwiftUI

struct ProgressView: View {
    @EnvironmentObject private var store: LearningStore
    @State private var focusedPracticeIDs: Set<UUID> = []
    @State private var showingFocusedPractice = false
    @State private var showingAdvanced = false

    private var forecast: [MemoryForecastDay] { store.dueForecast() }
    private var fragile: [VocabularyItem] { store.fragileWords() }
    private var retention: Double { store.estimatedRetention() }
    private var dueToday: Int { store.sessionCards(limit: 1_000).count }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        summary
                        forecastCard
                        atRiskCard
                        directionBalance
                        weeklyPractice
                        Button("Advanced memory details") { showingAdvanced = true }
                            .font(.caption.weight(.semibold)).foregroundStyle(LexiloTheme.sage).padding(.horizontal, 8)
                    }.padding(20)
                }
            }
            .navigationTitle("Memory")
            .fullScreenCover(isPresented: $showingFocusedPractice) { PracticeSessionView(focusVocabularyIDs: focusedPracticeIDs) }
            .sheet(isPresented: $showingAdvanced) { advancedDetails }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your memory today").font(.lexiloDisplay(27, weight: .semibold)).foregroundStyle(LexiloTheme.ink)
            HStack(spacing: 12) {
                summaryMetric(retention == 0 ? "—" : "\(Int(retention * 100))%", "Est. retention")
                summaryMetric("\(dueToday)", "Due today")
                summaryMetric("\(forecast.dropFirst().reduce(0) { $0 + $1.count })", "Next 7 days")
            }
            Text("Retention estimates how likely reviewed cards are to be recalled now. It becomes more useful as you build history.")
                .font(.caption).foregroundStyle(LexiloTheme.muted)
        }
        .padding(20).background(LexiloTheme.ink, in: RoundedRectangle(cornerRadius: 24))
        .foregroundStyle(.white)
    }

    private func summaryMetric(_ value: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title2.bold())
            Text(title).font(.caption2).foregroundStyle(.white.opacity(0.68))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var forecastCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Seven-day load").font(.lexiloDisplay(24, weight: .semibold)).foregroundStyle(LexiloTheme.ink)
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(forecast) { day in
                    VStack(spacing: 7) {
                        Text(day.count == 0 ? "" : "\(day.count)").font(.caption2).foregroundStyle(LexiloTheme.muted)
                        Capsule().fill(day.count > 0 ? LexiloTheme.sage : LexiloTheme.paperDeep)
                            .frame(height: max(10, min(86, CGFloat(day.count) * 5 + 10)))
                        Text(day.date.formatted(.dateTime.weekday(.narrow))).font(.caption2.bold()).foregroundStyle(LexiloTheme.muted)
                    }.frame(maxWidth: .infinity)
                }
            }.frame(height: 120, alignment: .bottom)
        }.padding(20).background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 22))
    }

    @ViewBuilder
    private var atRiskCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Words at risk").font(.lexiloDisplay(24, weight: .semibold)).foregroundStyle(LexiloTheme.ink)
                    Text("Fading cards that benefit from focused recall.").font(.caption).foregroundStyle(LexiloTheme.muted)
                }
                Spacer()
                if !fragile.isEmpty {
                    Button("Review") {
                        focusedPracticeIDs = Set(fragile.map(\.id))
                        showingFocusedPractice = true
                    }
                        .font(.caption.bold()).buttonStyle(.borderedProminent).tint(LexiloTheme.sage)
                }
            }
            if fragile.isEmpty {
                Label("No reviewed words are fading right now", systemImage: "checkmark.circle")
                    .font(.subheadline).foregroundStyle(LexiloTheme.sage)
            } else {
                ForEach(fragile.prefix(6)) { word in
                    Button {
                        focusedPracticeIDs = [word.id]
                        showingFocusedPractice = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(word.word).font(.headline).foregroundStyle(LexiloTheme.ink)
                                Text(weakestLabel(for: word)).font(.caption).foregroundStyle(LexiloTheme.muted)
                                DifficultyIndicator(
                                    value: store.averageDifficulty(vocabularyID: word.id, includePaused: true),
                                    measured: store.hasReviewedCard(vocabularyID: word.id, includePaused: true)
                                )
                            }
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill").foregroundStyle(LexiloTheme.sage)
                        }
                    }.buttonStyle(.plain)
                }
            }
        }.padding(20).background(LexiloTheme.paperDeep.opacity(0.55), in: RoundedRectangle(cornerRadius: 22))
    }

    private func weakestLabel(for word: VocabularyItem) -> String {
        let related = store.cards.filter { $0.vocabularyID == word.id && !$0.isPaused }
        guard let weakest = related.min(by: { store.currentRetrievability(for: $0) < store.currentRetrievability(for: $1) }) else { return "Needs recall" }
        return "\(weakest.direction == .recognition ? "Understand" : "Recall") · \(store.memoryLabel(for: weakest))"
    }

    private var directionBalance: some View {
        VStack(alignment: .leading, spacing: 17) {
            Text("Two-way strength").font(.lexiloDisplay(24, weight: .semibold)).foregroundStyle(LexiloTheme.ink)
            balanceRow("Understand", direction: .recognition)
            balanceRow("Recall", direction: .recall)
        }.padding(20).background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 22))
    }

    private func balanceRow(_ title: String, direction: CardDirection) -> some View {
        let reviewed = store.cards.filter { $0.direction == direction && $0.lastReviewedDate != nil && !$0.isPaused }
        let value = reviewed.isEmpty ? 0 : reviewed.map { store.currentRetrievability(for: $0) }.reduce(0, +) / Double(reviewed.count)
        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text(reviewed.isEmpty ? "Not started" : value >= 0.9 ? "Strong" : value >= 0.75 ? "Fading" : "Needs recall")
                    .font(.caption.bold()).foregroundStyle(LexiloTheme.sage)
            }
            SwiftUI.ProgressView(value: value).tint(LexiloTheme.sage)
        }.foregroundStyle(LexiloTheme.ink)
    }

    private var weeklyPractice: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Practice history").font(.lexiloDisplay(24, weight: .semibold)).foregroundStyle(LexiloTheme.ink)
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(0..<7, id: \.self) { offset in
                    let day = Calendar.current.date(byAdding: .day, value: offset - 6, to: .now)!
                    let count = store.logs.filter { Calendar.current.isDate($0.reviewedAt, inSameDayAs: day) }.count
                    VStack(spacing: 7) {
                        Text(count > 0 ? "\(count)" : "").font(.caption2).foregroundStyle(LexiloTheme.muted)
                        Capsule().fill(count > 0 ? LexiloTheme.sage : LexiloTheme.paperDeep).frame(height: max(10, CGFloat(count) * 5 + 10))
                        Text(day.formatted(.dateTime.weekday(.narrow))).font(.caption2.bold()).foregroundStyle(LexiloTheme.muted)
                    }.frame(maxWidth: .infinity)
                }
            }.frame(height: 120, alignment: .bottom)
        }.padding(20).background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 22))
    }

    private var advancedDetails: some View {
        NavigationStack {
            List {
                Section("Scheduler") {
                    LabeledContent("Desired retention", value: "\(Int((UserDefaults.standard.object(forKey: "desiredRetention") as? Double ?? 0.9) * 100))%")
                    LabeledContent("Memory model", value: "Adaptive")
                    LabeledContent("Reviewed cards", value: "\(store.cards.filter { $0.lastReviewedDate != nil }.count)")
                }
                Section("How it works") {
                    Text("Each direction tracks difficulty, stability, current retrievability, the last outcome, and response latency. Correct, quick answers wait longer; hints and failures shorten the next interval.")
                }
            }
            .navigationTitle("Memory details")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingAdvanced = false } } }
        }
    }
}
