//
//  ProgressTabView.swift
//  leap
//
//  One core feature: see your progress — streak + journey completion + habits.
//

import SwiftUI
import SwiftData

struct ProgressTabView: View {
    @Environment(DataManager.self) private var dataManager
    @State private var goals: [Goal] = []
    @State private var microhabits: [Microhabit] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showStreakSheet = false
    @State private var displayedMonth: Date = Date()
    private let calendar = Calendar.current
    
    private var globalStreak: Int {
        UserDefaults.standard.integer(forKey: StorageKey.streakCount)
    }

    private var completedCount: Int {
        goals.filter { $0.progress >= 100 }.count
    }
    
    private var streakDates: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<globalStreak).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    }
    
    private var milestoneDate: (date: Date, title: String)? {
        let today = calendar.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        var nearest: (Date, String)?
        for goal in goals {
            guard !goal.timeline.isEmpty else { continue }
            let trimmed = goal.timeline.trimmingCharacters(in: .whitespaces)
            guard let date = formatter.date(from: trimmed) else { continue }
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: date) ?? date
            let target = endOfMonth
            guard target >= today else { continue }
            if nearest == nil || target < nearest!.0 {
                nearest = (target, goal.destination.isEmpty ? goal.title : goal.destination)
            }
        }
        return nearest
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.noorBackground
                    .ignoresSafeArea()

                if isLoading {
                    LoadingSpinnerView()
                } else if let msg = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title)
                            .foregroundStyle(Color.noorOrange)
                        Text(msg)
                            .font(NoorFont.body)
                            .foregroundStyle(Color.noorTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Square cells side by side
                            HStack(spacing: 16) {
                                journeySquareCell
                                habitsSquareCell
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            
                            // Calendar view
                            calendarSection
                                .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Progress")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showStreakSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.noorOrange, Color.noorAccent],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            Text("\(globalStreak)")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showStreakSheet) {
                StreakCalendarSheet(streakCount: globalStreak, goals: goals, onDismiss: { showStreakSheet = false })
            }
            .onAppear {
                loadGoals()
                loadHabits()
            }
            .refreshable {
                loadGoals()
                loadHabits()
            }
        }
    }

    // MARK: - Square Cells
    private var journeySquareCell: some View {
        let totalProgress = goals.isEmpty ? 0 : goals.reduce(0.0) { $0 + $1.progress } / Double(goals.count)

        return VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("Your Journeys")
                    .font(NoorFont.body)
                    .foregroundStyle(.white)
                Image(systemName: "airplane.departure")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.noorRoseGold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.noorViolet.opacity(0.3), lineWidth: 8)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: totalProgress / 100)
                    .stroke(Color.noorRoseGold, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(Int(totalProgress))%")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("complete")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.noorTextSecondary)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var habitsSquareCell: some View {
        let todayCompletedCount = microhabits.filter { isCompletedToday($0) }.count
        let totalCount = microhabits.count
        let completionRate = totalCount > 0 ? Double(todayCompletedCount) / Double(totalCount) * 100 : 0

        return VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("Your Habits")
                    .font(NoorFont.body)
                    .foregroundStyle(.white)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.noorSuccess)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.noorViolet.opacity(0.3), lineWidth: 8)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: completionRate / 100)
                    .stroke(Color.noorSuccess, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(todayCompletedCount)/\(totalCount)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("today")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.noorTextSecondary)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Calendar Section
    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Progress Calendar")
                .font(NoorFont.title)
                .foregroundStyle(.white)
            
            Text("Track your journey milestones and habit completions")
                .font(NoorFont.caption)
                .foregroundStyle(Color.noorTextSecondary)
            
            ProgressCalendarView(
                month: displayedMonth,
                streakDates: streakDates,
                milestoneDate: milestoneDate?.date,
                goals: goals,
                habits: microhabits
            )
            
            HStack(spacing: 12) {
                Button {
                    if let prev = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
                        displayedMonth = prev
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.noorRoseGold)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(displayedMonth, format: .dateTime.month(.wide).year())
                    .font(NoorFont.body)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    if let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
                        displayedMonth = next
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.noorRoseGold)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            if let milestone = milestoneDate {
                HStack(spacing: 8) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.noorRoseGold)
                    Text("Next milestone: \(milestone.title)")
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorTextSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.noorRoseGold.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func isCompletedToday(_ habit: Microhabit) -> Bool {
        return habit.completedDates.contains { calendar.isDateInToday($0) }
    }

    private func loadHabits() {
        Task { @MainActor in
            do {
                microhabits = try await dataManager.fetchMicrohabits()
            } catch {
                // Silent fail for habits, just show empty
                microhabits = []
            }
        }
    }

    private func loadGoals() {
        Task { @MainActor in
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            do {
                goals = try await dataManager.fetchAllGoals()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// Custom loading spinner to avoid naming conflict with SwiftUI.ProgressView
private struct LoadingSpinnerView: View {
    @State private var isSpinning = false
    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.2, to: 1)
                .stroke(Color.noorRoseGold.opacity(0.6), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(isSpinning ? 360 : 0))
                .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: isSpinning)
        }
        .onAppear { isSpinning = true }
    }
}

