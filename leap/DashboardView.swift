//
//  DashboardView.swift
//  leap
//
//  Main daily view: greeting, today's goal cards, tasks, streak, CTA
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(DataManager.self) private var dataManager
    @Environment(PurchaseManager.self) private var purchaseManager
    @State private var goals: [Goal] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCreateGoal = false
    @State private var showPaywall = false
    private let calendar = Calendar.current
    private let userName = "Seeker" // placeholder; could come from UserDefaults

    private var canCreateNewGoal: Bool {
        purchaseManager.isPro || goals.count < 1
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.noorPurpleBlue
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                } else if let msg = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                        Text(msg)
                            .font(NoorFont.body)
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            greetingSection
                            if goals.isEmpty {
                                emptyState
                            } else {
                                goalCardsSection
                            }
                            ctaSection
                        }
                        .padding(20)
                        .padding(.bottom, 80)
                    }
                }

                // Floating action button: create goal or show paywall if at limit
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            if canCreateNewGoal {
                                showCreateGoal = true
                            } else {
                                showPaywall = true
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.noorPink)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                    }
                }
                .allowsHitTesting(!isLoading && errorMessage == nil)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if canCreateNewGoal {
                            showCreateGoal = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .onAppear {
                DataManager.shared.initialize()
                loadGoals()
            }
            .refreshable { loadGoals() }
            .sheet(isPresented: $showCreateGoal, onDismiss: { loadGoals() }) {
                CreateGoalView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(
                    onDismiss: { showPaywall = false },
                    proGateMessage: "Pro members can create unlimited goals"
                )
            }
        }
    }

    // MARK: - Greeting
    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Good morning, \(userName)!")
                .font(NoorFont.largeTitle)
                .foregroundStyle(.white)
            Text(formattedDate)
                .font(NoorFont.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: Date())
    }

    // MARK: - Empty state
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.7))
            Text("Create your first goal to get started")
                .font(NoorFont.title2)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Goal cards
    private var goalCardsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's goals")
                .font(NoorFont.title2)
                .foregroundStyle(.white)

            ForEach(goals, id: \.id) { goal in
                GoalCardView(
                    goal: goal,
                    todayTasks: sortedTasks(for: goal),
                    onToggleTask: { task in toggleTask(task, goal: goal) }
                )
            }
        }
    }

    private func sortedTasks(for goal: Goal) -> [DailyTask] {
        goal.dailyTasks.sorted { $0.order < $1.order }
    }

    private func isCompletedToday(_ task: DailyTask) -> Bool {
        let today = calendar.startOfDay(for: Date())
        return task.completedDates.contains { calendar.isDate($0, inSameDayAs: today) }
    }

    private func toggleTask(_ task: DailyTask, goal: Goal) {
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
                loadGoals()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - CTA
    private var ctaSection: some View {
        VStack(spacing: 12) {
            if goals.isEmpty {
                Button { showCreateGoal = true } label: {
                    ctaButton(title: "Create New Goal")
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink(destination: AllGoalsPlaceholderView()) {
                    ctaButton(title: "View All Goals")
                }
            }
        }
        .padding(.top, 8)
    }

    private func ctaButton(title: String) -> some View {
        Text(title)
            .font(NoorFont.title2)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: NoorLayout.buttonHeight)
            .background(Color.noorPink)
            .clipShape(RoundedRectangle(cornerRadius: NoorLayout.cornerRadius))
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

// MARK: - Goal card
struct GoalCardView: View {
    let goal: Goal
    let todayTasks: [DailyTask]
    let onToggleTask: (DailyTask) -> Void

    private let calendar = Calendar.current

    private func isCompletedToday(_ task: DailyTask) -> Bool {
        let today = calendar.startOfDay(for: Date())
        return task.completedDates.contains { calendar.isDate($0, inSameDayAs: today) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            NavigationLink(destination: DailyCheckInView(goal: goal)) {
                HStack(spacing: 12) {
                    Image(systemName: iconForCategory(goal.category))
                        .font(.title2)
                        .foregroundStyle(Color.noorPink)
                    Text(goal.title)
                        .font(NoorFont.title2)
                        .foregroundStyle(Color.noorCharcoal)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color.noorCharcoal.opacity(0.5))
                }
            }
            .buttonStyle(.plain)

            ForEach(todayTasks, id: \.id) { task in
                TaskRowView(
                    task: task,
                    isCompleted: isCompletedToday(task),
                    onTap: { onToggleTask(task) }
                )
            }

            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Color.noorPink)
                Text("\(goal.currentStreak) day streak")
                    .font(NoorFont.callout)
                    .foregroundStyle(Color.noorPink)
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: NoorLayout.cornerRadius))
        .shadow(color: .black.opacity(0.08), radius: NoorLayout.cardShadowRadius, x: 0, y: NoorLayout.cardShadowY)
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

// MARK: - Task row with checkbox
struct TaskRowView: View {
    let task: DailyTask
    let isCompleted: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { onTap() }
        }) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isCompleted ? Color.green : Color.gray.opacity(0.5), lineWidth: 2)
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
                Text(task.title)
                    .font(NoorFont.body)
                    .foregroundStyle(isCompleted ? Color.noorCharcoal.opacity(0.6) : Color.noorCharcoal)
                    .strikethrough(isCompleted)
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// Placeholder destinations until full flows exist
struct CreateGoalPlaceholderView: View {
    var body: some View {
        Text("Create New Goal")
            .font(NoorFont.title)
        Text("Goal creation flow coming soon.")
            .font(NoorFont.caption)
            .foregroundStyle(.secondary)
    }
}

struct AllGoalsPlaceholderView: View {
    var body: some View {
        Text("All Goals")
            .font(NoorFont.title)
        Text("Full list coming soon.")
            .font(NoorFont.caption)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Goal detail (navigation destination)
struct GoalDetailView: View {
    let goal: Goal
    private let calendar = Calendar.current

    private var sortedTasks: [DailyTask] {
        goal.dailyTasks.sorted { $0.order < $1.order }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(goal.goalDescription)
                    .font(NoorFont.body)
                    .foregroundStyle(Color.noorCharcoal)
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Color.noorPink)
                    Text("\(goal.currentStreak) day streak • Longest: \(goal.longestStreak)")
                        .font(NoorFont.callout)
                        .foregroundStyle(Color.noorCharcoal)
                }
                Text("Tasks")
                    .font(NoorFont.title2)
                    .foregroundStyle(Color.noorCharcoal)
                ForEach(sortedTasks, id: \.id) { task in
                    Text("• \(task.title)")
                        .font(NoorFont.body)
                        .foregroundStyle(Color.noorCharcoal)
                }
            }
            .padding(20)
        }
        .navigationTitle(goal.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    DashboardView()
        .environment(DataManager.shared)
}
