//
//  DailyCheckInView.swift
//  leap
//
//  Goal detail with sequential challenge unlocking
//  "Travel agency for life" - itinerary steps, one at a time
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
    @State private var isGoalComplete = false
    @State private var hasShownCelebrationThisSession = false
    @State private var showConfetti = false
    @State private var showStreakCelebration = false
    @State private var streakCelebrationCount = 0

    private var displayGoal: Goal { goalRefreshed ?? goal }
    private let calendar = Calendar.current

    private var sortedTasks: [DailyTask] {
        displayGoal.dailyTasks.sorted { $0.order < $1.order }
    }

    // Current challenge: first unlocked, uncompleted task
    private var currentChallenge: DailyTask? {
        sortedTasks.first { $0.isUnlocked && !$0.isCompleted }
    }

    // Upcoming: locked tasks
    private var upcomingChallenges: [DailyTask] {
        sortedTasks.filter { !$0.isUnlocked }
    }

    // Completed challenges
    private var completedChallenges: [DailyTask] {
        sortedTasks.filter { $0.isCompleted }
    }

    private var progress: Double {
        guard !sortedTasks.isEmpty else { return 0 }
        return Double(completedChallenges.count) / Double(sortedTasks.count) * 100
    }

    var body: some View {
        ZStack {
            // Background
            Color.noorBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    progressSection
                    currentChallengeSection
                    upcomingSection
                    completedSection
                }
                .padding(20)
                .padding(.bottom, 32)
            }

            // Confetti overlay
            if showConfetti {
                ConfettiView(isActive: showConfetti, duration: 2.0)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .navigationTitle(displayGoal.destination.isEmpty ? displayGoal.title : displayGoal.destination)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            loadStreak()
        }
        .overlay {
            if showStreakCelebration {
                StreakCelebrationView(
                    streakCount: streakCelebrationCount,
                    userName: userName,
                    onDismiss: {
                        showStreakCelebration = false
                        showConfetti = false
                    }
                )
                .transition(.opacity)
            } else if showCelebration {
                celebrationOverlay
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category icon and label
            HStack(spacing: 12) {
                Image(systemName: iconForCategory(displayGoal.category))
                    .font(.system(size: 32))
                    .foregroundStyle(Color.noorRoseGold)

                VStack(alignment: .leading, spacing: 4) {
                    Text(GoalCategory(rawValue: displayGoal.category)?.shortName ?? displayGoal.category)
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorTextSecondary)

                    if !displayGoal.timeline.isEmpty {
                        Text("Arrival: \(displayGoal.timeline)")
                            .font(NoorFont.caption)
                            .foregroundStyle(Color.noorRoseGold)
                    }
                }

                Spacer()

                // Streak badge
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Color.noorOrange)
                    Text("\(currentStreak)")
                        .font(NoorFont.callout)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
            }

            // User story / description
            if !displayGoal.userStory.isEmpty {
                Text(displayGoal.userStory)
                    .font(NoorFont.body)
                    .foregroundStyle(Color.noorTextSecondary)
                    .lineLimit(3)
            }

            // Boarding pass message
            if !displayGoal.boardingPass.isEmpty {
                Text(displayGoal.boardingPass)
                    .font(NoorFont.body)
                    .foregroundStyle(Color.noorRoseGold)
                    .italic()
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Progress Section
    private var progressSection: some View {
        VStack(spacing: 12) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.noorViolet.opacity(0.3), lineWidth: 8)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: progress / 100)
                    .stroke(
                        LinearGradient(
                            colors: [Color.noorViolet, Color.noorAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5), value: progress)

                VStack(spacing: 2) {
                    Text("\(Int(progress))%")
                        .font(NoorFont.title)
                        .foregroundStyle(.white)

                    Text("complete")
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorTextSecondary)
                }
            }

            Text("\(completedChallenges.count) of \(sortedTasks.count) challenges complete")
                .font(NoorFont.caption)
                .foregroundStyle(Color.noorTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Current Challenge Section
    @ViewBuilder
    private var currentChallengeSection: some View {
        if let challenge = currentChallenge {
            VStack(alignment: .leading, spacing: 16) {
                Text("Today's Challenge")
                    .font(NoorFont.title2)
                    .foregroundStyle(.white)

                // Challenge card
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 16) {
                        // Checkbox
                        Button {
                            completeChallenge(challenge)
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.noorRoseGold, lineWidth: 2)
                                    .frame(width: 32, height: 32)
                            }
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(challenge.title)
                                .font(NoorFont.title2)
                                .foregroundStyle(Color.noorCharcoal)

                            Text(challenge.taskDescription)
                                .font(NoorFont.body)
                                .foregroundStyle(Color.noorCharcoal.opacity(0.8))

                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 12))
                                Text(challenge.estimatedTime)
                                    .font(NoorFont.caption)
                            }
                            .foregroundStyle(Color.noorViolet)
                        }
                    }
                }
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
            }
        } else if progress >= 100 {
            // All complete
            VStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.noorSuccess)

                Text("Journey Complete!")
                    .font(NoorFont.title)
                    .foregroundStyle(.white)

                Text("You've completed all challenges for this goal.")
                    .font(NoorFont.body)
                    .foregroundStyle(Color.noorTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - Upcoming Section
    @ViewBuilder
    private var upcomingSection: some View {
        if !upcomingChallenges.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(Color.noorTextSecondary.opacity(0.5))
                    Text("Upcoming Challenges")
                        .font(NoorFont.title2)
                        .foregroundStyle(.white)
                }

                ForEach(upcomingChallenges, id: \.id) { challenge in
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.noorTextSecondary.opacity(0.4))
                            .frame(width: 24)

                        Text(challenge.title)
                            .font(NoorFont.body)
                            .foregroundStyle(Color.noorTextSecondary.opacity(0.5))

                        Spacer()
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Completed Section
    @ViewBuilder
    private var completedSection: some View {
        if !completedChallenges.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.noorSuccess)
                    Text("Completed")
                        .font(NoorFont.title2)
                        .foregroundStyle(.white)
                }

                ForEach(completedChallenges, id: \.id) { challenge in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.noorSuccess)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(challenge.title)
                                .font(NoorFont.body)
                                .foregroundStyle(Color.noorTextSecondary.opacity(0.6))
                                .strikethrough()

                            if let completedAt = challenge.completedAt {
                                Text(formatDate(completedAt))
                                    .font(NoorFont.caption)
                                    .foregroundStyle(Color.noorTextSecondary.opacity(0.4))
                            }
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Celebration overlay
    private var celebrationOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { }

            VStack(spacing: 24) {
                // Badge
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.noorRoseGold, Color.noorOrange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: Color.noorRoseGold.opacity(0.5), radius: 20)

                    Image(systemName: isGoalComplete ? "crown.fill" : "checkmark")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text(celebrationMessage)
                    .font(NoorFont.largeTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if isGoalComplete {
                    Text("""
                    I remember this day. I wondered if this would work. Would I finally follow through?

                    Here's a secret...you can.

                    How do I know? I am Future You. I did it. We did it.
                    """)
                        .font(NoorFont.body)
                        .foregroundStyle(Color.noorTextSecondary)
                        .multilineTextAlignment(.center)
                        .italic()
                        .padding(.horizontal, 24)
                }

                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showCelebration = false
                        showConfetti = false
                    }
                } label: {
                    Text("Continue")
                        .font(NoorFont.button)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.noorAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)
            }
            .padding(32)
            .frame(maxWidth: 340)
            .background(
                Color.noorDeepPurple
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
        }
    }

    // MARK: - Actions
    private func completeChallenge(_ task: DailyTask) {
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Show confetti
        showConfetti = true

        // Mark task as complete
        let goalID = goal.id.uuidString
        let taskID = task.id.uuidString

        Task { @MainActor in
            do {
                // Add completion
                try await dataManager.addDailyTaskCompletion(goalID: goalID, taskID: taskID, date: Date())

                // Unlock next challenge
                await unlockNextChallenge(after: task)

                // Update streak
                await updateStreak()

                // Sync global streak for Dashboard
                let existingGlobal = UserDefaults.standard.integer(forKey: StorageKey.streakCount)
                if currentStreak > existingGlobal {
                    UserDefaults.standard.set(currentStreak, forKey: StorageKey.streakCount)
                }

                // Refresh goal
                if let updated = await dataManager.getGoalByID(goalID) {
                    goalRefreshed = updated
                }

                // Check if goal is complete
                let newProgress = Double(completedChallenges.count + 1) / Double(sortedTasks.count) * 100
                if newProgress >= 100 {
                    isGoalComplete = true
                    celebrationMessage = "Congratulations, \(userName)!"
                }

                // Show streak pop-up when user has a streak (matches reference design)
                if currentStreak >= 1 {
                    streakCelebrationCount = currentStreak
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.spring(response: 0.5)) {
                            showStreakCelebration = true
                        }
                    }
                } else if newProgress >= 100 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.spring(response: 0.5)) {
                            showCelebration = true
                        }
                    }
                } else {
                    celebrationMessage = "Challenge complete!"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.spring(response: 0.5)) {
                            showCelebration = true
                        }
                    }
                }

                // Hide confetti after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    showConfetti = false
                }

            } catch {
                print("Failed to complete challenge: \(error)")
            }
        }
    }

    private func unlockNextChallenge(after completedTask: DailyTask) async {
        let nextOrder = completedTask.order + 1
        if let nextTask = sortedTasks.first(where: { $0.order == nextOrder }) {
            // Mark next task as unlocked
            nextTask.isUnlocked = true
            // Save changes through data manager
            if let updated = await dataManager.getGoalByID(goal.id.uuidString) {
                goalRefreshed = updated
            }
        }
    }

    private func updateStreak() async {
        let today = calendar.startOfDay(for: Date())
        let lastAction = displayGoal.lastActionDate ?? Date.distantPast
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        if calendar.isDate(lastAction, inSameDayAs: today) {
            // Already completed today, no change
            return
        } else if calendar.isDate(lastAction, inSameDayAs: yesterday) {
            // Streak continues
            currentStreak += 1
        } else {
            // Streak broken, start fresh
            currentStreak = 1
        }

        // Persist goal streak
        do {
            try await dataManager.updateGoalStreak(goalID: goal.id.uuidString, streak: currentStreak, lastActionDate: today)
        } catch {
            print("Failed to update goal streak: \(error)")
        }
    }

    private var userName: String {
        UserDefaults.standard.string(forKey: "userName") ?? "Traveler"
    }

    private func loadStreak() {
        Task { @MainActor in
            currentStreak = await dataManager.getCurrentStreak(goal.id.uuidString)
            if let g = await dataManager.getGoalByID(goal.id.uuidString) {
                goalRefreshed = g
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func iconForCategory(_ category: String) -> String {
        // Check new categories first
        if let goalCat = GoalCategory(rawValue: category) {
            return goalCat.icon
        }
        // Legacy category mapping
        switch category.lowercased() {
        case "fitness": return "figure.run"
        case "mindfulness": return "brain.head.profile"
        case "productivity": return "bolt.fill"
        case "financial habits", "finance": return "dollarsign.circle.fill"
        case "parenthood", "relationship": return "heart.fill"
        case "personal growth", "growth": return "leaf.fill"
        case "travel": return "airplane"
        case "career": return "briefcase.fill"
        default: return "target"
        }
    }
}

#Preview {
    NavigationStack {
        DailyCheckInView(goal: Goal(
            title: "Iceland Adventure",
            goalDescription: "Finally taking that solo trip I've been dreaming about.",
            category: "travel",
            destination: "Iceland",
            timeline: "June 2026",
            userStory: "I've been pinning Iceland photos for 3 years. Time to make it real.",
            boardingPass: "Your flight to the woman who travels solo is boarding.",
            targetDaysPerWeek: 7
        ))
        .environment(DataManager.shared)
    }
}
