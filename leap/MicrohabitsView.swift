//
//  MicrohabitsView.swift
//  leap
//
//  Microhabits section: list with focus timer, add-habit modal (Create / Replace)
//  Habits link to grander vision (goals).
//

import SwiftUI
import SwiftData
import UIKit
import UserNotifications

enum HabitFilter: String, CaseIterable {
    case all = "All Habits"
    case journey = "Journey Habits"
    case completed = "Completed"
    case archived = "Archived"
    case recent = "Recent"
    
    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .journey: return "airplane"
        case .completed: return "checkmark.circle.fill"
        case .archived: return "archivebox.fill"
        case .recent: return "clock.fill"
        }
    }
}

struct MicrohabitsView: View {
    @Environment(DataManager.self) private var dataManager
    @State private var microhabits: [Microhabit] = []
    @State private var goals: [Goal] = []
    @State private var isLoading = true
    @State private var showAddHabitModal = false
    @State private var habitToEdit: Microhabit?
    @State private var showEditSheet = false
    @State private var habitForTimer: Microhabit?
    @State private var habitForActions: Microhabit?  // tap card → show Edit/Delete
    @State private var errorMessage: String?
    @State private var selectedScienceLesson: HabitScienceLesson?
    @AppStorage("hasSeenHabitsIntro") private var hasSeenHabitsIntro: Bool = false
    @State private var selectedFilter: HabitFilter = .all
    @State private var showFilterMenu = false
    @State private var habitToDelete: Microhabit?
    @State private var showDeleteConfirmation = false

    private static let recentDays: Int = 7
    
    /// Filtered habits based on selected filter
    private var filteredHabits: [Microhabit] {
        switch selectedFilter {
        case .all:
            return microhabits.filter { !$0.isArchived }
        case .journey:
            return microhabits.filter { $0.goalID != nil && !$0.isArchived }
        case .completed:
            return microhabits.filter { !$0.completedDates.isEmpty && !$0.isArchived }
        case .archived:
            return microhabits.filter { $0.isArchived }
        case .recent:
            let cutoff = Calendar.current.date(byAdding: .day, value: -Self.recentDays, to: Date()) ?? Date()
            return microhabits.filter { $0.createdAt >= cutoff && !$0.isArchived }
        }
    }
    
