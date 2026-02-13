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
    @State private var completedTaskTitle: String = ""
    @State private var showDueDatePicker = false
    @State private var editingTask: DailyTask?
    @State private var editingDueDate: Date = Date()
    @State private var checkmarkFillProgress: CGFloat = 0
    @State private var showAddVisionSheet = false
    @State private var showAddHabitSheet = false
    @State private var showChallengeDetail = false
    @State private var linkedVisionItems: [VisionItem] = []

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
                    currentChallengeSection
                    goalOverviewSection
                    visionAndHabitsSection
                    upcomingSection
                    completedSection
                }
                .padding(20)
                .padding(.bottom, 32)
            }

            // Confetti overlay
            if showConfetti {
                ConfettiView(isActive: showConfetti, pieceCount: 160, duration: 4.0, style: .mixed)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(displayGoal.destination.isEmpty ? displayGoal.title : displayGoal.destination)
                    .font(NoorFont.title)
                    .foregroundStyle(.white)
            }
        }
        .onAppear {
            loadStreak()
            loadLinkedHabits()
            loadLinkedVisionItems()
            scheduleDailyChallengeNotification()
        }
        .sheet(isPresented: $showDueDatePicker) {
            dueDatePickerSheet
        }
        .sheet(isPresented: $showAddVisionSheet) {
            AddVisionToJourneySheet(
                goalID: displayGoal.id.uuidString,
                onSave: {
                    loadLinkedVisionItems()
                },
                onDismiss: {
                    showAddVisionSheet = false
                }
            )
        }
        .sheet(isPresented: $showAddHabitSheet) {
            AddMicrohabitView(
                initialType: .create,
                goals: [displayGoal],
                initialGoalID: displayGoal.id.uuidString,
                onDismiss: {
                    showAddHabitSheet = false
                },
                onSave: {
                    showAddHabitSheet = false
                    loadLinkedHabits()
                }
            )
            .environment(dataManager)
        }
        .overlay {
            if showStreakCelebration {
                StreakCelebrationView(
                    streakCount: streakCelebrationCount,
                    userName: userName,
                    completedTaskTitle: completedTaskTitle,
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

    // MARK: - Goal Overview Section (Flight Status — boarding pass style)
    private var goalOverviewSection: some View {
        VStack(spacing: 0) {
            // Header — boarding pass style
            HStack {
                Image(systemName: "airplane")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(white: 0.3))
                Text("FLIGHT STATUS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.3))
                    .tracking(2)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(progress >= 100 ? Color.noorSuccess : Color.noorAccent)
                        .frame(width: 6, height: 6)
                    Text(progress >= 100 ? "ARRIVED" : "EN ROUTE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(progress >= 100 ? Color.noorSuccess : Color.noorAccent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(white: 0.92))

            // Main body — white like boarding pass
            VStack(spacing: 16) {
                // Departure time (journey start) & Arrival time (goal target)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DEPARTURE")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color(white: 0.5))
                        Text(formatDate(displayGoal.createdAt))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                        Text(displayGoal.departure.isEmpty ? "Current You" : displayGoal.departure)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Color(white: 0.45))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("ARRIVAL")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color(white: 0.5))
                        Text(displayGoal.timeline.isEmpty ? "Your Goal" : displayGoal.timeline)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                        Text(displayGoal.destination.isEmpty ? displayGoal.title : displayGoal.destination)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Color(white: 0.45))
                            .lineLimit(1)
                    }
                }

                // Flight path progress line
                GeometryReader { geo in
                    let startX: CGFloat = 0
                    let endX: CGFloat = geo.size.width
                    let midY: CGFloat = geo.size.height / 2

                    ZStack {
                        Path { path in
                            path.move(to: CGPoint(x: startX, y: midY))
                            path.addLine(to: CGPoint(x: endX, y: midY))
                        }
                        .stroke(Color(white: 0.8), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))

                        Path { path in
                            path.move(to: CGPoint(x: startX, y: midY))
                            path.addLine(to: CGPoint(x: endX * progress / 100, y: midY))
                        }
                        .stroke(
                            progress >= 100 ? Color.noorSuccess : Color.noorAccent,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )

                        Circle()
                            .fill(Color(white: 0.5))
                            .frame(width: 6, height: 6)
                            .position(x: startX + 3, y: midY)

                        Circle()
                            .fill(progress >= 100 ? Color.noorSuccess : Color.noorAccent.opacity(0.5))
                            .frame(width: 6, height: 6)
                            .position(x: endX - 3, y: midY)

                        Image(systemName: "airplane")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(progress >= 100 ? Color.noorSuccess : Color.noorAccent)
                            .position(
                                x: max(10, endX * progress / 100),
                                y: midY - 12
                            )
                            .animation(.spring(response: 0.6), value: progress)
                    }
                }
                .frame(height: 32)

                // Stats row
                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("CHALLENGES")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color(white: 0.5))
                        Text("\(completedChallenges.count)/\(sortedTasks.count)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                        Text("completed")
                            .font(.system(size: 9, weight: .regular))
                            .foregroundStyle(Color(white: 0.5))
                    }
                    .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(Color(white: 0.85))
                        .frame(width: 1, height: 50)

                    VStack(spacing: 4) {
                        Text("PROGRESS")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color(white: 0.5))
                        Text("\(Int(progress))%")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(progress >= 100 ? Color.noorSuccess : Color.noorAccent)
                        Text("complete")
                            .font(.system(size: 9, weight: .regular))
                            .foregroundStyle(Color(white: 0.5))
                    }
                    .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(Color(white: 0.85))
                        .frame(width: 1, height: 50)

                    VStack(spacing: 4) {
                        Text("REMAINING")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color(white: 0.5))
                        Text("\(sortedTasks.count - completedChallenges.count)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                        Text("to go")
                            .font(.system(size: 9, weight: .regular))
                            .foregroundStyle(Color(white: 0.5))
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 12)
                .background(Color(white: 0.96))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(16)
            .background(Color.white)
        }
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

                // Challenge card — tap to see details
                Button {
                    showChallengeDetail = true
                } label: {
                    VStack(spacing: 12) {
                        Text(challenge.title)
                            .font(NoorFont.title2)
                            .foregroundStyle(.white)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                            Text(challenge.estimatedTime)
                                .font(NoorFont.callout)
                        }
                        .foregroundStyle(Color.noorSuccess)

                        // Checkbox
                        Button {
                            completeChallengeWithAnimation(challenge)
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white, lineWidth: 3)
                                    .frame(width: 36, height: 36)

                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white)
                                    .frame(width: 28 * checkmarkFillProgress, height: 28 * checkmarkFillProgress)

                                if checkmarkFillProgress >= 1 {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(Color.noorBackground)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showChallengeDetail) {
                    challengeDetailSheet(challenge)
                }
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

    // MARK: - Vision & Habits (list + always-visible add options)
    @ViewBuilder
    private var visionAndHabitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Vision & Habits")
                    .font(NoorFont.title)
                    .foregroundStyle(.white)
                Spacer()
            }

            // Linked vision items
            ForEach(linkedVisionItems) { item in
                Button {
                    openVisionItem(item)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.noorAccent.opacity(0.4))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(item.kind.rawValue.capitalized)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.noorTextSecondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.noorAccent)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            // Linked habit items
            ForEach(linkedHabits) { habit in
                Button {
                    NotificationCenter.default.post(name: NSNotification.Name("switchToTab"), object: 3)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.noorSuccess.opacity(0.4))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(habit.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("Daily habit")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.noorTextSecondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.noorSuccess)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            // Always show add buttons
            HStack(spacing: 12) {
                Button {
                    showAddVisionSheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.noorAccent.opacity(0.8))
                        Text("Add Vision")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.noorTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showAddHabitSheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.noorSuccess.opacity(0.8))
                        Text("Add Habit")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.noorTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
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

    // MARK: - Challenge Detail Sheet
    private func challengeDetailSheet(_ challenge: DailyTask) -> some View {
        NavigationStack {
            ZStack {
                Color.noorBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        Text(challenge.title)
                            .font(NoorFont.title)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        if let dueDate = challenge.dueDate {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12))
                                Text("Due \(formatShortDate(dueDate))")
                                    .font(NoorFont.callout)
                            }
                            .foregroundStyle(dueDateColor(dueDate))
                        }

                        Text(challenge.taskDescription)
                            .font(NoorFont.body)
                            .foregroundStyle(Color.noorTextSecondary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 14))
                            Text(challenge.estimatedTime)
                                .font(NoorFont.body)
                        }
                        .foregroundStyle(Color.noorSuccess)

                        // Complete button
                        if !challenge.isCompleted {
                            Button {
                                showChallengeDetail = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    completeChallengeWithAnimation(challenge)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .bold))
                                    Text("Mark Complete")
                                        .font(NoorFont.button)
                                }
                                .foregroundStyle(Color.noorBackground)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 8)
                        }
                    }
                    .padding(24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showChallengeDetail = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.medium])
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
        return Color.noorAccent // Future
    }

    // MARK: - Actions
    private func completeChallenge(_ task: DailyTask) {
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Show confetti with celebration haptics (heavy → medium → light)
        showConfetti = true
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

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

                // Show streak pop-up when user has a streak
                if currentStreak >= 1 {
                    streakCelebrationCount = currentStreak
                    completedTaskTitle = task.title
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        withAnimation(.spring(response: 0.5)) {
                            showStreakCelebration = true
                        }
                    }
                } else if newProgress >= 100 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        withAnimation(.spring(response: 0.5)) {
                            showCelebration = true
                        }
                    }
                } else {
                    celebrationMessage = "Challenge complete!"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        withAnimation(.spring(response: 0.5)) {
                            showCelebration = true
                        }
                    }
                }

                // Hide confetti after delay (longer so the big burst is visible)
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
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
    
    // MARK: - Load Linked Vision Items
    private func openVisionItem(_ item: VisionItem) {
        switch item.kind {
        case .pinterest, .instagram, .action:
            if let urlString = item.url, let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        case .destination:
            let name = item.placeName ?? item.title
            let query = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
            if let url = URL(string: "https://www.google.com/search?q=flights+to+\(query)") {
                UIApplication.shared.open(url)
            }
        }
    }

    private func loadLinkedVisionItems() {
        // Load vision items from UserDefaults that are linked to this goal
        let goalID = goal.id.uuidString
        if let data = UserDefaults.standard.data(forKey: StorageKey.visionItems),
           let items = try? JSONDecoder().decode([VisionItem].self, from: data) {
            linkedVisionItems = items.filter { $0.goalID == goalID }
        } else {
            linkedVisionItems = []
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

// MARK: - Add Vision to Journey Sheet
struct AddVisionToJourneySheet: View {
    let goalID: String
    let onSave: () -> Void
    let onDismiss: () -> Void
    
    @State private var selectedKind: VisionItemKind = .pinterest
    @State private var title = ""
    @State private var url = ""
    @State private var placeName = ""
    @State private var isSaving = false
    
    private var canSave: Bool {
        switch selectedKind {
        case .pinterest, .instagram:
            return !title.isEmpty && !url.isEmpty
        case .destination:
            return !placeName.isEmpty
        case .action:
            return !title.isEmpty
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.noorBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add to Your Vision")
                                .font(NoorFont.title)
                                .foregroundStyle(.white)
                            Text("Save inspiration that fuels this journey")
                                .font(NoorFont.body)
                                .foregroundStyle(Color.noorTextSecondary)
                        }
                        .padding(.top, 8)
                        
                        // Type selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What are you saving?")
                                .font(NoorFont.title2)
                                .foregroundStyle(.white)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(VisionItemKind.allCases, id: \.self) { kind in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedKind = kind
                                        }
                                    } label: {
                                        VStack(spacing: 8) {
                                            Image(systemName: kind.icon)
                                                .font(.system(size: 24))
                                            Text(kind.displayName)
                                                .font(NoorFont.caption)
                                                .multilineTextAlignment(.center)
                                        }
                                        .foregroundStyle(selectedKind == kind ? .white : Color.noorTextSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedKind == kind ? Color.noorOrange.opacity(0.3) : Color.white.opacity(0.06))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedKind == kind ? Color.noorOrange : Color.clear, lineWidth: 2)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        // Input fields based on type
                        VStack(alignment: .leading, spacing: 16) {
                            switch selectedKind {
                            case .pinterest, .instagram:
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Title")
                                        .font(NoorFont.callout)
                                        .foregroundStyle(Color.noorTextSecondary)
                                    TextField("Name this inspiration", text: $title)
                                        .font(NoorFont.body)
                                        .foregroundStyle(.white)
                                        .padding(14)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .tint(Color.noorOrange)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Link")
                                        .font(NoorFont.callout)
                                        .foregroundStyle(Color.noorTextSecondary)
                                    TextField("Paste URL here", text: $url)
                                        .font(NoorFont.body)
                                        .foregroundStyle(.white)
                                        .keyboardType(.URL)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .padding(14)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .tint(Color.noorOrange)
                                }

                            case .destination:
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Place Name")
                                        .font(NoorFont.callout)
                                        .foregroundStyle(Color.noorTextSecondary)
                                    TextField("Where do you want to go?", text: $placeName)
                                        .font(NoorFont.body)
                                        .foregroundStyle(.white)
                                        .padding(14)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .tint(Color.noorOrange)
                                }

                            case .action:
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Action Step")
                                        .font(NoorFont.callout)
                                        .foregroundStyle(Color.noorTextSecondary)
                                    TextField("What action will you take?", text: $title)
                                        .font(NoorFont.body)
                                        .foregroundStyle(.white)
                                        .padding(14)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .tint(Color.noorOrange)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Link (optional)")
                                        .font(NoorFont.callout)
                                        .foregroundStyle(Color.noorTextSecondary)
                                    TextField("Add a link if relevant", text: $url)
                                        .font(NoorFont.body)
                                        .foregroundStyle(.white)
                                        .keyboardType(.URL)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .padding(14)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .tint(Color.noorOrange)
                                }
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, NoorLayout.horizontalPadding)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveVisionItem()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Save")
                                .font(NoorFont.button)
                                .foregroundStyle(canSave ? Color.noorOrange : Color.noorTextSecondary)
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    private func saveVisionItem() {
        guard canSave, !isSaving else { return }
        isSaving = true
        
        let haptic = UIImpactFeedbackGenerator(style: .medium)
        haptic.impactOccurred()
        
        let item: VisionItem
        switch selectedKind {
        case .pinterest, .instagram:
            item = VisionItem(kind: selectedKind, title: title, url: url, goalID: goalID)
        case .destination:
            item = VisionItem(kind: .destination, title: placeName, placeName: placeName, goalID: goalID)
        case .action:
            item = VisionItem(kind: .action, title: title, url: url.isEmpty ? nil : url, goalID: goalID)
        }
        
        // Load existing items
        var items: [VisionItem] = []
        if let data = UserDefaults.standard.data(forKey: StorageKey.visionItems),
           let decoded = try? JSONDecoder().decode([VisionItem].self, from: data) {
            items = decoded
        }
        
        // Add new item
        items.append(item)
        
        // Save back
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: StorageKey.visionItems)
        }
        
        isSaving = false
        onSave()
        onDismiss()
    }
}

