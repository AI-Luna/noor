//
//  StreakCalendarSheet.swift
//  leap
//
//  Streak pop-up with calendar, next milestone, record streak.
//  Tapping a date shows what the user accomplished that day.
//

import SwiftUI
import SwiftData

struct StreakCalendarSheet: View {
    @Environment(DataManager.self) private var dataManager
    let streakCount: Int
    var goals: [Goal] = []
    let onDismiss: () -> Void

    @State private var selectedDateForInsight: IdentifiableDate?
    @State private var displayedMonth: Date = Date()

    /// Nearest future milestone date from goals' timelines (when user wants to accomplish a dream)
    private var milestoneDate: (date: Date, title: String)? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        var nearest: (Date, String)?
        for goal in goals {
            guard !goal.timeline.isEmpty else { continue }
            let trimmed = goal.timeline.trimmingCharacters(in: .whitespaces)
            guard let date = formatter.date(from: trimmed) else { continue }
            let endOfMonth = cal.date(byAdding: DateComponents(month: 1, day: -1), to: date) ?? date
            let target = endOfMonth
            guard target >= today else { continue }
            if nearest == nil || target < nearest!.0 {
                nearest = (target, goal.destination.isEmpty ? goal.title : goal.destination)
            }
        }
        return nearest
    }

    private var daysUntilMilestone: Int? {
        guard let m = milestoneDate else { return nil }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: m.date).day
    }

    private var streakDates: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<streakCount).compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
    }

    var body: some View {
        ZStack {
            Color.noorBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.noorTextSecondary)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .padding(.top, 12)
                }

                VStack(spacing: 20) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(streakCount)")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("day streak!")
                                .font(NoorFont.title2)
                                .foregroundStyle(Color.noorTextSecondary)
                            Text("Days in a row you've taken a step.")
                                .font(NoorFont.caption)
                                .foregroundStyle(Color.noorTextSecondary.opacity(0.8))
                        }
                        Spacer()
                        Image(systemName: "flame.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.noorOrange, Color.noorAccent],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.noorDeepPurple.opacity(0.8), Color.noorViolet.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Calendar")
                        .font(NoorFont.title2)
                        .foregroundStyle(.white)
                    Text("Tap a day to see what you accomplished")
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorTextSecondary)

                    StreakCalendarMonthView(
                        month: displayedMonth,
                        streakDates: streakDates,
                        milestoneDate: milestoneDate?.date,
                        onSelectDay: { date in
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedDateForInsight = IdentifiableDate(wrapped: date)
                        }
                    )

                    HStack(spacing: 12) {
                        Button {
                            if let prev = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) {
                                displayedMonth = prev
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.noorRoseGold)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Button {
                            if let next = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) {
                                displayedMonth = next
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.noorRoseGold)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(hex: "1E1B4B").opacity(0.98))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.noorRoseGold.opacity(0.4), lineWidth: 1.5)
                        )
                )
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Overview")
                        .font(NoorFont.title2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)

                    HStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.noorRoseGold)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Dream by")
                                    .font(NoorFont.caption)
                                    .foregroundStyle(Color.noorTextSecondary)
                                if let m = milestoneDate, let days = daysUntilMilestone {
                                    Text(days == 0 ? "Today" : "\(days) day\(days == 1 ? "" : "s")")
                                        .font(NoorFont.title2)
                                        .foregroundStyle(Color.noorRoseGold)
                                    Text(m.title)
                                        .font(NoorFont.caption)
                                        .foregroundStyle(Color.noorTextSecondary.opacity(0.8))
                                        .lineLimit(1)
                                } else {
                                    Text("Set a timeline")
                                        .font(NoorFont.title2)
                                        .foregroundStyle(Color.noorTextSecondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        HStack(spacing: 12) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.noorOrange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Record Streak")
                                    .font(NoorFont.caption)
                                    .foregroundStyle(Color.noorTextSecondary)
                                Text("\(streakCount) day\(streakCount == 1 ? "" : "s")")
                                    .font(NoorFont.title2)
                                    .foregroundStyle(Color.noorOrange)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(hex: "1E1B4B").opacity(0.98))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.noorRoseGold.opacity(0.4), lineWidth: 1.5)
                        )
                )
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer(minLength: 20)
            }
        }
        .sheet(item: $selectedDateForInsight) { idDate in
            DayInsightSheet(date: idDate.wrapped, onDismiss: { selectedDateForInsight = nil })
                .environment(dataManager)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(24)
                .presentationDragIndicator(.visible)
        }
    }
}

