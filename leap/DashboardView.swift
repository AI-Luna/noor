//
//  DashboardView.swift
//  leap
//
//  Main dashboard: greeting, active journeys, today's challenges
//  "Travel agency for life" - luxury magazine aesthetic
//

import SwiftUI
import SwiftData
import UIKit

enum DestinationSort: String, CaseIterable {
    case `default` = "Default"
    case leastProgress = "Least Progress"
    case mostProgress = "Most Progress"
    case mostTasksLeft = "Most Tasks Left"
    case newest = "Newest First"
    case dueDate = "Due Soonest"

    var label: String { rawValue }

    var icon: String {
        switch self {
        case .default: return "arrow.up.arrow.down"
        case .leastProgress: return "chart.bar.fill"
        case .mostProgress: return "chart.bar.xaxis"
        case .mostTasksLeft: return "list.number"
        case .newest: return "clock.fill"
        case .dueDate: return "calendar"
        }
    }
}

struct DashboardView: View {
    @Environment(DataManager.self) private var dataManager
    @Environment(PurchaseManager.self) private var purchaseManager
    @State private var goals: [Goal] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCreateGoal = false
    @State private var showPaywall = false
    @State private var showProfile = false
    @State private var showGoldenTicketSheet = false
    @State private var showDailyFlame = false
    @State private var globalStreak: Int = 0

    @State private var microhabits: [Microhabit] = []
    @State private var selectedGoal: Goal?
    @State private var scrollProxy: ScrollViewProxy?
    @State private var goalToDelete: Goal?
    @State private var showDeleteConfirmation = false
    @State private var goalToEdit: Goal?
    @State private var explanationPopup: String?
    @State private var itemToComplete: TodayItem?
    @State private var showCompleteConfirmation = false
    /// IDs of items user just confirmed complete — keeps checkmark visible before refresh and gives positive reinforcement
    @State private var confirmedCompletedIds: Set<String> = []
    /// Confetti celebration states
    @State private var showGreenConfetti = false
    @State private var showPinkConfetti = false
    /// Science of habits popup (shown when ALL habits complete for the day)
    @State private var showHabitSciencePopup = false
    @State private var habitScienceFact: HabitScienceFact?
    @State private var destinationSort: DestinationSort = .default
    private let calendar = Calendar.current

    private var guestPassCount: Int {
        // 1 guest pass per year for pro users
        let lastGiftedYear = UserDefaults.standard.integer(forKey: "lastGuestPassGiftYear")
        let currentYear = Calendar.current.component(.year, from: Date())
        return lastGiftedYear < currentYear ? 1 : 0
    }

    private var userName: String {
        UserDefaults.standard.string(forKey: "userName") ?? "Traveler"
    }

