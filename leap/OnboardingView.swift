//
//  OnboardingView.swift
//  leap
//
//  Cinematic onboarding flow with swipeable intro screens
//  "Travel agency for life" - luxury magazine aesthetic
//  Designed for visual impact and easy comprehension
//

import SwiftUI
import RevenueCat
import UserNotifications

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

// MARK: - Intro Page Model
private struct IntroPage: Identifiable {
    let id: Int
    let icon: String?
    let iconPair: (String, String)?
    let accentColor: Color
    let headline: String
    let subheadline: String?
    let body: [String]
    let quote: String?
}

// MARK: - Main Onboarding Container
struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var currentScreen: Int = 1
    @State private var introPage: Int = 0
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
    @State private var visibleChallengeCount: Int = 0
    
    // Splash animation states
    @State private var starOffset: CGSize = CGSize(width: -200, height: -300)
    @State private var starScale: CGFloat = 0.3
    @State private var starRotation: Double = -45
    @State private var backgroundIsDark: Bool = false
    @State private var starIsWhite: Bool = false
    @State private var showDarkOverlay: Bool = false
    @State private var darkOverlayOffset: CGFloat = -2000

    @Environment(PurchaseManager.self) private var purchaseManager
    
    // Intro pages data (swipeable carousel)
    private let introPages: [IntroPage] = [
        IntroPage(
            id: 0,
            icon: nil,
            iconPair: nil,
            accentColor: .noorRoseGold,
            headline: "Welcome to Noor",
            subheadline: "Light in Arabic",
            body: [
                "Built on behavioral science, not motivation.",
                "Designed around how the brain builds habits through attention, action, and reward."
            ],
            quote: OnboardingQuotes.welcome
        ),
        IntroPage(
            id: 1,
            icon: "airplane.departure",
            iconPair: nil,
            accentColor: .noorAccent,
            headline: "Think of us as your travel agency.",
            subheadline: "Not just for trips. For your entire life.",
            body: [
                "We don't help you dream.",
                "We book your flights.",
                "Career. Freedom. Adventures. The relationship. The salary.",
                "You've already lived it in your mind. Now we're making it real."
            ],
            quote: OnboardingQuotes.travel
        ),
        IntroPage(
            id: 2,
            icon: nil,
            iconPair: ("brain.head.profile", "eye"),
            accentColor: .noorViolet,
            headline: "Your brain prioritizes what it sees repeatedly.",
            subheadline: nil,
            body: [
                "Your Reticular Activating System filters millions of inputs.",
                "What you see daily becomes what your brain seeks.",
                "Clear visual goals help your brain filter for opportunities that match your future."
            ],
            quote: OnboardingQuotes.attention
        ),
        IntroPage(
            id: 3,
            icon: "point.3.connected.trianglepath.dotted",
            iconPair: nil,
            accentColor: .noorSuccess,
            headline: "Small, consistent actions rewire your brain.",
            subheadline: "Neuroplasticity in action.",
            body: [
                "Every micro-action you complete strengthens the pathway.",
                "Not through willpower. Through repetition.",
                "One small step daily builds the person who lives that life."
            ],
            quote: OnboardingQuotes.neuroplasticity
        ),
        IntroPage(
            id: 4,
            icon: "bolt.fill",
            iconPair: nil,
            accentColor: .noorOrange,
            headline: "Completed tasks release dopamine.",
            subheadline: "Reinforcing motivation and focus.",
            body: [
                "The brain repeats behaviors that feel rewarding.",
                "Small wins build momentum.",
                "We celebrate every step because your brain needs the signal."
            ],
            quote: OnboardingQuotes.dopamine
        ),
        IntroPage(
            id: 5,
            icon: "crown.fill",
            iconPair: nil,
            accentColor: .noorAccent,
            headline: "Every completed goal is evidence.",
            subheadline: "Of the person you're becoming.",
            body: [
                "You're not trying to become her.",
                "You're already her.",
                "These micro-actions are just proof. Progress builds identity."
            ],
            quote: OnboardingQuotes.identity
        )
    ]

    var body: some View {
        ZStack {
            Color.noorBackground
                .ignoresSafeArea()

            Group {
                switch currentScreen {
                case 1: splashScreen
                case 2: swipeableIntroScreen
                case 3: destinationSelectionScreen
                case 4: scienceAfterDestinationScreen
                case 5: OnboardingDestinationInputView(destination: $destination, selectedCategory: selectedCategory, onNext: { hapticLight(); advanceScreen() })
                case 6: OnboardingTimelineInputView(timeline: $timeline, onNext: { hapticLight(); advanceScreen() })
                case 7: OnboardingStoryInputView(userStory: $userStory, destination: destination, selectedCategory: selectedCategory, onNext: { hapticMedium(); advanceScreen(); generateItinerary() })
                case 8: aiGenerationScreen
                case 9: itineraryRevealScreen
                case 10: OnboardingNameInputView(userName: $userName, onNext: { hapticLight(); advanceScreen() })
                case 11: genderSelectionScreen
                case 12: paywallScreen
                default: splashScreen
                }
            }
            .id(currentScreen)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        }
        .animation(.easeInOut(duration: 0.35), value: currentScreen)
    }

    // MARK: - Screen 1: Splash with Shooting Star
    private var splashScreen: some View {
        ZStack {
            // Background - starts white, transitions to dark
            (backgroundIsDark ? Color.noorBackground : Color.white)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.4), value: backgroundIsDark)
            
            // Shooting star
            Image(systemName: "sparkle")
                .font(.system(size: 60, weight: .medium))
                .foregroundStyle(starIsWhite ? Color.white : Color.noorBackground)
                .scaleEffect(starScale)
                .rotationEffect(.degrees(starRotation))
                .offset(starOffset)
                .animation(.easeInOut(duration: 0.4), value: starIsWhite)
            
            // Dark overlay that slides down (for transition to next screen)
            if showDarkOverlay {
                Color.noorBackground
                    .ignoresSafeArea()
                    .offset(y: darkOverlayOffset)
            }
        }
        .onAppear {
            startSplashAnimation()
        }
    }
    
    private func startSplashAnimation() {
        hapticMedium()
        
        // Phase 1: Star flies in like a shooting star (0 - 0.8s)
        withAnimation(.easeOut(duration: 0.8)) {
            starOffset = .zero
            starScale = 1.0
            starRotation = 0
        }
        
        // Phase 2: Background goes dark, star turns white (0.8s - 1.2s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            hapticLight()
            withAnimation(.easeInOut(duration: 0.4)) {
                backgroundIsDark = true
                starIsWhite = true
            }
        }
        
        // Phase 3: Transition to Welcome screen (1.6s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            currentScreen = 2
        }
    }
    
    // MARK: - Screen 2: Swipeable Intro Carousel
    private var swipeableIntroScreen: some View {
        VStack(spacing: 0) {
            TabView(selection: $introPage) {
                // First page is special with typewriter animation
                TypewriterIntroPageView(onContinue: {
                    withAnimation { introPage = 1 }
                })
                .tag(0)
                
                // Rest of pages (starting from index 1)
                ForEach(introPages.dropFirst()) { page in
                    IntroPageView(page: page)
                        .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: introPage)
            
            // Bottom controls (only show after first page)
            if introPage > 0 {
                VStack(spacing: 20) {
                    // Page indicator (hide on final page)
                    if introPage < introPages.count - 1 {
                        HStack(spacing: 8) {
                            ForEach(0..<introPages.count, id: \.self) { index in
                                Capsule()
                                    .fill(index == introPage ? Color.noorAccent : Color.white.opacity(0.3))
                                    .frame(width: index == introPage ? 24 : 8, height: 8)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: introPage)
                            }
                        }
                    }

                    // Continue button - brighter on final screen
                    Button {
                        hapticLight()
                        if introPage < introPages.count - 1 {
                            withAnimation { introPage += 1 }
                        } else {
                            // Request notification permission before proceeding
                            requestNotificationPermission()
                            currentScreen = 3
                        }
                    } label: {
                        if introPage == introPages.count - 1 {
                            // Get Started - prominent button
                            HStack(spacing: 8) {
                                Text("Get Started")
                                    .font(NoorFont.button)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(Color.noorAccent)
                            .clipShape(Capsule())
                            .shadow(color: Color.noorAccent.opacity(0.6), radius: 20, x: 0, y: 4)
                        } else {
                            // Continue - subtle text link
                            HStack(spacing: 6) {
                                Text("Continue")
                                    .font(NoorFont.bodyLarge)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(Color.noorAccent)
                        }
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.3), value: introPage)
                }
                .padding(.bottom, 40)
                .transition(.opacity)
            }
        }
    }

    // MARK: - Screen 3: Destination Selection
    private var destinationSelectionScreen: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Let's book your first flight.")
                    .font(NoorFont.largeTitle)
                    .foregroundStyle(.white)

                Text("Where are you traveling first?")
                    .font(NoorFont.bodyLarge)
                    .foregroundStyle(Color.noorTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 28)

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
            
            Spacer()

            OnboardingTextButton(
                title: selectedCategory == nil ? "Select one to start" : "Continue",
                isDisabled: selectedCategory == nil
            ) {
                hapticLight()
                advanceScreen()
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, NoorLayout.horizontalPadding)
    }

    // MARK: - Screen 4: Science (after destination)
    private var scienceAfterDestinationScreen: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "pencil.and.list.clipboard")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.noorRoseGold)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Why writing it down works.")
                        .font(NoorFont.largeTitle)
                        .foregroundStyle(Color.noorTextPrimary)
                        .italic()

                    Rectangle()
                        .fill(Color.noorRoseGold.opacity(0.5))
                        .frame(width: 60, height: 2)

                    Text("Writing your goal turns a wish into a plan your brain can act on.")
                        .font(NoorFont.title2)
                        .foregroundStyle(Color.noorTextSecondary)

                    Text(OnboardingQuotes.writing)
                        .font(NoorFont.body)
                        .italic()
                        .foregroundStyle(Color.noorRoseGold)
                        .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()

            OnboardingTextButton(title: "Continue") {
                hapticLight()
                advanceScreen()
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, NoorLayout.horizontalPadding)
    }

    // MARK: - Screen 8: AI Generation Loading
    private var aiGenerationScreen: some View {
        VStack(spacing: 40) {
            Spacer()

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

                if !destination.isEmpty {
                    Text("Destination: \(destination)")
                        .font(NoorFont.body)
                        .foregroundStyle(Color.noorTextSecondary)
                }

                Text("Building your 7-step itinerary")
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorAccent)
            }

            Spacer()
        }
        .onAppear {
            isGenerating = true
        }
    }

    // MARK: - Screen 9: Itinerary Reveal
    private var itineraryRevealScreen: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header with white flight icon
                    VStack(spacing: 12) {
                        Image(systemName: "airplane")
                            .font(.system(size: 40))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(-45))

                        VStack(spacing: 4) {
                            Text("Your Flight to \(destination)")
                                .font(NoorFont.largeTitle)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("is now boarding")
                                .font(NoorFont.title)
                                .foregroundStyle(Color.noorAccent)
                        }

                        // Departure: Location → Arrival: Location with colors
                        HStack(spacing: 8) {
                            // Departure
                            HStack(spacing: 4) {
                                Text("Departure:")
                                    .font(NoorFont.caption)
                                    .foregroundStyle(Color.noorTextSecondary)
                                Text("Now")
                                    .font(NoorFont.callout)
                                    .foregroundStyle(Color.noorSuccess)
                                    .fontWeight(.semibold)
                            }
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.noorTextSecondary)
                            
                            // Arrival
                            HStack(spacing: 4) {
                                Text("Arrival:")
                                    .font(NoorFont.caption)
                                    .foregroundStyle(Color.noorTextSecondary)
                                Text(timeline.isEmpty ? "Your timeline" : timeline)
                                    .font(NoorFont.callout)
                                    .foregroundStyle(Color.noorAccent)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.top, 8)
                        
                        // Subtext - same color as Request New Route
                        if !boardingPass.isEmpty {
                            Text(boardingPass)
                                .font(NoorFont.callout)
                                .foregroundStyle(Color.noorTextSecondary)
                                .italic()
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.top, 24)

                    // 7 Steps with fade-in animation
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your 7-Step Journey")
                            .font(NoorFont.title2)
                            .foregroundStyle(.white)
                            .padding(.bottom, 4)
                        
                        ForEach(Array(generatedChallenges.enumerated()), id: \.element.id) { index, challenge in
                            ItineraryChallengeRow(
                                number: index + 1,
                                challenge: challenge,
                                isUnlocked: challenge.unlocked,
                                isFirstUnlocked: index == 0 && challenge.unlocked
                            )
                            .opacity(index < visibleChallengeCount ? 1 : 0)
                            .offset(y: index < visibleChallengeCount ? 0 : 10)
                            .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.15), value: visibleChallengeCount)
                        }
                    }
                    
                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, NoorLayout.horizontalPadding)
            }

            // Fixed bottom buttons
            VStack(spacing: 16) {
                // Big pink button with white text
                Button {
                    hapticStrong()
                    advanceScreen()
                } label: {
                    Text("Accept Itinerary")
                        .font(NoorFont.button)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: NoorLayout.buttonHeight)
                        .background(Color.noorAccent)
                        .clipShape(RoundedRectangle(cornerRadius: NoorLayout.cornerRadiusLarge))
                        .shadow(color: Color.noorAccent.opacity(0.4), radius: 12, x: 0, y: 4)
                }
                .buttonStyle(.plain)

                // Faint Request New Route
                Button {
                    // Reset to destination input screen so user can try again
                    destination = ""
                    timeline = ""
                    userStory = ""
                    generatedChallenges = []
                    visibleChallengeCount = 0
                    currentScreen = 5
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Request New Route")
                    }
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorTextSecondary.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, NoorLayout.horizontalPadding)
            .padding(.vertical, 12)
            .background(Color.noorBackground)
        }
        .onAppear {
            // Animate challenges fading in one by one
            visibleChallengeCount = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                visibleChallengeCount = generatedChallenges.count
            }
        }
    }

    // MARK: - Screen 10: Gender Selection
    private var genderSelectionScreen: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(alignment: .leading, spacing: 20) {
                Text("How do you identify?")
                    .font(NoorFont.title)
                    .foregroundStyle(.white)

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
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            OnboardingTextButton(title: "Continue") {
                hapticLight()
                advanceScreen()
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, NoorLayout.horizontalPadding)
    }

    // MARK: - Screen 12: Paywall
    private var annualPackage: RevenueCat.Package? {
        purchaseManager.currentOffering?.availablePackages.first { $0.packageType == .annual }
    }

    private var monthlyPackage: RevenueCat.Package? {
        purchaseManager.currentOffering?.availablePackages.first { $0.packageType == .monthly }
    }

    private var paywallScreen: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 12) {
                            Image(systemName: "airplane.departure")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.noorAccent)

                            Text("Your ticket is ready.")
                                .font(NoorFont.hero)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)

                            Rectangle()
                                .fill(Color.noorAccent.opacity(0.5))
                                .frame(width: 60, height: 1)
                        }
                        .padding(.top, 24)

                        OnboardingAnnualPlanCard(
                            priceString: annualPackage?.localizedPriceString ?? "$39.99",
                            action: { purchaseAnnual() }
                        )

                        OnboardingMonthlyPlanCard(
                            priceString: monthlyPackage?.localizedPriceString ?? "$14.99",
                            action: { purchaseMonthly() }
                        )

                        VStack(spacing: 8) {
                            Button("Restore Purchases") {
                                restorePurchases()
                            }
                            .font(NoorFont.callout)
                            .foregroundStyle(Color.noorTextSecondary)

                            if let error = purchaseManager.errorMessage {
                                Text(error)
                                    .font(NoorFont.caption)
                                    .foregroundStyle(Color.noorCoral)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }

                            Text("The woman who lives that life invests in herself.")
                                .font(NoorFont.caption)
                                .foregroundStyle(Color.noorTextSecondary.opacity(0.6))
                                .italic()
                                .padding(.top, 4)

                            Button("Skip for now") {
                                saveUserAndComplete()
                            }
                            .font(NoorFont.caption)
                            .foregroundStyle(Color.noorTextSecondary.opacity(0.6))
                            .padding(.top, 8)

                            HStack(spacing: 16) {
                                Button("Terms & Conditions") {
                                    if let url = URL(string: "https://noor-website-virid.vercel.app/terms/") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                    .font(NoorFont.caption)
                                    .foregroundStyle(Color.noorTextSecondary.opacity(0.7))

                                Button("Privacy Policy") {
                                    if let url = URL(string: "https://noor-website-virid.vercel.app/privacy/") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                    .font(NoorFont.caption)
                                    .foregroundStyle(Color.noorTextSecondary.opacity(0.7))
                            }
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    }
                    .padding(NoorLayout.horizontalPadding)
                }
            }

            // Loading overlay during purchase
            if purchaseManager.isLoading {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)
            }
        }
        .onAppear {
            if purchaseManager.currentOffering == nil {
                Task { await purchaseManager.loadOfferings() }
            }
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
                if currentScreen == 8 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentScreen = 9
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
        let profile = UserProfile(
            name: userName,
            gender: userGender,
            hasSubscription: purchaseManager.isPro,
            subscriptionType: purchaseManager.isPro ? .annual : nil,
            freeGoalsRemaining: purchaseManager.isPro ? 3 : 1,
            streak: 0,
            lastActionDate: nil,
            onboardingCompleted: true,
            createdAt: .now
        )

        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: StorageKey.userProfile)
        }

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
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func hapticMedium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func hapticStrong() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    
    // MARK: - Notifications
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
}

