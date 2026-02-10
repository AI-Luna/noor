//
//  OnboardingView.swift
//  leap
//
//  Cinematic 17-screen onboarding flow
//  "Travel agency for life" - luxury magazine aesthetic
//  Quotes trickled in by concept; destination split into 3 screens
//

import SwiftUI
import RevenueCat

// MARK: - Onboarding quotes (trickled in where they match the question/concept)
private enum OnboardingQuotes {
    static let welcome = "A journey of a thousand miles begins with a single step."
    static let travel = "The world is a book, and those who do not travel read only a page."
    static let attention = "What you focus on expands."
    static let neuroplasticity = "We are what we repeatedly do. Excellence is not an act, but a habit."
    static let dopamine = "Small wins are the key to lasting change."
    static let identity = "You are not trying to become her. You are already her."
    static let destination = "Where do you want to go? Name it."
    static let timeline = "A goal without a date is just a dream."
    static let story = "Why we do something matters more than what we do."
    static let writing = "Write it down. Make it real."
}

// MARK: - Main Onboarding Container
struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var currentScreen: Int = 1
    @State private var selectedCategory: GoalCategory?
    @State private var destination: String = ""
    @State private var timeline: String = ""
    @State private var userStory: String = ""
    @State private var userName: String = ""
    @State private var userGender: UserProfile.Gender = .woman
    @State private var generatedChallenges: [AIChallenge] = []
    @State private var boardingPass: String = ""
    @State private var isGenerating: Bool = false
    @State private var showPaywall: Bool = false

    @Environment(PurchaseManager.self) private var purchaseManager

    var body: some View {
        ZStack {
            // Background
            Color.noorBackground
                .ignoresSafeArea()

            // Screen content
            Group {
                switch currentScreen {
                case 1: splashScreen
                case 2: welcomeScreen
                case 3: travelAgencyScreen
                case 4: attentionScienceScreen
                case 5: neuroplasticityScienceScreen
                case 6: dopamineScienceScreen
                case 7: identityShiftScreen
                case 8: destinationSelectionScreen
                case 9: scienceAfterDestinationScreen
                case 10: destinationOnlyScreen
                case 11: timelineOnlyScreen
                case 12: storyOnlyScreen
                case 13: aiGenerationScreen
                case 14: itineraryRevealScreen
                case 15: genderSelectionScreen
                case 16: nameInputScreen
                case 17: paywallScreen
                default: splashScreen
                }
            }
            .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
    }

    // MARK: - Screen 1: Opening (Atoms-style: minimal, centered, slogan)
    private var splashScreen: some View {
        OnboardingCenteredLayout {
            VStack(spacing: 16) {
                // "Noor." with distinctive "o" (circle)
                HStack(spacing: 2) {
                    Text("N")
                        .font(NoorFont.hero)
                        .foregroundStyle(Color.noorTextPrimary)
                    ZStack {
                        Circle()
                            .fill(Color.noorTextPrimary)
                            .frame(width: 32, height: 32)
                        Text("o")
                            .font(NoorFont.hero)
                            .foregroundStyle(Color.noorBackground)
                    }
                    Text("or.")
                        .font(NoorFont.hero)
                        .foregroundStyle(Color.noorTextPrimary)
                }

                Text("Light your path.")
                    .font(NoorFont.bodyLarge)
                    .italic()
                    .foregroundStyle(Color.noorTextSecondary)
            }
        }
        .onAppear {
            hapticMedium()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentScreen = 2
                }
            }
        }
    }

    // MARK: - Screen 2: Welcome + Science Hook
    private var welcomeScreen: some View {
        OnboardingCenteredLayout {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                Text("Welcome to Noor")
                    .font(NoorFont.hero)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Light in Arabic")
                    .font(NoorFont.bodyLarge)
                    .foregroundStyle(Color.noorTextSecondary)
                    .multilineTextAlignment(.center)

                Rectangle()
                    .fill(Color.noorRoseGold.opacity(0.5))
                    .frame(width: 60, height: 1)
                    .padding(.vertical, 8)

                Text("Built on behavioral science, not motivation. Designed around how the brain builds habits—through attention, action, and reward.")
                    .font(NoorFont.body)
                    .foregroundStyle(Color.noorTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text(OnboardingQuotes.welcome)
                    .font(NoorFont.caption)
                    .italic()
                    .foregroundStyle(Color.noorRoseGold.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                }

                OnboardingButton(title: "Continue") {
                    hapticLight()
                    advanceScreen()
                }
            }
            .padding(NoorLayout.horizontalPadding)
        }
    }

    // MARK: - Screen 3: Travel Agency Metaphor
    private var travelAgencyScreen: some View {
        OnboardingCenteredLayout {
            VStack(spacing: 24) {
                Image(systemName: "airplane.departure")
                .font(.system(size: 64))
                .foregroundStyle(Color.noorRoseGold)

            VStack(spacing: 20) {
                Text("Think of us as your travel agency.")
                    .font(NoorFont.largeTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Not just for trips—for your entire life.")
                    .font(NoorFont.title2)
                    .foregroundStyle(Color.noorRoseGold)
                    .multilineTextAlignment(.center)

                Text("We don't help you dream. We book your flights. Career. Freedom. Adventures. The relationship. The salary.\n\nYou've already lived it in your mind. Now we're making it real.")
                    .font(NoorFont.body)
                    .foregroundStyle(Color.noorTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                Text(OnboardingQuotes.travel)
                    .font(NoorFont.caption)
                    .italic()
                    .foregroundStyle(Color.noorRoseGold.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                }

                OnboardingButton(title: "I'm ready") {
                    hapticStrong()
                    advanceScreen()
                }
            }
            .padding(NoorLayout.horizontalPadding)
        }
    }

    // MARK: - Screen 4: Attention Science (RAS)
    private var attentionScienceScreen: some View {
        OnboardingCenteredLayout {
            VStack(spacing: 24) {
                HStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 32))
                Image(systemName: "eye")
                    .font(.system(size: 32))
            }
            .foregroundStyle(Color.noorRoseGold)

            VStack(spacing: 20) {
                Text("Neuroscience shows the brain prioritizes what it sees repeatedly.")
                    .font(NoorFont.title)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .italic()

                Rectangle()
                    .fill(Color.noorRoseGold.opacity(0.5))
                    .frame(width: 60, height: 1)

                Text("Your Reticular Activating System filters millions of inputs. What you see daily becomes what your brain seeks.\n\nClear visual goals help your brain filter for opportunities that match your future.")
                    .font(NoorFont.body)
                    .foregroundStyle(Color.noorTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                Text(OnboardingQuotes.attention)
                    .font(NoorFont.caption)
                    .italic()
                    .foregroundStyle(Color.noorRoseGold.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                }

                OnboardingButton(title: "Next") {
                    hapticLight()
                    advanceScreen()
                }
            }
            .padding(NoorLayout.horizontalPadding)
        }
    }

    // MARK: - Screen 5: Neuroplasticity Science
    private var neuroplasticityScienceScreen: some View {
        OnboardingCenteredLayout {
            VStack(spacing: 24) {
                // Neural pathway visualization
            ZStack {
                ForEach(0..<5) { i in
                    Circle()
                        .stroke(Color.noorViolet.opacity(0.3), lineWidth: 2)
                        .frame(width: CGFloat(40 + i * 20), height: CGFloat(40 + i * 20))
                }
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.noorRoseGold)
            }

            VStack(spacing: 20) {
                Text("Small, consistent actions rewire neural pathways through neuroplasticity.")
                    .font(NoorFont.title)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .italic()

                Rectangle()
                    .fill(Color.noorRoseGold.opacity(0.5))
                    .frame(width: 60, height: 1)

                Text("Every micro-action you complete strengthens the pathway. Not through willpower. Through repetition.\n\nOne small step daily builds the person who lives that life.")
                    .font(NoorFont.body)
                    .foregroundStyle(Color.noorTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                Text(OnboardingQuotes.neuroplasticity)
                    .font(NoorFont.caption)
                    .italic()
                    .foregroundStyle(Color.noorRoseGold.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                }

                OnboardingButton(title: "Next") {
                    hapticLight()
                    advanceScreen()
                }
            }
            .padding(NoorLayout.horizontalPadding)
        }
    }

    // MARK: - Screen 6: Dopamine Science
    private var dopamineScienceScreen: some View {
        OnboardingCenteredLayout {
            VStack(spacing: 24) {
                // Sparkle burst
            ZStack {
                ForEach(0..<6) { i in
                    Image(systemName: "sparkle")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.noorRoseGold)
                        .offset(
                            x: cos(Double(i) * .pi / 3) * 40,
                            y: sin(Double(i) * .pi / 3) * 40
                        )
                }
                Image(systemName: "bolt.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.noorOrange)
            }

            VStack(spacing: 20) {
                Text("Each completed task releases dopamine, reinforcing motivation and focus.")
                    .font(NoorFont.title)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .italic()

                Rectangle()
                    .fill(Color.noorRoseGold.opacity(0.5))
                    .frame(width: 60, height: 1)

                Text("The brain repeats behaviors that feel rewarding. Small wins build momentum.\n\nWe celebrate every step—not because it's cute, but because your brain needs the signal.")
                    .font(NoorFont.body)
                    .foregroundStyle(Color.noorTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                Text(OnboardingQuotes.dopamine)
                    .font(NoorFont.caption)
                    .italic()
                    .foregroundStyle(Color.noorRoseGold.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                }

                OnboardingButton(title: "Next") {
                    hapticMedium()
                    advanceScreen()
                }
            }
            .padding(NoorLayout.horizontalPadding)
        }
    }

    // MARK: - Screen 7: Identity Shift
    private var identityShiftScreen: some View {
        OnboardingCenteredLayout {
            VStack(spacing: 24) {
                // Transformation visual
            HStack(spacing: 24) {
                Circle()
                    .stroke(Color.noorViolet.opacity(0.5), lineWidth: 2)
                    .frame(width: 50, height: 50)

                Image(systemName: "arrow.right")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.noorRoseGold)

                ZStack {
                    Circle()
                        .fill(Color.noorViolet.opacity(0.3))
                        .frame(width: 60, height: 60)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.noorRoseGold)
                }
            }

            VStack(spacing: 20) {
                Text("Every completed goal is evidence of the person you're becoming.")
                    .font(NoorFont.title)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .italic()

                Rectangle()
                    .fill(Color.noorRoseGold.opacity(0.5))
                    .frame(width: 60, height: 1)

                Text("You're not trying to become her.\nYou're already her.")
                    .font(NoorFont.title2)
                    .foregroundStyle(Color.noorAccent)
                    .multilineTextAlignment(.center)

                Text("These micro-actions are just proof. Progress builds identity. Identity drives lasting change.")
                    .font(NoorFont.body)
                    .foregroundStyle(Color.noorTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                Text(OnboardingQuotes.identity)
                    .font(NoorFont.caption)
                    .italic()
                    .foregroundStyle(Color.noorRoseGold.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                }

                OnboardingButton(title: "Next") {
                    hapticStrong()
                    advanceScreen()
                }
            }
            .padding(NoorLayout.horizontalPadding)
        }
    }

    // MARK: - Screen 8: Destination Selection (no scroll – button always visible)
    private var destinationSelectionScreen: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text("Let's book your first flight.")
                    .font(NoorFont.largeTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Where are you traveling first?")
                    .font(NoorFont.bodyLarge)
                    .foregroundStyle(Color.noorTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)

            VStack(spacing: 10) {
                ForEach(GoalCategory.allCases) { category in
                    CategorySelectionRow(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        hapticLight()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, 4)

            Spacer(minLength: 20)

            OnboardingButton(
                title: "Select one to start",
                isDisabled: selectedCategory == nil
            ) {
                hapticLight()
                advanceScreen()
            }
        }
        .padding(NoorLayout.horizontalPadding)
    }

    // MARK: - Screen 9: Science (after destination selection)
    private var scienceAfterDestinationScreen: some View {
        OnboardingCenteredLayout {
            VStack(spacing: 24) {
                Image(systemName: "pencil.and.list.clipboard")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.noorRoseGold)

                VStack(spacing: 12) {
                    Text("Why writing it down works.")
                        .font(NoorFont.title)
                        .foregroundStyle(Color.noorTextPrimary)
                        .multilineTextAlignment(.center)
                        .italic()

                    Rectangle()
                        .fill(Color.noorRoseGold.opacity(0.5))
                        .frame(width: 60, height: 1)

                    Text("Implementation intentions—\"When X, I will Y\"—activate the same brain regions as the action itself. Writing your destination and timeline turns a wish into a plan your brain can execute.")
                        .font(NoorFont.body)
                        .foregroundStyle(Color.noorTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Text(OnboardingQuotes.writing)
                        .font(NoorFont.caption)
                        .italic()
                        .foregroundStyle(Color.noorRoseGold.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }

                OnboardingButton(title: "Next") {
                    hapticLight()
                    advanceScreen()
                }
                .padding(.top, 8)
            }
            .padding(NoorLayout.horizontalPadding)
        }
    }

    // MARK: - Screen 10: Destination only (first of 3 “perfect destination” screens)
    private var destinationOnlyScreen: some View {
        OnboardingCenteredLayout {
            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    Text(selectedCategory?.travelAgencyTitle ?? "What's your perfect destination?")
                        .font(NoorFont.largeTitle)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    if selectedCategory == .travel {
                        Text("This trip you've been pinning about for years—where is it?")
                            .font(NoorFont.body)
                            .foregroundStyle(Color.noorTextSecondary)
                            .multilineTextAlignment(.center)
                    }

                    Text(OnboardingQuotes.destination)
                        .font(NoorFont.caption)
                        .italic()
                        .foregroundStyle(Color.noorRoseGold.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }

                TextField(selectedCategory?.destinationPlaceholder ?? "Your goal", text: $destination)
                    .textFieldStyle(.plain)
                    .font(NoorFont.body)
                    .foregroundStyle(.white)
                    .padding(20)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)

                OnboardingButton(title: "Next", isDisabled: destination.trimmingCharacters(in: .whitespaces).isEmpty) {
                    hapticLight()
                    advanceScreen()
                }
                .padding(.horizontal, NoorLayout.horizontalPadding)
            }
            .padding(NoorLayout.horizontalPadding)
        }
    }

    // MARK: - Screen 11: Timeline only (second of 3)
    private var timelineOnlyScreen: some View {
        OnboardingCenteredLayout {
            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    Text("When do you want to arrive?")
                        .font(NoorFont.largeTitle)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("A date makes it real.")
                        .font(NoorFont.body)
                        .foregroundStyle(Color.noorTextSecondary)
                        .multilineTextAlignment(.center)

                    Text(OnboardingQuotes.timeline)
                        .font(NoorFont.caption)
                        .italic()
                        .foregroundStyle(Color.noorRoseGold.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }

                TextField("e.g. June 2026", text: $timeline)
                    .textFieldStyle(.plain)
                    .font(NoorFont.body)
                    .foregroundStyle(.white)
                    .padding(20)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)

                OnboardingButton(title: "Next") {
                    hapticLight()
                    advanceScreen()
                }
                .padding(.horizontal, NoorLayout.horizontalPadding)
            }
            .padding(NoorLayout.horizontalPadding)
        }
    }

    // MARK: - Screen 12: Story only (third of 3) + Book my itinerary (no scroll – button always visible)
    private var storyOnlyScreen: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text(selectedCategory?.storyPrompt ?? "Why does this matter to you?")
                    .font(NoorFont.largeTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(OnboardingQuotes.story)
                    .font(NoorFont.caption)
                    .italic()
                    .foregroundStyle(Color.noorRoseGold.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 28)
            .padding(.bottom, 16)

            TextEditor(text: $userStory)
                .scrollContentBackground(.hidden)
                .font(NoorFont.body)
                .foregroundStyle(.white)
                .frame(height: 100)
                .padding(16)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer(minLength: 24)

            OnboardingButton(title: "Book my itinerary", isDisabled: destination.isEmpty) {
                hapticMedium()
                advanceScreen()
                generateItinerary()
            }
        }
        .padding(NoorLayout.horizontalPadding)
    }

    // MARK: - Screen 13: AI Generation Loading
    private var aiGenerationScreen: some View {
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
                    .multilineTextAlignment(.center)

                if !destination.isEmpty {
                    Text("Destination: \(destination)")
                        .font(NoorFont.body)
                        .foregroundStyle(Color.noorTextSecondary)
                        .multilineTextAlignment(.center)
                }

                Text("Building your 7-step itinerary")
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorRoseGold)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .onAppear {
            isGenerating = true
        }
    }

    // MARK: - Screen 14: Itinerary Reveal (scroll for list; primary button fixed at bottom so next step is obvious)
    private var itineraryRevealScreen: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: selectedCategory?.icon ?? "target")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.noorRoseGold)

                        Text("Your \(destination) Itinerary")
                            .font(NoorFont.largeTitle)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text("Departure: Now | Arrival: \(timeline.isEmpty ? "Your timeline" : timeline)")
                            .font(NoorFont.caption)
                            .foregroundStyle(Color.noorTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your 7-Step Boarding Process")
                            .font(NoorFont.title2)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)

                        ForEach(Array(generatedChallenges.enumerated()), id: \.element.id) { index, challenge in
                            ItineraryChallengeRow(
                                number: index + 1,
                                challenge: challenge,
                                isUnlocked: challenge.unlocked
                            )
                        }
                    }
                    .padding(.horizontal, 4)

                    if !boardingPass.isEmpty {
                        Text(boardingPass)
                            .font(NoorFont.body)
                            .foregroundStyle(Color.noorRoseGold)
                            .italic()
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 12)
                    }

                    Spacer().frame(height: 16)
                }
                .padding(NoorLayout.horizontalPadding)
            }
            .frame(maxHeight: .infinity)

            VStack(spacing: 10) {
                OnboardingButton(title: "Accept Itinerary") {
                    hapticStrong()
                    advanceScreen()
                }

                Button {
                    generateItinerary()
                    currentScreen = 13
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
            .padding(NoorLayout.horizontalPadding)
            .padding(.vertical, 16)
            .background(Color.noorBackground)
        }
    }

    // MARK: - Screen 15: Gender Selection
    private var genderSelectionScreen: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("Quick question for personalized recommendations:")
                .font(NoorFont.title)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                GenderButton(title: "Woman", isSelected: userGender == .woman) {
                    userGender = .woman
                }
                GenderButton(title: "Man", isSelected: userGender == .man) {
                    userGender = .man
                }
                GenderButton(title: "Non-binary", isSelected: userGender == .nonBinary) {
                    userGender = .nonBinary
                }
            }

            Spacer()

            OnboardingButton(title: "Continue") {
                hapticLight()
                advanceScreen()
            }
        }
        .padding(NoorLayout.horizontalPadding)
    }

    // MARK: - Screen 16: Name Input
    private var nameInputScreen: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Text("What should we call you?")
                    .font(NoorFont.largeTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                TextField("Your name", text: $userName)
                    .textFieldStyle(.plain)
                    .font(NoorFont.title)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(20)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text("We'll greet you each morning and track your journey.")
                    .font(NoorFont.body)
                    .foregroundStyle(Color.noorTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            OnboardingButton(
                title: "Continue",
                isDisabled: userName.trimmingCharacters(in: .whitespaces).isEmpty
            ) {
                hapticLight()
                advanceScreen()
            }
        }
        .padding(NoorLayout.horizontalPadding)
    }

    // MARK: - Screen 17: Paywall (scroll for plans; primary actions fixed at bottom so next step is obvious)
    private var paywallScreen: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.noorRoseGold)

                        Text("Your ticket is ready.")
                            .font(NoorFont.hero)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Rectangle()
                            .fill(Color.noorRoseGold.opacity(0.5))
                            .frame(width: 60, height: 1)
                    }
                    .padding(.top, 24)

                    OnboardingAnnualPlanCard {
                        purchaseAnnual()
                    }

                    OnboardingMonthlyPlanCard {
                        purchaseMonthly()
                    }

                    VStack(spacing: 8) {
                        Button("Restore Purchases") {
                            restorePurchases()
                        }
                        .font(NoorFont.callout)
                        .foregroundStyle(Color.noorTextSecondary)

                        Button("Skip for now") {
                            saveUserAndComplete()
                        }
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorTextSecondary.opacity(0.6))

                        HStack(spacing: 16) {
                            Button("Terms & Conditions") { }
                                .font(NoorFont.caption)
                                .foregroundStyle(Color.noorTextSecondary.opacity(0.7))

                            Button("Privacy Policy") { }
                                .font(NoorFont.caption)
                                .foregroundStyle(Color.noorTextSecondary.opacity(0.7))
                        }

                        Text("The woman who lives that life invests in herself.")
                            .font(NoorFont.caption)
                            .foregroundStyle(Color.noorTextSecondary.opacity(0.6))
                            .italic()
                            .padding(.top, 4)
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
                .padding(NoorLayout.horizontalPadding)
            }
            .frame(maxHeight: .infinity)
        }
    }

    // MARK: - Actions
    private func advanceScreen() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentScreen += 1
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
                if currentScreen == 13 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentScreen = 14
                    }
                }
            }
        }
    }

    private func purchaseAnnual() {
        Task {
            if let offerings = purchaseManager.currentOffering,
               let annual = offerings.availablePackages.first(where: { $0.packageType == .annual }) {
                let success = await purchaseManager.purchase(package: annual)
                if success {
                    saveUserAndComplete()
                }
            }
        }
    }

    private func purchaseMonthly() {
        Task {
            if let offerings = purchaseManager.currentOffering,
               let monthly = offerings.availablePackages.first(where: { $0.packageType == .monthly }) {
                let success = await purchaseManager.purchase(package: monthly)
                if success {
                    saveUserAndComplete()
                }
            }
        }
    }

    private func restorePurchases() {
        Task {
            await purchaseManager.restorePurchases()
            if purchaseManager.isPro {
                saveUserAndComplete()
            }
        }
    }

    private func saveUserAndComplete() {
        // Save user profile
        let profile = UserProfile(
            name: userName,
            gender: userGender,
            hasSubscription: true,
            subscriptionType: .annual,
            freeGoalsRemaining: 3,
            streak: 0,
            lastActionDate: nil,
            onboardingCompleted: true,
            createdAt: .now
        )

        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: StorageKey.userProfile)
        }

        // Save first goal data for creation
        let firstGoal: [String: Any] = [
            "category": selectedCategory?.rawValue ?? "travel",
            "destination": destination,
            "timeline": timeline,
            "userStory": userStory,
            "challenges": generatedChallenges.map { [
                "id": $0.id,
                "title": $0.title,
                "description": $0.description,
                "estimatedTime": $0.estimatedTime,
                "unlocked": $0.unlocked
            ] },
            "boardingPass": boardingPass
        ]

        if let data = try? JSONSerialization.data(withJSONObject: firstGoal) {
            UserDefaults.standard.set(data, forKey: StorageKey.firstGoalData)
        }

        UserDefaults.standard.set(userName, forKey: "userName")
        onComplete()
    }

    // MARK: - Haptics
    private func hapticLight() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func hapticMedium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func hapticStrong() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
}

