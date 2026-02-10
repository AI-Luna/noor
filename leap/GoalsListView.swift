//
//  GoalsListView.swift
//  leap
//
//  List of all goals: title, streak, last completed; tap → DailyCheckIn, swipe to delete
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

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.noorPurpleBlue
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                } else if goals.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(goals, id: \.id) { goal in
                            NavigationLink(destination: DailyCheckInView(goal: goal)) {
                                GoalRowView(goal: goal)
                            }
                            .listRowBackground(Color.white.opacity(0.95))
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                            .listRowSeparatorTint(Color.noorCharcoal.opacity(0.15))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    goalToDelete = goal
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Goals")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                DataManager.shared.initialize()
                loadGoals()
            }
            .refreshable { loadGoals() }
            .confirmationDialog("Delete Goal", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let goal = goalToDelete {
                        deleteGoal(goal)
                    }
                    goalToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    goalToDelete = nil
                }
            } message: {
                Text("Are you sure? This cannot be undone.")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.7))
            Text("No goals yet")
                .font(NoorFont.title2)
                .foregroundStyle(.white)
            Text("Create one from the Home tab")
                .font(NoorFont.caption)
                .foregroundStyle(.white.opacity(0.8))
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

// MARK: - Goal row
private struct GoalRowView: View {
    let goal: Goal

    private var lastCompletedDate: Date? {
        let allDates = goal.dailyTasks.flatMap(\.completedDates)
        return allDates.max()
    }

    private var lastCompletedText: String {
        guard let date = lastCompletedDate else { return "Not yet" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: iconForCategory(goal.category))
                .font(.title2)
                .foregroundStyle(Color.noorPink)
                .frame(width: 36, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(NoorFont.callout)
                    .foregroundStyle(Color.noorCharcoal)
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.noorPink)
                        Text("\(goal.currentStreak) day streak")
                            .font(NoorFont.caption)
                            .foregroundStyle(Color.noorCharcoal.opacity(0.8))
                    }
                    Text("•")
                        .foregroundStyle(Color.noorCharcoal.opacity(0.5))
                    Text(lastCompletedText)
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorCharcoal.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.noorCharcoal.opacity(0.4))
        }
        .padding(.vertical, 4)
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

#Preview {
    GoalsListView()
        .environment(DataManager.shared)
}
