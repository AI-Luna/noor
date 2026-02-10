//
//  ProgressTabView.swift
//  leap
//
//  One core feature: see your progress — streak + journey completion.
//

import SwiftUI
import SwiftData

struct ProgressTabView: View {
    @Environment(DataManager.self) private var dataManager
    @State private var goals: [Goal] = []
    @State private var visionItems: [VisionItem] = []
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
                        VStack(alignment: .leading, spacing: 24) {
                            streakBlock
                            journeysProgressSection
                            visionByJourneySection
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
                loadVisionItems()
            }
            .refreshable {
                loadGoals()
                loadVisionItems()
            }
        }
    }

    private var streakBlock: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.noorOrange, Color.noorAccent],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(globalStreak) day streak")
                        .font(NoorFont.title)
                        .foregroundStyle(.white)

                    Text(globalStreak > 0 ? "Keep it going." : "Start your first step from Home.")
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorTextSecondary)
                }

                Spacer()
            }
            .padding(20)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 20))

            if completedCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.noorSuccess)
                    Text("\(completedCount) journey\(completedCount == 1 ? "" : "s") completed")
                        .font(NoorFont.body)
                        .foregroundStyle(Color.noorTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var journeysProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your journeys")
                .font(NoorFont.title2)
                .foregroundStyle(.white)

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

    private var visionByJourneySection: some View {
        VisionByJourneyBlock(goals: goals, visionItems: visionItems)
    }

    private func loadVisionItems() {
        guard let data = UserDefaults.standard.data(forKey: StorageKey.visionItems),
              let decoded = try? JSONDecoder().decode([VisionItem].self, from: data) else {
            visionItems = []
            return
        }
        visionItems = decoded
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

// MARK: - Vision tied to journeys (Progress tab)
private struct VisionByJourneyBlock: View {
    let goals: [Goal]
    let visionItems: [VisionItem]

    private var linkedByGoal: [(Goal, [VisionItem])] {
        goals.map { goal in
            let items = visionItems.filter { $0.goalID == goal.id.uuidString }
            return (goal, items)
        }.filter { !$0.1.isEmpty }
    }

    private var unlinkedItems: [VisionItem] {
        visionItems.filter { $0.goalID == nil || $0.goalID?.isEmpty == true }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if visionItems.isEmpty {
                Spacer(minLength: 0)
                    .frame(height: 0)
            } else {
                HStack {
                    Image(systemName: "link")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.noorRoseGold)
                    Text("Vision tied to your journeys")
                        .font(NoorFont.title2)
                        .foregroundStyle(.white)
                }

                ForEach(linkedByGoal, id: \.0.id) { goal, items in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(goal.destination.isEmpty ? goal.title : goal.destination)
                            .font(NoorFont.title2)
                            .foregroundStyle(Color.noorRoseGold)
                        ForEach(items, id: \.id) { item in
                            visionItemRow(item)
                        }
                    }
                }

                if !unlinkedItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Not linked to a journey")
                            .font(NoorFont.title2)
                            .foregroundStyle(Color.noorTextSecondary)
                        ForEach(unlinkedItems, id: \.id) { item in
                            visionItemRow(item)
                        }
                    }
                }

                Text("Add and link vision items in the Vision tab.")
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorTextSecondary)
            }
        }
    }

    private func visionItemRow(_ item: VisionItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.kind.icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.noorTextSecondary)
                .frame(width: 24, alignment: .center)
            Text(item.title)
                .font(NoorFont.body)
                .foregroundStyle(.white)
                .strikethrough(item.isCompleted)
                .lineLimit(1)
            if item.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.noorSuccess)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
