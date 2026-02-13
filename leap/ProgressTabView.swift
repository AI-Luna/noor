//
//  ProgressTabView.swift
//  leap
//
//  One core feature: see your progress — streak + journey completion + habits.
//

import SwiftUI
import SwiftData
import UIKit

struct ProgressTabView: View {
    @Environment(DataManager.self) private var dataManager
    @State private var goals: [Goal] = []
    @State private var microhabits: [Microhabit] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showStreakSheet = false
    @State private var displayedMonth: Date = Date()
    @State private var selectedTab: Int = 0
    @State private var legendPopup: String? = nil
    @State private var metricPopup: (id: String, value: String)? = nil
    @State private var selectedDateForInsight: IdentifiableDate?
    @State private var selectedGoal: Goal?
    @State private var goalToShare: Goal?
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
                        VStack(alignment: .leading, spacing: 16) {
                            // Calendar at top (compact)
                            calendarSection
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                            // Metrics grid below calendar
                            metricsSection
                                .padding(.horizontal, 16)

                            // Completed Journeys (boarding passes)
                            completedJourneysSection
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                        }
                        .padding(.bottom, 100)
                    }
                }

                // Legend popup overlay
                if let popup = legendPopup {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation { legendPopup = nil } }

                    VStack(spacing: 12) {
                        Text(legendTitle(for: popup))
                            .font(NoorFont.title2)
                            .foregroundStyle(.white)

                        Text(legendDescription(for: popup))
                            .font(NoorFont.body)
                            .foregroundStyle(Color.noorTextSecondary)
                            .multilineTextAlignment(.center)

                        Button {
                            withAnimation { legendPopup = nil }
                        } label: {
                            Text("Got it")
                                .font(NoorFont.callout)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Color.noorAccent)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .padding(24)
                    .background(Color.noorDeepPurple)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 20)
                    .padding(.horizontal, 40)
                    .transition(.scale.combined(with: .opacity))
                }
                
                // Metric explanation popup (definition + your number)
                if let popup = metricPopup {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation { metricPopup = nil } }
                    
                    VStack(spacing: 12) {
                        Text(metricPopupTitle(for: popup.id))
                            .font(NoorFont.title2)
                            .foregroundStyle(.white)
                        
                        Text(metricPopupDescription(for: popup.id, value: popup.value))
                            .font(NoorFont.body)
                            .foregroundStyle(Color.noorTextSecondary)
                            .multilineTextAlignment(.center)
                        
                        Button {
                            withAnimation { metricPopup = nil }
                        } label: {
                            Text("Got it")
                                .font(NoorFont.callout)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Color.noorAccent)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .padding(24)
                    .background(Color.noorDeepPurple)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 20)
                    .padding(.horizontal, 40)
                    .transition(.scale.combined(with: .opacity))
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
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showStreakSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            FlickerFlameView()
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
                SimpleStreakPopup(streakCount: globalStreak, onDismiss: { showStreakSheet = false })
                    .presentationDetents([PresentationDetent.height(280)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedDateForInsight) { idDate in
                DayInsightSheet(date: idDate.wrapped, onDismiss: { selectedDateForInsight = nil })
                    .environment(dataManager)
                    .presentationDetents([.height(480)])
                    .presentationCornerRadius(24)
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedGoal) { goal in
                DailyCheckInView(goal: goal)
                    .environment(dataManager)
            }
            .sheet(item: $goalToShare) { goal in
                ProgressShareSheet(goal: goal)
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

    // MARK: - Metrics Section (Daily vs Lifetime)
    private var metricsSection: some View {
        let totalProgress = goals.isEmpty ? 0 : goals.reduce(0.0) { $0 + $1.progress } / Double(goals.count)
        let todayHabitsComplete = microhabits.filter { isCompletedToday($0) }.count
        let totalHabits = microhabits.count
        
        return VStack(alignment: .leading, spacing: 20) {
            // Daily
            VStack(alignment: .leading, spacing: 10) {
                Text("Today")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundStyle(.white)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    Button {
                        metricPopup = ("today", "\(todayHabitsComplete)/\(totalHabits)")
                    } label: {
                        metricCell(
                            icon: "leaf.fill",
                            iconColor: Color.noorSuccess,
                            value: "\(todayHabitsComplete)/\(totalHabits)",
                            label: "Habits done"
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        metricPopup = ("todayChallenges", "\(todayCompletedChallenges)/\(todayTotalChallenges)")
                    } label: {
                        metricCell(
                            icon: "checkmark.seal.fill",
                            iconColor: Color.noorRoseGold,
                            value: "\(todayCompletedChallenges)/\(todayTotalChallenges)",
                            label: "Challenges done"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Lifetime
            VStack(alignment: .leading, spacing: 10) {
                Text("Lifetime")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundStyle(.white)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    Button {
                        metricPopup = ("overall", "\(Int(totalProgress))%")
                    } label: {
                        metricOverallCell(progress: totalProgress)
                    }
                    .buttonStyle(.plain)

                    Button {
                        metricPopup = ("streak", "\(globalStreak)")
                    } label: {
                        metricStreakCell()
                    }
                    .buttonStyle(.plain)

                    Button {
                        metricPopup = ("journeys", "\(goals.count)")
                    } label: {
                        metricCell(
                            icon: "airplane.departure",
                            iconColor: Color.noorAccent,
                            value: "\(goals.count)",
                            label: "Journeys"
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        metricPopup = ("done", "\(totalCompletedChallenges)")
                    } label: {
                        metricCell(
                            icon: "checkmark.circle.fill",
                            iconColor: Color.noorViolet,
                            value: "\(totalCompletedChallenges)",
                            label: "Challenges done"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func metricOverallCell(progress: Double) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 5)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: progress / 100)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                Text("\(Int(progress))%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Text("Overall")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.noorTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func metricStreakCell() -> some View {
        VStack(spacing: 6) {
            Text("\(globalStreak)")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Image(systemName: "flame.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.noorOrange.opacity(0.5))
            Text("Day Streak")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.noorTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func metricCell(icon: String, iconColor: Color, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(iconColor)

            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.noorTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private var totalCompletedChallenges: Int {
        goals.flatMap { $0.dailyTasks }.filter { $0.isCompleted }.count
    }

    private var todayCompletedChallenges: Int {
        goals.flatMap { $0.dailyTasks }.filter { task in
            task.completedDates.contains { calendar.isDateInToday($0) }
        }.count
    }

    private var todayTotalChallenges: Int {
        goals.flatMap { $0.dailyTasks }.filter { $0.isUnlocked && !$0.isCompleted }.count + todayCompletedChallenges
    }

    // MARK: - Completed Journeys Section
    private var completedJourneysSection: some View {
        let completedGoals = goals.filter { $0.isComplete }
        return Group {
            if !completedGoals.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Completed Journeys")
                            .font(.system(size: 24, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(completedGoals.count)")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.noorSuccess)
                    }

                    ForEach(completedGoals.sorted { ($0.archivedAt ?? $0.createdAt) > ($1.archivedAt ?? $1.createdAt) }, id: \.id) { goal in
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            selectedGoal = goal
                        } label: {
                            ProgressBoardingPassCard(goal: goal, onShare: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                goalToShare = goal
                            })
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Calendar Section (compact, at top)
    private var calendarSection: some View {
        VStack(spacing: 8) {
            // Month navigation (compact)
            HStack {
                Button {
                    if let prev = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
                        displayedMonth = prev
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.noorAccent)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(displayedMonth, format: .dateTime.month(.wide).year())
                    .font(NoorFont.title2)
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    if let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
                        displayedMonth = next
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.noorAccent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            // Calendar grid
            ProgressCalendarView(
                month: displayedMonth,
                streakDates: streakDates,
                milestoneDate: milestoneDate?.date,
                goals: goals,
                habits: microhabits,
                selectedDate: selectedDateForInsight?.wrapped,
                onLegendTap: { label in
                    withAnimation(.spring(response: 0.3)) {
                        legendPopup = label
                    }
                },
                onSelectDay: { date in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    selectedDateForInsight = IdentifiableDate(wrapped: date)
                }
            )
        }
    }

    // MARK: - Legend Popups
    private func legendTitle(for label: String) -> String {
        switch label {
        case "Journey": return "Journey Activity"
        case "Habit": return "Habit Activity"
        case "Streak": return "Streak"
        default: return label
        }
    }

    private func legendDescription(for label: String) -> String {
        switch label {
        case "Journey":
            return "Days when you completed a challenge for one of your dream journeys. Each completed mission lights up this day."
        case "Habit":
            return "Days when you checked off at least one of your daily habits. Consistency here builds lasting change."
        case "Streak":
            return "Your streak grows for every day you show up on the app. The flame marks each day you kept the streak alive."
        default:
            return ""
        }
    }
    
    // MARK: - Metric Popups (definition + your number)
    private func metricPopupTitle(for id: String) -> String {
        switch id {
        case "today": return "Habits Today"
        case "todayChallenges": return "Challenges Today"
        case "overall": return "Overall Progress"
        case "streak": return "Day Streak"
        case "journeys": return "Journeys"
        case "done": return "Challenges Done"
        default: return id
        }
    }
    
    private func metricPopupDescription(for id: String, value: String) -> String {
        switch id {
        case "today":
            return "How many habits you completed today. You've done \(value) so far—small steps add up."
        case "todayChallenges":
            return "Journey challenges you've completed today. You've knocked out \(value) so far—keep the momentum going."
        case "overall":
            return "Average completion across all your journeys. You’re at \(value) overall. Each challenge you finish moves this up."
        case "streak":
            return "Consecutive days you’ve opened the app and taken action. You’re at \(value) day\(value == "1" ? "" : "s") right now. Keep showing up."
        case "journeys":
            return "Active journeys you’re working toward. You have \(value) journey\(value == "1" ? "" : "s")—each is a destination with step-by-step challenges."
        case "done":
            return "Total journey challenges you’ve completed. You’ve finished \(value) so far. Every one counts toward your growth."
        default:
            return ""
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

// Wrapper so we can use Date in .sheet(item:)
private struct IdentifiableDate: Identifiable {
    let id = UUID()
    let wrapped: Date
    init(wrapped: Date) { self.wrapped = wrapped }
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
    var selectedDate: Date? = nil
    var onLegendTap: ((String) -> Void)? = nil
    var onSelectDay: ((Date) -> Void)? = nil

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
            for task in goal.dailyTasks {
                let completedOnDay = task.completedDates.contains { calendar.isDate($0, inSameDayAs: dayStart) }
                if completedOnDay { return true }
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
                        Button {
                            onSelectDay?(date)
                        } label: {
                            CalendarDayCell(
                                date: date,
                                isToday: calendar.isDateInToday(date),
                                hasJourney: hasJourneyActivity(on: date),
                                hasHabit: hasHabitActivity(on: date),
                                isStreak: isStreakDay(date),
                                isMilestone: isMilestone(date),
                                isSelected: selectedDate.map { calendar.isDate(date, inSameDayAs: $0) } ?? false
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }

            // Legend — tappable, larger
            HStack(spacing: 20) {
                legendItem(color: Color.noorAccent, label: "Journey")
                legendItem(color: Color.noorSuccess, label: "Habit")
                legendItem(icon: "flame.fill", color: Color.noorOrange, label: "Streak")
            }
            .padding(.top, 12)
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func legendItem(icon: String? = nil, color: Color, label: String) -> some View {
        Button {
            onLegendTap?(label)
        } label: {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundStyle(color)
                } else {
                    Circle()
                        .fill(color)
                        .frame(width: 10, height: 10)
                }
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.noorTextSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CalendarDayCell: View {
    let date: Date
    let isToday: Bool
    let hasJourney: Bool
    let hasHabit: Bool
    let isStreak: Bool
    let isMilestone: Bool
    var isSelected: Bool = false

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var hasAnyActivity: Bool {
        hasJourney || hasHabit || isStreak
    }

    // Background color priority: milestone > today > journey+habit combo > journey > habit > none
    private var backgroundColor: Color {
        if isMilestone { return Color.noorAccent.opacity(0.2) }
        if isToday { return Color.noorViolet.opacity(0.3) }
        if hasJourney && hasHabit { return Color.noorAccent.opacity(0.15) }
        if hasJourney { return Color.noorAccent.opacity(0.2) }
        if hasHabit { return Color.noorSuccess.opacity(0.2) }
        return Color.white.opacity(0.05)
    }

    private var textColor: Color {
        if isToday { return .white }
        if hasJourney { return Color.noorAccent }
        if hasHabit { return Color.noorSuccess }
        if isStreak { return .white }
        return Color.noorTextSecondary
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
                .overlay(
                    isMilestone && !isSelected ?
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.noorAccent, lineWidth: 2) : nil
                )
                .overlay(
                    isSelected ?
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white, lineWidth: 2.5) : nil
                )

            // Streak flame background
            if isStreak && !isToday {
                Image(systemName: "flame.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.noorOrange.opacity(0.25))
            }

            VStack(spacing: 1) {
                Text(dayNumber)
                    .font(.system(size: 14, weight: isToday || isStreak ? .bold : .regular))
                    .foregroundStyle(textColor)

                if hasAnyActivity {
                    HStack(spacing: 2) {
                        if hasJourney {
                            Circle().fill(Color.noorAccent).frame(width: 4, height: 4)
                        }
                        if hasHabit {
                            Circle().fill(Color.noorSuccess).frame(width: 4, height: 4)
                        }
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Simple Streak Popup
struct SimpleStreakPopup: View {
    let streakCount: Int
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.noorBackground
                .ignoresSafeArea()

            VStack(spacing: 12) {
                // Flame icon on top
                Image(systemName: "flame.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.noorOrange, Color(hex: "DC2626")],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )

                if streakCount > 0 {
                    // Number centered below flame
                    Text("\(streakCount)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    // "Day(s) in a Row" centered below number
                    Text("Day\(streakCount == 1 ? "" : "s") in a Row")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.noorTextSecondary)
                } else {
                    Text("Start your streak!")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Text(streakCount > 0
                     ? "Open the app daily to keep your streak going!"
                     : "Open Noor tomorrow to start your streak.")
                    .font(NoorFont.callout)
                    .foregroundStyle(Color.noorTextSecondary.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - Animated Flame Icon (realistic flicker)
private struct FlickerFlameView: View {
    @State private var flickerPhase: CGFloat = 0
    @State private var scalePhase: CGFloat = 1

    var body: some View {
        Image(systemName: "flame.fill")
            .font(.system(size: 16))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.noorOrange, Color(hex: "DC2626")],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .scaleEffect(x: 1, y: scalePhase, anchor: .bottom)
            .rotationEffect(.degrees(flickerPhase), anchor: .bottom)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                    flickerPhase = 2.5
                }
                withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                    scalePhase = 1.08
                }
            }
    }
}

// MARK: - Completed Journey Boarding Pass Card
private struct ProgressBoardingPassCard: View {
    let goal: Goal
    let onShare: () -> Void

    private var progress: Double {
        guard !goal.dailyTasks.isEmpty else { return 0 }
        let completed = goal.dailyTasks.filter { $0.isCompleted }.count
        return Double(completed) / Double(goal.dailyTasks.count) * 100
    }
    private var completedSteps: Int { goal.dailyTasks.filter { $0.isCompleted }.count }
    private var totalSteps: Int { goal.dailyTasks.count }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Image(systemName: "airplane")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(white: 0.35))
                Text("BOARDING PASS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.35))
                    .tracking(1.5)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 10))
                    Text("COMPLETED")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(Color.noorSuccess)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.noorSuccess.opacity(0.15))

            // Main content
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FROM")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.5))
                        Text(goal.departure.isEmpty ? "Current You" : goal.departure)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("TO")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.5))
                        Text(goal.destination.isEmpty ? goal.title : goal.destination)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                    }
                }

                // Flight path
                HStack(spacing: 6) {
                    Circle().fill(Color(white: 0.65)).frame(width: 5, height: 5)
                    Rectangle().fill(Color.noorSuccess).frame(height: 2).frame(maxWidth: .infinity)
                    Image(systemName: "airplane").font(.system(size: 10)).foregroundStyle(Color.noorSuccess)
                    Circle().fill(Color.noorSuccess).frame(width: 5, height: 5)
                }

                // Timeline + share button row
                HStack {
                    if !goal.timeline.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar").font(.system(size: 8)).foregroundStyle(Color(white: 0.5))
                            Text("ETA: \(goal.timeline)")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color(white: 0.4))
                        }
                    }
                    Spacer()
                    Button {
                        onShare()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color(white: 0.4))
                            .frame(width: 24, height: 24)
                            .background(Color(white: 0.92))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(Color.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Share Sheet for Progress Tab
private let progressAppLink = "https://testflight.apple.com/join/BJkkK6N6"

private struct ProgressShareSheet: View {
    let goal: Goal

    var body: some View {
        ActivityShareSheet(items: shareItems)
    }

    private var shareItems: [Any] {
        let dest = goal.destination.isEmpty ? goal.title : goal.destination
        let message = "Hey, check out this recent accomplishment of mine — I made it to \(dest)! ✈️\n\nJoin me on Noor:"
        return [message, progressAppLink]
    }
}

#Preview {
    ProgressTabView()
        .environment(DataManager.shared)
}
