//
//  GoalsListView.swift
//  leap
//
//  All flights: active, completed, with filter tabs
//  "Travel agency for life" - your flight history
//

import SwiftUI
import SwiftData

struct GoalsListView: View {
    @Environment(DataManager.self) private var dataManager
    @State private var goals: [Goal] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var goalToDelete: Goal?
    @State private var showDeleteConfirmation = false
    @State private var selectedFilter: GoalFilter = .all

    enum GoalFilter: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case completed = "Completed"
    }

    private var filteredGoals: [Goal] {
        switch selectedFilter {
        case .all: return goals
        case .active: return goals.filter { $0.progress < 100 }
        case .completed: return goals.filter { $0.progress >= 100 }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.noorBackground
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                } else if goals.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        // Filter tabs
                        filterTabs
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        // Goals list
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredGoals, id: \.id) { goal in
                                    NavigationLink(destination: DailyCheckInView(goal: goal)) {
                                        FlightRowCard(goal: goal)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            goalToDelete = goal
                                            showDeleteConfirmation = true
                                        } label: {
                                            Label("Cancel Flight", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding(20)
                        }
                    }
                }
            }
            .navigationTitle("Your Flights")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                DataManager.shared.initialize()
                loadGoals()
            }
            .refreshable { loadGoals() }
            .confirmationDialog("Cancel Flight", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Cancel Flight", role: .destructive) {
                    if let goal = goalToDelete {
                        deleteGoal(goal)
                    }
                    goalToDelete = nil
                }
                Button("Keep", role: .cancel) {
                    goalToDelete = nil
                }
            } message: {
                Text("Are you sure you want to cancel this flight? This cannot be undone.")
            }
        }
    }

    private var filterTabs: some View {
        HStack(spacing: 8) {
            ForEach(GoalFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFilter = filter
                    }
                } label: {
                    Text(filter.rawValue)
                        .font(NoorFont.callout)
                        .foregroundStyle(selectedFilter == filter ? .white : Color.noorTextSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedFilter == filter ? Color.noorViolet : Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "airplane")
                .font(.system(size: 56))
                .foregroundStyle(Color.noorRoseGold.opacity(0.6))

            VStack(spacing: 8) {
                Text("No flights booked yet")
                    .font(NoorFont.title)
                    .foregroundStyle(.white)

                Text("Book your first flight from the Home tab")
                    .font(NoorFont.body)
                    .foregroundStyle(Color.noorTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private func deleteGoal(_ goal: Goal) {
        Task { @MainActor in
            do {
                try await dataManager.deleteGoal(goal.id.uuidString)
                loadGoals()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Flight Row Card
private struct FlightRowCard: View {
    let goal: Goal

    private var progress: Double {
        guard !goal.dailyTasks.isEmpty else { return 0 }
        let completed = goal.dailyTasks.filter { $0.isCompleted }.count
        return Double(completed) / Double(goal.dailyTasks.count) * 100
    }

    private var isComplete: Bool {
        progress >= 100
    }

    var body: some View {
        HStack(spacing: 16) {
            // Category icon
            ZStack {
                Circle()
                    .fill(isComplete ? Color.noorSuccess.opacity(0.2) : Color.noorViolet.opacity(0.3))
                    .frame(width: 48, height: 48)

                Image(systemName: iconForCategory(goal.category))
                    .font(.system(size: 20))
                    .foregroundStyle(isComplete ? Color.noorSuccess : Color.noorRoseGold)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(goal.destination.isEmpty ? goal.title : goal.destination)
                    .font(NoorFont.body)
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    if !goal.timeline.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                            Text(goal.timeline)
                        }
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorTextSecondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.noorOrange)
                        Text("\(goal.currentStreak)")
                    }
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorTextSecondary)
                }
            }

            Spacer()

            // Progress or complete badge
            if isComplete {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.noorSuccess)
            } else {
                VStack(spacing: 2) {
                    Text("\(Int(progress))%")
                        .font(NoorFont.callout)
                        .foregroundStyle(.white)

                    Text("progress")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.noorTextSecondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(Color.noorTextSecondary.opacity(0.5))
        }
        .padding(16)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func iconForCategory(_ category: String) -> String {
        if let goalCat = GoalCategory(rawValue: category) {
            return goalCat.icon
        }
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
    GoalsListView()
        .environment(DataManager.shared)
}
