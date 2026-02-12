//
//  DailyCheckInView.swift
//  leap
//
//  Goal detail with sequential challenge unlocking
//  "Travel agency for life" - itinerary steps, one at a time
//

import SwiftUI
import SwiftData
import UserNotifications

struct DailyCheckInView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataManager.self) private var dataManager

    let goal: Goal
    @State private var goalRefreshed: Goal?
    @State private var linkedHabits: [Microhabit] = []
    @State private var currentStreak: Int = 0
    @State private var showCelebration = false
    @State private var celebrationMessage = ""
    @State private var isGoalComplete = false
    @State private var hasShownCelebrationThisSession = false
    @State private var showConfetti = false
    @State private var showStreakCelebration = false
    @State private var streakCelebrationCount = 0
    @State private var showDueDatePicker = false
    @State private var editingTask: DailyTask?
    @State private var editingDueDate: Date = Date()
    @State private var checkmarkFillProgress: CGFloat = 0

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
                VStack(alignment: .leading, spacing: 20) {
                    goalOverviewSection
                    currentChallengeSection
                    linkedVisionSection
                    linkedHabitsSection
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
            loadLinkedHabits()
            scheduleDailyChallengeNotification()
        }
        .sheet(isPresented: $showDueDatePicker) {
            dueDatePickerSheet
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

    // MARK: - Goal Overview Section (merged with progress)
    private var goalOverviewSection: some View {
        HStack(alignment: .top, spacing: 16) {
            // Left side: Destination & Why
            VStack(alignment: .leading, spacing: 8) {
                Text("Destination")
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorTextSecondary)
                
                Text(displayGoal.destination.isEmpty ? displayGoal.title : displayGoal.destination)
                    .font(NoorFont.title)
                    .foregroundStyle(.white)
                
                if !displayGoal.timeline.isEmpty {
                    HStack(spacing: 6) {
                        Text("Arrival:")
                            .font(NoorFont.caption)
                            .foregroundStyle(Color.noorTextSecondary)
                        Text(displayGoal.timeline)
                            .font(NoorFont.callout)
                            .foregroundStyle(Color.noorAccent)
                            .fontWeight(.medium)
                    }
                }
                
                // Why this matters (user story)
                if !displayGoal.userStory.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Why this matters")
                            .font(NoorFont.caption)
                            .foregroundStyle(Color.noorTextSecondary)
                        Text(displayGoal.userStory)
                            .font(NoorFont.body)
                            .foregroundStyle(Color.noorRoseGold)
                            .italic()
                            .lineLimit(3)
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right side: Progress ring and challenges count
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.noorViolet.opacity(0.3), lineWidth: 6)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: progress / 100)
                        .stroke(Color.noorAccent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.5), value: progress)
                    
                    VStack(spacing: 0) {
                        Text("\(Int(progress))%")
                            .font(NoorFont.title2)
                            .foregroundStyle(.white)
                    }
                }
                
                Text("\(completedChallenges.count)/\(sortedTasks.count)")
                    .font(NoorFont.callout)
                    .foregroundStyle(Color.noorAccent)
                
                Text("complete")
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorTextSecondary)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Current Challenge Section
    @ViewBuilder
    private var currentChallengeSection: some View {
        if let challenge = currentChallenge {
            VStack(alignment: .leading, spacing: 12) {
                // Header with emphasis
                HStack {
                    Text("Today's Challenge")
                        .font(NoorFont.title)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    if let dueDate = challenge.dueDate {
                        Text("Due \(formatShortDate(dueDate))")
                            .font(NoorFont.callout)
                            .foregroundStyle(dueDateColor(dueDate))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(dueDateColor(dueDate).opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                // Challenge card — prominent and clear
                VStack(spacing: 16) {
                    HStack(alignment: .top, spacing: 16) {
                        // Animated fill checkbox
                        Button {
                            completeChallengeWithAnimation(challenge)
                        } label: {
                            ZStack {
                                // Outline (always visible)
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.noorSuccess, lineWidth: 3)
                                    .frame(width: 36, height: 36)
                                
                                // Fill (animates in)
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.noorSuccess)
                                    .frame(width: 28 * checkmarkFillProgress, height: 28 * checkmarkFillProgress)
                                
                                // Checkmark (appears when complete)
                                if checkmarkFillProgress >= 1 {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(.white)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(challenge.title)
                                .font(NoorFont.title2)
                                .foregroundStyle(Color.noorCharcoal)
                                .fontWeight(.semibold)

                            Text(challenge.taskDescription)
                                .font(NoorFont.body)
                                .foregroundStyle(Color.noorCharcoal.opacity(0.75))

                            HStack(spacing: 12) {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 12))
                                    Text(challenge.estimatedTime)
                                        .font(NoorFont.callout)
                                }
                                .foregroundStyle(Color.noorSuccess)
                            }
                        }
                        
                        Spacer()
                    }
                    
                    // Tap to complete hint — centered
                    Text("Tap the checkbox when you've completed this challenge")
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorCharcoal.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.noorSuccess.opacity(0.2), radius: 12, x: 0, y: 6)
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

    // MARK: - Linked Habits Section
    @ViewBuilder
    private var linkedHabitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(Color.noorSuccess)
                Text("Linked Habits")
                    .font(NoorFont.title2)
                    .foregroundStyle(.white)
            }
            
            if linkedHabits.isEmpty {
                VStack(spacing: 8) {
                    Text("No habits linked yet")
                        .font(NoorFont.body)
                        .foregroundStyle(Color.noorTextSecondary)
                    
                    Text("Link habits to this journey to build consistent daily action")
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorTextSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(linkedHabits, id: \.id) { habit in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.noorSuccess)
                            .frame(width: 8, height: 8)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(habit.title)
                                .font(NoorFont.body)
                                .foregroundStyle(.white)
                            
                            if !habit.habitDescription.isEmpty {
                                Text(habit.habitDescription)
                                    .font(NoorFont.caption)
                                    .foregroundStyle(Color.noorTextSecondary)
                            }
                        }
                        
                        Spacer()
                        
                        if habit.focusDurationMinutes > 0 {
                            Text("\(habit.focusDurationMinutes) min")
                                .font(NoorFont.caption)
                                .foregroundStyle(Color.noorSuccess)
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Linked Vision Section
    @ViewBuilder
    private var linkedVisionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Action-oriented header
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(Color.noorOrange)
                    Text("Take Action Now")
                        .font(NoorFont.title2)
                        .foregroundStyle(.white)
                }
                
                Text("Tap into your vision to fuel momentum")
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorTextSecondary)
            }
            
            VStack(spacing: 8) {
                if !displayGoal.destination.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Color.noorOrange)
                            .font(.system(size: 14))
                        
                        Text("Becoming someone who \(displayGoal.destination.lowercased())")
                            .font(NoorFont.body)
                            .foregroundStyle(Color.noorTextSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.noorOrange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Text("Add vision triggers in the Vision tab to stay inspired and ready to act")
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorTextSecondary.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
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

                        VStack(alignment: .leading, spacing: 2) {
                            Text(challenge.title)
                                .font(NoorFont.body)
                                .foregroundStyle(Color.noorTextSecondary.opacity(0.5))

                            if let dueDate = challenge.dueDate {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 10))
                                    Text("Due \(formatShortDate(dueDate))")
                                        .font(NoorFont.caption)
                                }
                                .foregroundStyle(Color.noorTextSecondary.opacity(0.4))
                                .onTapGesture {
                                    editingTask = challenge
                                    editingDueDate = dueDate
                                    showDueDatePicker = true
                                }
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

                            HStack(spacing: 12) {
                                if let completedAt = challenge.completedAt {
                                    Text("Completed \(formatDate(completedAt))")
                                        .font(NoorFont.caption)
                                        .foregroundStyle(Color.noorTextSecondary.opacity(0.4))
                                }
                                if let dueDate = challenge.dueDate {
                                    Text("Due \(formatShortDate(dueDate))")
                                        .font(NoorFont.caption)
                                        .foregroundStyle(Color.noorTextSecondary.opacity(0.3))
                                }
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

    // MARK: - Due Date Picker Sheet
    private var dueDatePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let task = editingTask {
                    Text(task.title)
                        .font(NoorFont.title2)
                        .foregroundStyle(.white)
                }

                DatePicker(
                    "Due Date",
                    selection: $editingDueDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(Color.noorAccent)
                .colorScheme(.dark)

                Button {
                    if let task = editingTask {
                        task.dueDate = editingDueDate
                        if let updated = goalRefreshed ?? goal as Goal? {
                            goalRefreshed = nil
                            Task { @MainActor in
                                if let g = await dataManager.getGoalByID(updated.id.uuidString) {
                                    goalRefreshed = g
                                }
                            }
                        }
                    }
                    showDueDatePicker = false
                } label: {
                    Text("Save")
                        .font(NoorFont.button)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.noorAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color.noorBackground)
            .navigationTitle("Change Due Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showDueDatePicker = false }
                        .foregroundStyle(Color.noorTextSecondary)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func dueDateColor(_ date: Date) -> Color {
        let today = Calendar.current.startOfDay(for: Date())
        let due = Calendar.current.startOfDay(for: date)
        if due < today {
            return Color.noorCoral // Overdue
        } else if due == today {
            return Color.noorOrange // Due today
        }
        return Color.noorViolet // Future
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

    // MARK: - Load Linked Habits
    private func loadLinkedHabits() {
        Task { @MainActor in
            // Get habits linked to this goal
            let goalID = goal.id.uuidString
            do {
                let allHabits = try await dataManager.fetchMicrohabits()
                linkedHabits = allHabits.filter { habit in
                    habit.goalID == goalID
                }
            } catch {
                print("Failed to load linked habits: \(error)")
            }
        }
    }

    // MARK: - Schedule Daily Challenge Notification
    private func scheduleDailyChallengeNotification() {
        guard let challenge = currentChallenge, let dueDate = challenge.dueDate else { return }
        
        let center = UNUserNotificationCenter.current()
        
        // Remove existing notifications for this goal
        center.removePendingNotificationRequests(withIdentifiers: ["challenge_\(goal.id.uuidString)"])
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Today's Challenge"
        content.body = "\(challenge.title) - Due \(formatShortDate(dueDate))"
        content.sound = .default
        
        // Schedule for 9 AM every day until challenge is complete
        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "challenge_\(goal.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Failed to schedule challenge notification: \(error)")
            }
        }
    }

    // MARK: - Complete Challenge with Animation
    private func completeChallengeWithAnimation(_ task: DailyTask) {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Animate the checkbox filling
        withAnimation(.easeInOut(duration: 0.4)) {
            checkmarkFillProgress = 1.0
        }
        
        // After animation, complete the challenge
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completeChallenge(task)
            // Reset for next challenge
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                checkmarkFillProgress = 0
            }
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
