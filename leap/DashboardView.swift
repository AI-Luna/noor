//
//  DashboardView.swift
//  leap
//
//  Main dashboard: greeting, active journeys, today's challenges
//  "Travel agency for life" - luxury magazine aesthetic
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
    @State private var showProfile = false
    @State private var showStreakSheet = false
    @State private var showGoldenTicketSheet = false
    @State private var showDailyFlame = false
    @State private var globalStreak: Int = 0
    @State private var visionItems: [VisionItem] = []
    @State private var selectedGoal: Goal?
    @State private var scrollProxy: ScrollViewProxy?
    @State private var goalToDelete: Goal?
    @State private var showDeleteConfirmation = false
    @State private var goalToEdit: Goal?
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
                                greetingSection
                                streakSection
                                fromYourVisionSection
                                if goals.isEmpty {
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
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkle")
                            .foregroundStyle(.white)
                        Text("Noor")
                            .font(.system(size: 24, weight: .regular, design: .serif))
                            .foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showStreakSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.noorOrange)
                                Text("\(globalStreak)")
                                    .font(NoorFont.callout)
                                    .foregroundStyle(Color.noorTextSecondary)
                            }
                            .padding(.horizontal, 10)
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
                                    .font(.system(size: 12, weight: .bold, design: .serif))
                                    .foregroundStyle(.white)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .sheet(isPresented: $showStreakSheet) {
                StreakCalendarSheet(streakCount: globalStreak, goals: goals, onDismiss: { showStreakSheet = false })
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
                loadVisionItems()
                tryShowDailyFlame()
            }
            .refreshable {
                loadGoals()
                loadGlobalStreak()
                loadVisionItems()
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
                    proGateMessage: "Unlock unlimited flights with Pro"
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

    // MARK: - Greeting Section
    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(greeting), \(userName)!")
                .font(NoorFont.largeTitle)
                .foregroundStyle(.white)

            Text(formattedDate)
                .font(NoorFont.caption)
                .foregroundStyle(Color.noorTextSecondary)
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: Date())
    }

    // MARK: - Streak & Flights Section
    private var streakSection: some View {
        HStack(spacing: 12) {
            // Streak cell — taps into streak breakdown
            Button {
                showStreakSheet = true
            } label: {
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.noorOrange, Color.noorAccent],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        Text("\(globalStreak)")
                            .font(NoorFont.largeTitle)
                            .foregroundStyle(.white)
                    }

                    Text("Day Streak")
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)

            // Active flights cell — taps into goal / dreams
            Button {
                if goals.count == 1, let goal = goals.first {
                    selectedGoal = goal
                } else if !goals.isEmpty {
                    withAnimation {
                        scrollProxy?.scrollTo("dreamsSection", anchor: .top)
                    }
                }
            } label: {
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.noorRoseGold)

                        Text("\(goals.count)")
                            .font(NoorFont.largeTitle)
                            .foregroundStyle(.white)
                    }

                    Text("Active \(goals.count == 1 ? "Flight" : "Flights")")
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - From your vision (today's one thing to act on)
    private var fromYourVisionSection: some View {
        FromYourVisionBlock(items: visionItems, onOpen: openVisionItem)
    }

    private func loadVisionItems() {
        guard let data = UserDefaults.standard.data(forKey: StorageKey.visionItems),
              let decoded = try? JSONDecoder().decode([VisionItem].self, from: data) else {
            visionItems = []
            return
        }
        visionItems = decoded
    }

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

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 56))
                .foregroundStyle(Color.noorRoseGold.opacity(0.7))

            VStack(spacing: 8) {
                Text("Book your first flight")
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
                Text("Book Your First Flight")
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

    // Goals sorted: incomplete (least progress first), then completed at bottom
    private var sortedGoals: [Goal] {
        goals.sorted { a, b in
            let aComplete = a.isComplete
            let bComplete = b.isComplete
            if aComplete != bComplete { return !aComplete }
            return a.progress < b.progress
        }
    }

    // MARK: - Active Journeys
    private var activeJourneysSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Dreams")
                .font(NoorFont.largeTitle)
                .foregroundStyle(.white)

            ForEach(sortedGoals, id: \.id) { goal in
                SwipeActionCard(
                    onEdit: { goalToEdit = goal },
                    onDelete: {
                        goalToDelete = goal
                        showDeleteConfirmation = true
                    }
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

    private func loadGlobalStreak() {
        globalStreak = UserDefaults.standard.integer(forKey: StorageKey.streakCount)
    }

    private func tryShowDailyFlame() {
        guard globalStreak > 0 else { return }
        let today = calendar.startOfDay(for: Date())
        let lastShown = UserDefaults.standard.object(forKey: StorageKey.lastDailyFlameDate) as? Date
        if lastShown == nil || !calendar.isDate(lastShown!, inSameDayAs: today) {
            showDailyFlame = true
        }
    }

    private func recordDailyFlameShown() {
        UserDefaults.standard.set(Date(), forKey: StorageKey.lastDailyFlameDate)
    }
}

// MARK: - From your vision (one card for Home)
private struct FromYourVisionBlock: View {
    let items: [VisionItem]
    let onOpen: (VisionItem) -> Void

    private var firstUncompleted: VisionItem? {
        items.first { !$0.isCompleted }
    }

    var body: some View {
        if let item = firstUncompleted {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.noorRoseGold)
                    Text("From your vision")
                        .font(NoorFont.title)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 4)

                Button {
                    onOpen(item)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: item.kind.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(Color.noorRoseGold)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Act on it")
                                .font(NoorFont.caption)
                                .foregroundStyle(Color.noorTextSecondary)
                            Text(item.title)
                                .font(NoorFont.body)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.noorRoseGold)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Journey Card
struct JourneyCard: View {
    let goal: Goal

    private var progress: Double {
        guard !goal.dailyTasks.isEmpty else { return 0 }
        let completed = goal.dailyTasks.filter { $0.isCompleted }.count
        return Double(completed) / Double(goal.dailyTasks.count) * 100
    }

    private var currentChallenge: DailyTask? {
        goal.dailyTasks
            .sorted { $0.order < $1.order }
            .first { $0.isUnlocked && !$0.isCompleted }
    }

    private var remainingChallenges: Int {
        goal.dailyTasks.filter { !$0.isCompleted }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: iconForCategory(goal.category))
                    .font(.system(size: 24))
                    .foregroundStyle(Color.noorRoseGold)

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

                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Color.noorViolet.opacity(0.3), lineWidth: 4)
                        .frame(width: 44, height: 44)

                    Circle()
                        .trim(from: 0, to: progress / 100)
                        .stroke(
                            progress >= 100 ? Color.noorSuccess : Color.noorRoseGold,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))

                    if progress >= 100 {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.noorSuccess)
                    } else {
                        Text("\(Int(progress))%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }

            // Current challenge preview
            if let challenge = currentChallenge {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(Color.noorAccent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today's Mission")
                            .font(NoorFont.caption)
                            .foregroundStyle(Color.noorTextSecondary)

                        Text(challenge.title)
                            .font(NoorFont.body)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.noorTextSecondary.opacity(0.5))
                }
                .padding(12)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if progress >= 100 {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.noorSuccess)

                    Text("Journey Complete!")
                        .font(NoorFont.body)
                        .foregroundStyle(Color.noorSuccess)
                }
                .padding(12)
                .background(Color.noorSuccess.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Remaining challenges
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.noorAccent)

                Text("\(remainingChallenges) of \(goal.dailyTasks.count) challenges left")
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorTextSecondary)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.noorDeepPurple, Color.noorViolet.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(progress >= 100 ? Color.noorSuccess.opacity(0.4) : Color.noorViolet.opacity(0.3), lineWidth: 1)
        )
        .opacity(progress >= 100 ? 0.65 : 1.0)
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

