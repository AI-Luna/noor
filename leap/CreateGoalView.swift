//
//  CreateGoalView.swift
//  leap
//
//  3-step modal: Category → Goal details → Micro-actions, then save. Pro-gated.
//

import SwiftUI
import SwiftData

// MARK: - Category model for selection
struct GoalCategoryItem: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color
}

private let goalCategories: [GoalCategoryItem] = [
    GoalCategoryItem(id: "Fitness", name: "Fitness", icon: "figure.run", color: Color(hex: "4ECDC4")),
    GoalCategoryItem(id: "Mindfulness", name: "Mindfulness", icon: "brain.head.profile", color: Color(hex: "9B59B6")),
    GoalCategoryItem(id: "Productivity", name: "Productivity", icon: "bolt.fill", color: Color(hex: "F39C12")),
    GoalCategoryItem(id: "Financial Habits", name: "Financial Habits", icon: "dollarsign.circle.fill", color: Color(hex: "27AE60")),
    GoalCategoryItem(id: "Parenthood", name: "Parenthood", icon: "heart.circle.fill", color: Color(hex: "E91E8C")),
    GoalCategoryItem(id: "Personal Growth", name: "Personal Growth", icon: "leaf.fill", color: Color(hex: "3498DB")),
]

// MARK: - Create Goal View
struct CreateGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataManager.self) private var dataManager
    @Environment(PurchaseManager.self) private var purchaseManager

    @State private var step: Int = 1
    @State private var selectedCategory: GoalCategoryItem?
    @State private var goalTitle: String = ""
    @State private var goalDescription: String = ""
    @State private var daysPerWeek: Int = 5
    @State private var tasks: [(title: String, description: String)] = [("", "")]
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showPaywall = false
    @State private var existingGoalCount = 0

    private let maxTasks = 3
    private let minTasks = 1

    var body: some View {
        NavigationStack {
            ZStack {
                stepGradient
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    stepIndicator
                    ScrollView {
                        Group {
                            switch step {
                            case 1: step1Category
                            case 2: step2Details
                            case 3: step3Tasks
                            default: EmptyView()
                            }
                        }
                        .padding(20)
                        .padding(.bottom, 24)
                    }

                    if let err = errorMessage {
                        Text(err)
                            .font(NoorFont.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal)
                    }

                    primaryButton
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .onAppear { loadGoalCount() }
            .sheet(isPresented: $showPaywall) {
                PaywallView(
                    onDismiss: { showPaywall = false },
                    proGateMessage: "Pro members can create unlimited goals"
                )
            }
        }
    }

    private var stepGradient: LinearGradient {
        switch step {
        case 1:
            LinearGradient(colors: [Color(red: 0.58, green: 0.2, blue: 0.8), Color(red: 0.2, green: 0.4, blue: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 2:
            LinearGradient(colors: [Color(hex: "1A535C"), Color(hex: "4ECDC4")], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            LinearGradient(colors: [Color(hex: "E91E8C"), Color(hex: "FF6B6B")], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { i in
                Capsule()
                    .fill(step >= i ? Color.white : Color.white.opacity(0.3))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    // MARK: - Step 1: Category
    private var step1Category: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Choose a category")
                .font(NoorFont.largeTitle)
                .foregroundStyle(.white)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(goalCategories) { cat in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedCategory = cat }
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 28))
                                .foregroundStyle(selectedCategory?.id == cat.id ? .white : cat.color)
                            Text(cat.name)
                                .font(NoorFont.caption)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(selectedCategory?.id == cat.id ? cat.color.opacity(0.9) : Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Step 2: Details
    private var step2Details: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Goal details")
                .font(NoorFont.largeTitle)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(NoorFont.callout)
                    .foregroundStyle(.white.opacity(0.9))
                TextField("e.g. Build a morning routine", text: $goalTitle)
                    .textFieldStyle(.plain)
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .foregroundStyle(Color.noorCharcoal)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Description (optional)")
                    .font(NoorFont.callout)
                    .foregroundStyle(.white.opacity(0.9))
                TextEditor(text: $goalDescription)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .frame(minHeight: 80)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .foregroundStyle(Color.noorCharcoal)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Days per week")
                    .font(NoorFont.callout)
                    .foregroundStyle(.white.opacity(0.9))
                Picker("", selection: $daysPerWeek) {
                    ForEach(1...7, id: \.self) { n in
                        Text("\(n) day\(n == 1 ? "" : "s")").tag(n)
                    }
                }
                .pickerStyle(.menu)
                .tint(.white)
            }
        }
    }

    // MARK: - Step 3: Tasks
    private var step3Tasks: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Daily micro-actions")
                .font(NoorFont.largeTitle)
                .foregroundStyle(.white)
            Text("Add 2–3 small tasks you’ll do each day.")
                .font(NoorFont.caption)
                .foregroundStyle(.white.opacity(0.9))

            ForEach(tasks.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    Text("Task \(index + 1)")
                        .font(NoorFont.callout)
                        .foregroundStyle(.white.opacity(0.9))
                    TextField("Task title", text: Binding(
                        get: { tasks.indices.contains(index) ? tasks[index].title : "" },
                        set: { newVal in
                            if tasks.indices.contains(index) {
                                tasks[index] = (newVal, tasks[index].description)
                            }
                        }
                    ))
                    .textFieldStyle(.plain)
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .foregroundStyle(Color.noorCharcoal)
                    TextField("Description (optional)", text: Binding(
                        get: { tasks.indices.contains(index) ? tasks[index].description : "" },
                        set: { newVal in
                            if tasks.indices.contains(index) {
                                tasks[index] = (tasks[index].title, newVal)
                            }
                        }
                    ))
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(Color.noorCharcoal)
                }
            }

            if tasks.count < maxTasks {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { tasks.append(("", "")) }
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add another task")
                    }
                    .font(NoorFont.callout)
                    .foregroundStyle(.white)
                }
                .padding(.top, 8)
            }
        }
    }

    private var primaryButton: some View {
        Group {
            if step == 1 {
                nextButton(title: "Next") { tryAdvanceFromStep1() }
            } else if step == 2 {
                nextButton(title: "Next") { advanceStep() }
            } else {
                nextButton(title: "Create Goal", isLoading: isSaving) { submitGoal() }
            }
        }
        .padding(20)
    }

    private func nextButton(title: String, isLoading: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                }
            }
            .font(NoorFont.title2)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.noorPink)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .disabled(isLoading)
        .buttonStyle(.plain)
    }

    private func loadGoalCount() {
        Task { @MainActor in
            do {
                let list = try await dataManager.fetchAllGoals()
                existingGoalCount = list.count
                if existingGoalCount >= 1 && !purchaseManager.isPro {
                    showPaywall = true
                }
            } catch {
                existingGoalCount = 0
            }
        }
    }

    private func tryAdvanceFromStep1() {
        errorMessage = nil
        guard selectedCategory != nil else {
            errorMessage = "Please select a category."
            return
        }
        if existingGoalCount >= 1 && !purchaseManager.isPro {
            showPaywall = true
            return
        }
        advanceStep()
    }

    private func advanceStep() {
        if step == 2 {
            guard !goalTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                errorMessage = "Please enter a goal title."
                return
            }
        }
        errorMessage = nil
        withAnimation(.easeInOut(duration: 0.3)) {
            step = min(step + 1, 3)
        }
    }

    private func submitGoal() {
        errorMessage = nil
        let trimmedTitle = goalTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Please enter a goal title."
            return
        }
        let filledTasks = tasks.map { ($0.title.trimmingCharacters(in: .whitespacesAndNewlines), $0.description.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.0.isEmpty }
        guard filledTasks.count >= minTasks else {
            errorMessage = "Add at least one task."
            return
        }

        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }
            do {
                let categoryName = selectedCategory?.name ?? "Personal Growth"
                let goal = Goal(
                    title: trimmedTitle,
                    goalDescription: goalDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                    category: categoryName,
                    targetDaysPerWeek: daysPerWeek
                )
                let goalID = goal.id.uuidString
                for (i, t) in filledTasks.enumerated() {
                    let task = DailyTask(
                        goalID: goalID,
                        title: t.0,
                        taskDescription: t.1,
                        order: i
                    )
                    task.goal = goal
                    goal.dailyTasks.append(task)
                }
                try await dataManager.saveGoal(goal)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    CreateGoalView()
        .environment(DataManager.shared)
        .environment(PurchaseManager.shared)
}