// MARK: - Typewriter Intro Page (First Page with Special Animation)
private struct TypewriterIntroPageView: View {
    let onContinue: () -> Void

    // Reveal animation states
    @State private var revealProgress: CGFloat = 0
    @State private var hasStartedTypewriter: Bool = false

    // Phase tracking
    // 0: Typing "Welcome to Noor"
    // 1: Deleting "Welcome to Noor"
    // 2: Typing "Built on "
    // 3: Typing "motivation"
    // 4: Strikethrough "motivation" (stays visible, crossed out)
    // 5: Typing "behavioral science." below
    // 6: Show rest of content
    @State private var phase: Int = 0

    // Text states
    @State private var welcomeText: String = ""
    @State private var builtOnText: String = ""
    @State private var motivationText: String = ""
    @State private var strikethroughProgress: CGFloat = 0
    @State private var motivationFaded: Bool = false
    @State private var behavioralScienceText: String = ""
    @State private var showCursor: Bool = true
    @State private var cursorTimer: Timer?

    // Content fade states
    @State private var subtextOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var dotsOpacity: Double = 0

    private let fullWelcome = "Welcome to Noor"
    private let builtOnFull = "Built on "
    private let motivationFull = "motivation."
    private let behavioralScienceFull = "behavioral science."

    var body: some View {
        GeometryReader { geo in
            ZStack {
                VStack(spacing: 0) {
                    Spacer()

                    // Main text area - fixed position, no layout shifts
                    VStack(alignment: .leading, spacing: 0) {
                        ZStack(alignment: .topLeading) {
                            // Phase 0-1: "Welcome to Noor" (same position as built-on text)
                            HStack(spacing: 0) {
                                Text(welcomeText)
                                    .font(NoorFont.hero)
                                    .foregroundStyle(.white)

                                if showCursor && hasStartedTypewriter && phase < 2 {
                                    Rectangle()
                                        .fill(Color.noorAccent)
                                        .frame(width: 3, height: 40)
                                }
                            }
                            .opacity(phase < 2 ? 1 : 0)

                            // Phase 2+: "Built on motivation" -> strikethrough -> "behavioral science."
                            VStack(alignment: .leading, spacing: 6) {
                                // Line 1: "Built on motivation." with strikethrough
                                HStack(spacing: 0) {
                                    Text(builtOnText)
                                        .font(NoorFont.largeTitle)
                                        .foregroundStyle(.white)

                                    // motivation typed then struck through
                                    if !motivationText.isEmpty {
                                        ZStack(alignment: .leading) {
                                            Text(motivationText)
                                                .font(NoorFont.largeTitle)
                                                .foregroundStyle(motivationFaded ? Color.noorTextSecondary.opacity(0.4) : .white)

                                            // Strikethrough line
                                            GeometryReader { textGeo in
                                                Rectangle()
                                                    .fill(Color.noorAccent)
                                                    .frame(width: textGeo.size.width * strikethroughProgress, height: 3)
                                                    .offset(y: textGeo.size.height / 2 - 1.5)
                                            }
                                        }
                                        .fixedSize()
                                    }

                                    // Cursor while typing "Built on " or "motivation"
                                    if showCursor && (phase == 2 || phase == 3) {
                                        Rectangle()
                                            .fill(Color.noorAccent)
                                            .frame(width: 3, height: 32)
                                    }
                                }

                                // Line 2: "behavioral science." typed in after strikethrough
                                HStack(spacing: 0) {
                                    Text(behavioralScienceText)
                                        .font(NoorFont.largeTitle)
                                        .foregroundStyle(Color.noorAccent)
                                        .fontWeight(.bold)

                                    if showCursor && phase == 5 {
                                        Rectangle()
                                            .fill(Color.noorAccent)
                                            .frame(width: 3, height: 32)
                                    }
                                }
                                .opacity(behavioralScienceText.isEmpty ? 0 : 1)
                            }
                            .opacity(phase >= 2 ? 1 : 0)
                        }

                        // Subtext - always in layout, opacity controlled
                        Text("Designed around how your brain builds habits through attention, action, and reward.")
                            .font(NoorFont.bodyLarge)
                            .foregroundStyle(Color.noorTextSecondary)
                            .multilineTextAlignment(.leading)
                            .opacity(subtextOpacity)
                            .padding(.top, 16)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, NoorLayout.horizontalPadding)

                    Spacer()

                    // Bottom controls
                    VStack(spacing: 20) {
                        HStack(spacing: 8) {
                            ForEach(0..<6, id: \.self) { index in
                                Capsule()
                                    .fill(index == 0 ? Color.noorAccent : Color.white.opacity(0.3))
                                    .frame(width: index == 0 ? 24 : 8, height: 8)
                            }
                        }
                        .opacity(dotsOpacity)

                        Button {
                            onContinue()
                        } label: {
                            HStack(spacing: 6) {
                                Text("Continue")
                                    .font(NoorFont.bodyLarge)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(Color.noorAccent)
                        }
                        .buttonStyle(.plain)
                        .opacity(buttonOpacity)
                    }
                    .padding(.bottom, 40)
                }
                .mask(
                    VStack(spacing: 0) {
                        Rectangle()
                            .frame(height: geo.size.height * revealProgress)
                        Spacer(minLength: 0)
                    }
                )
            }
        }
        .ignoresSafeArea()
        .onAppear {
            if !hasStartedTypewriter && revealProgress == 0 {
                startRevealAnimation()
            }
        }
        .onDisappear {
            cursorTimer?.invalidate()
        }
    }

    private func startRevealAnimation() {
        phase = 0
        welcomeText = ""
        builtOnText = ""
        motivationText = ""
        strikethroughProgress = 0
        motivationFaded = false
        behavioralScienceText = ""
        subtextOpacity = 0
        buttonOpacity = 0
        dotsOpacity = 0

        withAnimation(.easeOut(duration: 0.6)) {
            revealProgress = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            hasStartedTypewriter = true
            startCursorBlink()
            typeWelcome()
        }
    }

    private func startCursorBlink() {
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            if phase == 4 || phase >= 6 {
                showCursor = false
            } else {
                showCursor.toggle()
            }
        }
    }

