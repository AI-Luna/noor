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

struct MicrohabitsView: View {
    @Environment(DataManager.self) private var dataManager
    @State private var microhabits: [Microhabit] = []
    @State private var goals: [Goal] = []
    @State private var isLoading = true
    @State private var showAddHabitModal = false
    @State private var showAddForm = false
    @State private var selectedHabitType: MicrohabitType = .create
    @State private var habitToEdit: Microhabit?
    @State private var showEditSheet = false
    @State private var habitForTimer: Microhabit?
    @State private var errorMessage: String?
    @State private var selectedScienceLesson: HabitScienceLesson?

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
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            scienceOfHabitsSection

                            if microhabits.isEmpty {
                                emptyState
                            } else {
                                habitsGroupedByTimeframe
                            }
                        }
                        .padding(20)
                        .padding(.bottom, 100)
                    }
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            showAddHabitModal = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                                )
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
                        Image(systemName: "leaf.fill")
                            .foregroundStyle(Color.noorRoseGold)
                        Text("Habits")
                            .font(.system(size: 20, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                    }
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
                    onDismiss: { showAddHabitModal = false },
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
                .presentationDetents([.height(360)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAddForm) {
                AddMicrohabitView(
                    initialType: selectedHabitType,
                    goals: goals,
                    onDismiss: {
                        showAddForm = false
                        loadData()
                    },
                    onSave: {
                        showAddForm = false
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
            .overlay {
                if let lesson = selectedScienceLesson {
                    HabitScienceLessonPopover(
                        lesson: lesson,
                        allLessons: HabitScienceLesson.allLessons,
                        onSelectLesson: { selectedScienceLesson = $0 },
                        onDismiss: { selectedScienceLesson = nil }
                    )
                }
            }
        }
    }

    private var habitsGroupedByTimeframe: some View {
        let order = HabitTimeframe.displayOrder
        return VStack(alignment: .leading, spacing: 16) {
            ForEach(order, id: \.self) { timeframe in
                let habitsInSlot = microhabits.filter { $0.timeframe == timeframe }
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

    // MARK: - Science of micro habits (daily lesson card only; "More to read" is inside popover)
    private var scienceOfHabitsSection: some View {
        let daily = HabitScienceLesson.dailyLesson

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.noorRoseGold)
                Text("Science of micro habits")
                    .font(NoorFont.title)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            HabitScienceLessonCard(lesson: daily, onTap: { selectedScienceLesson = daily }, showTag: false)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.noorViolet.opacity(0.14))
        .overlay(
            Rectangle()
                .fill(Color.noorRoseGold.opacity(0.5))
                .frame(width: 4),
            alignment: .leading
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(Color.noorRoseGold.opacity(0.8))

            VStack(spacing: 8) {
                Text("Reorient and rebuild")
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorRoseGold)
                    .multilineTextAlignment(.center)

                Text("Small steps, big change")
                    .font(NoorFont.title)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Add habits that support your grander vision. Use the focus timer to stay present.")
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

// Centered pop-over: same card scheme as Add Habit modal, tighter padding
struct HabitScienceLessonPopover: View {
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
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                // Header with X close (matches Add Habit modal)
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 2)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(lesson.title)
                            .font(NoorFont.title)
                            .foregroundStyle(.white)

                        Text(lesson.fullText)
                            .font(NoorFont.body)
                            .foregroundStyle(Color.noorTextSecondary)

                        if !otherLessons.isEmpty {
                            Text("More to read")
                                .font(NoorFont.callout)
                                .foregroundStyle(Color.noorRoseGold)
                                .padding(.top, 8)

                            VStack(spacing: 6) {
                                ForEach(otherLessons) { other in
                                    Button {
                                        onSelectLesson(other)
                                    } label: {
                                        HStack(spacing: 10) {
                                            Text(other.title)
                                                .font(NoorFont.body)
                                                .foregroundStyle(.white)
                                                .multilineTextAlignment(.leading)
                                                .lineLimit(2)
                                            Spacer()
                                            Image(systemName: "arrow.right")
                                                .font(.system(size: 14))
                                                .foregroundStyle(Color.noorRoseGold.opacity(0.8))
                                        }
                                        .padding(12)
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: 300, maxHeight: 420)
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(hex: "1E1B4B").opacity(0.98))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.noorRoseGold.opacity(0.4), lineWidth: 1.5)
                    )
            )
            .padding(.horizontal, 16)
            .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 12)
        }
    }
}

struct HabitScienceLessonSheet: View {
    let lesson: HabitScienceLesson
    let onDismiss: () -> Void

    var body: some View {
        HabitScienceLessonPopover(
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
                        Text(habit.reminderFrequency.displayName)
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

// MARK: - Add Habit Modal (Create a habit / Replace a bad habit) — card style so it stands out
struct AddHabitModal: View {
    let onDismiss: () -> Void
    let onCreateHabit: () -> Void
    let onReplaceHabit: () -> Void

    var body: some View {
        ZStack {
            // Dimmed app background so the card reads as an overlay
            Color.noorBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .padding(.top, 14)
                }

                VStack(spacing: 20) {
                    HStack(spacing: 8) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.noorRoseGold)
                        Text("Add a habit")
                            .font(NoorFont.title)
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 4)

                    VStack(spacing: 12) {
                        AddHabitOptionRow(
                            icon: "plus.circle.fill",
                            iconColor: Color.noorRoseGold,
                            title: "Create a habit",
                            subtitle: "Start a new habit that will have remarkable results.",
                            action: onCreateHabit
                        )

                        AddHabitOptionRow(
                            icon: "arrow.triangle.2.circlepath",
                            iconColor: Color.noorTextSecondary,
                            title: "Replace a bad habit",
                            subtitle: "Redirect the time and energy towards a good habit instead.",
                            action: onReplaceHabit
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(hex: "1E1B4B").opacity(0.98))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.noorRoseGold.opacity(0.4), lineWidth: 1.5)
                    )
            )
            .padding(.horizontal, 16)
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
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(iconColor)
                    .frame(width: 48, height: 48)
                    .background(iconColor.opacity(0.2))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(NoorFont.title2)
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(NoorFont.body)
                        .foregroundStyle(Color.noorTextSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.noorRoseGold.opacity(0.8))
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

// MARK: - Add / Edit Microhabit Form (links to goal, focus duration)
struct AddMicrohabitView: View {
    @Environment(DataManager.self) private var dataManager
    let initialType: MicrohabitType
    let goals: [Goal]
    var existing: Microhabit?
    let onDismiss: () -> Void
    let onSave: () -> Void

    @State private var title = ""
    @State private var habitDescription = ""
    @State private var selectedGoalID: String?
    @State private var customTag = ""
    @State private var timeframe: HabitTimeframe = .anytime
    @State private var focusMinutes: Int = 5
    @State private var reminderFrequency: HabitReminderFrequency = .never
    @State private var reminderTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var isSaving = false

    private let focusOptions = [5, 10, 15, 20, 25, 30]
    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ZStack {
                Color.noorBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Habit title")
                                .font(NoorFont.title2)
                                .foregroundStyle(.white)
                            TextField("e.g. Put on my running shoes", text: $title)
                                .textFieldStyle(.plain)
                                .font(NoorFont.body)
                                .foregroundStyle(.white)
                                .padding(16)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("How it supports your grander vision")
                                .font(NoorFont.title2)
                                .foregroundStyle(.white)
                            TextField("I will ... so that I can become ...", text: $habitDescription, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(NoorFont.body)
                                .foregroundStyle(.white)
                                .lineLimit(3...6)
                                .padding(16)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("When")
                                .font(NoorFont.title2)
                                .foregroundStyle(.white)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(HabitTimeframe.displayOrder, id: \.self) { slot in
                                        Button {
                                            timeframe = slot
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: slot.icon)
                                                    .font(.system(size: 14))
                                                Text(slot.displayName)
                                                    .font(NoorFont.callout)
                                            }
                                            .foregroundStyle(timeframe == slot ? .white : Color.noorTextSecondary)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(timeframe == slot ? Color.noorViolet : Color.white.opacity(0.1))
                                            .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Link to a journey (optional)")
                                .font(NoorFont.title2)
                                .foregroundStyle(.white)
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
                            Text("Custom label (optional)")
                                .font(NoorFont.title2)
                                .foregroundStyle(.white)
                            Text("Your own category to group or filter habits, e.g. Health, Morning routine.")
                                .font(NoorFont.caption)
                                .foregroundStyle(Color.noorTextSecondary)
                            TextField("e.g. Health, Morning routine", text: $customTag)
                                .textFieldStyle(.plain)
                                .font(NoorFont.body)
                                .foregroundStyle(.white)
                                .padding(16)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
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
                                    ForEach(focusOptions, id: \.self) { min in
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
                            Text("Remind me")
                                .font(NoorFont.title2)
                                .foregroundStyle(.white)
                            VStack(spacing: 8) {
                                ForEach(HabitReminderFrequency.allCases, id: \.self) { freq in
                                    Button {
                                        reminderFrequency = freq
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: freq.icon)
                                                .font(.system(size: 18))
                                                .foregroundStyle(reminderFrequency == freq ? Color.noorRoseGold : Color.noorTextSecondary)
                                                .frame(width: 28, alignment: .center)
                                            Text(freq.displayName)
                                                .font(NoorFont.body)
                                                .foregroundStyle(.white)
                                            Spacer()
                                            if reminderFrequency == freq {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 18))
                                                    .foregroundStyle(Color.noorRoseGold)
                                            }
                                        }
                                        .padding(14)
                                        .background(reminderFrequency == freq ? Color.noorViolet.opacity(0.25) : Color.white.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(reminderFrequency == freq ? Color.noorRoseGold.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            if reminderFrequency != .never {
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
                            Text("Choose how often you'd like to be reminded of this habit.")
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
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
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
                    Button("Cancel") {
                        onDismiss()
                    }
                    .foregroundStyle(Color.noorTextSecondary)
                }
                ToolbarItem(placement: .principal) {
                    Text(existing == nil ? "New microhabit" : "Edit habit")
                        .font(NoorFont.title2)
                        .foregroundStyle(.white)
                }
            }
            .onAppear {
                if let h = existing {
                    title = h.title
                    habitDescription = h.habitDescription
                    selectedGoalID = h.goalID
                    customTag = h.customTag ?? ""
                    timeframe = h.timeframe
                    focusMinutes = h.focusDurationMinutes
                    reminderFrequency = h.reminderFrequency
                    let hour = h.reminderHour ?? 9
                    let minute = h.reminderMinute ?? 0
                    reminderTime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? reminderTime
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
                    h.focusDurationMinutes = focusMinutes
                    h.reminderFrequency = reminderFrequency
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
                        reminderFrequency: reminderFrequency,
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

// MARK: - Focus Timer (fullscreen countdown)
struct FocusTimerView: View {
    let habit: Microhabit
    let onDismiss: () -> Void

    @State private var remainingSeconds: Int = 0
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var hasCompleted = false

    var body: some View {
        ZStack {
            Color.noorBackground
                .ignoresSafeArea()

            VStack(spacing: 32) {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.noorTextSecondary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .padding(.top, 16)
                }

                Text(habit.title)
                    .font(NoorFont.title)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 8)
                        .frame(width: 220, height: 220)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.noorRoseGold, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 220, height: 220)
                        .rotationEffect(.degrees(-90))

                    Text(timeString)
                        .font(.system(size: 48, weight: .light, design: .rounded))
                        .foregroundStyle(.white)
                }

                if hasCompleted {
                    Text("Done! Great focus.")
                        .font(NoorFont.title2)
                        .foregroundStyle(Color.noorRoseGold)
                    Button("Close") {
                        onDismiss()
                    }
                    .font(NoorFont.button)
                    .foregroundStyle(.white)
                    .padding(.top, 8)
                } else {
                    HStack(spacing: 20) {
                        Button {
                            if isRunning {
                                timer?.invalidate()
                                timer = nil
                            } else {
                                startTimer()
                            }
                            isRunning.toggle()
                        } label: {
                            Text(isRunning ? "Pause" : "Start")
                                .font(NoorFont.button)
                                .foregroundStyle(.white)
                                .frame(width: 120, height: 52)
                                .background(Color.white.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
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