    /// Journeys that have at least one linked habit (for showing journey names)
    private var journeysWithHabits: [Goal] {
        let linkedIDs = Set(microhabits.compactMap(\.goalID))
        return goals.filter { linkedIDs.contains($0.id.uuidString) }
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
                } else if let msg = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title)
                            .foregroundStyle(Color.noorSuccess)
                        Text(msg)
                            .font(NoorFont.body)
                            .foregroundStyle(Color.noorTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            if filteredHabits.isEmpty {
                                emptyStateHabits
                            } else {
                                allHabitsList
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Habits")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedScienceLesson = HabitScienceLesson.dailyLesson
                    } label: {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.noorSuccess)
                    }
                    .buttonStyle(.plain)
                    .allowsHitTesting(!isLoading && errorMessage == nil)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        // Filter menu
                        Menu {
                            ForEach(HabitFilter.allCases, id: \.self) { filter in
                                Button {
                                    selectedFilter = filter
                                } label: {
                                    Label(filter.rawValue, systemImage: filter.icon)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: selectedFilter.icon)
                                    .font(.system(size: 16))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                        }
                        .allowsHitTesting(!isLoading && errorMessage == nil)
                        
                        // Add button
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showAddHabitModal = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .allowsHitTesting(!isLoading && errorMessage == nil)
                    }
                }
            }
            .onAppear {
                loadData()
                if !hasSeenHabitsIntro {
                    hasSeenHabitsIntro = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        selectedScienceLesson = HabitScienceLesson.dailyLesson
                    }
                }
            }
            .refreshable {
                loadData()
            }
            .confirmationDialog("Habit", isPresented: Binding(
                get: { habitForActions != nil },
                set: { if !$0 { habitForActions = nil } }
            )) {
                if let h = habitForActions {
                    Button("Edit") {
                        habitToEdit = h
                        showEditSheet = true
                        habitForActions = nil
                    }
                    Button(h.isArchived ? "Unarchive" : "Archive") {
                        archiveHabit(h, archive: !h.isArchived)
                        habitForActions = nil
                    }
                    Button("Delete", role: .destructive) {
                        deleteHabit(h)
                        habitForActions = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    habitForActions = nil
                }
            } message: {
                Text("Edit, archive, or delete this habit?")
            }
            .sheet(isPresented: $showAddHabitModal, onDismiss: loadData) {
                AddMicrohabitView(
                    initialType: .create,
                    goals: goals,
                    onDismiss: { showAddHabitModal = false },
                    onSave: {
                        showAddHabitModal = false
                        loadData()
                    }
                )
                .environment(dataManager)
            }
            .sheet(isPresented: $showEditSheet, onDismiss: {
                habitToEdit = nil
            }) {
                if let habit = habitToEdit {
                    AddMicrohabitView(
                        initialType: habit.type,
                        goals: goals,
                        existing: habit,
                        onDismiss: {
                            showEditSheet = false
                            habitToEdit = nil
                            loadData()
                        },
                        onSave: {
                            showEditSheet = false
                            habitToEdit = nil
                            loadData()
                        }
                    )
                    .environment(dataManager)
                }
            }
            .alert("Delete Habit", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    habitToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    confirmDeleteHabit()
                }
            } message: {
                if let habit = habitToDelete {
                    Text("Are you sure you want to delete \"\(habit.title)\"? This can't be undone.")
                } else {
                    Text("Are you sure you want to delete this habit? This can't be undone.")
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { habitForTimer != nil },
                set: { if !$0 { habitForTimer = nil } }
            )) {
                if let habit = habitForTimer {
                    FocusTimerView(
                        habit: habit,
                        onDismiss: { habitForTimer = nil }
                    )
                }
            }
            .sheet(item: $selectedScienceLesson) { lesson in
                HabitScienceLessonSheetContent(
                    lesson: lesson,
                    allLessons: HabitScienceLesson.allLessons,
                    onSelectLesson: { selectedScienceLesson = $0 },
                    onDismiss: { selectedScienceLesson = nil },
                    onAddHabit: {
                        selectedScienceLesson = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            showAddHabitModal = true
                        }
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            }
            .preferredColorScheme(.dark)
        }
    }

    private func habitsGroupedByTimeframe(habits: [Microhabit]) -> some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(habits, id: \.id) { habit in
                SwipeActionCard(
                    onEdit: {
                        habitToEdit = habit
                        showEditSheet = true
                    },
                    onDelete: { deleteHabit(habit) }
                ) {
                    MicrohabitCard(
                        habit: habit,
                        linkedGoal: goals.first { $0.id.uuidString == habit.goalID },
                        onStartFocus: { habitForTimer = habit },
                        onEdit: {
                            habitToEdit = habit
                            showEditSheet = true
                        },
                        onDelete: { deleteHabit(habit) },
                        onTap: { habitForActions = habit }
                    )
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 100)
    }

    // MARK: - All Habits List (unified view with category badges)
    private var allHabitsList: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(filteredHabits, id: \.id) { habit in
                SwipeActionCard(
                    onEdit: {
                        habitToEdit = habit
                        showEditSheet = true
                    },
                    onDelete: { deleteHabit(habit) }
                ) {
                    MicrohabitCard(
                        habit: habit,
                        linkedGoal: goals.first { $0.id.uuidString == habit.goalID },
                        onStartFocus: { habitForTimer = habit },
                        onEdit: {
                            habitToEdit = habit
                            showEditSheet = true
                        },
                        onDelete: { deleteHabit(habit) },
                        onTap: { habitForActions = habit }
                    )
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Unified Empty State
    private var emptyStateHabits: some View {
        VStack(spacing: 20) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.noorSuccess.opacity(0.8))

            VStack(spacing: 8) {
                Text("Build your daily rhythm")
                    .font(NoorFont.title)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(emptyStateMessage)
                    .font(NoorFont.body)
                    .foregroundStyle(Color.noorTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                showAddHabitModal = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                    Text("Add a habit")
                        .font(NoorFont.button)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.noorSuccess)
                .clipShape(RoundedRectangle(cornerRadius: NoorLayout.cornerRadiusLarge))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 20)
    }
    
    private var emptyStateMessage: String {
        switch selectedFilter {
        case .all:
            return "Add habits to build consistency. Link them to a journey or keep them standalone."
        case .journey:
            return "No journey habits yet. Link habits to your journeys when creating them."
        case .completed:
            return "Habits you've completed at least once will show here. Complete one to see it."
        case .archived:
            return "Archived habits move here. Archive from the habit's edit menu."
        case .recent:
            return "Habits you added in the last 7 days appear here."
        }
    }

    private var emptyStateMicroHabits: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(Color.noorSuccess.opacity(0.8))

            VStack(spacing: 8) {
                Text("Flexible, everyday wins")
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorSuccess)
                    .multilineTextAlignment(.center)

                Text("Standalone habits")
                    .font(NoorFont.title)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Day-to-day habits you can add, swap, or adjust anytime. Not tied to a journey—just simple actions that keep you moving forward.")
                    .font(NoorFont.body)
                    .foregroundStyle(Color.noorTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                showAddHabitModal = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                    Text("Add a habit")
                        .font(NoorFont.button)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.noorSuccess)
                .clipShape(RoundedRectangle(cornerRadius: NoorLayout.cornerRadiusLarge))
                    .shadow(color: Color.noorSuccess.opacity(0.5), radius: 16, x: 0, y: 0)
                    .shadow(color: Color.noorSuccess.opacity(0.3), radius: 24, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var emptyStateJourneyHabits: some View {
        VStack(spacing: 20) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 48))
                .foregroundStyle(Color.noorSuccess.opacity(0.8))

            VStack(spacing: 8) {
                Text("Fuel your journey")
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorSuccess)
                    .multilineTextAlignment(.center)

                Text("Journey habits")
                    .font(NoorFont.title)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Habits linked to a journey become the steady engine behind your bigger goals. Link a habit when creating or editing, and it'll show here.")
                    .font(NoorFont.body)
                    .foregroundStyle(Color.noorTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                showAddHabitModal = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                    Text("Add a habit")
                        .font(NoorFont.button)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.noorSuccess)
                .clipShape(RoundedRectangle(cornerRadius: NoorLayout.cornerRadiusLarge))
                    .shadow(color: Color.noorSuccess.opacity(0.5), radius: 16, x: 0, y: 0)
                    .shadow(color: Color.noorSuccess.opacity(0.3), radius: 24, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var journeyHabitsList: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(journeysWithHabits, id: \.id) { goal in
                let habitsForJourney = microhabits.filter { $0.goalID == goal.id.uuidString }
                if !habitsForJourney.isEmpty {
                    // Section header - journey name
                    HStack(spacing: 6) {
                        Image(systemName: "cloud.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.noorAccent)
                        Text(goal.destination.isEmpty ? goal.title : goal.destination)
                            .font(NoorFont.callout)
                            .foregroundStyle(Color.noorAccent)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 2)

                    ForEach(habitsForJourney, id: \.id) { habit in
                        SwipeActionCard(
                            onEdit: {
                                habitToEdit = habit
                                showEditSheet = true
                            },
                            onDelete: { deleteHabit(habit) }
                        ) {
                            MicrohabitCard(
                                habit: habit,
                                linkedGoal: goal,
                                onStartFocus: { habitForTimer = habit },
                                onEdit: {
                                    habitToEdit = habit
                                    showEditSheet = true
                                },
                                onDelete: { deleteHabit(habit) },
                                onTap: { habitForActions = habit }
                            )
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
        .padding(.bottom, 100)
    }

    // MARK: - Journey Habits Detail (all habits for one journey)
    // Used as NavigationLink destination; passed habits so parent refresh (after edit) updates the list.
    private struct JourneyHabitsDetailView: View {
        @Environment(DataManager.self) private var dataManager
        let goal: Goal
        let habits: [Microhabit]
        let goals: [Goal]
        let onDismiss: () -> Void
        let onEditHabit: (Microhabit) -> Void
        let onDeleteHabit: (Microhabit) -> Void
        let onStartFocus: (Microhabit) -> Void
        @State private var habitForActions: Microhabit?

        var body: some View {
            ZStack {
                Color.noorBackground
                    .ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(habits, id: \.id) { habit in
                            SwipeActionCard(
                                onEdit: { onEditHabit(habit) },
                                onDelete: { onDeleteHabit(habit) }
                            ) {
                                MicrohabitCard(
                                    habit: habit,
                                    linkedGoal: goals.first { $0.id.uuidString == habit.goalID },
                                    onStartFocus: { onStartFocus(habit) },
                                    onEdit: { onEditHabit(habit) },
                                    onDelete: { onDeleteHabit(habit) },
                                    onTap: { habitForActions = habit }
                                )
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(goal.destination.isEmpty ? goal.title : goal.destination)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .confirmationDialog("Habit", isPresented: Binding(
                get: { habitForActions != nil },
                set: { if !$0 { habitForActions = nil } }
            )) {
                if let h = habitForActions {
                    Button("Edit") {
                        onEditHabit(h)
                        habitForActions = nil
                    }
                    Button("Delete", role: .destructive) {
                        onDeleteHabit(h)
                        habitForActions = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    habitForActions = nil
                }
            } message: {
                Text("Edit or delete this habit?")
            }
            .preferredColorScheme(.dark)
        }
    }

    private func loadData() {
        Task { @MainActor in
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            do {
                microhabits = try await dataManager.fetchMicrohabits()
                goals = try await dataManager.fetchAllGoals()
                print("📊 Loaded \(microhabits.count) habits, \(goals.count) goals")
                print("📊 Micro habits only (goalID == nil): \(microhabits.filter { $0.goalID == nil }.count)")
                for habit in microhabits {
                    print("  - \(habit.title) (goalID: \(habit.goalID ?? "nil"))")
                }
            } catch {
                print("❌ Error loading data: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteHabit(_ habit: Microhabit) {
        habitToDelete = habit
        showDeleteConfirmation = true
    }

    private func confirmDeleteHabit() {
        guard let habit = habitToDelete else { return }
        Task {
            do {
                try await dataManager.deleteMicrohabit(habit.id)
                loadData()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        habitToDelete = nil
    }
    
    private func archiveHabit(_ habit: Microhabit, archive: Bool) {
        habit.isArchived = archive
        Task {
            do {
                try await dataManager.saveMicrohabit(habit)
                await MainActor.run { loadData() }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Science of micro habits (lesson model + card + sheet)
struct HabitScienceLesson: Identifiable {
    let id: UUID
    let tag: String
    let title: String
    let snippet: String
    let fullText: String

    init(id: UUID = UUID(), tag: String, title: String, snippet: String, fullText: String) {
        self.id = id
        self.tag = tag
        self.title = title
        self.snippet = snippet
        self.fullText = fullText
    }

    static let allLessons: [HabitScienceLesson] = [
        HabitScienceLesson(
            tag: "Science",
            title: "Why small habits create big wins",
            snippet: "Research shows that 1% improvements compound. You don't need a big gesture—you need a small, repeatable action that your brain can automate.",
            fullText: "Research in behavioral science shows that 1% improvements compound over time. You don't need a big gesture—you need a small, repeatable action that your brain can automate.\n\nMicro habits work because they lower the barrier to start. Once you start, momentum often carries you further. The goal is to make the habit so small that you can't say no (e.g. \"put on my running shoes\" instead of \"run 5K\").\n\nIdentity-based change beats outcome-based change: focus on becoming the type of person who does the thing, not on the outcome. Small wins build that identity."
        ),
        HabitScienceLesson(
            tag: "Science",
            title: "Implementation intentions",
            snippet: "\"When X happens, I will Y.\" This formula dramatically increases the chance you'll follow through by linking the habit to a cue.",
            fullText: "Implementation intentions take the form: \"When X happens, I will Y.\" Studies show this formula dramatically increases the chance you'll follow through.\n\nBy linking your micro habit to a specific cue (a time, a place, or an existing habit), you help your brain recognize the trigger and execute the behavior without relying on motivation.\n\nExample: \"When I finish my morning coffee, I will open my running shoes.\" The cue is clear; the action is tiny. Over time, the cue automatically triggers the action."
        ),
        HabitScienceLesson(
            tag: "Science",
            title: "The focus timer and attention",
            snippet: "Short, timed blocks reduce overwhelm and train your brain to stay present. Even 5 minutes of focused action beats 30 minutes of distracted effort.",
            fullText: "Short, timed blocks reduce overwhelm and train your brain to stay present. Even 5 minutes of focused action often beats 30 minutes of distracted effort.\n\nUsing a focus timer for your micro habit does two things: it creates a clear start and end (lowering resistance), and it builds the muscle of sustained attention. Over time, you can extend the duration if you want—but the habit of \"showing up\" for a few minutes is what compounds."
        )
    ]

    static var dailyLesson: HabitScienceLesson {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return allLessons[day % allLessons.count]
    }
}

struct HabitScienceLessonCard: View {
    let lesson: HabitScienceLesson
    let onTap: () -> Void
    var showTag: Bool = false // hide "Science" tag to save space in cell

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                if showTag {
                    HStack {
                        Text(lesson.tag)
                            .font(NoorFont.caption)
                            .foregroundStyle(Color.noorSuccess.opacity(0.9))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                        Spacer()
                    }
                }

                Text(lesson.title)
                    .font(NoorFont.title2)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .truncationMode(.tail)

                Text(lesson.snippet)
                    .font(NoorFont.body)
                    .foregroundStyle(Color.noorTextSecondary.opacity(0.95))
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    Text("Tap to read more")
                        .font(NoorFont.callout)
                        .foregroundStyle(Color.noorSuccess)
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.noorSuccess.opacity(0.9))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// Bottom sheet content: same aesthetic as Add a habit (full-width, seamless header, drag to dismiss)
struct HabitScienceLessonSheetContent: View {
    let lesson: HabitScienceLesson
    let allLessons: [HabitScienceLesson]
    let onSelectLesson: (HabitScienceLesson) -> Void
    let onDismiss: () -> Void
    var onAddHabit: (() -> Void)? = nil

    private var otherLessons: [HabitScienceLesson] {
        allLessons.filter { $0.id != lesson.id }
    }

    var body: some View {
        ZStack {
            Color.noorBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Spacer above header so content isn’t cut off by the sheet edge
                Spacer()
                    .frame(height: 24)

                // Header with seamless close (matches Add a habit sheet)
                HStack(alignment: .center) {
                    HStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.noorSuccess)
                        Text("Science of micro habits")
                            .font(NoorFont.largeTitle)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.noorTextSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(lesson.title)
                            .font(NoorFont.title2)
                            .foregroundStyle(.white)

                        Text(lesson.fullText)
                            .font(NoorFont.body)
                            .foregroundStyle(Color.noorTextSecondary)

                        if !otherLessons.isEmpty {
                            Text("More to read")
                                .font(NoorFont.callout)
                                .foregroundStyle(Color.noorSuccess)
                                .padding(.top, 8)

                            VStack(spacing: 10) {
                                ForEach(otherLessons) { other in
                                    Button {
                                        onSelectLesson(other)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Text(other.title)
                                                .font(NoorFont.body)
                                                .foregroundStyle(.white)
                                                .multilineTextAlignment(.leading)
                                                .lineLimit(2)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(Color.noorSuccess.opacity(0.8))
                                        }
                                        .padding(16)
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Add a habit CTA
                        if let onAddHabit {
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onAddHabit()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .bold))
                                    Text("Add a habit")
                                        .font(NoorFont.button)
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.noorSuccess)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 12)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

struct HabitScienceLessonSheet: View {
    let lesson: HabitScienceLesson
    let onDismiss: () -> Void

    var body: some View {
        HabitScienceLessonSheetContent(
            lesson: lesson,
            allLessons: HabitScienceLesson.allLessons,
            onSelectLesson: { _ in },
            onDismiss: onDismiss
        )
    }
}

// MARK: - Microhabit Card (title, reminder days under name, focus + time on right; edit/delete via swipe or tap)
struct MicrohabitCard: View {
    let habit: Microhabit
    let linkedGoal: Goal?
    let onStartFocus: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    var onTap: (() -> Void)? = nil  // tap center to show Edit/Delete choice

    static func formatTime(hour: Int, minute: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let h = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d %@", h, minute, period)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left: title, description, timeframe + journey, reminder days at bottom left
            VStack(alignment: .leading, spacing: 8) {
                Text(habit.title)
                    .font(NoorFont.title2)
                    .foregroundStyle(.white)

                if !habit.habitDescription.isEmpty {
                    Text(habit.habitDescription)
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorTextSecondary)
                        .lineLimit(3)
                }

                // Category badge and journey/tag info
                HStack(spacing: 8) {
                    // Category badge
                    if let goal = linkedGoal {
                        HStack(spacing: 4) {
                            Image(systemName: "airplane.departure")
                                .font(.system(size: 10))
                            Text(goal.destination.isEmpty ? goal.title : goal.destination)
                                .font(.system(size: 11))
                                .lineLimit(1)
                        }
                        .foregroundStyle(Color.noorAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.noorAccent.opacity(0.15))
                        .clipShape(Capsule())
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 10))
                            Text("Micro")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(Color.noorSuccess)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.noorSuccess.opacity(0.15))
                        .clipShape(Capsule())
                    }

                    if let tag = habit.customTag, !tag.isEmpty {
                        Text(tag)
                            .font(NoorFont.caption)
                            .foregroundStyle(Color.noorViolet.opacity(0.95))
                            .lineLimit(1)
                    }
                }

                // Reminder time + days
                if habit.reminderFrequency != .never {
                    HStack(spacing: 4) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 11))
                        if let hour = habit.reminderHour, let minute = habit.reminderMinute {
                            Text(Self.formatTime(hour: hour, minute: minute))
                                .font(NoorFont.caption)
                        }
                        Text(habit.reminderDaysDisplayName)
                            .font(NoorFont.caption)
                    }
                    .foregroundStyle(Color.noorTextSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }

            // Right: timer icon + focus duration
            if habit.hasFocusTimer {
                Button(action: onStartFocus) {
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                            .font(.system(size: 20))
                        Text("\(habit.focusDurationMinutes) min")
                            .font(NoorFont.caption)
                            .foregroundStyle(Color.noorTextSecondary)
                    }
                    .foregroundStyle(Color.noorSuccess)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: NoorLayout.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: NoorLayout.cornerRadius)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Add Habit (simple one-step sheet)
struct AddHabitSimpleSheet: View {
    @Environment(DataManager.self) private var dataManager
    let onDismiss: () -> Void

    @State private var habitTitle = ""
    @State private var isSaving = false
    @FocusState private var titleFocused: Bool

    private var canAdd: Bool {
        !habitTitle.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
    }

    var body: some View {
        ZStack {
            Color.noorBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 24)
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 28, weight: .bold))
                        Text("Add a habit")
                            .font(NoorFont.largeTitle)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.noorTextSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 12) {
                    Text("What habit would you like to build?")
                        .font(NoorFont.bodyLarge)
                        .foregroundStyle(Color.noorTextSecondary)
                    TextField("e.g. 2-page journal session", text: $habitTitle)
                        .textFieldStyle(.plain)
                        .font(NoorFont.body)
                        .foregroundStyle(.white)
                        .padding(16)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .focused($titleFocused)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)

                Button {
                    addHabit()
                } label: {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .bold))
                        }
                        Text("Add habit")
                            .font(NoorFont.button)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(canAdd ? Color.noorSuccess : Color.noorSuccess.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: NoorLayout.cornerRadiusLarge))
                }
                .buttonStyle(.plain)
                .disabled(!canAdd)
                .padding(.horizontal, 20)
                Spacer()
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                titleFocused = true
            }
        }
    }

    private func addHabit() {
        let trimmed = habitTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isSaving else { return }
        isSaving = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task { @MainActor in
            do {
                let habit = Microhabit(
                    title: trimmed,
                    habitDescription: "",
                    goalID: nil,
                    customTag: nil,
                    focusDurationMinutes: 5,
                    type: .create,
                    timeframe: .anytime,
                    habitHour: nil,
                    habitMinute: nil,
                    reminderFrequency: .never,
                    reminderDaysRaw: nil,
                    reminderHour: 9,
                    reminderMinute: 0
                )
                try await dataManager.saveMicrohabit(habit)
                onDismiss()
            } catch {
                isSaving = false
            }
        }
    }
}

// MARK: - Add / Edit Microhabit Form (links to goal, focus duration)
struct AddMicrohabitView: View {
    @Environment(DataManager.self) private var dataManager
    @Environment(\.dismiss) private var dismiss
    let initialType: MicrohabitType
    var initialTitle: String = ""  // title from modal
    var initialDescription: String = ""  // description from modal
    let goals: [Goal]
    var existing: Microhabit?
    let onDismiss: () -> Void
    let onSave: () -> Void

    @State private var title: String
    @State private var habitDescription: String
    @State private var selectedGoalID: String?
    @State private var customTag = ""
    @State private var timeframe: HabitTimeframe = .anytime
    @State private var habitTime: Date? = nil  // preferred time of day (hour/minute); nil = not set
    @State private var showHabitTimeSheet = false
    @State private var focusMinutes: Int = 5
    @State private var reminderFrequency: HabitReminderFrequency = .never
    @State private var reminderDays: Set<Int> = []  // 0 = Sun … 6 = Sat; at least 1 when reminder on
    @State private var reminderTimeOffset: ReminderTimeOffset = .atHabitTime
    @State private var isSaving = false
    
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
    }

    private static let weekdayLetters = ["S", "M", "T", "W", "T", "F", "S"]  // Sun–Sat
    
    enum ReminderTimeOffset: Int, CaseIterable, Identifiable {
        case atHabitTime = 0
        case fiveMinutesBefore = -5
        case tenMinutesBefore = -10
        case fifteenMinutesBefore = -15
        case thirtyMinutesBefore = -30
        
        var id: Int { rawValue }
        
        var displayName: String {
            switch self {
            case .atHabitTime: return "At the habit time"
            case .fiveMinutesBefore: return "5 minutes before"
            case .tenMinutesBefore: return "10 minutes before"
            case .fifteenMinutesBefore: return "15 minutes before"
            case .thirtyMinutesBefore: return "30 minutes before"
            }
        }
    }

    var initialGoalID: String? = nil

    init(
        initialType: MicrohabitType,
        initialTitle: String = "",
        initialDescription: String = "",
        goals: [Goal],
        existing: Microhabit? = nil,
        initialGoalID: String? = nil,
        onDismiss: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) {
        self.initialType = initialType
        self.initialTitle = initialTitle
        self.initialDescription = initialDescription
        self.goals = goals
        self.existing = existing
        self.initialGoalID = initialGoalID
        self.onDismiss = onDismiss
        self.onSave = onSave
        // Initialize from existing habit or from modal input
        _title = State(initialValue: existing?.title ?? initialTitle)
        _habitDescription = State(initialValue: existing?.habitDescription ?? initialDescription)
        _selectedGoalID = State(initialValue: existing?.goalID ?? initialGoalID)
    }

    /// Preset buttons only up to 20 min; 21–60 selected via slider to avoid horizontal scroll.
    private let focusPresetOptions = [5, 10, 15, 20]
    private let calendar = Calendar.current
    private static let habitTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.noorBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Habit name (required) — always show so new-habit flow works
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Name of habit")
                                .font(NoorFont.title)
                                .foregroundStyle(.white)
                            TextField("e.g. 2-page journal session", text: $title)
                                .textFieldStyle(.plain)
                                .font(NoorFont.body)
                                .foregroundStyle(.white)
                                .padding(14)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Time of day (required for add flow; optional for edit)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Schedule")
                                .font(NoorFont.title)
                                .foregroundStyle(.white)
                            Text("When do you want to do this habit?")
                                .font(NoorFont.bodyLarge)
                                .foregroundStyle(Color.noorTextSecondary)
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Time of day")
                                        .font(NoorFont.bodyLarge)
                                        .foregroundStyle(Color.noorTextSecondary)
                                    if let t = habitTime {
                                        Text(Self.habitTimeFormatter.string(from: t))
                                            .font(NoorFont.body)
                                            .foregroundStyle(.white)
                                    } else {
                                        Text("Not set")
                                            .font(NoorFont.body)
                                            .foregroundStyle(Color.noorTextSecondary.opacity(0.6))
                                    }
                                }
                                Spacer()
                                Button {
                                    showHabitTimeSheet = true
                                } label: {
                                    Text(habitTime == nil ? "Set time" : "Change")
                                        .font(NoorFont.caption)
                                        .foregroundStyle(Color.noorSuccess)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.noorSuccess.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .sheet(isPresented: $showHabitTimeSheet) {
                            HabitTimePickerSheet(
                                initialTime: habitTime ?? calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date(),
                                onConfirm: { date in
                                    habitTime = date
                                    showHabitTimeSheet = false
                                },
                                onRemove: {
                                    habitTime = nil
                                    showHabitTimeSheet = false
                                }
                            )
                            .presentationDetents([.fraction(0.45)])
                            .presentationDragIndicator(.visible)
                        }

                        // Remind me — same for new and edit (simple toggle)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Remind me at this time")
                                    .font(NoorFont.title)
                                    .foregroundStyle(.white)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { reminderFrequency != .never },
                                    set: {
                                        if $0 {
                                            reminderFrequency = .daily
                                            reminderDays = [0, 1, 2, 3, 4, 5, 6]
                                        } else {
                                            reminderFrequency = .never
                                            reminderDays = []
                                        }
                                    }
                                ))
                                .labelsHidden()
                                .tint(Color.noorSuccess)
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Focus time — same for new and edit
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Focus time")
                                .font(NoorFont.title)
                                .foregroundStyle(.white)
                            Text("Minutes to focus when you start this habit")
                                .font(NoorFont.bodyLarge)
                                .foregroundStyle(Color.noorTextSecondary)
                            HStack(spacing: 8) {
                                ForEach(focusPresetOptions, id: \.self) { min in
                                    Button {
                                        focusMinutes = min
                                    } label: {
                                        Text("\(min)")
                                            .font(NoorFont.callout)
                                            .foregroundStyle(focusMinutes == min ? .white : Color.noorTextSecondary)
                                            .frame(width: 44, height: 36)
                                            .background(focusMinutes == min ? Color.noorSuccess : Color.white.opacity(0.08))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                }
                                Button {
                                    focusMinutes = 0
                                } label: {
                                    Text("Off")
                                        .font(NoorFont.callout)
                                        .foregroundStyle(focusMinutes == 0 ? .white : Color.noorTextSecondary)
                                        .frame(width: 44, height: 36)
                                        .background(focusMinutes == 0 ? Color.noorSuccess : Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                Spacer()
                                Text("\(focusMinutes) min")
                                    .font(NoorFont.caption)
                                    .foregroundStyle(Color.noorTextSecondary)
                            }
                            if focusMinutes > 0 {
                                Slider(
                                    value: Binding(
                                        get: { Double(focusMinutes) },
                                        set: { focusMinutes = Int($0) }
                                    ),
                                    in: 1...60,
                                    step: 1
                                )
                                .tint(Color.noorSuccess)
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Optional sections only when editing
                        if existing != nil {
                            // Vision & link (edit only)
                            VStack(alignment: .leading, spacing: 12) {
                                Text("How it supports your vision")
                                    .font(NoorFont.title)
                                    .foregroundStyle(.white)
                                TextField("I will ... so that I can become ...", text: $habitDescription, axis: .vertical)
                                    .textFieldStyle(.plain)
                                    .font(NoorFont.body)
                                    .foregroundStyle(Color.noorTextSecondary)
                                    .lineLimit(3...8)
                                    .padding(14)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 4) {
                                        Text("Link to a journey")
                                            .font(NoorFont.bodyLarge)
                                            .foregroundStyle(Color.noorTextSecondary)
                                        Text("(optional)")
                                            .font(NoorFont.bodyLarge)
                                            .foregroundStyle(Color.noorTextSecondary.opacity(0.6))
                                    }
                                    Picker("Journey", selection: $selectedGoalID) {
                                        Text("Stand-alone habit").tag(nil as String?)
                                        ForEach(goals, id: \.id) { goal in
                                            Text(goal.destination.isEmpty ? goal.title : goal.destination)
                                                .lineLimit(1)
                                                .tag(goal.id.uuidString as String?)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(.white)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 14)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            .padding(16)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        Button {
                            print("🔘 Add habit button tapped - canSave: \(canSave), isSaving: \(isSaving)")
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            saveHabit()
                        } label: {
                            HStack(spacing: 8) {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.8)
                                }
                                Text(existing == nil ? "Add habit" : "Save changes")
                                    .font(NoorFont.button)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(canSave ? Color.noorSuccess : Color.noorSuccess.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: NoorLayout.cornerRadiusLarge))
                        }
                        .disabled(!canSave)
                        .padding(.top, 16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                print("📝 Form appeared - initialTitle: '\(initialTitle)', title: '\(title)', existing: \(existing != nil)")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                ToolbarItem(placement: .principal) {
                    Text(title.isEmpty ? "New habit" : title)
                        .font(NoorFont.title2)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
            .onAppear {
                if let h = existing {
                    title = h.title
                    habitDescription = h.habitDescription
                    selectedGoalID = h.goalID
                    customTag = h.customTag ?? ""
                    timeframe = h.timeframe
                    if let hour = h.habitHour, let minute = h.habitMinute {
                        habitTime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date())
                    } else {
                        habitTime = nil
                    }
                    focusMinutes = h.focusDurationMinutes
                    reminderFrequency = h.reminderFrequency
                    if !h.reminderDays.isEmpty {
                        reminderDays = h.reminderDays
                    } else {
                        switch h.reminderFrequency {
                        case .never: reminderDays = []
                        case .daily: reminderDays = [0, 1, 2, 3, 4, 5, 6]
                        case .weekdays: reminderDays = [1, 2, 3, 4, 5]
                        case .weekends: reminderDays = [0, 6]
                        }
                    }
                    // Calculate reminder time offset from stored times
                    if let habitHour = h.habitHour, let habitMinute = h.habitMinute,
                       let reminderHour = h.reminderHour, let reminderMinute = h.reminderMinute,
                       let habitDate = calendar.date(bySettingHour: habitHour, minute: habitMinute, second: 0, of: Date()),
                       let reminderDate = calendar.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: Date()) {
                        let diff = calendar.dateComponents([.minute], from: habitDate, to: reminderDate).minute ?? 0
                        reminderTimeOffset = ReminderTimeOffset.allCases.first { $0.rawValue == diff } ?? .atHabitTime
                    }
                }
            }
        }
    }

    private func calculateReminderTime() -> Date {
        // Use habit time if set, otherwise default to 9 AM
        let baseTime = habitTime ?? calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        // Apply offset
        return calendar.date(byAdding: .minute, value: reminderTimeOffset.rawValue, to: baseTime) ?? baseTime
    }

    private func saveHabit() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else {
            print("❌ Save failed: title is empty (title='\(title)')")
            return
        }
        
        guard !isSaving else {
            print("⚠️ Already saving, ignoring duplicate tap")
            return
        }
        
        print("💾 Starting to save habit: '\(trimmedTitle)'")
        print("   - goalID: \(selectedGoalID ?? "nil")")
        print("   - reminderFrequency: \(reminderFrequency)")
        print("   - reminderDays: \(reminderDays)")
        
        isSaving = true

        Task { @MainActor in
            do {
                if let h = existing {
                    print("📝 Updating existing habit...")
                    h.title = trimmedTitle
                    h.habitDescription = habitDescription.trimmingCharacters(in: .whitespaces)
                    h.goalID = selectedGoalID
                    h.customTag = customTag.trimmingCharacters(in: .whitespaces).isEmpty ? nil : customTag.trimmingCharacters(in: .whitespaces)
                    h.timeframe = timeframe
                    h.habitHour = habitTime.map { calendar.component(.hour, from: $0) }
                    h.habitMinute = habitTime.map { calendar.component(.minute, from: $0) }
                    h.focusDurationMinutes = focusMinutes
                    h.reminderFrequency = reminderFrequency
                    h.reminderDays = reminderDays
                    let reminderTime = calculateReminderTime()
                    h.reminderHour = calendar.component(.hour, from: reminderTime)
                    h.reminderMinute = calendar.component(.minute, from: reminderTime)
                    try await dataManager.saveContext()
                    print("✅ Updated existing habit")
                } else {
                    print("📝 Creating new habit...")
                    let habit = Microhabit(
                        title: trimmedTitle,
                        habitDescription: habitDescription.trimmingCharacters(in: .whitespaces),
                        goalID: selectedGoalID,
                        customTag: customTag.trimmingCharacters(in: .whitespaces).isEmpty ? nil : customTag.trimmingCharacters(in: .whitespaces),
                        focusDurationMinutes: focusMinutes,
                        type: initialType,
                        timeframe: timeframe,
                        habitHour: habitTime.map { calendar.component(.hour, from: $0) },
                        habitMinute: habitTime.map { calendar.component(.minute, from: $0) },
                        reminderFrequency: reminderFrequency,
                        reminderDaysRaw: reminderDays.isEmpty ? nil : reminderDays.sorted().map(String.init).joined(separator: ","),
                        reminderHour: calendar.component(.hour, from: calculateReminderTime()),
                        reminderMinute: calendar.component(.minute, from: calculateReminderTime())
                    )
                    print("   Created habit object - goalID: \(habit.goalID ?? "nil"), title: \(habit.title)")
                    try await dataManager.saveMicrohabit(habit)
                    print("✅ Saved new habit to database")
                }
                
                print("🔄 Dismissing and refreshing...")
                isSaving = false
                // Dismiss sheet first, then trigger parent refresh
                dismiss()
                onSave()
            } catch {
                print("❌ Error saving habit: \(error)")
                print("   Error details: \(error.localizedDescription)")
                isSaving = false
            }
        }
    }
}

// MARK: - Habit time picker sheet (hour, minute, AM/PM)
private struct HabitTimePickerSheet: View {
    let initialTime: Date
    let onConfirm: (Date) -> Void
    let onRemove: () -> Void

    @State private var pickerTime: Date = Date()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.noorBackground
                    .ignoresSafeArea()
                VStack(spacing: 24) {
                    DatePicker("Time", selection: $pickerTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .tint(.white)
                        .colorScheme(.dark)
                    VStack(spacing: 12) {
                        Button {
                            onConfirm(pickerTime)
                        } label: {
                            Text("Confirm")
                                .font(NoorFont.button)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.noorSuccess)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        Button {
                            onRemove()
                        } label: {
                            Text("Remove")
                                .font(NoorFont.body)
                                .foregroundStyle(Color.noorTextSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 24)
            }
            .navigationTitle("Habit time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .onAppear {
                pickerTime = initialTime
            }
        }
    }
}

// MARK: - Focus Timer (fullscreen countdown)
struct FocusTimerView: View {
    let habit: Microhabit
    let onDismiss: () -> Void

    @State private var remainingSeconds: Int = 0
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var hasCompleted = false
    @State private var animatedProgress: CGFloat = 0

    var body: some View {
        ZStack {
            Color.noorBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with close button
                HStack {
                    Spacer()
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onDismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.noorTextSecondary)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // Main content
                VStack(spacing: 40) {
                    // Habit title
                    VStack(spacing: 8) {
                        Text("Focus Time")
                            .font(NoorFont.caption)
                            .foregroundStyle(Color.noorSuccess)

                        Text(habit.title)
                            .font(NoorFont.title)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    // Timer circle
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 10)
                            .frame(width: 240, height: 240)

                        // Progress circle with smooth animation
                        Circle()
                            .trim(from: 0, to: animatedProgress)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.noorSuccess, Color.noorSuccess.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .frame(width: 240, height: 240)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: animatedProgress)

                        // Inner content
                        VStack(spacing: 4) {
                            Text(timeString)
                                .font(.system(size: 56, weight: .light, design: .rounded))
                                .foregroundStyle(.white)
                                .monospacedDigit()

                            if !hasCompleted {
                                Text(isRunning ? "remaining" : "tap start")
                                    .font(NoorFont.caption)
                                    .foregroundStyle(Color.noorTextSecondary)
                            }
                        }
                    }

                    // Status and buttons
                    if hasCompleted {
                        VStack(spacing: 20) {
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(Color.noorSuccess)

                                Text("Great focus!")
                                    .font(NoorFont.title2)
                                    .foregroundStyle(.white)

                                Text("You stayed present for \(habit.focusDurationMinutes) minutes")
                                    .font(NoorFont.body)
                                    .foregroundStyle(Color.noorTextSecondary)
                            }

                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onDismiss()
                            } label: {
                                Text("Done")
                                    .font(NoorFont.button)
                                    .foregroundStyle(.white)
                                    .frame(width: 160, height: 52)
                                    .background(Color.noorSuccess.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.noorSuccess.opacity(0.5), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        HStack(spacing: 16) {
                            // Reset button (only when running or paused mid-session)
                            if isRunning || remainingSeconds < totalSeconds {
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    timer?.invalidate()
                                    timer = nil
                                    isRunning = false
                                    remainingSeconds = totalSeconds
                                    cancelTimerNotification()
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        animatedProgress = 0
                                    }
                                } label: {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(Color.noorTextSecondary)
                                        .frame(width: 52, height: 52)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }

                            // Start/Pause button
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                if isRunning {
                                    timer?.invalidate()
                                    timer = nil
                                    cancelTimerNotification()
                                } else {
                                    startTimer()
                                }
                                isRunning.toggle()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                                        .font(.system(size: 16))
                                    Text(isRunning ? "Pause" : "Start")
                                        .font(NoorFont.button)
                                }
                                .foregroundStyle(.white)
                                .frame(width: 140, height: 52)
                                .background(
                                    isRunning
                                        ? Color.white.opacity(0.12)
                                        : Color.noorSuccess.opacity(0.2)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            isRunning
                                                ? Color.white.opacity(0.2)
                                                : Color.noorSuccess.opacity(0.5),
                                            lineWidth: 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            remainingSeconds = habit.focusDurationMinutes * 60
        }
        .onDisappear {
            timer?.invalidate()
            cancelTimerNotification()
        }
    }

    private var totalSeconds: Int {
        habit.focusDurationMinutes * 60
    }

    private var progress: CGFloat {
        guard totalSeconds > 0 else { return 0 }
        return CGFloat(totalSeconds - remainingSeconds) / CGFloat(totalSeconds)
    }

    private var timeString: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func startTimer() {
        // Schedule a local notification so the phone vibrates even if app is closed
        scheduleTimerNotification()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
                withAnimation(.linear(duration: 1)) {
                    animatedProgress = progress
                }
            } else {
                timer?.invalidate()
                timer = nil
                isRunning = false
                hasCompleted = true
                // Haptic burst on completion
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                }
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func scheduleTimerNotification() {
        // Remove any previous timer notification
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["focusTimer_\(habit.id.uuidString)"])

        let content = UNMutableNotificationContent()
        content.title = "Focus Complete!"
        content.body = "You finished your \(habit.focusDurationMinutes)-minute session for \(habit.title)."
        content.sound = .default // triggers vibration on silent mode too

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(remainingSeconds),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "focusTimer_\(habit.id.uuidString)",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("Failed to schedule focus timer notification: \(error)")
            }
        }
    }

    private func cancelTimerNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["focusTimer_\(habit.id.uuidString)"])
    }
}

#if DEBUG
#Preview("Microhabits") {
    MicrohabitsView()
        .environment(DataManager.shared)
}
#endif
