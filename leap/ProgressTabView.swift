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
    private var globalStreak: Int {
        UserDefaults.standard.integer(forKey: StorageKey.streakCount)
    }

    private var completedCount: Int {
        goals.filter { $0.progress >= 100 }.count
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
                        VStack(alignment: .leading, spacing: 18) {
                            journeysProgressSection
                            habitsProgressSection
                            streakFooter
                        }
                        .padding(20)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Progress")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                }
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

    // Streak at bottom with a different layout: compact horizontal strip, not a top card
    private var streakFooter: some View {
        HStack(spacing: 0) {
            // Streak pill
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.noorOrange, Color.noorAccent],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Text("\(globalStreak)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("day streak")
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorTextSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())

            Spacer()

            // Completed journeys (if any)
            if completedCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.noorSuccess)
                    Text("\(completedCount) done")
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorTextSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
            }
        }
        .padding(.vertical, 8)
    }

    private var journeysProgressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "airplane")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.noorRoseGold)
                Text("Your Journeys")
                    .font(NoorFont.title)
                    .foregroundStyle(.white)
            }

            if goals.isEmpty {
                Text("Book a flight from Home to see progress here.")
                    .font(NoorFont.body)
                    .foregroundStyle(Color.noorTextSecondary)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(goals, id: \.id) { goal in
                    NavigationLink(destination: DailyCheckInView(goal: goal)) {
                        ProgressJourneyRow(goal: goal)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Habits Progress Section
    private var habitsProgressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.noorRoseGold)
                Text("Your Habits")
                    .font(NoorFont.title)
                    .foregroundStyle(.white)
            }

            if microhabits.isEmpty {
                emptyHabitsState
            } else {
                // Stats summary
                habitStatsSummary

                // List of habits with completion status
                ForEach(microhabits, id: \.id) { habit in
                    ProgressHabitRow(habit: habit)
                }
            }
        }
    }

    private var emptyHabitsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf")
                .font(.system(size: 28))
                .foregroundStyle(Color.noorTextSecondary.opacity(0.5))
            Text("No habits yet")
                .font(NoorFont.body)
                .foregroundStyle(Color.noorTextSecondary)
            Text("Add habits from the Habits tab to track them here.")
                .font(NoorFont.caption)
                .foregroundStyle(Color.noorTextSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }

    private var habitStatsSummary: some View {
        let todayCompletedCount = microhabits.filter { isCompletedToday($0) }.count
        let totalCount = microhabits.count
        let completionRate = totalCount > 0 ? Int(Double(todayCompletedCount) / Double(totalCount) * 100) : 0

        return HStack(spacing: 16) {
            // Today's completion
            VStack(spacing: 4) {
                Text("\(todayCompletedCount)/\(totalCount)")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                Text("Today")
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Completion rate
            VStack(spacing: 4) {
                Text("\(completionRate)%")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundStyle(completionRate >= 80 ? Color.noorSuccess : (completionRate >= 50 ? Color.noorRoseGold : Color.noorTextSecondary))
                Text("Complete")
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Total habits tracked
            VStack(spacing: 4) {
                Text("\(totalHabitCompletions())")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundStyle(Color.noorRoseGold)
                Text("All time")
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func isCompletedToday(_ habit: Microhabit) -> Bool {
        let calendar = Calendar.current
        return habit.completedDates.contains { calendar.isDateInToday($0) }
    }

    private func totalHabitCompletions() -> Int {
        microhabits.reduce(0) { $0 + $1.completedDates.count }
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

// MARK: - Progress Habit Row
private struct ProgressHabitRow: View {
    let habit: Microhabit

    private var isCompletedToday: Bool {
        let calendar = Calendar.current
        return habit.completedDates.contains { calendar.isDateInToday($0) }
    }

    private var completionCount: Int {
        habit.completedDates.count
    }

    private var currentStreak: Int {
        let calendar = Calendar.current
        let sortedDates = habit.completedDates
            .map { calendar.startOfDay(for: $0) }
            .sorted(by: >)

        guard !sortedDates.isEmpty else { return 0 }

        var streak = 0
        var expectedDate = calendar.startOfDay(for: Date())

        // If not completed today, start from yesterday
        if !isCompletedToday {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: expectedDate) else { return 0 }
            expectedDate = yesterday
        }

        for date in sortedDates {
            if date == expectedDate {
                streak += 1
                guard let prevDay = calendar.date(byAdding: .day, value: -1, to: expectedDate) else { break }
                expectedDate = prevDay
            } else if date < expectedDate {
                break
            }
        }

        return streak
    }

    var body: some View {
        HStack(spacing: 12) {
            // Completion indicator
            ZStack {
                Circle()
                    .stroke(Color.noorViolet.opacity(0.3), lineWidth: 2)
                    .frame(width: 36, height: 36)

                if isCompletedToday {
                    Circle()
                        .fill(Color.noorSuccess)
                        .frame(width: 36, height: 36)
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: habit.type == .create ? "plus" : "arrow.2.squarepath")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.noorTextSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(habit.title)
                    .font(NoorFont.body)
                    .foregroundStyle(isCompletedToday ? Color.noorTextSecondary : .white)
                    .strikethrough(isCompletedToday)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    // Timeframe
                    HStack(spacing: 4) {
                        Image(systemName: habit.timeframe.icon)
                            .font(.system(size: 10))
                        Text(habit.timeframe.displayName)
                    }
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorTextSecondary.opacity(0.7))

                    // Streak if any
                    if currentStreak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                            Text("\(currentStreak) day\(currentStreak == 1 ? "" : "s")")
                        }
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorOrange)
                    }

                    // Total completions
                    if completionCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 10))
                            Text("\(completionCount)x")
                        }
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorSuccess.opacity(0.8))
                    }
                }
            }

            Spacer()

            // Custom tag if present
            if let tag = habit.customTag, !tag.isEmpty {
                Text(tag)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.noorRoseGold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.noorRoseGold.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(14)
        .background(Color.white.opacity(isCompletedToday ? 0.03 : 0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct ProgressJourneyRow: View {
    let goal: Goal

    private var progress: Double {
        guard !goal.dailyTasks.isEmpty else { return 0 }
        let completed = goal.dailyTasks.filter { $0.isCompleted }.count
        return Double(completed) / Double(goal.dailyTasks.count) * 100
    }

    private var iconForCategory: String {
        if let cat = GoalCategory(rawValue: goal.category) { return cat.icon }
        return "target"
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.noorViolet.opacity(0.3), lineWidth: 3)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(from: 0, to: progress / 100)
                    .stroke(Color.noorRoseGold, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))

                Image(systemName: iconForCategory)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.noorRoseGold)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(goal.destination.isEmpty ? goal.title : goal.destination)
                    .font(NoorFont.body)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Text("\(Int(progress))% complete")
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorTextSecondary)

                    if goal.currentStreak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                            Text("\(goal.currentStreak) day")
                        }
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorOrange)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundStyle(Color.noorTextSecondary.opacity(0.5))
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    ProgressTabView()
        .environment(DataManager.shared)
}
