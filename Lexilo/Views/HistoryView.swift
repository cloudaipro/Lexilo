import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: LearningStore
    @State private var displayedMonth = Calendar.current.startOfDay(for: .now)
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var reviewSession: ReviewSession?

    private struct ReviewSession: Identifiable {
        let id = UUID()
        let words: [VocabularyItem]
        let title: String
    }

    private var calendar: Calendar { .current }

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) ?? displayedMonth
    }

    private var monthTitle: String {
        monthStart.formatted(.dateTime.month(.wide).year())
    }

    private var monthGrid: [Date?] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        let weekday = calendar.component(.weekday, from: monthStart)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        let dates = dayRange.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: monthStart) }
        return Array(repeating: nil, count: leading) + dates.map(Optional.some)
    }

    private var currentMonth: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: .now)) ?? .now
    }

    private var selectedStudied: [VocabularyItem] { store.wordsStudied(on: selectedDate) }
    private var selectedPlanned: [VocabularyItem] { store.plannedWords(on: selectedDate) }
    private var displayedWords: [VocabularyItem] { selectedStudied.isEmpty ? selectedPlanned : selectedStudied }

    private var actionWords: [VocabularyItem] {
        selectedStudied.isEmpty ? selectedPlanned : selectedStudied
    }

    private var selectedIsToday: Bool { calendar.isDate(selectedDate, inSameDayAs: .now) }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        monthPicker
                        calendarCard
                        selectedDayContent
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Study history")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(item: $reviewSession) { session in
                HistoricalStudyView(words: session.words, title: session.title)
            }
        }
        .onAppear {
            let today = calendar.startOfDay(for: .now)
            selectedDate = today
            displayedMonth = today
        }
    }

    private var monthPicker: some View {
        HStack {
            Button {
                displayedMonth = calendar.date(byAdding: .month, value: -1, to: monthStart) ?? monthStart
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 38, height: 38)
                    .foregroundStyle(LexiloTheme.ink)
                    .background(.white.opacity(0.64), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous month")
            .accessibilityIdentifier("history-previous-month")

            Spacer()
            Text(monthTitle)
                .font(.lexiloDisplay(25, weight: .semibold))
                .foregroundStyle(LexiloTheme.ink)
            Spacer()

            Button {
                displayedMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 38, height: 38)
                    .foregroundStyle(LexiloTheme.ink)
                    .background(.white.opacity(0.64), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next month")
            .accessibilityIdentifier("history-next-month")
            .disabled(monthStart >= currentMonth)
            .opacity(monthStart >= currentMonth ? 0.35 : 1)
        }
        .padding(.top, 12)
    }

    private var calendarCard: some View {
        VStack(spacing: 12) {
            HStack {
                ForEach(calendar.veryShortStandaloneWeekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(LexiloTheme.muted)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 8) {
                ForEach(Array(monthGrid.enumerated()), id: \.offset) { item in
                    if let date = item.element {
                        dayButton(for: date)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityIdentifier("learning-history-calendar")
    }

    private func dayButton(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDate(date, inSameDayAs: .now)
        let isFuture = calendar.startOfDay(for: date) > calendar.startOfDay(for: .now)
        let hasActivity = store.hasStudyActivity(on: date)

        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 4) {
                Text(calendar.component(.day, from: date), format: .number)
                    .font(.subheadline.weight(isSelected || isToday ? .bold : .regular))
                    .foregroundStyle(isSelected ? .white : isFuture ? LexiloTheme.muted.opacity(0.42) : LexiloTheme.ink)
                Circle()
                    .fill(hasActivity ? (isSelected ? .white : LexiloTheme.sage) : .clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(isSelected ? LexiloTheme.ink : isToday ? LexiloTheme.sageLight : .clear, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
        .accessibilityValue(hasActivity ? "Study activity" : "No study activity")
        .accessibilityIdentifier("history-date-\(date.formatted(.iso8601.year().month().day()))")
    }

    @ViewBuilder
    private var selectedDayContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1.1)
                    .foregroundStyle(LexiloTheme.brass)
                Text(selectedStudied.isEmpty ? (selectedPlanned.isEmpty ? "No words recorded" : "Words prepared") : "Words studied")
                    .font(.lexiloDisplay(29, weight: .semibold))
                    .foregroundStyle(LexiloTheme.ink)
            }

            if !selectedStudied.isEmpty {
                HStack(spacing: 10) {
                    historyStat("\(selectedStudied.count)", "Studied")
                }
            }

            if selectedStudied.isEmpty && selectedPlanned.isEmpty {
                ContentUnavailableView(
                    "Nothing recorded yet",
                    systemImage: "calendar.badge.plus",
                    description: Text("Complete a learning pass or practice session and it will appear here.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                wordList(words: displayedWords)

                if !actionWords.isEmpty {
                    Button {
                        reviewSession = ReviewSession(
                            words: actionWords,
                            title: selectedIsToday ? "Review these words" : "Relearn words"
                        )
                    } label: {
                        Label(selectedStudied.isEmpty ? "Study these words" : "Relearn these words", systemImage: "book.pages")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(LexiloTheme.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(PressableScale())
                    .accessibilityIdentifier("history-relearn")
                }
            }
        }
    }

    private func historyStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.title3.weight(.semibold)).foregroundStyle(LexiloTheme.ink)
            Text(label).font(.caption2).foregroundStyle(LexiloTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(LexiloTheme.sageLight.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func wordList(words: [VocabularyItem]) -> some View {
        if !words.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(words) { word in
                    NavigationLink { WordDetailView(word: word) } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(word.word)
                                    .font(.lexiloDisplay(20, weight: .medium))
                                    .foregroundStyle(LexiloTheme.ink)
                                Text(word.conciseDefinition)
                                    .font(.caption)
                                    .foregroundStyle(LexiloTheme.muted)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(LexiloTheme.sage)
                        }
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                    if word.id != words.last?.id {
                        Divider().overlay(LexiloTheme.brass.opacity(0.18))
                    }
                }
            }
            .padding(16)
            .background(.white.opacity(0.54), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}