    // Phase 0: Type "Welcome to Noor"
    private func typeWelcome() {
        guard phase == 0 else { return }
        for (index, _) in fullWelcome.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.12) {
                guard self.phase == 0 else { return }
                self.welcomeText = String(self.fullWelcome.prefix(index + 1))

                if index == self.fullWelcome.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        self.phase = 1
                        self.deleteWelcome()
                    }
                }
            }
        }
    }

    // Phase 1: Delete "Welcome to Noor"
    private func deleteWelcome() {
        guard phase == 1 else { return }
        for index in 0..<fullWelcome.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                guard self.phase == 1 else { return }
                let remaining = self.fullWelcome.count - index - 1
                self.welcomeText = String(self.fullWelcome.prefix(remaining))

                if remaining == 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        self.phase = 2
                        self.typeBuiltOn()
                    }
                }
            }
        }
    }

    // Phase 2: Type "Built on "
    private func typeBuiltOn() {
        guard phase == 2 else { return }
        for (index, _) in builtOnFull.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.12) {
                guard self.phase == 2 else { return }
                self.builtOnText = String(self.builtOnFull.prefix(index + 1))

                if index == self.builtOnFull.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        self.phase = 3
                        self.typeMotivation()
                    }
                }
            }
        }
    }

    // Phase 3: Type "motivation." character by character
    private func typeMotivation() {
        guard phase == 3 else { return }
        for (index, _) in motivationFull.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.10) {
                guard self.phase == 3 else { return }
                self.motivationText = String(self.motivationFull.prefix(index + 1))

                if index == self.motivationFull.count - 1 {
                    // Pause, then strikethrough
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        self.phase = 4
                        self.strikethroughMotivation()
                    }
                }
            }
        }
    }

    // Phase 4: Strike through "motivation." — it stays visible, just crossed out and faded
    private func strikethroughMotivation() {
        withAnimation(.easeInOut(duration: 0.5)) {
            strikethroughProgress = 1.0
        }

        // Fade the text after strikethrough completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.3)) {
                motivationFaded = true
            }
        }

        // Move to typing behavioral science
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            phase = 5
            typeBehavioralScience()
        }
    }

    // Phase 5: Type "behavioral science." character by character on the next line
    private func typeBehavioralScience() {
        guard phase == 5 else { return }
        for (index, _) in behavioralScienceFull.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.08) {
                guard self.phase == 5 else { return }
                self.behavioralScienceText = String(self.behavioralScienceFull.prefix(index + 1))

                if index == self.behavioralScienceFull.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.phase = 6
                        self.showFinalContent()
                    }
                }
            }
        }
    }

    // Phase 6: Show subtext and controls
    private func showFinalContent() {
        withAnimation(.easeOut(duration: 1.8)) {
            subtextOpacity = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.6)) {
                dotsOpacity = 1
                buttonOpacity = 1
            }
        }
    }
}