    private var canCreateNewGoal: Bool {
        purchaseManager.isPro || goals.count < 1
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.noorBackground
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
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
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                todaysGamePlanSection
                                if sortedGoals.isEmpty {
                                    emptyState
                                } else {
                                    activeJourneysSection
                                        .id("dreamsSection")
                                }
                            }
                            .padding(20)
                            .padding(.bottom, 100)
                        }
                        .onAppear { scrollProxy = proxy }
                    }
                }

                // Floating action button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            if canCreateNewGoal {
                                showCreateGoal = true
                            } else {
                                showPaywall = true
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 60, height: 60)
                                .background(
                                    LinearGradient(
                                        colors: [Color.noorAccent, Color.noorViolet],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Circle())
                                .shadow(color: Color.noorAccent.opacity(0.4), radius: 12, x: 0, y: 6)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                    }
                }
                .allowsHitTesting(!isLoading && errorMessage == nil)

                // Explanation popup overlay
                if let popup = explanationPopup {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation { explanationPopup = nil } }

                    VStack(spacing: 12) {
                        Text(explanationTitle(for: popup))
                            .font(NoorFont.title2)
                            .foregroundStyle(.white)

                        Text(explanationDescription(for: popup))
                            .font(NoorFont.body)
                            .foregroundStyle(Color.noorTextSecondary)
                            .multilineTextAlignment(.center)

                        Button {
                            withAnimation { explanationPopup = nil }
                        } label: {
                            Text("Got it")
                                .font(NoorFont.callout)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Color.noorAccent)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .padding(24)
                    .background(Color.noorDeepPurple)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 20)
                    .padding(.horizontal, 40)
                    .transition(.scale.combined(with: .opacity))
                }
                
                // Green confetti for habit completion — big, bold burst
                if showGreenConfetti {
                    ConfettiView(isActive: true, pieceCount: 160, duration: 4.0, style: .green)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
                
                // Pink confetti for journey mission completion — big, bold burst
                if showPinkConfetti {
                    ConfettiView(isActive: true, pieceCount: 160, duration: 4.0, style: .pink)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
                
                // Science of habits popup (when ALL habits complete)
                if showHabitSciencePopup, let fact = habitScienceFact {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation { showHabitSciencePopup = false } }
                    
                    VStack(spacing: 16) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.noorSuccess)
                        
                        Text("All Habits Complete!")
                            .font(NoorFont.title)
                            .foregroundStyle(.white)
                        
                        Text(fact.title)
                            .font(NoorFont.title2)
                            .foregroundStyle(Color.noorSuccess)
                            .multilineTextAlignment(.center)
                        
                        Text(fact.description)
                            .font(NoorFont.body)
                            .foregroundStyle(Color.noorTextSecondary)
                            .multilineTextAlignment(.center)
                        
                        Button {
                            withAnimation { showHabitSciencePopup = false }
                        } label: {
                            Text("Amazing!")
                                .font(NoorFont.button)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .background(Color.noorSuccess)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                    .padding(28)
                    .background(Color.noorDeepPurple)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.noorSuccess.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 24)
                    .padding(.horizontal, 32)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                // Custom top bar so "Noor" has no circle (no UIBarButtonItem)
                HStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                        Text("Noor")
                            .font(.system(size: 28, weight: .regular, design: .serif))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Button {
                        NotificationCenter.default.post(name: NSNotification.Name("switchToTab"), object: 1)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.noorOrange)
                            Text("\(globalStreak)")
                                .font(NoorFont.callout)
                                .foregroundStyle(Color.noorTextSecondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        showGoldenTicketSheet = true
                    } label: {
                        Image("GoldenTicket")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showProfile = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.noorViolet, Color.noorAccent],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 28, height: 28)
                            Text(String(userName.prefix(1)).uppercased())
                                .font(NoorFont.caption)
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .frame(height: 52)
                .padding(.horizontal, 16)
                .background(Color.noorBackground)
            }
            .sheet(isPresented: $showGoldenTicketSheet) {
                GoldenTicketSheet(
                    guestPassCount: guestPassCount,
                    onDismiss: { showGoldenTicketSheet = false },
                    onGift: {
                        showGoldenTicketSheet = false
                        let currentYear = Calendar.current.component(.year, from: Date())
                        UserDefaults.standard.set(currentYear, forKey: "lastGuestPassGiftYear")
                    }
                )
            }
            .sheet(isPresented: $showProfile) {
                NavigationStack {
                    ProfileView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showProfile = false }
                                    .foregroundStyle(Color.noorTextSecondary)
                            }
                        }
                }
                .environment(dataManager)
                .environment(purchaseManager)
            }
            .onAppear {
                DataManager.shared.initialize()
                loadGoals()
                loadGlobalStreak()
                loadMicrohabits()
                tryShowDailyFlame()
            }
            .refreshable {
                loadGoals()
                loadGlobalStreak()
                loadMicrohabits()
            }
            .fullScreenCover(isPresented: $showDailyFlame) {
                DailyFlameView(
                    streakCount: globalStreak,
                    userName: userName,
                    onDismiss: {
                        recordDailyFlameShown()
                        showDailyFlame = false
                    }
                )
            }
            .sheet(isPresented: $showCreateGoal, onDismiss: { loadGoals() }) {
                CreateGoalView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(
                    onDismiss: { showPaywall = false },
                    proGateMessage: "Unlock unlimited journeys with Pro"
                )
            }
            .navigationDestination(item: $selectedGoal) { goal in
                DailyCheckInView(goal: goal)
            }
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
            .alert("Mark as Complete?", isPresented: $showCompleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    itemToComplete = nil
                }
                Button("Yes, I did it!") {
                    if let item = itemToComplete {
                        markItemComplete(item)
                    }
                }
            } message: {
                if let item = itemToComplete {
                    Text("Did you complete \"\(item.title)\"?")
                }
            }
            .sheet(item: $goalToEdit, onDismiss: { loadGoals() }) { goal in
                EditDreamSheet(goal: goal)
                    .environment(dataManager)
            }
        }
    }

    private func deleteDream(_ goal: Goal) {
        Task { @MainActor in
            do {
                try await dataManager.deleteGoal(goal.id.uuidString)
                goalToDelete = nil
                loadGoals()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func archiveDream(_ goal: Goal) {
        Task { @MainActor in
            do {
                try await dataManager.archiveGoal(goal.id.uuidString)
                loadGoals()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func markItemComplete(_ item: TodayItem) {
        // Show filled checkmark immediately for positive reinforcement (persists; never disappears)
        confirmedCompletedIds.insert(item.id)
        itemToComplete = nil
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Show confetti based on item type + extra haptic excitement
        if item.kind == .habit {
            showGreenConfetti = true
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                showGreenConfetti = false
            }
        } else if item.kind == .mission {
            showPinkConfetti = true
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                showPinkConfetti = false
            }
        }
        
        Task { @MainActor in
            do {
                if item.kind == .habit {
                    if let habitID = UUID(uuidString: item.id) {
                        try await dataManager.addMicrohabitCompletion(habitID, date: Date())
                    }
                } else if item.kind == .mission, let goal = item.goal {
                    try await dataManager.addDailyTaskCompletion(goalID: goal.id.uuidString, taskID: item.id, date: Date())
                }
                loadGoals()
                loadMicrohabits()
                
                // Check if ALL habits for the day are now complete
                if item.kind == .habit {
                    checkAllHabitsComplete()
                }
            } catch {
                print("Failed to mark item complete: \(error)")
                confirmedCompletedIds.remove(item.id)
            }
        }
    }
    
    /// Check if all habits are complete for today and show science popup
    private func checkAllHabitsComplete() {
        guard !microhabits.isEmpty else { return }
        
        let allHabitsCompleteToday = microhabits.allSatisfy { habit in
            habit.completedDates.contains { calendar.isDateInToday($0) } || confirmedCompletedIds.contains(habit.id.uuidString)
        }
        
        if allHabitsCompleteToday {
            // Pick a random science fact and show popup
            habitScienceFact = HabitScienceFact.allFacts.randomElement()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showHabitSciencePopup = true
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: Date())
    }

    // MARK: - Today's Itinerary
    private var todaysMissions: [TodayItem] {
        var items: [TodayItem] = []
        var addedMissionIds: Set<String> = []

        // For each active journey: show current challenge and any challenge completed today (so checkmark persists)
        for goal in goals where !goal.isComplete {
            let sortedTasks = goal.dailyTasks.sorted { $0.order < $1.order }
            for task in sortedTasks {
                let completedToday = task.completedDates.contains { calendar.isDateInToday($0) }
                let isCurrent = goal.currentChallenge?.id == task.id
                if isCurrent || completedToday {
                    let id = task.id.uuidString
                    guard !addedMissionIds.contains(id) else { continue }
                    addedMissionIds.insert(id)
                    items.append(TodayItem(
                        id: id,
                        title: task.title,
                        subtitle: goal.destination.isEmpty ? goal.title : goal.destination,
                        icon: "arrow.right.circle.fill",
                        iconColor: Color.noorAccent,
                        kind: .mission,
                        isCompleted: completedToday,
                        goal: goal
                    ))
                }
            }
        }

        // Collect all microhabits
        for habit in microhabits {
            let done = habit.completedDates.contains { calendar.isDateInToday($0) }
            items.append(TodayItem(
                id: habit.id.uuidString,
                title: habit.title,
                subtitle: habit.goalID != nil
                    ? goals.first(where: { $0.id.uuidString == habit.goalID })?.destination ?? "Habit"
                    : habit.customTag ?? "Daily habit",
                icon: "leaf.fill",
                iconColor: Color.noorSuccess,
                kind: .habit,
                isCompleted: done,
                goal: nil
            ))
        }

        return items
    }

    private var todaysGamePlanSection: some View {
        let items = todaysMissions
        let completedCount = items.filter(\.isCompleted).count
        let totalCount = items.count

        return VStack(alignment: .leading, spacing: 16) {
            // Combined greeting and game plan header
            VStack(alignment: .leading, spacing: 4) {
                Text("\(greeting), \(userName)!")
                    .font(NoorFont.largeTitle)
                    .foregroundStyle(.white)
                
                Text(formattedDate)
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorTextSecondary)
            }
            
            if totalCount > 0 {
                // Game plan card
                VStack(alignment: .leading, spacing: 12) {
                    // Header row
                    HStack {
                        Text("Today's Itinerary")
                            .font(NoorFont.title2)
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        Text(completedCount == totalCount ? "Done!" : "\(completedCount)/\(totalCount)")
                            .font(NoorFont.body)
                            .foregroundStyle(completedCount == totalCount ? Color.noorSuccess : Color.noorAccent)
                    }
                    
                    // Status line
                    Text(completedCount == totalCount
                         ? "All done — you crushed it."
                         : "\(totalCount - completedCount) thing\(totalCount - completedCount == 1 ? "" : "s") left today")
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorTextSecondary)

                    // Task list
                    VStack(spacing: 0) {
                        let sorted = items.sorted { !$0.isCompleted && $1.isCompleted }
                        ForEach(Array(sorted.enumerated()), id: \.element.id) { index, item in
                            todayItemRow(item)

                            if index < sorted.count - 1 {
                                Divider()
                                    .background(Color.white.opacity(0.08))
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func todayItemRow(_ item: TodayItem) -> some View {
        let showFilled = item.isCompleted || confirmedCompletedIds.contains(item.id)
        
        return HStack(spacing: 14) {
            // Completion indicator — tappable to show confirmation; checkmark fills and stays once confirmed
            Button {
                if !showFilled {
                    itemToComplete = item
                    showCompleteConfirmation = true
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(showFilled ? Color.noorSuccess : Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 28, height: 28)

                    if showFilled {
                        Circle()
                            .fill(Color.noorSuccess)
                            .frame(width: 28, height: 28)

                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            // Title + type — tappable to navigate
            Button {
                if let goal = item.goal {
                    selectedGoal = goal
                } else if item.kind == .habit {
                    NotificationCenter.default.post(name: NSNotification.Name("switchToTab"), object: 3)
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(NoorFont.body)
                            .foregroundStyle(showFilled ? Color.noorTextSecondary.opacity(0.5) : .white)
                            .strikethrough(showFilled, color: Color.noorTextSecondary.opacity(0.4))
                            .lineLimit(1)

                        Text(item.kind == .mission ? "Challenge · \(item.subtitle)" : "Habit · \(item.subtitle)")
                            .font(NoorFont.caption)
                            .foregroundStyle(item.kind == .mission ? Color.noorAccent.opacity(0.7) : Color.noorSuccess.opacity(0.7))
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.noorTextSecondary.opacity(0.3))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }


    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 56))
                .foregroundStyle(Color.noorRoseGold.opacity(0.7))

            VStack(spacing: 8) {
                Text("Book your first journey")
                    .font(NoorFont.title)
                    .foregroundStyle(.white)

                Text("Your journey to the woman who lives that life starts with one small step.")
                    .font(NoorFont.body)
                    .foregroundStyle(Color.noorTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showCreateGoal = true
            } label: {
                Text("Book Your First Journey")
                    .font(NoorFont.button)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.noorAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(24)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    // Goals sorted based on selected filter — only active (non-completed) journeys
    // Completed journeys live on the Progress tab under "Completed Journeys"
    private var sortedGoals: [Goal] {
        goals.filter { !$0.isComplete }.sorted { a, b in
            switch destinationSort {
            case .default:
                return a.progress < b.progress
            case .leastProgress:
                return a.progress < b.progress
            case .mostProgress:
                return a.progress > b.progress
            case .mostTasksLeft:
                let aLeft = a.dailyTasks.filter { !$0.isCompleted }.count
                let bLeft = b.dailyTasks.filter { !$0.isCompleted }.count
                return aLeft > bLeft
            case .newest:
                return (a.dailyTasks.first?.createdAt ?? .distantPast) > (b.dailyTasks.first?.createdAt ?? .distantPast)
            case .dueDate:
                let aDate = a.dailyTasks.compactMap(\.dueDate).min() ?? .distantFuture
                let bDate = b.dailyTasks.compactMap(\.dueDate).min() ?? .distantFuture
                return aDate < bDate
            }
        }
    }

    // MARK: - Active Journeys
    private var activeJourneysSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Current Journeys")
                    .font(NoorFont.title)
                    .foregroundStyle(.white)

                Spacer()

                Menu {
                    ForEach(DestinationSort.allCases, id: \.self) { sort in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                destinationSort = sort
                            }
                        } label: {
                            Label(sort.label, systemImage: sort.icon)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(destinationSort == .default ? Color.noorTextSecondary : Color.noorAccent)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
            }

            ForEach(sortedGoals, id: \.id) { goal in
                SwipeActionCard(
                    onEdit: { goalToEdit = goal },
                    onDelete: {
                        goalToDelete = goal
                        showDeleteConfirmation = true
                    },
                    onArchive: goal.isComplete ? {
                        archiveDream(goal)
                    } : nil
                ) {
                    NavigationLink(destination: DailyCheckInView(goal: goal)) {
                        JourneyCard(goal: goal)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Data Loading
    private func loadGoals() {
        Task { @MainActor in
            // Only show loading spinner on first load, not on refreshes
            let isFirstLoad = goals.isEmpty && errorMessage == nil
            if isFirstLoad { isLoading = true }
            errorMessage = nil
            defer { if isFirstLoad { isLoading = false } }
            do {
                goals = try await dataManager.fetchAllGoals()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadGlobalStreak() {
        globalStreak = UserDefaults.standard.integer(forKey: StorageKey.streakCount)
    }

    private func loadMicrohabits() {
        Task { @MainActor in
            do {
                microhabits = try await dataManager.fetchMicrohabits()
            } catch {
                microhabits = []
            }
        }
    }

    /// Update streak based on consecutive daily app opens and show popup if first open today
    private func tryShowDailyFlame() {
        let today = calendar.startOfDay(for: Date())
        let lastOpenDate = UserDefaults.standard.object(forKey: StorageKey.lastAppOpenDate) as? Date
        let lastShownDate = UserDefaults.standard.object(forKey: StorageKey.lastDailyFlameDate) as? Date
        
        // Check if this is the first open today
        let isFirstOpenToday = lastOpenDate == nil || !calendar.isDate(lastOpenDate!, inSameDayAs: today)
        
        if isFirstOpenToday {
            // Update streak based on consecutive days
            if let lastOpen = lastOpenDate {
                let lastDay = calendar.startOfDay(for: lastOpen)
                let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
                
                if calendar.isDate(lastDay, inSameDayAs: yesterday) {
                    // Consecutive day - increment streak
                    globalStreak += 1
                } else if lastDay < yesterday {
                    // Skipped a day - reset streak to 1
                    globalStreak = 1
                }
                // If somehow lastDay == today (shouldn't happen), streak stays same
            } else {
                // First time ever opening - start streak at 1
                globalStreak = 1
            }
            
            // Save updated streak and app open date
            UserDefaults.standard.set(globalStreak, forKey: StorageKey.streakCount)
            UserDefaults.standard.set(today, forKey: StorageKey.lastAppOpenDate)
        }
        
        // Show popup if not already shown today
        let shouldShowPopup = lastShownDate == nil || !calendar.isDate(lastShownDate!, inSameDayAs: today)
        if shouldShowPopup && globalStreak > 0 {
            showDailyFlame = true
        }
    }

    private func recordDailyFlameShown() {
        UserDefaults.standard.set(Date(), forKey: StorageKey.lastDailyFlameDate)
    }

    // MARK: - Explanation Popups
    private func explanationTitle(for label: String) -> String {
        switch label {
        case "Streak": return "Day Streak"
        case "Journey": return "Journeys"
        case "Habit": return "Habits"
        default: return label
        }
    }

    private func explanationDescription(for label: String) -> String {
        switch label {
        case "Streak":
            return "Your streak counts the days in a row you've opened Noor and taken action. It's a simple reminder: showing up matters. Even small steps keep momentum alive."
        case "Journey":
            return "A journey is a destination you're working toward—a bigger goal broken into daily challenges. Think of it as booking a flight to your future self. Each journey has 7 steps designed to move you closer to that version of you."
        case "Habit":
            return "Habits are the small, repeatable actions you commit to daily. They're not tied to a specific journey—they support who you're becoming across every area of your life. Consistency here builds lasting change."
        default:
            return ""
        }
    }
}


// MARK: - Today Item Model
private struct TodayItem {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let kind: Kind
    let isCompleted: Bool
    let goal: Goal?

    enum Kind { case mission, habit }
}

// MARK: - Journey Card (Boarding Pass Style)
struct JourneyCard: View {
    let goal: Goal

    private var progress: Double {
        guard !goal.dailyTasks.isEmpty else { return 0 }
        let completed = goal.dailyTasks.filter { $0.isCompleted }.count
        return Double(completed) / Double(goal.dailyTasks.count) * 100
    }

    private var completedCount: Int {
        goal.dailyTasks.filter { $0.isCompleted }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Image(systemName: "airplane")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(white: 0.3))
                Text("BOARDING PASS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.3))
                    .tracking(1.5)
                Spacer()
                (Text("Steps ")
                    .foregroundStyle(Color(white: 0.5))
                 + Text("\(completedCount) of \(goal.dailyTasks.count)")
                    .foregroundStyle(goal.isComplete ? Color.noorSuccess : Color.noorAccent)
                    .fontWeight(.semibold))
                    .font(.system(size: 10, design: .monospaced))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(white: 0.92))

            // Body
            VStack(alignment: .leading, spacing: 10) {
                // FROM and TO on same line
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FROM")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.black)
                        Text(goal.departure.isEmpty ? "Current You" : goal.departure)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("TO")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.black)
                        Text(goal.destination.isEmpty ? goal.title : goal.destination)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                    }
                }

                // Flight path
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(white: 0.65))
                        .frame(width: 5, height: 5)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color(white: 0.8))
                                .frame(height: 1)

                            Rectangle()
                                .fill(Color.noorAccent)
                                .frame(width: geo.size.width * progress / 100, height: 2)

                            Image(systemName: "airplane")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.noorAccent)
                                .offset(x: max(0, geo.size.width * progress / 100 - 5))
                        }
                    }
                    .frame(height: 10)

                    Circle()
                        .fill(progress >= 100 ? Color.noorSuccess : Color.noorAccent.opacity(0.4))
                        .frame(width: 5, height: 5)
                }

                // ETA
                if !goal.timeline.isEmpty {
                    Text("ETA: \(goal.timeline)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(white: 0.45))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Swipe Action Card
struct SwipeActionCard<Content: View>: View {
    let onEdit: () -> Void
    let onDelete: () -> Void
    var onArchive: (() -> Void)? = nil
    var editIcon: String = "pencil"
    var editLabel: String = "Edit"
    var editColor: Color = Color.noorViolet
    @ViewBuilder let content: Content

    @State private var offset: CGFloat = 0
    @State private var showingAction: SwipeDirection = .none

    private enum SwipeDirection { case none, left, right }
    private let singleActionWidth: CGFloat = 80

    private var trailingWidth: CGFloat {
        onArchive != nil ? singleActionWidth * 2 + 4 : singleActionWidth
    }

    var body: some View {
        content
            .offset(x: offset)
            .background(alignment: .leading) {
                // Edit — revealed behind left edge when swiping right
                if offset > 0 {
                    Button {
                        withAnimation(.spring(response: 0.3)) { offset = 0; showingAction = .none }
                        onEdit()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: editIcon)
                                .font(.system(size: 20))
                            Text(editLabel)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .frame(width: singleActionWidth)
                        .frame(maxHeight: .infinity)
                        .background(editColor)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .background(alignment: .trailing) {
                // Trailing actions — revealed when swiping left
                if offset < 0 {
                    HStack(spacing: 4) {
                        if let onArchive {
                            Button {
                                withAnimation(.spring(response: 0.3)) { offset = 0; showingAction = .none }
                                onArchive()
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "archivebox")
                                        .font(.system(size: 20))
                                    Text("Archive")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundStyle(.white)
                                .frame(width: singleActionWidth)
                                .frame(maxHeight: .infinity)
                                .background(Color.noorAmber)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            withAnimation(.spring(response: 0.3)) { offset = 0; showingAction = .none }
                            onDelete()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "trash")
                                    .font(.system(size: 20))
                                Text("Delete")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(.white)
                            .frame(width: singleActionWidth)
                            .frame(maxHeight: .infinity)
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .highPriorityGesture(
                DragGesture(minimumDistance: 15)
                    .onChanged { value in
                        let h = abs(value.translation.width)
                        let v = abs(value.translation.height)
                        guard h > v else { return }
                        let translation = value.translation.width
                        if showingAction == .none {
                            offset = translation * 0.6
                        } else if showingAction == .right {
                            offset = singleActionWidth + translation * 0.6
                        } else {
                            offset = -trailingWidth + translation * 0.6
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.3)) {
                            if value.translation.width > 60 {
                                offset = singleActionWidth
                                showingAction = .right
                            } else if value.translation.width < -60 {
                                offset = -trailingWidth
                                showingAction = .left
                            } else {
                                offset = 0
                                showingAction = .none
                            }
                        }
                    }
            )
            .clipped()
    }
}

// MARK: - Edit Final Destination Sheet
private struct EditDreamSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataManager.self) private var dataManager

    let goal: Goal
    @State private var destination: String = ""
    @State private var timeline: String = ""
    @State private var userStory: String = ""
    @State private var selectedCategory: GoalCategory?
    @State private var isSaving = false

    private var canSave: Bool {
        !destination.trimmingCharacters(in: .whitespaces).isEmpty
            && selectedCategory != nil
            && !isSaving
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Category (dropdown)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Category")
                            .font(NoorFont.title2)
                            .foregroundStyle(.white)

                        Text("Select the category for your destination")
                            .font(NoorFont.caption)
                            .foregroundStyle(Color.noorTextSecondary)

                        Picker("Category", selection: $selectedCategory) {
                            Text("Select category").tag(nil as GoalCategory?)
                            ForEach(GoalCategory.allCases) { cat in
                                Label(cat.displayName, systemImage: cat.icon)
                                    .tag(cat as GoalCategory?)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // Destination
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Destination")
                            .font(NoorFont.title2)
                            .foregroundStyle(.white)

                        TextField("Your goal", text: $destination)
                            .font(NoorFont.body)
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // Timeline
                    VStack(alignment: .leading, spacing: 10) {
                        Text("When are you arriving?")
                            .font(NoorFont.title2)
                            .foregroundStyle(.white)

                        TextField("June 2026", text: $timeline)
                            .font(NoorFont.body)
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // User story
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Why does this matter to you?")
                            .font(NoorFont.title2)
                            .foregroundStyle(.white)

                        TextEditor(text: $userStory)
                            .font(NoorFont.body)
                            .foregroundStyle(.white)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 100)
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // Save button (enabled only when required fields are filled)
                    Button {
                        save()
                    } label: {
                        Text(isSaving ? "Saving..." : "Save Changes")
                            .font(NoorFont.button)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(canSave ? Color.noorAccent : Color.noorAccent.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .background(Color.noorBackground)
            .navigationTitle("Edit Final Destination")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.noorTextSecondary)
                }
            }
        }
        .onAppear {
            destination = goal.destination
            timeline = goal.timeline
            userStory = goal.userStory
            selectedCategory = GoalCategory(rawValue: goal.category)
        }
    }

    private func save() {
        guard canSave else { return }
        isSaving = true
        let trimmedDestination = destination.trimmingCharacters(in: .whitespaces)
        goal.destination = trimmedDestination
        goal.timeline = timeline
        goal.userStory = userStory
        if let cat = selectedCategory {
            goal.category = cat.rawValue
        }
        Task { @MainActor in
            do {
                try await dataManager.saveContext()
                dismiss()
            } catch {
                print("Failed to save dream edits: \(error)")
            }
            isSaving = false
        }
    }
}

// MARK: - Habit Science Facts (25 variations for popup)
struct HabitScienceFact: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    
    static let allFacts: [HabitScienceFact] = [
        HabitScienceFact(
            title: "The 21-Day Myth",
            description: "Research shows habits take 66 days on average to form, not 21. But consistency matters more than perfection—missing one day doesn't reset your progress."
        ),
        HabitScienceFact(
            title: "Habit Stacking",
            description: "Link new habits to existing ones. 'After I [current habit], I will [new habit].' This uses your brain's existing neural pathways to build new behaviors."
        ),
        HabitScienceFact(
            title: "The 2-Minute Rule",
            description: "Make habits so small they take less than 2 minutes. Reading one page beats not reading. The goal is to become the person who shows up."
        ),
        HabitScienceFact(
            title: "Environment Design",
            description: "Your environment shapes your behavior more than willpower. Make good habits obvious and easy; make bad habits invisible and hard."
        ),
        HabitScienceFact(
            title: "Identity-Based Habits",
            description: "Focus on who you want to become, not what you want to achieve. Each small action is a vote for your new identity."
        ),
        HabitScienceFact(
            title: "The Habit Loop",
            description: "Every habit follows: Cue → Craving → Response → Reward. Understanding this loop helps you redesign your behaviors intentionally."
        ),
        HabitScienceFact(
            title: "Dopamine & Anticipation",
            description: "Dopamine rises in anticipation of a reward, not just during it. This is why making habits attractive and exciting helps them stick."
        ),
        HabitScienceFact(
            title: "Implementation Intentions",
            description: "'I will [behavior] at [time] in [location]' makes you 2-3x more likely to follow through. Specificity removes decision fatigue."
        ),
        HabitScienceFact(
            title: "The Plateau of Latent Potential",
            description: "Results often lag behind effort. Like ice melting at 32°F, your work compounds beneath the surface before visible breakthroughs appear."
        ),
        HabitScienceFact(
            title: "Temptation Bundling",
            description: "Pair habits you need to do with things you want to do. Listen to your favorite podcast only while exercising—anticipation drives action."
        ),
        HabitScienceFact(
            title: "The Goldilocks Rule",
            description: "Humans stay motivated when working on tasks of 'just manageable difficulty'—not too easy, not too hard. Adjust challenge levels to stay engaged."
        ),
        HabitScienceFact(
            title: "Never Miss Twice",
            description: "Missing once is an accident. Missing twice starts a new habit. Get back on track immediately—the compound effect of consistency is powerful."
        ),
        HabitScienceFact(
            title: "Reward Timing",
            description: "Immediate rewards beat delayed ones. Celebrate small wins right after completing habits to reinforce the behavior in your brain."
        ),
        HabitScienceFact(
            title: "Social Proof",
            description: "We adopt habits of those around us. Surround yourself with people who have the habits you want—you become the average of your environment."
        ),
        HabitScienceFact(
            title: "Variable Rewards",
            description: "Unpredictable rewards create stronger habits than consistent ones. This is why habits with surprise elements are more engaging."
        ),
        HabitScienceFact(
            title: "Habit Tracking",
            description: "Tracking creates awareness. Seeing your streak builds momentum and makes the cost of breaking it emotionally real."
        ),
        HabitScienceFact(
            title: "The Fresh Start Effect",
            description: "New beginnings (Mondays, new months, birthdays) increase motivation. Use these moments to launch new habits."
        ),
        HabitScienceFact(
            title: "Friction Reduction",
            description: "Every step between you and a habit is friction. Reduce steps for good habits; add steps for bad ones. Convenience wins."
        ),
        HabitScienceFact(
            title: "Keystone Habits",
            description: "Some habits trigger cascade effects. Exercise often leads to better eating, better sleep, and more energy. Find your keystone."
        ),
        HabitScienceFact(
            title: "The Power of Ritual",
            description: "Pre-habit rituals signal your brain it's time to perform. Athletes use this—a specific warmup routine puts them in the zone."
        ),
        HabitScienceFact(
            title: "Neuroplasticity",
            description: "Your brain physically changes with repetition. Neural pathways strengthen each time you practice, making habits literally easier over time."
        ),
        HabitScienceFact(
            title: "Decision Fatigue",
            description: "Willpower depletes throughout the day. Schedule important habits for when your self-control is highest—usually mornings."
        ),
        HabitScienceFact(
            title: "The Seinfeld Strategy",
            description: "Jerry Seinfeld wrote jokes daily and marked X's on a calendar. His only goal: 'Don't break the chain.' Visual streaks motivate."
        ),
        HabitScienceFact(
            title: "Cue Specificity",
            description: "Vague cues fail. 'Exercise more' loses to 'Put on running shoes at 7am.' The more specific the trigger, the more reliable the habit."
        ),
        HabitScienceFact(
            title: "Habit Graduation",
            description: "Once a habit is automatic, increase the challenge slightly. This prevents boredom and continues growth. Small upgrades, big results."
        ),
    ]
}

#Preview {
    DashboardView()
        .environment(DataManager.shared)
        .environment(PurchaseManager.shared)
}
