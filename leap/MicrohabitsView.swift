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

enum HabitsTab: String, CaseIterable {
    case microHabits = "Micro Habits"
    case journeyHabits = "Journey Habits"
}

struct MicrohabitsView: View {
    @Environment(DataManager.self) private var dataManager
    @State private var microhabits: [Microhabit] = []
    @State private var goals: [Goal] = []
    @State private var isLoading = true
    @State private var showAddHabitModal = false
    @State private var showAddForm = false
    @State private var selectedHabitType: MicrohabitType = .create
    @State private var newHabitTitle = ""
    @State private var habitToEdit: Microhabit?
    @State private var showEditSheet = false
    @State private var habitForTimer: Microhabit?
    @State private var errorMessage: String?
    @State private var selectedScienceLesson: HabitScienceLesson?
    @State private var selectedHabitsTab: HabitsTab = .microHabits

    /// Standalone habits (not linked to a journey)
    private var microHabitsOnly: [Microhabit] {
        microhabits.filter { $0.goalID == nil }
    }

    /// Journeys that have at least one linked habit
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
                            .foregroundStyle(Color.noorOrange)
                        Text(msg)
                            .font(NoorFont.body)
                            .foregroundStyle(Color.noorTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    VStack(spacing: 0) {
                        Picker("", selection: $selectedHabitsTab) {
                            ForEach(HabitsTab.allCases, id: \.self) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)

                        switch selectedHabitsTab {
                        case .microHabits:
                            ScrollView {
                                VStack(alignment: .leading, spacing: 14) {
                                    if microHabitsOnly.isEmpty {
                                        emptyStateMicroHabits
                                    } else {
                                        habitsGroupedByTimeframe(habits: microHabitsOnly)
                                    }
                                }
                                .padding(20)
                                .padding(.bottom, 24)
                            }
                        case .journeyHabits:
                            ScrollView {
                                VStack(alignment: .leading, spacing: 14) {
                                    if journeysWithHabits.isEmpty {
                                        emptyStateJourneyHabits
                                    } else {
                                        journeyHabitsList
                                    }
                                }
                                .padding(20)
                                .padding(.bottom, 24)
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "leaf.fill")
                            .foregroundStyle(Color.noorRoseGold)
                        Text("Habits")
                            .font(.system(size: 20, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedScienceLesson = HabitScienceLesson.dailyLesson
                    } label: {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.noorRoseGold)
                    }
                    .buttonStyle(.plain)
                    .allowsHitTesting(!isLoading && errorMessage == nil)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showAddHabitModal = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.noorAccent)
                    }
                    .buttonStyle(.plain)
                    .allowsHitTesting(!isLoading && errorMessage == nil)
                }
            }
            .onAppear {
                loadData()
            }
            .refreshable {
                loadData()
            }
            .sheet(isPresented: $showAddHabitModal) {
                AddHabitModal(
                    habitTitle: $newHabitTitle,
                    onDismiss: {
                        showAddHabitModal = false
                        newHabitTitle = ""
                    },
                    onCreateHabit: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        selectedHabitType = .create
                        showAddHabitModal = false
                        showAddForm = true
                    },
                    onReplaceHabit: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        selectedHabitType = .replace
                        showAddHabitModal = false
                        showAddForm = true
                    }
                )
                .presentationDetents([.height(440)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            }
            .sheet(isPresented: $showAddForm) {
                AddMicrohabitView(
                    initialType: selectedHabitType,
                    initialTitle: newHabitTitle,
                    goals: goals,
                    onDismiss: {
                        showAddForm = false
                        newHabitTitle = ""
                        loadData()
                    },
                    onSave: {
                        showAddForm = false
                        newHabitTitle = ""
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
                    onDismiss: { selectedScienceLesson = nil }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            }
        }
    }

    private func habitsGroupedByTimeframe(habits: [Microhabit]) -> some View {
        let order = HabitTimeframe.displayOrder
        return VStack(alignment: .leading, spacing: 16) {
            ForEach(order, id: \.self) { timeframe in
                let habitsInSlot = habits.filter { $0.timeframe == timeframe }
                if !habitsInSlot.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: timeframe.icon)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.noorRoseGold)
                            Text(timeframe.displayName)
                                .font(NoorFont.callout)
                                .foregroundStyle(Color.noorRoseGold)
                        }
                        .padding(.horizontal, 4)

                        ForEach(habitsInSlot, id: \.id) { habit in
                            MicrohabitCard(
                                habit: habit,
                                linkedGoal: goals.first { $0.id.uuidString == habit.goalID },
                                onStartFocus: { habitForTimer = habit },
                                onEdit: {
                                    habitToEdit = habit
                                    showEditSheet = true
                                },
                                onDelete: { deleteHabit(habit) }
                            )
                        }
                    }
                }
            }
        }
    }

    private var emptyStateMicroHabits: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(Color.noorRoseGold.opacity(0.8))

            VStack(spacing: 8) {
                Text("Flexible, everyday wins")
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorRoseGold)
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
                Text("Add a habit")
                    .font(NoorFont.button)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: NoorLayout.cornerRadiusLarge))
                    .overlay(
                        RoundedRectangle(cornerRadius: NoorLayout.cornerRadiusLarge)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
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
                .foregroundStyle(Color.noorRoseGold.opacity(0.8))

            VStack(spacing: 8) {
                Text("Fuel your journey")
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorRoseGold)
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
                Text("Add a habit")
                    .font(NoorFont.button)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: NoorLayout.cornerRadiusLarge))
                    .overlay(
                        RoundedRectangle(cornerRadius: NoorLayout.cornerRadiusLarge)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
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
        VStack(alignment: .leading, spacing: 10) {
            ForEach(journeysWithHabits, id: \.id) { goal in
                let count = microhabits.filter { $0.goalID == goal.id.uuidString }.count
                NavigationLink {
                    JourneyHabitsDetailView(
                        goal: goal,
                        habits: microhabits.filter { $0.goalID == goal.id.uuidString },
                        goals: goals,
                        onDismiss: { loadData() },
                        onEditHabit: { habit in
                            habitToEdit = habit
                            showEditSheet = true
                        },
                        onDeleteHabit: { deleteHabit($0) },
                        onStartFocus: { habitForTimer = $0 }
                    )
                    .environment(dataManager)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.noorRoseGold)
                            .frame(width: 44, height: 44)
                            .background(Color.noorRoseGold.opacity(0.2))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(goal.destination.isEmpty ? goal.title : goal.destination)
                                .font(NoorFont.title2)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("\(count) habit\(count == 1 ? "" : "s")")
                                .font(NoorFont.caption)
                                .foregroundStyle(Color.noorTextSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.noorTextSecondary)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
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

        var body: some View {
            ZStack {
                Color.noorBackground
                    .ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(habits, id: \.id) { habit in
                            MicrohabitCard(
                                habit: habit,
                                linkedGoal: goals.first { $0.id.uuidString == habit.goalID },
                                onStartFocus: { onStartFocus(habit) },
                                onEdit: { onEditHabit(habit) },
                                onDelete: { onDeleteHabit(habit) }
                            )
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(goal.destination.isEmpty ? goal.title : goal.destination)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteHabit(_ habit: Microhabit) {
        Task {
            do {
                try await dataManager.deleteMicrohabit(habit.id)
                loadData()
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
                            .foregroundStyle(Color.noorRoseGold.opacity(0.9))
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
                        .foregroundStyle(Color.noorRoseGold)
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.noorRoseGold.opacity(0.9))
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

    private var otherLessons: [HabitScienceLesson] {
        allLessons.filter { $0.id != lesson.id }
    }

    var body: some View {
        ZStack {
            Color.noorBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with seamless close (matches Add a habit sheet)
                HStack(alignment: .center) {
                    HStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.noorRoseGold)
                        Text("Science of micro habits")
                            .font(NoorFont.title)
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
                .padding(.top, 8)
                .padding(.bottom, 4)

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
                                .foregroundStyle(Color.noorRoseGold)
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
                                                .foregroundStyle(Color.noorRoseGold.opacity(0.8))
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
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
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

// MARK: - Microhabit Card (title, grander vision description, focus timer icon, edit/delete)
struct MicrohabitCard: View {
    let habit: Microhabit
    let linkedGoal: Goal?
    let onStartFocus: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(habit.title)
                        .font(NoorFont.title2)
                        .foregroundStyle(.white)

                    if !habit.habitDescription.isEmpty {
                        Text(habit.habitDescription)
                            .font(NoorFont.caption)
                            .foregroundStyle(Color.noorTextSecondary)
                            .lineLimit(3)
                    }

                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: habit.timeframe.icon)
                                .font(.system(size: 11))
                            Text(habit.timeframe.displayName)
                                .font(NoorFont.caption)
                        }
                        .foregroundStyle(Color.noorTextSecondary)

                        if let goal = linkedGoal {
                            HStack(spacing: 4) {
                                Image(systemName: "airplane.departure")
                                    .font(.system(size: 11))
                                Text(goal.destination.isEmpty ? goal.title : goal.destination)
                                    .font(NoorFont.caption)
                                    .lineLimit(1)
                            }
                            .foregroundStyle(Color.noorRoseGold.opacity(0.9))
                        }

                        if let tag = habit.customTag, !tag.isEmpty {
                            Text(tag)
                                .font(NoorFont.caption)
                                .foregroundStyle(Color.noorViolet.opacity(0.95))
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                if habit.hasFocusTimer {
                    Button(action: onStartFocus) {
                        Image(systemName: "timer")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.noorRoseGold)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 16) {
                if habit.hasFocusTimer {
                    Text("\(habit.focusDurationMinutes) min focus")
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorTextSecondary)
                }
                if habit.reminderFrequency != .never {
                    HStack(spacing: 4) {
                        Image(systemName: habit.reminderFrequency.icon)
                            .font(.system(size: 12))
                        Text(habit.reminderDaysDisplayName)
                            .font(NoorFont.caption)
                    }
                    .foregroundStyle(Color.noorTextSecondary)
                }
                Spacer()
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.noorTextSecondary)
                }
                .buttonStyle(.plain)
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.noorTextSecondary.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    Color.noorOrange.opacity(0.2),
                    Color.noorViolet.opacity(0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: NoorLayout.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: NoorLayout.cornerRadius)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Add Habit Sheet (title entry + Create/Replace) — bottom sheet, drag to dismiss
struct AddHabitModal: View {
    @Binding var habitTitle: String
    let onDismiss: () -> Void
    let onCreateHabit: () -> Void
    let onReplaceHabit: () -> Void

    @FocusState private var titleFocused: Bool

    private var canProceed: Bool {
        !habitTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Color.noorBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with seamless close
                HStack(alignment: .center) {
                    Text("Add a habit")
                        .font(NoorFont.title)
                        .foregroundStyle(.white)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.noorTextSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)

                VStack(alignment: .leading, spacing: 12) {
                    Text("What habit would you like to build?")
                        .font(NoorFont.body)
                        .foregroundStyle(Color.noorTextSecondary)
                    TextField("e.g. Put on my running shoes", text: $habitTitle)
                        .textFieldStyle(.plain)
                        .font(NoorFont.body)
                        .foregroundStyle(.white)
                        .padding(16)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .focused($titleFocused)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)

                VStack(spacing: 12) {
                    AddHabitOptionRow(
                        icon: "plus.circle.fill",
                        iconColor: canProceed ? Color.noorRoseGold : Color.noorTextSecondary.opacity(0.5),
                        title: "Create a habit",
                        subtitle: "Start a new habit that will have remarkable results.",
                        action: onCreateHabit
                    )
                    .opacity(canProceed ? 1 : 0.5)
                    .allowsHitTesting(canProceed)

                    AddHabitOptionRow(
                        icon: "arrow.triangle.2.circlepath",
                        iconColor: canProceed ? Color.noorTextSecondary : Color.noorTextSecondary.opacity(0.5),
                        title: "Replace a bad habit",
                        subtitle: "Swap a bad habit for a good one.",
                        action: onReplaceHabit
                    )
                    .opacity(canProceed ? 1 : 0.5)
                    .allowsHitTesting(canProceed)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            titleFocused = true
        }
    }
}

struct AddHabitOptionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(iconColor)
                    .frame(width: 44, height: 44)
                    .background(iconColor.opacity(0.2))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(NoorFont.title2)
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorTextSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.noorRoseGold.opacity(0.8))
            }
            .frame(minHeight: 76)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
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

// MARK: - Add / Edit Microhabit Form (links to goal, focus duration)
struct AddMicrohabitView: View {
    @Environment(DataManager.self) private var dataManager
    let initialType: MicrohabitType
    var initialTitle: String = ""  // title from modal; if provided, skip title section
    let goals: [Goal]
    var existing: Microhabit?
    let onDismiss: () -> Void
    let onSave: () -> Void

    @State private var title: String
    @State private var habitDescription = ""
    @State private var selectedGoalID: String?
    @State private var customTag = ""
    @State private var timeframe: HabitTimeframe = .anytime
    @State private var habitTime: Date? = nil  // preferred time of day (hour/minute); nil = not set
    @State private var showHabitTimeSheet = false
    @State private var focusMinutes: Int = 5
    @State private var reminderFrequency: HabitReminderFrequency = .never
    @State private var reminderDays: Set<Int> = []  // 0 = Sun … 6 = Sat; at least 1 when reminder on
    @State private var reminderTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var isSaving = false

    private static let weekdayLetters = ["S", "M", "T", "W", "T", "F", "S"]  // Sun–Sat

    init(
        initialType: MicrohabitType,
        initialTitle: String = "",
        goals: [Goal],
        existing: Microhabit? = nil,
        onDismiss: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) {
        self.initialType = initialType
        self.initialTitle = initialTitle
        self.goals = goals
        self.existing = existing
        self.onDismiss = onDismiss
        self.onSave = onSave
        // Initialize title from existing habit or from modal input
        _title = State(initialValue: existing?.title ?? initialTitle)
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
                    VStack(alignment: .leading, spacing: 24) {
                        // Title section: only when editing; new habits get title from the initial popup
                        if existing != nil {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Habit title")
                                    .font(NoorFont.title2)
                                    .foregroundStyle(.white)
                                TextField("e.g. Put on my running shoes", text: $title)
                                    .textFieldStyle(.plain)
                                    .font(NoorFont.body)
                                    .foregroundStyle(.white)
                                    .padding(16)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            }
                        }

                        // Description: notes-app style (no cell border, just text)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How it supports your grander vision")
                                .font(NoorFont.title2)
                                .foregroundStyle(.white)
                            TextField("I will ... so that I can become ...", text: $habitDescription, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(NoorFont.body)
                                .foregroundStyle(.white)
                                .lineLimit(3...10)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("Link to a journey")
                                    .font(NoorFont.title2)
                                    .foregroundStyle(.white)
                                Text("(optional)")
                                    .font(NoorFont.caption)
                                    .foregroundStyle(.white)
                            }
                            Text("Connect this habit to one of your visions or goals.")
                                .font(NoorFont.caption)
                                .foregroundStyle(Color.noorTextSecondary)
                            Picker("Journey", selection: $selectedGoalID) {
                                Text("None").tag(nil as String?)
                                ForEach(goals, id: \.id) { goal in
                                    Text(goal.destination.isEmpty ? goal.title : goal.destination)
                                        .lineLimit(1)
                                        .tag(goal.id.uuidString as String?)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(.white)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Habit time")
                                .font(NoorFont.title2)
                                .foregroundStyle(.white)
                            Button {
                                showHabitTimeSheet = true
                            } label: {
                                HStack {
                                    if let t = habitTime {
                                        Text(Self.habitTimeFormatter.string(from: t))
                                            .font(NoorFont.body)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.white)
                                    } else {
                                        Text("Set time")
                                            .font(NoorFont.body)
                                            .foregroundStyle(Color.noorTextSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.noorTextSecondary)
                                }
                                .padding(16)
                                .background(Color.white.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
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
                            .presentationDetents([.medium, .large])
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Focus timer (minutes)")
                                .font(NoorFont.title2)
                                .foregroundStyle(.white)
                            Text("Preset or drag the slider for a custom duration.")
                                .font(NoorFont.caption)
                                .foregroundStyle(Color.noorTextSecondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(focusPresetOptions, id: \.self) { min in
                                        Button {
                                            focusMinutes = min
                                        } label: {
                                            Text("\(min) min")
                                                .font(NoorFont.callout)
                                                .foregroundStyle(focusMinutes == min ? .white : Color.noorTextSecondary)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                                .background(focusMinutes == min ? Color.noorViolet : Color.white.opacity(0.1))
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    Button {
                                        focusMinutes = 0
                                    } label: {
                                        Text("No timer")
                                            .font(NoorFont.callout)
                                            .foregroundStyle(focusMinutes == 0 ? .white : Color.noorTextSecondary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(focusMinutes == 0 ? Color.noorViolet : Color.white.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            if focusMinutes > 0 {
                                HStack(spacing: 12) {
                                    Slider(
                                        value: Binding(
                                            get: { Double(focusMinutes) },
                                            set: { focusMinutes = Int($0) }
                                        ),
                                        in: 1...60,
                                        step: 1
                                    )
                                    .tint(Color.noorViolet)
                                    Text("\(focusMinutes) min")
                                        .font(NoorFont.callout)
                                        .foregroundStyle(.white)
                                        .frame(width: 44, alignment: .trailing)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Send reminder")
                                    .font(NoorFont.title2)
                                    .foregroundStyle(.white)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { reminderFrequency != .never },
                                    set: {
                                        if $0 {
                                            reminderFrequency = .daily
                                            if reminderDays.isEmpty {
                                                reminderDays = [0, 1, 2, 3, 4, 5, 6]
                                            }
                                        } else {
                                            reminderFrequency = .never
                                            reminderDays = []
                                        }
                                    }
                                ))
                                .labelsHidden()
                                .tint(Color.noorRoseGold)
                            }
                            .padding(.vertical, 4)

                            if reminderFrequency != .never {
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("Repeat")
                                        .font(NoorFont.title2)
                                        .foregroundStyle(.white)
                                    Text("Choose at least 1 day")
                                        .font(NoorFont.caption)
                                        .foregroundStyle(Color.noorTextSecondary)
                                }
                                .padding(.top, 4)
                                HStack(spacing: 10) {
                                    ForEach(0..<7, id: \.self) { day in
                                        Button {
                                            if reminderDays.contains(day) {
                                                if reminderDays.count > 1 {
                                                    reminderDays.remove(day)
                                                }
                                            } else {
                                                reminderDays.insert(day)
                                            }
                                        } label: {
                                            Text(Self.weekdayLetters[day])
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(reminderDays.contains(day) ? .white : Color.noorTextSecondary)
                                                .frame(width: 40, height: 40)
                                                .background(reminderDays.contains(day) ? Color.noorViolet : Color.white.opacity(0.1))
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                Text("Remind at")
                                    .font(NoorFont.title2)
                                    .foregroundStyle(.white)
                                    .padding(.top, 8)
                                DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .tint(.white)
                                    .colorScheme(.dark)
                            }
                            Text("Choose whether and how often you'd like to be reminded of this habit.")
                                .font(NoorFont.caption)
                                .foregroundStyle(Color.noorTextSecondary)
                        }

                        Button {
                            saveHabit()
                        } label: {
                            Text(existing == nil ? "Add habit" : "Save changes")
                                .font(NoorFont.button)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(title.trimmingCharacters(in: .whitespaces).isEmpty ? Color.white.opacity(0.2) : Color.white.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: NoorLayout.cornerRadiusLarge))
                                .overlay(
                                    RoundedRectangle(cornerRadius: NoorLayout.cornerRadiusLarge)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .disabled(
                            title.trimmingCharacters(in: .whitespaces).isEmpty
                            || isSaving
                            || (reminderFrequency != .never && reminderDays.isEmpty)
                        )
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
                    Text(existing == nil ? (title.isEmpty ? "New microhabit" : title) : "Edit habit")
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
                    let hour = h.reminderHour ?? 9
                    let minute = h.reminderMinute ?? 0
                    reminderTime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? reminderTime
                } else if !initialTitle.isEmpty {
                    // New habit: use title from modal
                    title = initialTitle
                }
            }
        }
    }

    private func saveHabit() {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSaving = true

        Task {
            defer { isSaving = false }
            do {
                if let h = existing {
                    h.title = title.trimmingCharacters(in: .whitespaces)
                    h.habitDescription = habitDescription.trimmingCharacters(in: .whitespaces)
                    h.goalID = selectedGoalID
                    h.customTag = customTag.trimmingCharacters(in: .whitespaces).isEmpty ? nil : customTag.trimmingCharacters(in: .whitespaces)
                    h.timeframe = timeframe
                    h.habitHour = habitTime.map { calendar.component(.hour, from: $0) }
                    h.habitMinute = habitTime.map { calendar.component(.minute, from: $0) }
                    h.focusDurationMinutes = focusMinutes
                    h.reminderFrequency = reminderFrequency
                    h.reminderDays = reminderDays
                    h.reminderHour = calendar.component(.hour, from: reminderTime)
                    h.reminderMinute = calendar.component(.minute, from: reminderTime)
                    try await dataManager.saveContext()
                } else {
                    let habit = Microhabit(
                        title: title.trimmingCharacters(in: .whitespaces),
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
                        reminderHour: calendar.component(.hour, from: reminderTime),
                        reminderMinute: calendar.component(.minute, from: reminderTime)
                    )
                    try await dataManager.saveMicrohabit(habit)
                }
                await MainActor.run { onSave() }
            } catch {
                await MainActor.run { }
                // could set error state
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
                                .background(Color.noorViolet)
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
                            .foregroundStyle(Color.noorRoseGold)

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
                                    colors: [Color.noorRoseGold, Color.noorRoseGold.opacity(0.7)],
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
                                    .foregroundStyle(Color.noorRoseGold)

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
                                    .background(Color.noorRoseGold.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.noorRoseGold.opacity(0.5), lineWidth: 1)
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
                                        : Color.noorRoseGold.opacity(0.2)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            isRunning
                                                ? Color.white.opacity(0.2)
                                                : Color.noorRoseGold.opacity(0.5),
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
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
}

#if DEBUG
#Preview("Microhabits") {
    MicrohabitsView()
        .environment(DataManager.shared)
}
#endif