// MARK: - Intro Page View (for swipeable carousel)
private struct IntroPageView: View {
    let page: IntroPage
    @State private var headlineAppeared = false
    @State private var restAppeared = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                Spacer().frame(height: 40)
                
                // Icon - appears with headline
                Group {
                    if let icon = page.icon {
                        Image(systemName: icon)
                            .font(.system(size: 56))
                            .foregroundStyle(page.accentColor)
                    } else if let pair = page.iconPair {
                        HStack(spacing: 16) {
                            Image(systemName: pair.0)
                                .font(.system(size: 40))
                            Image(systemName: pair.1)
                                .font(.system(size: 40))
                        }
                        .foregroundStyle(page.accentColor)
                    }
                }
                .opacity(headlineAppeared ? 1 : 0)
                .offset(y: headlineAppeared ? 0 : 20)
                
                // Headline - appears first
                Text(page.headline)
                    .font(NoorFont.largeTitle)
                    .foregroundStyle(.white)
                    .opacity(headlineAppeared ? 1 : 0)
                    .offset(y: headlineAppeared ? 0 : 20)
                
                // Subheadline - fades in slowly after headline
                if let subheadline = page.subheadline {
                    Text(subheadline)
                        .font(NoorFont.title)
                        .foregroundStyle(page.accentColor)
                        .opacity(restAppeared ? 1 : 0)
                        .offset(y: restAppeared ? 0 : 15)
                }
                
