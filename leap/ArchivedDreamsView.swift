//
//  ArchivedDreamsView.swift
//  leap
//
//  Archived dreams: completed journeys stored for posterity.
//

import SwiftUI

struct ArchivedDreamsView: View {
    @Environment(DataManager.self) private var dataManager
    @State private var archivedGoals: [Goal] = []
    @State private var goalToDelete: Goal?
    @State private var showDeleteConfirmation = false

    var body: some View {
        ZStack {
            Color.noorBackground
                .ignoresSafeArea()

            if archivedGoals.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(archivedGoals, id: \.id) { goal in
                            SwipeActionCard(
                                onEdit: { unarchive(goal) },
                                onDelete: {
                                    goalToDelete = goal
                                    showDeleteConfirmation = true
                                },
                                editIcon: "arrow.uturn.backward",
                                editLabel: "Restore",
                                editColor: Color.noorAmber
                            ) {
                                archivedCard(goal: goal)
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 16)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Image(systemName: "archivebox")
                        .foregroundStyle(Color.noorRoseGold)
                    Text("Archives")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                }
            }
        }
        .onAppear { loadArchived() }
        .alert("Delete this dream?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                goalToDelete = nil
            }
            Button("Delete Forever", role: .destructive) {
                if let goal = goalToDelete {
                    deleteDream(goal)
                }
            }
        } message: {
            Text("This will permanently remove this dream and all its challenges. This cannot be undone.")
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "archivebox")
                .font(.system(size: 48))
                .foregroundStyle(Color.noorTextSecondary.opacity(0.4))

            Text("No archived dreams yet")
                .font(NoorFont.title2)
                .foregroundStyle(Color.noorTextSecondary.opacity(0.6))

            Text("Completed dreams can be archived\nfrom your home screen.")
                .font(NoorFont.caption)
                .foregroundStyle(Color.noorTextSecondary.opacity(0.4))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Archived Card
    private func archivedCard(goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.destination.isEmpty ? goal.title : goal.destination)
                        .font(NoorFont.title2)
                        .foregroundStyle(.white)

                    if !goal.timeline.isEmpty {
                        Text("Arrival: \(goal.timeline)")
                            .font(NoorFont.caption)
                            .foregroundStyle(Color.noorTextSecondary)
                    }
                }

                Spacer()

                // Completed badge
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.noorSuccess)
            }

            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.noorSuccess)

                Text("Journey Complete — \(goal.dailyTasks.count) challenges done")
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorTextSecondary)
            }

            // Hint
            Text("Swipe right to restore · Swipe left to delete")
                .font(.system(size: 11))
                .foregroundStyle(Color.noorTextSecondary.opacity(0.4))
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.noorDeepPurple, Color.noorViolet.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .opacity(0.8)
    }

    // MARK: - Actions
    private func loadArchived() {
        Task { @MainActor in
            do {
                archivedGoals = try await dataManager.fetchArchivedGoals()
            } catch {
                archivedGoals = []
            }
        }
    }

    private func unarchive(_ goal: Goal) {
        Task { @MainActor in
            do {
                try await dataManager.unarchiveGoal(goal.id.uuidString)
                loadArchived()
            } catch {}
        }
    }

    private func deleteDream(_ goal: Goal) {
        Task { @MainActor in
            do {
                try await dataManager.deleteGoal(goal.id.uuidString)
                goalToDelete = nil
                loadArchived()
            } catch {}
        }
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
    NavigationStack {
        ArchivedDreamsView()
            .environment(DataManager.shared)
    }
}