// MARK: - Swipe Action Card
private struct SwipeActionCard<Content: View>: View {
    let onEdit: () -> Void
    let onDelete: () -> Void
    @ViewBuilder let content: Content

    @State private var offset: CGFloat = 0
    @State private var showingAction: SwipeDirection = .none

    private enum SwipeDirection { case none, left, right }
    private let actionWidth: CGFloat = 80

    var body: some View {
        ZStack {
            // Background actions
            HStack(spacing: 0) {
                // Edit (revealed on swipe right)
                Button {
                    withAnimation(.spring(response: 0.3)) { offset = 0; showingAction = .none }
                    onEdit()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 20))
                        Text("Edit")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.noorViolet)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(.plain)

                Spacer()

                // Delete (revealed on swipe left)
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
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(.plain)
            }

            // Main content
            content
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            let translation = value.translation.width
                            if showingAction == .none {
                                offset = translation * 0.6
                            } else if showingAction == .right {
                                offset = actionWidth + translation * 0.6
                            } else {
                                offset = -actionWidth + translation * 0.6
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.3)) {
                                if value.translation.width > 60 {
                                    offset = actionWidth
                                    showingAction = .right
                                } else if value.translation.width < -60 {
                                    offset = -actionWidth
                                    showingAction = .left
                                } else {
                                    offset = 0
                                    showingAction = .none
                                }
                            }
                        }
                )
        }
        .clipped()
    }
}