// Wrapper so we can use Date in .sheet(item:)
private struct IdentifiableDate: Identifiable {
    let id = UUID()
    let wrapped: Date
    init(wrapped: Date) { self.wrapped = wrapped }
}

private struct StreakCalendarMonthView: View {
    let month: Date
    let streakDates: [Date]
    var milestoneDate: Date?
    var onSelectDay: (Date) -> Void = { _ in }

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    private static let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    private var weekdayLabels: [String] {
        let first = calendar.firstWeekday - 1
        return (0..<7).map { StreakCalendarMonthView.weekdaySymbols[(first + $0) % 7] }
    }

    private var monthYear: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: month)
    }

    private var firstDayOfMonth: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
    }

    private var startWeekday: Int {
        (calendar.component(.weekday, from: firstDayOfMonth) - calendar.firstWeekday + 7) % 7
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: month)!.count
    }

    private var leadingEmpty: Int { startWeekday }
    private var totalCells: Int { leadingEmpty + daysInMonth }

    private func isStreakDay(_ day: Int) -> Bool {
        guard day >= 1, day <= daysInMonth else { return false }
        guard let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) else { return false }
        let dayStart = calendar.startOfDay(for: date)
        return streakDates.contains { calendar.isDate($0, inSameDayAs: dayStart) }
    }

    private func isMilestoneDay(_ day: Int) -> Bool {
        guard let target = milestoneDate else { return false }
        guard day >= 1, day <= daysInMonth else { return false }
        guard let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) else { return false }
        return calendar.isDate(date, inSameDayAs: target)
    }

    private func date(forDay day: Int) -> Date? {
        guard day >= 1, day <= daysInMonth else { return nil }
        return calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth)
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(monthYear)
                .font(NoorFont.title2)
                .foregroundStyle(.white)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdayLabels, id: \.self) { d in
                    Text(d)
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorTextSecondary)
                }
                ForEach(0..<totalCells, id: \.self) { i in
                    if i < leadingEmpty {
                        Text("")
                            .font(NoorFont.caption)
                            .frame(height: 40)
                    } else {
                        let day = i - leadingEmpty + 1
                        let isStreak = isStreakDay(day)
                        let isMilestone = isMilestoneDay(day)
                        let dayDate = date(forDay: day)
                        Button {
                            if let d = dayDate { onSelectDay(d) }
                        } label: {
                            ZStack {
                                if isMilestone && !isStreak {
                                    Circle()
                                        .fill(Color.noorRoseGold.opacity(0.25))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "flag.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.noorRoseGold)
                                }
                                if isStreak {
                                    Circle()
                                        .fill(Color.noorOrange.opacity(0.4))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [Color.noorOrange, Color(hex: "DC2626")],
                                                startPoint: .bottom,
                                                endPoint: .top
                                            )
                                        )
                                }
                                Text("\(day)")
                                    .font(NoorFont.caption)
                                    .foregroundStyle(isStreak || isMilestone ? .white : Color.noorTextSecondary)
                            }
                            .frame(height: 40)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
    }
}

// MARK: - Day Insight (what you accomplished on a selected date)
struct DayInsightSheet: View {
    @Environment(DataManager.self) private var dataManager
    let date: Date
    let onDismiss: () -> Void

    @State private var goals: [Goal] = []
    @State private var microhabits: [Microhabit] = []
    @State private var viewingDate: Date
    @State private var isLoading = true

    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    init(date: Date, onDismiss: @escaping () -> Void) {
        self.date = date
        self.onDismiss = onDismiss
        _viewingDate = State(initialValue: date)
    }

