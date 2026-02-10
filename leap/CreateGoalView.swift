//
//  CreateGoalView.swift
//  leap
//
//  Goal creation with AI-generated itinerary
//  "Travel agency for life" - book your flight to the future
//

import SwiftUI
import SwiftData

// MARK: - Create Goal View
struct CreateGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataManager.self) private var dataManager
    @Environment(PurchaseManager.self) private var purchaseManager

    @State private var step: Int = 1
    @State private var selectedCategory: GoalCategory?
    @State private var destination: String = ""
    @State private var timeline: String = ""
    @State private var userStory: String = ""
    @State private var generatedChallenges: [AIChallenge] = []
    @State private var boardingPass: String = ""
    @State private var isGenerating = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showPaywall = false
    @State private var existingGoalCount = 0

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.noorBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    stepIndicator
                    ScrollView {
                        Group {
                            switch step {
                            case 1: step1Category
                            case 2: step2Details
                            case 3: step3Loading
                            case 4: step4Itinerary
                            default: EmptyView()
                            }
                        }
                        .padding(20)
                        .padding(.bottom, 24)
                    }

                    if let err = errorMessage {
                        Text(err)
                            .font(NoorFont.caption)
                            .foregroundStyle(Color.noorCoral)
                            .padding(.horizontal)
                    }

                    if step != 3 {
                        primaryButton
                    }
                }
            }
            .navigationTitle("Book a Flight")
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
                    proGateMessage: "Unlock unlimited flights with Pro"
                )
            }
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(1...4, id: \.self) { i in
                Capsule()
                    .fill(step >= i ? Color.noorRoseGold : Color.white.opacity(0.2))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    // MARK: - Step 1: Category Selection
    private var step1Category: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Let's book your next flight.")
                    .font(NoorFont.largeTitle)
                    .foregroundStyle(.white)

                Text("Where are you traveling?")
                    .font(NoorFont.bodyLarge)
                    .foregroundStyle(Color.noorTextSecondary)
            }

            VStack(spacing: 12) {
                ForEach(GoalCategory.allCases) { category in
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: category.icon)
                                .font(.system(size: 24))
                                .foregroundStyle(selectedCategory == category ? .white : Color.noorRoseGold)
                                .frame(width: 40)

                            Text(category.displayName)
                                .font(NoorFont.body)
                                .foregroundStyle(selectedCategory == category ? .white : Color.noorTextSecondary)

                            Spacer()

                            if selectedCategory == category {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.noorSuccess)
                            }
                        }
                        .padding(16)
                        .background(selectedCategory == category ? Color.noorViolet.opacity(0.5) : Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Step 2: Destination Details
    private var step2Details: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(selectedCategory?.travelAgencyTitle ?? "Tell us more")
                    .font(NoorFont.largeTitle)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Destination")
                    .font(NoorFont.callout)
                    .foregroundStyle(Color.noorTextSecondary)

                TextField(selectedCategory?.destinationPlaceholder ?? "Your goal", text: $destination)
                    .textFieldStyle(.plain)
                    .font(NoorFont.body)
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("When are you arriving?")
                    .font(NoorFont.callout)
                    .foregroundStyle(Color.noorTextSecondary)

                TextField("June 2026", text: $timeline)
                    .textFieldStyle(.plain)
                    .font(NoorFont.body)
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(selectedCategory?.storyPrompt ?? "Why does this matter to you?")
                    .font(NoorFont.callout)
                    .foregroundStyle(Color.noorTextSecondary)

                TextEditor(text: $userStory)
                    .scrollContentBackground(.hidden)
                    .font(NoorFont.body)
                    .foregroundStyle(.white)
                    .frame(minHeight: 100)
                    .padding(16)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Step 3: AI Generation Loading
    private var step3Loading: some View {
        VStack(spacing: 40) {
            Spacer().frame(height: 60)

            // Boarding pass visual
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 280, height: 160)

                VStack(spacing: 12) {
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.noorRoseGold)
                        .rotationEffect(.degrees(-15))

                    HStack(spacing: 8) {
                        ForEach(0..<3) { i in
                            Circle()
                                .fill(Color.noorRoseGold)
                                .frame(width: 8, height: 8)
                                .opacity(isGenerating ? 1 : 0.3)
                                .animation(
                                    .easeInOut(duration: 0.5)
                                    .repeatForever()
                                    .delay(Double(i) * 0.2),
                                    value: isGenerating
                                )
                        }
                    }
                }
            }

            VStack(spacing: 16) {
                Text("Mapping your route...")
                    .font(NoorFont.title)
                    .foregroundStyle(.white)

                Text("Destination: \(destination)")
                    .font(NoorFont.body)
                    .foregroundStyle(Color.noorTextSecondary)

                Text("Building your 7-step itinerary")
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorRoseGold)
            }

            Spacer()
        }
        .onAppear {
            isGenerating = true
            generateItinerary()
        }
    }

    // MARK: - Step 4: Itinerary Reveal
    private var step4Itinerary: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: selectedCategory?.icon ?? "target")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.noorRoseGold)

                Text("Your \(destination) Itinerary")
                    .font(NoorFont.largeTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Departure: Now | Arrival: \(timeline.isEmpty ? "Your timeline" : timeline)")
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorTextSecondary)
            }

            // Challenges list
            VStack(alignment: .leading, spacing: 12) {
                Text("Your 7-Step Boarding Process")
                    .font(NoorFont.title2)
                    .foregroundStyle(.white)

                ForEach(Array(generatedChallenges.enumerated()), id: \.element.id) { index, challenge in
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(challenge.unlocked ? Color.noorViolet : Color.white.opacity(0.1))
                                .frame(width: 32, height: 32)

                            if challenge.unlocked {
                                Text("\(index + 1)")
                                    .font(NoorFont.callout)
                                    .foregroundStyle(.white)
                            } else {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.noorTextSecondary.opacity(0.5))
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(challenge.title)
                                .font(NoorFont.body)
                                .foregroundStyle(challenge.unlocked ? .white : Color.noorTextSecondary.opacity(0.5))

                            if challenge.unlocked {
                                Text(challenge.estimatedTime)
                                    .font(NoorFont.caption)
                                    .foregroundStyle(Color.noorRoseGold)
                            }
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            // Boarding pass message
            if !boardingPass.isEmpty {
                Text(boardingPass)
                    .font(NoorFont.body)
                    .foregroundStyle(Color.noorRoseGold)
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 8)
            }

            // Regenerate button
            Button {
                step = 3
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Request New Route")
                }
                .font(NoorFont.callout)
                .foregroundStyle(Color.noorTextSecondary)
            }
        }
    }

    private var primaryButton: some View {
        Group {
            switch step {
            case 1:
                actionButton(title: "Next", isDisabled: selectedCategory == nil) {
                    tryAdvanceFromStep1()
                }
            case 2:
                actionButton(title: "Book my itinerary", isDisabled: destination.isEmpty) {
                    advanceToGeneration()
                }
            case 4:
                actionButton(title: "Accept Itinerary", isLoading: isSaving) {
                    saveGoal()
                }
            default:
                EmptyView()
            }
        }
        .padding(20)
    }

    private func actionButton(title: String, isDisabled: Bool = false, isLoading: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                }
            }
            .font(NoorFont.button)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(isDisabled ? Color.noorAccent.opacity(0.4) : Color.noorAccent)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .disabled(isDisabled || isLoading)
        .buttonStyle(.plain)
    }

    // MARK: - Actions
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
            errorMessage = "Please select a destination."
            return
        }
        if existingGoalCount >= 1 && !purchaseManager.isPro {
            showPaywall = true
            return
        }
        withAnimation(.easeInOut(duration: 0.3)) {
            step = 2
        }
    }

    private func advanceToGeneration() {
        guard !destination.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter a destination."
            return
        }
        errorMessage = nil
        withAnimation(.easeInOut(duration: 0.3)) {
            step = 3
        }
    }

    private func generateItinerary() {
        Task {
            guard let category = selectedCategory else { return }

            let result = await AIService.shared.generateChallenges(
                category: category,
                destination: destination,
                timeline: timeline,
                userStory: userStory
            )

            await MainActor.run {
                if let result = result {
                    generatedChallenges = result.challenges
                    boardingPass = result.encouragement
                }
                isGenerating = false
                withAnimation(.easeInOut(duration: 0.3)) {
                    step = 4
                }
            }
        }
    }

    private func saveGoal() {
        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }
            do {
                guard let category = selectedCategory else { return }

                let goal = Goal(
                    title: destination,
                    goalDescription: userStory,
                    category: category.rawValue,
                    destination: destination,
                    timeline: timeline,
                    userStory: userStory,
                    boardingPass: boardingPass,
                    targetDaysPerWeek: 7
                )

                let goalID = goal.id.uuidString
                for (index, challenge) in generatedChallenges.enumerated() {
                    let task = DailyTask(
                        goalID: goalID,
                        title: challenge.title,
                        taskDescription: challenge.description,
                        estimatedTime: challenge.estimatedTime,
                        order: index,
                        isUnlocked: index == 0,
                        goal: goal
                    )
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
