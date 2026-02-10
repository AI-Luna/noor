//
//  DailyCheckInView.swift
//  leap
//
//  Daily check-in: goal header, today's tasks with checkboxes, streak, celebration modal
//

import SwiftUI
import SwiftData

struct DailyCheckInView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataManager.self) private var dataManager

    let goal: Goal
    @State private var goalRefreshed: Goal?
    @State private var currentStreak: Int = 0
    @State private var showCelebration = false
    @State private var celebrationMessage = ""
    @State private var isSevenDayStreak = false
    @State private var hasShownCelebrationThisSession = false

    private var displayGoal: Goal { goalRefreshed ?? goal }
    private let calendar = Calendar.current

    private var sortedTasks: [DailyTask] {
        displayGoal.dailyTasks.sorted { $0.order < $1.order }
    }

    private func isCompletedToday(_ task: DailyTask) -> Bool {
        let today = calendar.startOfDay(for: Date())
        return task.completedDates.contains { calendar.isDate($0, inSameDayAs: today) }
    }

    private var completedCount: Int {
        sortedTasks.filter { isCompletedToday($0) }.count
    }

    private var totalCount: Int {
        sortedTasks.count
    }

    private var allCompletedToday: Bool {
        totalCount > 0 && completedCount == totalCount
    }

    var body: some View {
        ZStack {
            LinearGradient.noorPurpleBlue
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    todayTasksSection
                    streakSection
                }
                .padding(20)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(displayGoal.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            loadStreak()
        }
        .onChange(of: completedCount) { _, newCount in
            if newCount < totalCount {
                hasShownCelebrationThisSession = false
            } else if newCount == totalCount && totalCount > 0 && !hasShownCelebrationThisSession {
                hasShownCelebrationThisSession = true
                triggerCelebrationIfNeeded()
            }
        }
        .overlay {
            if showCelebration {
                celebrationOverlay
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: iconForCategory(displayGoal.category))
                    .font(.title2)
                    .foregroundStyle(Color.noorPink)
                Text(displayGoal.category)
                    .font(NoorFont.caption)
                    .foregroundStyle(.white.opacity(0.9))
            }
            if !displayGoal.goalDescription.isEmpty {
                Text(displayGoal.goalDescription)
                    .font(NoorFont.body)
                    .foregroundStyle(.white.opacity(0.95))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Today's tasks
    private var todayTasksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Today's tasks")
                    .font(NoorFont.title2)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(completedCount) of \(totalCount) completed")
                    .font(NoorFont.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }

            VStack(spacing: 0) {
                ForEach(sortedTasks, id: \.id) { task in
                    DailyCheckInTaskRow(
                        task: task,
                        isCompleted: isCompletedToday(task),
                        onTap: { toggleTask(task) }
                    )
                }
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
    }

    // MARK: - Streak
    private var streakSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.noorPink.opacity(0.3), lineWidth: 6)
                    .frame(width: 120, height: 120)
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 110, height: 110)
                VStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.noorPink)
                    Text("\(currentStreak)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color.noorPink)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentStreak)

            Text("Current streak: \(currentStreak) day\(currentStreak == 1 ? "" : "s")")
                .font(NoorFont.callout)
                .foregroundStyle(.white)
            Text("Longest streak: \(displayGoal.longestStreak) days")
                .font(NoorFont.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Celebration overlay
    private var celebrationOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { }

            ZStack {
                ConfettiView(isActive: showCelebration, duration: 2.5)
                    .clipShape(RoundedRectangle(cornerRadius: 24))

                VStack(spacing: 24) {
                    Image(systemName: isSevenDayStreak ? "star.circle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color(hex: "FFD93D"))

                    Text(celebrationMessage)
                        .font(NoorFont.largeTitle)
                        .foregroundStyle(Color.noorCharcoal)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { showCelebration = false }
                    } label: {
                        Text("Done")
                            .font(NoorFont.title2)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.noorPink)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
                }
                .padding(32)
                .frame(maxWidth: 320)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "FFE5EC"), Color(hex: "FFF0E5")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            }
            .padding(40)
        }
    }

    // MARK: - Actions
    private func toggleTask(_ task: DailyTask) {
        let goalID = goal.id.uuidString
        let taskID = task.id.uuidString
        let completed = isCompletedToday(task)

        Task { @MainActor in
            do {
                if completed {
                    try await dataManager.removeDailyTaskCompletion(goalID: goalID, taskID: taskID, date: Date())
                } else {
                    try await dataManager.addDailyTaskCompletion(goalID: goalID, taskID: taskID, date: Date())
                }
                loadStreak()
                if let updated = await dataManager.getGoalByID(goal.id.uuidString) {
                    goalRefreshed = updated
                }
            } catch { }
        }
    }

    private func loadStreak() {
        Task { @MainActor in
            currentStreak = await dataManager.getCurrentStreak(goal.id.uuidString)
            if let g = await dataManager.getGoalByID(goal.id.uuidString) {
                goalRefreshed = g
            }
        }
    }

    private func triggerCelebrationIfNeeded() {
        let streak = currentStreak
        if streak >= 7 {
            celebrationMessage = "7 days in a row! You're on fire! 🔥"
            isSevenDayStreak = true
        } else {
            celebrationMessage = "You crushed it today!"
            isSevenDayStreak = false
        }
        withAnimation(.easeOut(duration: 0.25)) {
            showCelebration = true
        }
    }

    private func iconForCategory(_ category: String) -> String {
        switch category.lowercased() {
        case "fitness": return "figure.run"
        case "mindfulness": return "brain.head.profile"
        case "productivity": return "bolt.fill"
        case "financial habits": return "dollarsign.circle.fill"
        case "parenthood": return "heart.circle.fill"
        case "personal growth": return "leaf.fill"
        default: return "target"
        }
    }
}

// MARK: - Task row with checkbox and haptic
struct DailyCheckInTaskRow: View {
    let task: DailyTask
    let isCompleted: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { onTap() }
        }) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isCompleted ? Color.green : Color.gray.opacity(0.4), lineWidth: 2)
                        .frame(width: 28, height: 28)
                    if isCompleted {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green)
                            .frame(width: 28, height: 28)
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isCompleted)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(NoorFont.body)
                        .foregroundStyle(isCompleted ? Color.noorCharcoal.opacity(0.6) : Color.noorCharcoal)
                        .strikethrough(isCompleted)
                    if !task.taskDescription.isEmpty {
                        Text(task.taskDescription)
                            .font(NoorFont.caption)
                            .foregroundStyle(Color.noorCharcoal.opacity(0.6))
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        DailyCheckInView(goal: Goal(
            title: "Morning routine",
            goalDescription: "Start the day right.",
            category: "Personal Growth",
            targetDaysPerWeek: 5
        ))
        .environment(DataManager.shared)
    }
}
