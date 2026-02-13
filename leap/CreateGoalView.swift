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
    @State private var departure: String = ""
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
    
    @FocusState private var isTextFieldFocused: Bool

    // Total steps: 1=category, 2=destination, 3=timeline, 4=departure, 5=story, 6=loading, 7=itinerary
    private let totalSteps = 7

    var body: some View {
        NavigationStack {
            ZStack {
                Color.noorBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Step indicator
                    HStack(spacing: 8) {
                        ForEach(1...totalSteps, id: \.self) { i in
                            Capsule()
                                .fill(step >= i ? Color.noorAccent : Color.white.opacity(0.2))
                                .frame(height: 4)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, NoorLayout.horizontalPadding)
                    .padding(.top, 12)

                    // Content
                    Group {
                        switch step {
                        case 1: stepCategorySelection
                        case 2: stepDestination
                        case 3: stepTimeline
                        case 4: stepDeparture
                        case 5: stepStory
                        case 6: stepLoading
                        case 7: stepItinerary
                        default: EmptyView()
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .animation(.easeInOut(duration: 0.3), value: step)
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

    // MARK: - Step 1: Category Selection
    private var stepCategorySelection: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                Text("Every journey has a destination.")
                    .font(NoorFont.largeTitle)
                    .foregroundStyle(.white)

                Text("Where are you headed first?")
                    .font(NoorFont.title)
                    .foregroundStyle(Color.noorTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 32)

            VStack(spacing: 12) {
                ForEach(GoalCategory.allCases) { category in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: category.icon)
                                .font(.system(size: 24))
                                .foregroundStyle(selectedCategory == category ? .white : Color.noorAccent)
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

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation { step = 2 }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedCategory == nil ? "Select one to start" : "Continue")
                        .font(NoorFont.button)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(selectedCategory == nil ? Color.noorTextSecondary : .white)
            }
            .buttonStyle(.plain)
            .disabled(selectedCategory == nil)
            .padding(.bottom, 20)
        }
        .padding(.horizontal, NoorLayout.horizontalPadding)
    }

    // MARK: - Step 2: Destination
    private var stepDestination: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                Text(selectedCategory?.travelAgencyTitle ?? "What's your destination?")
                    .font(NoorFont.largeTitle)
                    .foregroundStyle(.white)

                Text("Be specific. The clearer the destination, the better we can map your route.")
                    .font(NoorFont.title)
                    .foregroundStyle(Color.noorTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 24)

            TextField(selectedCategory?.destinationPlaceholder ?? "Your goal", text: $destination)
                .textFieldStyle(.plain)
                .font(NoorFont.title)
                .foregroundStyle(.white)
                .tint(Color.noorAccent)
                .padding(20)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .focused($isTextFieldFocused)

            Spacer()

            continueButton(disabled: destination.trimmingCharacters(in: .whitespaces).isEmpty) {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation { step = 3 }
                }
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, NoorLayout.horizontalPadding)
        .onAppear { isTextFieldFocused = true }
    }

    // MARK: - Step 3: Timeline
    private var stepTimeline: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                Text("When do you want to arrive?")
                    .font(NoorFont.largeTitle)
                    .foregroundStyle(.white)

                Text("A date makes it real.")
                    .font(NoorFont.title)
                    .foregroundStyle(Color.noorTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 24)

            TextField("e.g. June 2026, End of summer, 6 months", text: $timeline)
                .textFieldStyle(.plain)
                .font(NoorFont.title)
                .foregroundStyle(.white)
                .tint(Color.noorAccent)
                .padding(20)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .focused($isTextFieldFocused)

            Spacer()

            continueButton(disabled: timeline.trimmingCharacters(in: .whitespaces).isEmpty) {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation { step = 4 }
                }
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, NoorLayout.horizontalPadding)
        .onAppear { isTextFieldFocused = true }
    }

    // MARK: - Step 4: Departure
    private var stepDeparture: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                Text("Where are you departing from?")
                    .font(NoorFont.largeTitle)
                    .foregroundStyle(.white)

                Text("The mindset, situation, or place you're leaving behind.")
                    .font(NoorFont.title)
                    .foregroundStyle(Color.noorTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 24)

            TextField("e.g. Overthinking, 9-to-5, Square one", text: $departure)
                .textFieldStyle(.plain)
                .font(NoorFont.title)
                .foregroundStyle(.white)
                .tint(Color.noorAccent)
                .padding(20)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .focused($isTextFieldFocused)

            Spacer()

            continueButton(disabled: departure.trimmingCharacters(in: .whitespaces).isEmpty) {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation { step = 5 }
                }
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, NoorLayout.horizontalPadding)
        .onAppear { isTextFieldFocused = true }
    }

    // MARK: - Step 5: Story / Why
    private var stepStory: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                Text(selectedCategory?.storyPrompt ?? "Why does this matter to you?")
                    .font(NoorFont.largeTitle)
                    .foregroundStyle(.white)

                Text("Your reason is your fuel. Share what drives you.")
                    .font(NoorFont.title)
                    .foregroundStyle(Color.noorTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 24)

            TextField("Share your story...", text: $userStory, axis: .vertical)
                .textFieldStyle(.plain)
                .font(NoorFont.title)
                .foregroundStyle(.white)
                .tint(Color.noorAccent)
                .lineLimit(4...8)
                .padding(20)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .focused($isTextFieldFocused)

            Spacer()

            continueButton(disabled: userStory.trimmingCharacters(in: .whitespaces).isEmpty) {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation { step = 6 }
                }
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, NoorLayout.horizontalPadding)
        .onAppear { isTextFieldFocused = true }
    }

    // MARK: - Continue Button (onboarding style)
    private func continueButton(disabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 6) {
                Text("Continue")
                    .font(NoorFont.button)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(disabled ? Color.noorTextSecondary : .white)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    // MARK: - Step 6: Loading
    private var stepLoading: some View {
        VStack(spacing: 40) {
            Spacer()

            // Boarding pass visual
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 280, height: 160)

                VStack(spacing: 12) {
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.noorAccent)
                        .rotationEffect(.degrees(-15))

                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(Color.noorAccent)
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
                    .foregroundStyle(Color.noorAccent)
            }

            Spacer()
        }
        .onAppear {
            isGenerating = true
            generateItinerary()
        }
    }

    // MARK: - Step 7: Itinerary Reveal
    private var stepItinerary: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: selectedCategory?.icon ?? "target")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.noorAccent)

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
                                        .foregroundStyle(Color.noorAccent)
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
                        .foregroundStyle(Color.noorAccent)
                        .italic()
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 8)
                }

                // Accept button
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    saveGoal()
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Accept Itinerary")
                        }
                    }
                    .font(NoorFont.button)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.noorAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(.plain)
                .disabled(isSaving)

                // Regenerate button
                Button {
                    withAnimation { step = 6 }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Request New Route")
                    }
                    .font(NoorFont.callout)
                    .foregroundStyle(Color.noorTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, NoorLayout.horizontalPadding)
            .padding(.vertical, 20)
        }
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
                    step = 7
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
                    departure: departure,
                    destination: destination,
                    timeline: timeline,
                    userStory: userStory,
                    boardingPass: boardingPass,
                    targetDaysPerWeek: 7
                )

                let goalID = goal.id.uuidString
                let startDate = Calendar.current.startOfDay(for: Date())
                for (index, challenge) in generatedChallenges.enumerated() {
                    let challengeDueDate = Calendar.current.date(byAdding: .day, value: index + 1, to: startDate)
                    let task = DailyTask(
                        goalID: goalID,
                        title: challenge.title,
                        taskDescription: challenge.description,
                        estimatedTime: challenge.estimatedTime,
                        order: index,
                        isUnlocked: index == 0,
                        dueDate: challengeDueDate,
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