// MARK: - Edit Dream Sheet
private struct EditDreamSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataManager.self) private var dataManager

    let goal: Goal
    @State private var destination: String = ""
    @State private var timeline: String = ""
    @State private var userStory: String = ""
    @State private var selectedCategory: GoalCategory?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Category
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(NoorFont.caption)
                            .foregroundStyle(Color.noorTextSecondary)

                        HStack(spacing: 10) {
                            ForEach(GoalCategory.allCases) { cat in
                                Button {
                                    selectedCategory = cat
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: cat.icon)
                                            .font(.system(size: 20))
                                        Text(cat.displayName)
                                            .font(.system(size: 10))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(selectedCategory == cat ? Color.noorAccent.opacity(0.3) : Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedCategory == cat ? Color.noorAccent : Color.clear, lineWidth: 1.5)
                                    )
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(selectedCategory == cat ? Color.noorAccent : Color.noorTextSecondary)
                            }
                        }
                    }

                    // Destination
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Destination")
                            .font(NoorFont.caption)
                            .foregroundStyle(Color.noorTextSecondary)

                        TextField("Your goal", text: $destination)
                            .font(NoorFont.body)
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // Timeline
                    VStack(alignment: .leading, spacing: 8) {
                        Text("When are you arriving?")
                            .font(NoorFont.caption)
                            .foregroundStyle(Color.noorTextSecondary)

                        TextField("June 2026", text: $timeline)
                            .font(NoorFont.body)
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // User story
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Why does this matter to you?")
                            .font(NoorFont.caption)
                            .foregroundStyle(Color.noorTextSecondary)

                        TextEditor(text: $userStory)
                            .font(NoorFont.body)
                            .foregroundStyle(.white)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 100)
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // Save button
                    Button {
                        save()
                    } label: {
                        Text(isSaving ? "Saving..." : "Save Changes")
                            .font(NoorFont.button)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.noorAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .background(Color.noorBackground)
            .navigationTitle("Edit Dream")
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
        isSaving = true
        goal.destination = destination
        goal.timeline = timeline
        goal.userStory = userStory
        if let cat = selectedCategory {
            goal.category = cat.rawValue
        }
        Task { @MainActor in
            do {
                try await dataManager.saveContext()
            } catch {
                print("Failed to save dream edits: \(error)")
            }
            isSaving = false
            dismiss()
        }
    }
}

#Preview {
    DashboardView()
        .environment(DataManager.shared)
        .environment(PurchaseManager.shared)
}