// MARK: - Progress Calendar View
private struct ProgressCalendarView: View {
    let month: Date
    let streakDates: [Date]
    let milestoneDate: Date?
    let goals: [Goal]
    let habits: [Microhabit]

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var monthDays: [Date?] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let offsetDays = (firstWeekday - calendar.firstWeekday + 7) % 7

        guard let monthRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }

        var days: [Date?] = Array(repeating: nil, count: offsetDays)

        for day in monthRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(date)
            }
        }

        return days
    }

    private func hasJourneyActivity(on date: Date) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        for goal in goals {
            for task in goal.dailyTasks where task.isCompleted {
                if let completedAt = task.completedAt, calendar.isDate(completedAt, inSameDayAs: dayStart) {
                    return true
                }
            }
        }
        return false
    }

    private func hasHabitActivity(on date: Date) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        for habit in habits {
            if habit.completedDates.contains(where: { calendar.isDate($0, inSameDayAs: dayStart) }) {
                return true
            }
        }
        return false
    }

    private func isStreakDay(_ date: Date) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        return streakDates.contains(where: { calendar.isDate($0, inSameDayAs: dayStart) })
    }

    private func isMilestone(_ date: Date) -> Bool {
        guard let milestone = milestoneDate else { return false }
        return calendar.isDate(date, inSameDayAs: milestone)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Weekday headers
            HStack(spacing: 4) {
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
                    Text(String(day.prefix(1)))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.noorTextSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        CalendarDayCell(
                            date: date,
                            isToday: calendar.isDateInToday(date),
                            hasJourney: hasJourneyActivity(on: date),
                            hasHabit: hasHabitActivity(on: date),
                            isStreak: isStreakDay(date),
                            isMilestone: isMilestone(date)
                        )
                    } else {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }

            // Legend
            HStack(spacing: 16) {
                legendDot(color: Color.noorRoseGold, label: "Journey")
                legendDot(color: Color.noorSuccess, label: "Habit")
                legendDot(color: Color.noorOrange, label: "Streak")
            }
            .padding(.top, 8)
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color.noorTextSecondary)
        }
    }
}

private struct CalendarDayCell: View {
    let date: Date
    let isToday: Bool
    let hasJourney: Bool
    let hasHabit: Bool
    let isStreak: Bool
    let isMilestone: Bool

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var hasAnyActivity: Bool {
        hasJourney || hasHabit || isStreak
    }

    // Background color priority: milestone > today > journey+habit combo > journey > habit > streak > none
    private var backgroundColor: Color {
        if isMilestone { return Color.noorRoseGold.opacity(0.2) }
        if isToday { return Color.noorViolet.opacity(0.3) }
        if hasJourney && hasHabit { return Color.noorRoseGold.opacity(0.15) }
        if hasJourney { return Color.noorRoseGold.opacity(0.2) }
        if hasHabit { return Color.noorSuccess.opacity(0.2) }
        if isStreak { return Color.noorOrange.opacity(0.2) }
        return Color.white.opacity(0.05)
    }

    private var textColor: Color {
        if isToday { return .white }
        if hasJourney { return Color.noorRoseGold }
        if hasHabit { return Color.noorSuccess }
        if isStreak { return Color.noorOrange }
        return Color.noorTextSecondary
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
                .overlay(
                    isMilestone ?
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.noorRoseGold, lineWidth: 2) : nil
                )

            VStack(spacing: 1) {
                Text(dayNumber)
                    .font(.system(size: 14, weight: isToday ? .bold : .regular))
                    .foregroundStyle(textColor)

                if hasAnyActivity && !isToday {
                    HStack(spacing: 2) {
                        if hasJourney {
                            Circle().fill(Color.noorRoseGold).frame(width: 4, height: 4)
                        }
                        if hasHabit {
                            Circle().fill(Color.noorSuccess).frame(width: 4, height: 4)
                        }
                        if isStreak && !hasJourney && !hasHabit {
                            Circle().fill(Color.noorOrange).frame(width: 4, height: 4)
                        }
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    ProgressTabView()
        .environment(DataManager.shared)
}