// MARK: - Centered layout for onboarding (consistent alignment)
private struct OnboardingCenteredLayout<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack {
            Spacer()
            content()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Supporting Views

struct OnboardingButton: View {
    let title: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(NoorFont.button)
                .foregroundStyle(isDisabled ? Color.noorTextSecondary.opacity(0.6) : Color.noorTextPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: NoorLayout.buttonHeight)
                .background(Color.white.opacity(isDisabled ? 0.06 : 0.12))
                .clipShape(RoundedRectangle(cornerRadius: NoorLayout.cornerRadiusLarge))
                .overlay(
                    RoundedRectangle(cornerRadius: NoorLayout.cornerRadiusLarge)
                        .stroke(Color.white.opacity(isDisabled ? 0.15 : 0.3), lineWidth: 1)
                )
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
    }
}

struct CategorySelectionRow: View {
    let category: GoalCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: category.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? .white : Color.noorRoseGold)
                    .frame(width: 40)

                Text(category.displayName)
                    .font(NoorFont.body)
                    .foregroundStyle(isSelected ? .white : Color.noorTextSecondary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.noorSuccess)
                }
            }
            .padding(16)
            .background(isSelected ? Color.noorViolet.opacity(0.5) : Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

struct ItineraryChallengeRow: View {
    let number: Int
    let challenge: AIChallenge
    let isUnlocked: Bool

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? Color.noorViolet : Color.white.opacity(0.1))
                    .frame(width: 32, height: 32)

                if isUnlocked {
                    Text("\(number)")
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
                    .foregroundStyle(isUnlocked ? .white : Color.noorTextSecondary.opacity(0.5))

                if isUnlocked {
                    Text(challenge.description)
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorTextSecondary)
                        .lineLimit(2)

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

struct GenderButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(NoorFont.body)
                    .foregroundStyle(isSelected ? .white : Color.noorTextSecondary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.noorSuccess)
                }
            }
            .padding(16)
            .background(isSelected ? Color.noorViolet.opacity(0.5) : Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

private struct OnboardingAnnualPlanCard: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Annual Pass")
                    .font(NoorFont.title)
                    .foregroundStyle(Color.noorCharcoal)

                Spacer()

                Text("BEST VALUE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.noorSuccess)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("$39.99/year")
                    .font(NoorFont.largeTitle)
                    .foregroundStyle(Color.noorCharcoal)

                Text("Only $3.33/month")
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorSuccess)
            }

            VStack(alignment: .leading, spacing: 8) {
                OnboardingFeatureRow(text: "Board 3 flights immediately")
                OnboardingFeatureRow(text: "Unlimited destinations after")
                OnboardingFeatureRow(text: "Daily itinerary updates")
                OnboardingFeatureRow(text: "Progress tracking & proof")
            }

            Button(action: action) {
                Text("Purchase Annual Pass")
                    .font(NoorFont.button)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.noorAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.noorRoseGold, lineWidth: 2)
        )
    }
}

private struct OnboardingMonthlyPlanCard: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Monthly Pass")
                .font(NoorFont.title)
                .foregroundStyle(Color.noorCharcoal)

            Text("$14.99/month")
                .font(NoorFont.title2)
                .foregroundStyle(Color.noorCharcoal)

            OnboardingFeatureRow(text: "Unlimited flights immediately")

            Button(action: action) {
                Text("Purchase Monthly Pass")
                    .font(NoorFont.button)
                    .foregroundStyle(Color.noorViolet)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.noorViolet, lineWidth: 2)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

private struct OnboardingFeatureRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.noorSuccess)

            Text(text)
                .font(NoorFont.body)
                .foregroundStyle(Color.noorCharcoal)
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .environment(PurchaseManager.shared)
}