                // Divider - fades in with rest
                Rectangle()
                    .fill(page.accentColor.opacity(0.5))
                    .frame(width: 60, height: 2)
                    .opacity(restAppeared ? 1 : 0)
                
                // Body text - fades in slowly, staggered
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(page.body.enumerated()), id: \.offset) { index, text in
                        Text(text)
                            .font(NoorFont.bodyLarge)
                            .foregroundStyle(Color.noorTextSecondary)
                            .opacity(restAppeared ? 1 : 0)
                            .offset(y: restAppeared ? 0 : 10)
                            .animation(.easeOut(duration: 0.6).delay(Double(index) * 0.15), value: restAppeared)
                    }
                }
                
                // Quote - fades in last
                if let quote = page.quote {
                    Text("\"\(quote)\"")
                        .font(NoorFont.body)
                        .italic()
                        .foregroundStyle(page.accentColor.opacity(0.9))
                        .padding(.top, 8)
                        .opacity(restAppeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.6).delay(0.6), value: restAppeared)
                }
                
                Spacer().frame(height: 120)
            }
            .padding(.horizontal, NoorLayout.horizontalPadding)
        }
        .onAppear {
            // Headline appears first with gentle fade
            withAnimation(.easeOut(duration: 0.7)) {
                headlineAppeared = true
            }
            // Rest fades in slowly after headline settles
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(.easeOut(duration: 1.0)) {
                    restAppeared = true
                }
            }
        }
        .onDisappear {
            headlineAppeared = false
            restAppeared = false
        }
    }
}