    private var habitsCompletedOnDate: [Microhabit] {
        let dayStart = calendar.startOfDay(for: viewingDate)
        return microhabits.filter { habit in
            habit.completedDates.contains { calendar.isDate($0, inSameDayAs: dayStart) }
        }
    }

    private var journeyStepsCompletedOnDate: [(goalTitle: String, taskTitle: String)] {
        let dayStart = calendar.startOfDay(for: viewingDate)
        var result: [(String, String)] = []
        for goal in goals {
            let goalTitle = goal.destination.isEmpty ? goal.title : goal.destination
            for task in goal.dailyTasks where task.completedDates.contains(where: { calendar.isDate($0, inSameDayAs: dayStart) }) {
                result.append((goalTitle, task.title))
            }
        }
        return result
    }

    private var hasAnyAccomplishments: Bool {
        !habitsCompletedOnDate.isEmpty || !journeyStepsCompletedOnDate.isEmpty
    }

    var body: some View {
        ZStack {
            Color.noorBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with breathing room
                VStack(alignment: .leading, spacing: 10) {
                    Text("What you accomplished")
                        .font(NoorFont.title)
                        .foregroundStyle(.white)

                    HStack {
                        Text(dateFormatter.string(from: viewingDate))
                            .font(NoorFont.title2)
                            .foregroundStyle(Color.noorRoseGold)

                        Spacer()

                        HStack(spacing: 16) {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                if let prev = calendar.date(byAdding: .day, value: -1, to: viewingDate) {
                                    viewingDate = prev
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.noorRoseGold)
                                    .frame(width: 36, height: 36)
                                    .background(Color.noorRoseGold.opacity(0.15))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)

                            Button {
                                let today = calendar.startOfDay(for: Date())
                                if let next = calendar.date(byAdding: .day, value: 1, to: viewingDate), next <= today {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    viewingDate = next
                                }
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.noorRoseGold)
                                    .frame(width: 36, height: 36)
                                    .background(Color.noorRoseGold.opacity(0.15))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 20)

                // Accomplishments content — scrollable list only; header stays fixed
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                } else if !hasAnyAccomplishments {
                    VStack(spacing: 10) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.noorTextSecondary.opacity(0.6))
                        Text("No recorded activity this day")
                            .font(NoorFont.body)
                            .foregroundStyle(Color.noorTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 10) {
                            if !habitsCompletedOnDate.isEmpty {
                                Text("Habits")
                                    .font(NoorFont.caption)
                                    .foregroundStyle(Color.noorRoseGold)
                                ForEach(habitsCompletedOnDate, id: \.id) { habit in
                                    DayInsightRow(
                                        icon: "leaf.fill",
                                        iconColor: Color.noorSuccess,
                                        title: habit.title,
                                        subtitle: viewingDate.formatted(date: .abbreviated, time: .omitted)
                                    )
                                }
                            }
                            if !journeyStepsCompletedOnDate.isEmpty {
                                Text("Journey steps")
                                    .font(NoorFont.caption)
                                    .foregroundStyle(Color.noorRoseGold)
                                ForEach(Array(journeyStepsCompletedOnDate.enumerated()), id: \.offset) { _, item in
                                    DayInsightRow(
                                        icon: "checkmark.circle.fill",
                                        iconColor: Color.noorRoseGold,
                                        title: item.taskTitle,
                                        subtitle: item.goalTitle
                                    )
                                }
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .onAppear {
            Task {
                await loadData()
            }
        }
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            goals = try await dataManager.fetchAllGoals()
            microhabits = try await dataManager.fetchMicrohabits()
        } catch {
            goals = []
            microhabits = []
        }
    }
}

private struct DayInsightRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(NoorFont.body)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorTextSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    StreakCalendarSheet(streakCount: 3, goals: [], onDismiss: {})
        .environment(DataManager.shared)
}
