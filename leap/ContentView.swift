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

    // Splash animation states
    @State private var showSplash = true
    @State private var splashStarOffset: CGSize = CGSize(width: -200, height: -300)
    @State private var splashStarScale: CGFloat = 0.3
    @State private var splashStarRotation: Double = -45
    @State private var splashBgDark: Bool = false
    @State private var splashStarWhite: Bool = false
    @State private var splashShowNoor: Bool = false

    var body: some View {
        ZStack {
            if !hasCompletedOnboarding {
                OnboardingView(onComplete: {
                    hasCompletedOnboarding = true
                    showSplash = false // Skip splash since onboarding just ended
                    createFirstGoalFromOnboarding()
                })
            } else if showSplash {
                // Returning user splash — same star animation as onboarding
                ZStack {
                    (splashBgDark ? Color.noorBackground : Color.white)
                        .ignoresSafeArea()
                        .animation(.easeInOut(duration: 0.4), value: splashBgDark)

                    HStack(spacing: 8) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 22))
                            .foregroundStyle(splashStarWhite ? Color.white : Color.noorBackground)
                            .scaleEffect(splashStarScale)
                            .rotationEffect(.degrees(splashStarRotation))
                            .offset(splashStarOffset)
                            .animation(.easeInOut(duration: 0.4), value: splashStarWhite)

                        if splashShowNoor {
                            Text("Noor")
                                .font(.system(size: 28, weight: .regular, design: .serif))
                                .foregroundStyle(.white)
                                .transition(.opacity)
                        }
                    }
                }
                .onAppear {
                    startReturningSplash()
                }
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
                    PassportView()
                        .tabItem {
                            Label("Passport", systemImage: "globe.americas.fill")
                        }
                        .tag(2)
                    MicrohabitsView()
                        .tabItem {
                            Label("Habits", systemImage: "leaf.fill")
                        }
                        .tag(3)
                }
                .tint(.white)
                .onAppear {
                    let appearance = UITabBarAppearance()
                    appearance.configureWithOpaqueBackground()
                    appearance.backgroundColor = UIColor(white: 0.06, alpha: 1)
                    appearance.shadowColor = .black

                    // Unselected: dim gray
                    let itemAppearance = UITabBarItemAppearance()
                    itemAppearance.normal.iconColor = UIColor(white: 1, alpha: 0.3)
                    itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(white: 1, alpha: 0.3)]

                    // Selected: bright white
                    itemAppearance.selected.iconColor = .white
                    itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]

                    appearance.stackedLayoutAppearance = itemAppearance
                    appearance.inlineLayoutAppearance = itemAppearance
                    appearance.compactInlineLayoutAppearance = itemAppearance

                    UITabBar.appearance().standardAppearance = appearance
                    UITabBar.appearance().scrollEdgeAppearance = appearance
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("switchToTab"))) { notification in
                    if let tab = notification.object as? Int {
                        selectedTab = tab
                    }
                }
                .onChange(of: selectedTab) { _, _ in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
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

    private func startReturningSplash() {
        splashStarOffset = CGSize(width: -200, height: -300)
        splashStarScale = 0.3
        splashStarRotation = -45
        splashBgDark = false
        splashStarWhite = false
        splashShowNoor = false

        // Star flies in
        withAnimation(.easeOut(duration: 0.8)) {
            splashStarOffset = .zero
            splashStarScale = 1.0
            splashStarRotation = 0
        }

        // Background goes dark, star turns white
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.4)) {
                splashBgDark = true
                splashStarWhite = true
            }
        }

        // "Noor" text fades in
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeIn(duration: 0.5)) {
                splashShowNoor = true
            }
        }

        // Transition to main app
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.4)) {
                showSplash = false
            }
        }
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
        let departure = goalData["departure"] as? String ?? ""
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
            departure: departure,
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