// MARK: - Text-input screens (extracted for performance)
private struct OnboardingDestinationInputView: View {
    @Binding var destination: String
    let selectedCategory: GoalCategory?
    let onNext: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(alignment: .leading, spacing: 16) {
                Text(selectedCategory?.travelAgencyTitle ?? "What's your perfect destination?")
                    .font(NoorFont.largeTitle)
                    .foregroundStyle(.white)
                
                if selectedCategory == .travel {
                    Text("This trip you've been pinning about for years. Where is it?")
                        .font(NoorFont.title)
                        .foregroundStyle(Color.noorTextSecondary)
                }
                
                Text(OnboardingQuotes.destination)
                    .font(NoorFont.title)
                    .italic()
                    .foregroundStyle(Color.noorRoseGold)
                    .padding(.top, 4)
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
                .focused($isFocused)
            
            Spacer()
            
            OnboardingTextButton(
                title: "Continue",
                isDisabled: destination.trimmingCharacters(in: .whitespaces).isEmpty,
                action: onNext
            )
            .padding(.bottom, 20)
        }
        .padding(.horizontal, NoorLayout.horizontalPadding)
        .onAppear { isFocused = true }
    }
}

private struct OnboardingTimelineInputView: View {
    @Binding var timeline: String
    let onNext: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(alignment: .leading, spacing: 16) {
                Text("When do you want to arrive?")
                    .font(NoorFont.largeTitle)
                    .foregroundStyle(.white)
                
                Text("A date makes it real.")
                        .font(NoorFont.title)
                        .foregroundStyle(Color.noorTextSecondary)
                
                Text(OnboardingQuotes.timeline)
                    .font(NoorFont.title)
                    .italic()
                    .foregroundStyle(Color.noorRoseGold)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 24)
            
