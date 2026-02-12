//
//  ContentView.swift
//  leap
//
//  App shell: cinematic onboarding gate then TabView (Home, Goals, Profile)
//

import SwiftUI

struct ContentView: View {
    @Environment(PurchaseManager.self) private var purchaseManager
    @Environment(DataManager.self) private var dataManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var showPurchaseErrorAlert = false
    @State private var hasCreatedFirstGoal = false
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack {
            if !hasCompletedOnboarding {
                OnboardingView(onComplete: {
                    hasCompletedOnboarding = true
                    createFirstGoalFromOnboarding()
                })
            } else {
                TabView(selection: $selectedTab) {
                    DashboardView()
                        .tabItem {
                            Label("Home", systemImage: "airplane")
                        }
                        .tag(0)
                    ProgressTabView()
                        .tabItem {
                            Label("Progress", systemImage: "flame.fill")
                        }
                        .tag(1)
                    VisionView()
                        .tabItem {
                            Label("Vision", systemImage: "eye.fill")
                        }
                        .tag(2)
                    MicrohabitsView()
                        .tabItem {
                            Label("Habits", systemImage: "leaf.fill")
                        }
                        .tag(3)
                }
                .tint(Color.noorAccent)
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("switchToTab"))) { notification in
                    if let tab = notification.object as? Int {
                        selectedTab = tab
                    }
                }
                .onChange(of: purchaseManager.errorMessage) { _, newValue in
                    showPurchaseErrorAlert = (newValue != nil && !(newValue?.isEmpty ?? true))
                }
                .alert("Error", isPresented: $showPurchaseErrorAlert) {
                    Button("OK") {
                        showPurchaseErrorAlert = false
                        purchaseManager.errorMessage = nil
                    }
                } message: {
                    if let msg = purchaseManager.errorMessage {
                        Text(msg)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func createFirstGoalFromOnboarding() {
        guard !hasCreatedFirstGoal else { return }
        hasCreatedFirstGoal = true

        // Retrieve first goal data from onboarding
        guard let data = UserDefaults.standard.data(forKey: StorageKey.firstGoalData),
              let goalData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        let category = goalData["category"] as? String ?? "travel"
        let destination = goalData["destination"] as? String ?? ""
        let timeline = goalData["timeline"] as? String ?? ""
        let userStory = goalData["userStory"] as? String ?? ""
        let boardingPass = goalData["boardingPass"] as? String ?? ""
        let challengesData = goalData["challenges"] as? [[String: Any]] ?? []

        // Create goal
        let goal = Goal(
            title: destination.isEmpty ? "My First Journey" : destination,
            goalDescription: userStory,
            category: category,
            destination: destination,
            timeline: timeline,
            userStory: userStory,
            boardingPass: boardingPass,
            targetDaysPerWeek: 7
        )

        // Create tasks from challenges
        let startDate = Calendar.current.startOfDay(for: Date())
        for (index, challengeData) in challengesData.enumerated() {
            let challengeDueDate = Calendar.current.date(byAdding: .day, value: index + 1, to: startDate)
            let task = DailyTask(
                goalID: goal.id.uuidString,
                title: challengeData["title"] as? String ?? "Challenge \(index + 1)",
                taskDescription: challengeData["description"] as? String ?? "",
                estimatedTime: challengeData["estimatedTime"] as? String ?? "10 min",
                order: index,
                isUnlocked: index == 0, // Only first task unlocked
                dueDate: challengeDueDate,
                goal: goal
            )
            goal.dailyTasks.append(task)
        }

        // Save goal
        Task {
            do {
                try await dataManager.saveGoal(goal)
            } catch {
                print("Failed to save first goal: \(error)")
            }
        }

        // Clean up stored data
        UserDefaults.standard.removeObject(forKey: StorageKey.firstGoalData)
    }
}