// MARK: - Add Habit to Journey Sheet
struct AddHabitToJourneySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataManager.self) private var dataManager
    
    let goalID: String
    let goalName: String
    let onSave: () -> Void
    let onDismiss: () -> Void
    
    @State private var habitTitle = ""
    @State private var selectedDays: Set<Int> = []
    @State private var focusDuration: Int = 5
    @State private var reminderTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var visionStatement = ""
    @State private var isSaving = false
    
    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    private var canSave: Bool {
        !habitTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !selectedDays.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.noorBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add a Habit")
                                .font(NoorFont.title)
                                .foregroundStyle(.white)
                            HStack(spacing: 6) {
                                Image(systemName: "airplane")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.noorAccent)
                                Text("Linked to: \(goalName)")
                                    .font(NoorFont.callout)
                                    .foregroundStyle(Color.noorAccent)
                            }
                        }
                        .padding(.top, 8)
                        
                        // Habit name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What habit will support this journey?")
                                .font(NoorFont.title2)
                                .foregroundStyle(.white)
                            TextField("e.g., Practice language, Exercise, Read", text: $habitTitle)
                                .font(NoorFont.body)
                                .foregroundStyle(.white)
                                .padding(14)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .tint(Color.noorAccent)
                        }
                        
                        // Days selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Which days?")
                                .font(NoorFont.title2)
                                .foregroundStyle(.white)
                            
                            HStack(spacing: 8) {
                                ForEach(0..<7, id: \.self) { day in
                                    Button {
                                        if selectedDays.contains(day) {
                                            selectedDays.remove(day)
                                        } else {
                                            selectedDays.insert(day)
                                        }
                                    } label: {
                                        Text(dayNames[day])
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(selectedDays.contains(day) ? Color.noorBackground : Color.noorTextSecondary)
                                            .frame(width: 40, height: 40)
                                            .background(
                                                Circle()
                                                    .fill(selectedDays.contains(day) ? Color.noorSuccess : Color.white.opacity(0.08))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        // Focus duration
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Focus time")
                                .font(NoorFont.title2)
                                .foregroundStyle(.white)
                            Text("How many minutes will you dedicate?")
                                .font(NoorFont.caption)
                                .foregroundStyle(Color.noorTextSecondary)
                            
                            HStack(spacing: 16) {
                                ForEach([5, 10, 15, 30], id: \.self) { mins in
                                    Button {
                                        focusDuration = mins
                                    } label: {
                                        Text("\(mins)m")
                                            .font(NoorFont.callout)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(focusDuration == mins ? Color.noorBackground : Color.noorTextSecondary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(
                                                Capsule()
                                                    .fill(focusDuration == mins ? Color.noorSuccess : Color.white.opacity(0.08))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        // Vision statement (optional)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Why does this habit matter?")
                                .font(NoorFont.title2)
                                .foregroundStyle(.white)
                            Text("Connect this habit to your bigger vision (optional)")
                                .font(NoorFont.caption)
                                .foregroundStyle(Color.noorTextSecondary)
                            TextField("e.g., Because I want to become fluent", text: $visionStatement)
                                .font(NoorFont.body)
                                .foregroundStyle(.white)
                                .padding(14)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .tint(Color.noorAccent)
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, NoorLayout.horizontalPadding)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveHabit()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Add")
                                .font(NoorFont.button)
                                .foregroundStyle(canSave ? Color.noorSuccess : Color.noorTextSecondary)
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    private func saveHabit() {
        guard canSave, !isSaving else { return }
        isSaving = true
        
        let haptic = UIImpactFeedbackGenerator(style: .medium)
        haptic.impactOccurred()
        
        let trimmedTitle = habitTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Create the habit
        let habit = Microhabit(
            title: trimmedTitle,
            habitDescription: visionStatement.trimmingCharacters(in: .whitespacesAndNewlines),
            goalID: goalID,
            focusDurationMinutes: focusDuration,
            isArchived: false
        )

        // Save using DataManager
        Task {
            do {
                try await dataManager.saveMicrohabit(habit)
                await MainActor.run {
                    isSaving = false
                    onSave()
                    onDismiss()
                }
            } catch {
                print("Failed to save habit: \(error)")
                await MainActor.run {
                    isSaving = false
                }
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