            TextField("e.g. June 2026", text: $timeline)
                .textFieldStyle(.plain)
                .font(NoorFont.title)
                .foregroundStyle(.white)
                .tint(Color.noorAccent)
                .padding(20)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .focused($isFocused)
            
            Spacer()
            
            OnboardingTextButton(title: "Continue", action: onNext)
                .padding(.bottom, 20)
        }
        .padding(.horizontal, NoorLayout.horizontalPadding)
        .onAppear { isFocused = true }
    }
}

private struct OnboardingStoryInputView: View {
    @Binding var userStory: String
    let destination: String
    let selectedCategory: GoalCategory?
    let onNext: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(alignment: .leading, spacing: 16) {
                Text(selectedCategory?.storyPrompt ?? "Why does this matter to you?")
                    .font(NoorFont.largeTitle)
                    .foregroundStyle(.white)
                
                Text(OnboardingQuotes.story)
                    .font(NoorFont.title)
                    .italic()
                    .foregroundStyle(Color.noorRoseGold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 24)
            
            TextField("Share your story...", text: $userStory, axis: .vertical)
                .textFieldStyle(.plain)
                .font(NoorFont.title)
                .foregroundStyle(.white)
                .tint(Color.noorAccent)
                .lineLimit(1...6)
                .padding(20)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .focused($isFocused)
            
            Spacer()
            
            OnboardingTextButton(
                title: "Book my itinerary",
                isDisabled: destination.isEmpty,
                action: onNext
            )
            .padding(.bottom, 20)
        }
        .padding(.horizontal, NoorLayout.horizontalPadding)
        .onAppear { isFocused = true }
    }
}

private struct OnboardingNameInputView: View {
    @Binding var userName: String
    let onNext: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(alignment: .leading, spacing: 16) {
                Text("What's your name?")
                    .font(NoorFont.largeTitle)
                    .foregroundStyle(.white)
                
                Text("We'll greet you each morning and track your journey.")
                    .font(NoorFont.title)
                    .foregroundStyle(Color.noorTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 24)
            
            TextField("Your name", text: $userName)
                .textFieldStyle(.plain)
                .font(NoorFont.title)
                .foregroundStyle(.white)
                .tint(Color.noorAccent)
                .padding(20)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .focused($isFocused)
            
            Spacer()
            
            OnboardingTextButton(
                title: "Continue",
                isDisabled: userName.trimmingCharacters(in: .whitespaces).isEmpty,
                action: onNext
            )
            .padding(.bottom, 20)
        }
        .padding(.horizontal, NoorLayout.horizontalPadding)
        .onAppear { isFocused = true }
    }
}

// MARK: - Centered layout
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

// MARK: - OnboardingButton with neon pink glow when enabled
struct OnboardingButton: View {
    let title: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(NoorFont.button)
                .foregroundStyle(isDisabled ? Color.noorTextSecondary.opacity(0.5) : .white)
                .frame(maxWidth: .infinity)
                .frame(height: NoorLayout.buttonHeight)
                .background(isDisabled ? Color.white.opacity(0.06) : Color.noorAccent)
                .clipShape(RoundedRectangle(cornerRadius: NoorLayout.cornerRadiusLarge))
                .shadow(
                    color: isDisabled ? .clear : Color.noorAccent.opacity(0.5),
                    radius: isDisabled ? 0 : 16,
                    x: 0,
                    y: isDisabled ? 0 : 4
                )
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isDisabled)
    }
}

// MARK: - Text Link Style Button
private struct OnboardingTextButton: View {
    let title: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(NoorFont.bodyLarge)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(isDisabled ? Color.noorTextSecondary.opacity(0.5) : Color.noorAccent)
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isDisabled)
    }
}

// MARK: - Supporting Views
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
            .background(isSelected ? Color.noorAccent.opacity(0.3) : Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.noorAccent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ItineraryChallengeRow: View {
    let number: Int
    let challenge: AIChallenge
    let isUnlocked: Bool
    var isFirstUnlocked: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            // Number circle - green accent for first unlocked
            ZStack {
                Circle()
                    .fill(isFirstUnlocked ? Color.noorSuccess : (isUnlocked ? Color.white.opacity(0.15) : Color.white.opacity(0.08)))
                    .frame(width: 32, height: 32)

                if isUnlocked {
                    Text("\(number)")
                        .font(NoorFont.callout)
                        .fontWeight(isFirstUnlocked ? .bold : .regular)
                        .foregroundStyle(isFirstUnlocked ? .white : Color.noorTextPrimary)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.noorTextSecondary.opacity(0.4))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.title)
                    .font(NoorFont.body)
                    .fontWeight(isFirstUnlocked ? .semibold : .regular)
                    .foregroundStyle(isUnlocked ? .white : Color.noorTextSecondary.opacity(0.5))

                if isUnlocked {
                    Text(challenge.description)
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorTextSecondary)
                        .lineLimit(2)

                    Text(challenge.estimatedTime)
                        .font(NoorFont.caption)
                        .foregroundStyle(isFirstUnlocked ? Color.noorSuccess : Color.noorTextSecondary.opacity(0.7))
                }
            }

            Spacer()
            
            // Green arrow for first unlocked step
            if isFirstUnlocked {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.noorSuccess)
            }
        }
        .padding(14)
        .background(isFirstUnlocked ? Color.noorSuccess.opacity(0.1) : Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFirstUnlocked ? Color.noorSuccess.opacity(0.3) : Color.clear, lineWidth: 1)
        )
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
            .background(isSelected ? Color.noorAccent.opacity(0.3) : Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.noorAccent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct OnboardingAnnualPlanCard: View {
    let priceString: String
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
                Text("\(priceString)/year")
                    .font(NoorFont.largeTitle)
                    .foregroundStyle(Color.noorCharcoal)
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
                .stroke(Color.noorAccent, lineWidth: 2)
        )
    }
}

private struct OnboardingMonthlyPlanCard: View {
    let priceString: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Monthly Pass")
                .font(NoorFont.title)
                .foregroundStyle(Color.noorCharcoal)

            Text("\(priceString)/month")
                .font(NoorFont.title2)
                .foregroundStyle(Color.noorCharcoal)

            OnboardingFeatureRow(text: "Unlimited flights immediately")

            Button(action: action) {
                Text("Purchase Monthly Pass")
                    .font(NoorFont.button)
                    .foregroundStyle(Color.noorAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.noorAccent, lineWidth: 2)
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
