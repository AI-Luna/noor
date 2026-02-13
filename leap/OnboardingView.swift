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
    @State private var departure: String = ""
    @State private var userName: String = ""
    @State private var userGender: UserProfile.Gender = .woman
    @State private var generatedChallenges: [AIChallenge] = []
    @State private var boardingPass: String = ""
    @State private var isGenerating: Bool = false
    @State private var showPaywall: Bool = false
    @State private var visibleChallengeCount: Int = 0
    @State private var showItineraryHeader: Bool = false
    @State private var showItineraryChallenges: Bool = false
    
    // Splash animation states
    @State private var starOffset: CGSize = CGSize(width: -200, height: -300)
    @State private var starScale: CGFloat = 0.3
    @State private var starRotation: Double = -45
    @State private var backgroundIsDark: Bool = false
    @State private var starIsWhite: Bool = false
    @State private var showDarkOverlay: Bool = false
    @State private var darkOverlayOffset: CGFloat = -2000
    @State private var showNoorText: Bool = false
    @State private var showSplashContinue: Bool = false

    @Environment(PurchaseManager.self) private var purchaseManager
    
    // Intro pages data (swipeable carousel) - "Show, don't tell" with app mockups
    // Pages with mockupType will render visual examples from the app
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
        // Page 1: Travel Agency - shows boarding pass mockup
        IntroPage(
            id: 1,
            icon: nil,
            iconPair: nil,
            accentColor: .noorAccent,
            headline: "Think of us as your travel agency.",
            subheadline: nil,
            body: [
                "You pick the destination.",
                "We plan the route."
            ],
            quote: nil
        ),
        // Page 2: Brain prioritizes - shows notification mockup
        IntroPage(
            id: 2,
            icon: nil,
            iconPair: nil,
            accentColor: .noorViolet,
            headline: "Your brain prioritizes what it sees repeatedly.",
            subheadline: nil,
            body: [
                "We keep your goals visible so your brain stays focused."
            ],
            quote: nil
        ),
        // Page 3: Dopamine - shows task completion mockup
        IntroPage(
            id: 3,
            icon: nil,
            iconPair: nil,
            accentColor: .noorSuccess,
            headline: "Completed tasks release dopamine.",
            subheadline: nil,
            body: [
                "Every checkmark signals progress. Your brain craves the next win."
            ],
            quote: nil
        ),
        // Page 4: Vision feature - reduce friction to take action
        IntroPage(
            id: 4,
            icon: nil,
            iconPair: nil,
            accentColor: .noorOrange,
            headline: "Reduce friction. Take action instantly.",
            subheadline: nil,
            body: [
                "Your vision board lives inside each journey.",
                "Pin a Pinterest board, save an Instagram profile, book a flight. Open any of them in one tap."
            ],
            quote: nil
        ),
        // Page 5: Passport - real vacation tracking
        IntroPage(
            id: 5,
            icon: nil,
            iconPair: nil,
            accentColor: .noorViolet,
            headline: "Your Noor Passport.",
            subheadline: nil,
            body: [
                "Beyond your dream life, keep tabs on the real places you\u{2019}ve traveled.",
                "Pin every vacation. Watch your world fill up."
            ],
            quote: OnboardingQuotes.travel
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
                case 7: OnboardingStoryInputView(userStory: $userStory, destination: destination, selectedCategory: selectedCategory, onNext: { hapticMedium(); advanceScreen() })
                case 8: OnboardingDepartureInputView(departure: $departure, onNext: { hapticLight(); advanceScreen() })
                case 9: OnboardingNameInputView(userName: $userName, onNext: {
                    hapticLight()
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        advanceScreen()
                        generateItinerary()
                    }
                })
                case 10: aiGenerationScreen
                case 11: itineraryRevealScreen
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

    // MARK: - Screen 1: Splash with Shooting Star + "Noor" fade-in
    private var splashScreen: some View {
        ZStack {
            // Background - starts white, transitions to dark
            (backgroundIsDark ? Color.noorBackground : Color.white)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.4), value: backgroundIsDark)
            
            // The star flies in to the center, then "Noor" fades in beside it
            // Using fixed layout so the star stays in place when text appears
            HStack(spacing: 8) {
                Image(systemName: "sparkle")
                    .font(.system(size: 22))
                    .foregroundStyle(starIsWhite ? Color.white : Color.noorBackground)
                    .scaleEffect(starScale)
                    .rotationEffect(.degrees(starRotation))
                    .animation(.easeInOut(duration: 0.4), value: starIsWhite)
                
                // "Noor" text fades in after star settles
                Text("Noor")
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .foregroundStyle(.white)
                    .opacity(showNoorText ? 1 : 0)
                    .animation(.easeIn(duration: 0.6), value: showNoorText)
            }
            // Entire HStack is offset initially, then animates to center
            .offset(starOffset)
            
            // Continue button + page dots at bottom (appear after "Noor" shows)
            VStack {
                Spacer()
                
                if showSplashContinue {
                    Button {
                        hapticLight()
                        introPage = 1
                        withAnimation(.easeInOut(duration: 0.5)) {
                            currentScreen = 2
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("Continue")
                                .font(NoorFont.onboardingBodyLarge)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 40)
                    .transition(.opacity)
                }
            }
        }
        .onAppear {
            startSplashAnimation()
        }
    }
    
    private func startSplashAnimation() {
        showNoorText = false
        showSplashContinue = false

        // Phase 1: Star flies in like a shooting star (0 - 0.8s)
        // Cascading haptics during flight
        hapticStrong() // Initial launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { hapticMedium() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { hapticMedium() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { hapticLight() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { hapticLight() }

        withAnimation(.easeOut(duration: 0.8)) {
            starOffset = .zero
            starScale = 1.0
            starRotation = 0
        }

        // Star lands — satisfying thud
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            hapticStrong()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { hapticMedium() }
        }

        // Phase 2: Background goes dark, star turns white (0.8s - 1.2s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            hapticLight()
            withAnimation(.easeInOut(duration: 0.4)) {
                backgroundIsDark = true
                starIsWhite = true
            }
        }

        // Phase 3: "Noor" text fades in beside star (1.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.easeIn(duration: 0.6)) {
                showNoorText = true
            }
        }

        // Phase 4: Show Continue button (2.3s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeOut(duration: 0.4)) {
                showSplashContinue = true
            }
        }
    }
    
    // MARK: - Screen 2: Swipeable Intro Carousel (Noor shown in splash, starts at page 1)
    private var swipeableIntroScreen: some View {
        VStack(spacing: 0) {
            TabView(selection: $introPage) {
                // Page 1: Built on motivation / behavioral science (Noor was already shown in splash)
                TypewriterIntroPageView(onContinue: {
                    withAnimation(.easeInOut(duration: 0.5)) { introPage = 2 }
                })
                .tag(1)
                .transition(.opacity)
                
                // Rest of pages (indices 2–5)
                ForEach(Array(introPages.dropFirst().enumerated()), id: \.element.id) { offset, page in
                    IntroPageView(page: page)
                        .tag(offset + 2)
                        .transition(.opacity)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.5), value: introPage)
            
            // Bottom controls — only show from "Travel Agency" page onwards (page 2+)
            if introPage >= 2 {
                let lastPage = introPages.count // final tag = 6
                VStack(spacing: 20) {
                    // Page indicator dots (hide on final page)
                    if introPage < lastPage {
                        HStack(spacing: 8) {
                            ForEach(2...lastPage, id: \.self) { index in
                                Capsule()
                                    .fill(index == introPage ? Color.white : Color.white.opacity(0.3))
                                    .frame(width: index == introPage ? 24 : 8, height: 8)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: introPage)
                            }
                        }
                    }

                    Button {
                        hapticLight()
                        if introPage < lastPage {
                            withAnimation(.easeInOut(duration: 0.5)) { introPage += 1 }
                        } else {
                            requestNotificationPermission()
                            withAnimation(.easeInOut(duration: 0.5)) {
                                currentScreen = 3
                            }
                        }
                    } label: {
                        if introPage == lastPage {
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
                            HStack(spacing: 6) {
                                Text("Continue")
                                    .font(NoorFont.onboardingBodyLarge)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.3), value: introPage)
                }
                .padding(.bottom, 40)
                .transition(.opacity.animation(.easeInOut(duration: 0.4)))
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
                    .font(NoorFont.onboardingBodyLarge)
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
                        .font(NoorFont.onboardingBody)
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

    // MARK: - Screen 8: AI Generation Loading (Personalized, flight-details vibe)
    @State private var loadingPhraseIndex: Int = 0
    @State private var loadingPhraseOpacity: Double = 0
    @State private var loadingCircleRotation: Double = 0

    private var loadingPhrases: [String] {
        var phrases: [String] = ["Personalizing your journey..."]
        if !destination.isEmpty {
            phrases.append("Destination: \(destination)")
        }
        if !timeline.isEmpty {
            phrases.append("Arrival: \(timeline)")
        }
        if !userStory.isEmpty {
            let excerpt = String(userStory.prefix(50))
            phrases.append("Your vision: \(excerpt)\(userStory.count > 50 ? "..." : "")")
        }
        if let cat = selectedCategory, !destination.isEmpty {
            phrases.append("Mapping your \(cat.shortName) route to \(destination)")
        } else if !destination.isEmpty {
            phrases.append("Mapping your route to \(destination)")
        }
        if !departure.isEmpty {
            phrases.append("From \(departure) to \(destination.isEmpty ? "your goal" : destination)")
        }
        if !userName.isEmpty {
            phrases.append("Crafting steps for \(userName)")
        }
        phrases.append("Analyzing your goals...")
        phrases.append("Building your boarding pass...")
        phrases.append("Preparing for takeoff...")
        return phrases
    }

    private var aiGenerationScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            // Personalized loading text above the circle — slow fade for each phrase
            VStack(spacing: 16) {
                Text("Loading your flight details")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .tracking(1.5)

                Text(loadingPhrases[min(loadingPhraseIndex, loadingPhrases.count - 1)])
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(minHeight: 54)
                    .opacity(loadingPhraseOpacity)
                    .id(loadingPhraseIndex)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)

            // Large centered loading circle
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 4)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(
                        LinearGradient(
                            colors: [Color.noorAccent, Color.noorAccent.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(loadingCircleRotation))

                Image(systemName: "airplane")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.noorAccent.opacity(0.9))
            }
            .frame(width: 120, height: 120)

            Spacer()

            // Bottom hint
            Text("Your itinerary is almost ready")
                .font(NoorFont.onboardingCaption)
                .foregroundStyle(Color.noorTextSecondary.opacity(0.7))
                .padding(.bottom, 48)
        }
        .onAppear {
            isGenerating = true
            loadingPhraseIndex = 0
            loadingPhraseOpacity = 0

            // Slow fade-in for first phrase
            withAnimation(.easeIn(duration: 1.2)) {
                loadingPhraseOpacity = 1
            }

            // Rotate loading arc continuously
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                loadingCircleRotation = 360
            }

            // Cycle through personalized phrases with slow fade
            let phrases = loadingPhrases
            for i in 1..<phrases.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 2.0) {
                    guard isGenerating else { return }
                    withAnimation(.easeOut(duration: 0.4)) {
                        loadingPhraseOpacity = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        loadingPhraseIndex = min(i, phrases.count - 1)
                        withAnimation(.easeIn(duration: 1.0)) {
                            loadingPhraseOpacity = 1
                        }
                    }
                }
            }
        }
    }

    // MARK: - Screen 9: Itinerary Reveal
    private var itineraryRevealScreen: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Boarding pass on top with real user info
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "airplane")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color(white: 0.3))
                            Text("BOARDING PASS")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(white: 0.3))
                                .tracking(2)
                            Spacer()
                            Text("NOOR AIRLINES")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color(white: 0.45))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(white: 0.92))

                        HStack(spacing: 0) {
                            VStack(spacing: 12) {
                                // Passenger + class
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("PASSENGER")
                                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                                            .foregroundStyle(Color(white: 0.5))
                                        Text(userName.isEmpty ? "You" : userName.uppercased())
                                            .font(.system(size: 16, weight: .bold, design: .serif))
                                            .foregroundStyle(.black)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("CLASS")
                                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                                            .foregroundStyle(Color(white: 0.5))
                                        Text("First Class")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.black)
                                    }
                                }

                                // FROM / TO
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("FROM")
                                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.black.opacity(0.6))
                                        Text(departure.isEmpty ? "Current You" : departure)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.black)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("TO")
                                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.black.opacity(0.6))
                                        Text(destination.isEmpty ? "Your Dream" : destination)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(.black)
                                            .lineLimit(1)
                                    }
                                }

                                // Flight path — airplane with progress (hot pink to the left)
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color(white: 0.6))
                                        .frame(width: 6, height: 6)
                                    GeometryReader { geo in
                                        let progressFraction: CGFloat = 0.42
                                        ZStack(alignment: .leading) {
                                            Rectangle()
                                                .fill(Color(white: 0.75))
                                                .frame(height: 2)
                                            Rectangle()
                                                .fill(Color.noorAccent)
                                                .frame(width: geo.size.width * progressFraction, height: 2)
                                            Image(systemName: "airplane")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(Color.noorAccent)
                                                .offset(x: geo.size.width * progressFraction - 6)
                                        }
                                    }
                                    .frame(height: 14)
                                    Circle()
                                        .fill(Color.noorAccent.opacity(0.5))
                                        .frame(width: 6, height: 6)
                                }

                                HStack(spacing: 6) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color(white: 0.45))
                                    Text("ETA: February 26, 2026")
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundStyle(Color(white: 0.35))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)

                            // Perforation
                            VStack(spacing: 3) {
                                ForEach(0..<8, id: \.self) { _ in
                                    Circle().fill(Color.noorBackground).frame(width: 3, height: 3)
                                }
                            }
                            .padding(.vertical, 6)

                            // Right stub — step count
                            VStack(spacing: 4) {
                                Text("\(generatedChallenges.count)")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(.black)
                                Text("STEPS")
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Color(white: 0.45))
                            }
                            .frame(width: 54)
                            .padding(.vertical, 10)
                        }
                        .background(Color.white)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .opacity(showItineraryHeader ? 1 : 0)
                    .offset(y: showItineraryHeader ? 0 : -10)
                    .padding(.top, 30)

                    // 7-Step Journey — fades in below the boarding pass
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your 7-Step Journey")
                            .font(NoorFont.title)
                            .foregroundStyle(.white)
                            .padding(.bottom, 4)
                            .opacity(showItineraryChallenges ? 1 : 0)

                        ForEach(Array(generatedChallenges.enumerated()), id: \.element.id) { index, challenge in
                            ItineraryChallengeRow(
                                number: index + 1,
                                challenge: challenge,
                                isUnlocked: challenge.unlocked,
                                isFirstUnlocked: index == 0 && challenge.unlocked
                            )
                            .opacity(index < visibleChallengeCount ? 1 : 0)
                            .offset(y: index < visibleChallengeCount ? 0 : 10)
                            .animation(.easeOut(duration: 0.35), value: visibleChallengeCount)
                        }
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, NoorLayout.horizontalPadding)
            }

            // Fixed bottom buttons
            VStack(spacing: 16) {
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

                Button {
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
                    .font(NoorFont.onboardingCaption)
                    .foregroundStyle(Color.noorTextSecondary.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, NoorLayout.horizontalPadding)
            .padding(.vertical, 12)
            .background(Color.noorBackground)
        }
        .onAppear {
            showItineraryHeader = false
            showItineraryChallenges = false
            visibleChallengeCount = 0

            // Boarding pass fades in with haptic
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.easeOut(duration: 0.6)) {
                showItineraryHeader = true
            }

            // "Your 7-Step Journey" heading fades in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeIn(duration: 0.5)) {
                    showItineraryChallenges = true
                }
            }

            // Each challenge row appears one at a time with haptics
            let challengeCount = generatedChallenges.count
            for i in 0..<challengeCount {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.3 + Double(i) * 0.25) {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5)
                    withAnimation(.easeOut(duration: 0.35)) {
                        visibleChallengeCount = i + 1
                    }
                }
            }
        }
    }

    // MARK: - Removed Gender Selection (default preserved)
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
                            .font(NoorFont.onboardingCallout)
                            .foregroundStyle(Color.noorTextSecondary)

                            if let error = purchaseManager.errorMessage {
                                Text(error)
                                    .font(NoorFont.onboardingCaption)
                                    .foregroundStyle(Color.noorCoral)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }

                            Text("The woman who lives that life invests in herself.")
                                .font(NoorFont.onboardingCaption)
                                .foregroundStyle(Color.noorTextSecondary.opacity(0.6))
                                .italic()
                                .padding(.top, 4)

                            Button("Skip for now") {
                                saveUserAndComplete()
                            }
                            .font(NoorFont.onboardingCaption)
                            .foregroundStyle(Color.noorTextSecondary.opacity(0.6))
                            .padding(.top, 8)

                            HStack(spacing: 16) {
                                Button("Terms & Conditions") {
                                    if let url = URL(string: "https://noor-website-virid.vercel.app/terms/") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                    .font(NoorFont.onboardingCaption)
                                    .foregroundStyle(Color.noorTextSecondary.opacity(0.7))

                                Button("Privacy Policy") {
                                    if let url = URL(string: "https://noor-website-virid.vercel.app/privacy/") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                    .font(NoorFont.onboardingCaption)
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
                if currentScreen == 10 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentScreen = 11
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
            "departure": departure,
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

// MARK: - Typewriter Intro Page (Built on motivation / behavioral science — no "Noor" on this page)
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
    @State private var buttonOpacity: Double = 0

    private let fullWelcome = "Welcome to Noor"
    private let builtOnFull = "Built on "
    private let motivationFull = "motivation."
    private let behavioralScienceFull = "behavioral science."

    var body: some View {
        GeometryReader { geo in
            ZStack {
                VStack(spacing: 0) {
                    Spacer()

                    // Main text area — "Built on motivation" -> "behavioral science."
                    VStack(alignment: .leading, spacing: 0) {
                        ZStack(alignment: .topLeading) {
                            // "Built on motivation" -> strikethrough -> "behavioral science."
                            VStack(alignment: .leading, spacing: 6) {
                                // Line 1: "Built on motivation." with strikethrough
                                HStack(spacing: 0) {
                                    Text(builtOnText)
                                        .font(.system(size: 32, weight: .regular))
                                        .foregroundStyle(.white)

                                    // motivation typed then struck through
                                    if !motivationText.isEmpty {
                                        ZStack(alignment: .leading) {
                                            Text(motivationText)
                                                .font(.system(size: 32, weight: .regular))
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
                                        .font(.system(size: 32, weight: .regular))
                                        .foregroundStyle(Color.noorAccent)

                                    if showCursor && phase == 5 {
                                        Rectangle()
                                            .fill(Color.noorAccent)
                                            .frame(width: 3, height: 32)
                                    }
                                }
                                .opacity(behavioralScienceText.isEmpty ? 0 : 1)
                            }
                        }

                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, NoorLayout.horizontalPadding)

                    Spacer()

                    // Bottom controls — continue only, no dots on this screen
                    Button {
                        onContinue()
                    } label: {
                        HStack(spacing: 6) {
                            Text("Continue")
                                .font(NoorFont.onboardingBodyLarge)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .opacity(buttonOpacity)
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
        phase = 2
        welcomeText = ""
        builtOnText = ""
        motivationText = ""
        strikethroughProgress = 0
        motivationFaded = false
        behavioralScienceText = ""
        buttonOpacity = 0

        withAnimation(.easeOut(duration: 0.6)) {
            revealProgress = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            hasStartedTypewriter = true
            startCursorBlink()
            typeBuiltOn()
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
                UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.3)

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
                UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.4)

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
        // Dramatic strikethrough haptic
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

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
                UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5)

                if index == self.behavioralScienceFull.count - 1 {
                    // Success haptic when fully typed
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    // Wait before showing continue
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        self.phase = 6
                        self.showFinalContent()
                    }
                }
            }
        }
    }

    // Phase 6: Show continue button (no "Noor" on this page)
    private func showFinalContent() {
        // Button appears after a pause
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.6)) {
                buttonOpacity = 1
            }
        }
    }
}

// MARK: - Intro Page View (for swipeable carousel) - "Show, don't tell" with mockups
private struct IntroPageView: View {
    let page: IntroPage
    @State private var headlineAppeared = false
    @State private var restAppeared = false
    @State private var mockupAppeared = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .center, spacing: 20) {
                Spacer().frame(height: 50)
                
                // Icon - only for pages that have one
                Group {
                    if let icon = page.icon {
                        Image(systemName: icon)
                            .font(.system(size: 48))
                            .foregroundStyle(page.accentColor)
                    } else if let pair = page.iconPair {
                        HStack(spacing: 16) {
                            Image(systemName: pair.0)
                                .font(.system(size: 36))
                            Image(systemName: pair.1)
                                .font(.system(size: 36))
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
                    .multilineTextAlignment(.center)
                    .opacity(headlineAppeared ? 1 : 0)
                    .offset(y: headlineAppeared ? 0 : 20)
                
                // Subheadline - fades in slowly after headline
                if let subheadline = page.subheadline {
                    Text(subheadline)
                        .font(NoorFont.title)
                        .foregroundStyle(page.accentColor)
                        .multilineTextAlignment(.center)
                        .opacity(restAppeared ? 1 : 0)
                        .offset(y: restAppeared ? 0 : 15)
                }
                
                // Page 4 (Vision): mockup first, then body text under it
                // Other pages: body text first, then mockup
                if page.id == 4 {
                    // Vision: mockup first
                    Group {
                        OnboardingVisionMockup()
                    }
                    .opacity(mockupAppeared ? 1 : 0)
                    .scaleEffect(mockupAppeared ? 1 : 0.95)
                    .padding(.top, 8)
                    
                    // Body text under vision mockup
                    VStack(alignment: .center, spacing: 10) {
                        ForEach(Array(page.body.enumerated()), id: \.offset) { index, text in
                            Text(text)
                                .font(.system(size: 20, weight: .regular, design: .serif))
                                .foregroundStyle(Color.noorTextSecondary)
                                .multilineTextAlignment(.center)
                                .opacity(restAppeared ? 1 : 0)
                                .offset(y: restAppeared ? 0 : 10)
                                .animation(.easeOut(duration: 0.6).delay(Double(index) * 0.1), value: restAppeared)
                        }
                    }
                    .padding(.top, 16)
                } else {
                    // Other pages: body text then mockup
                    VStack(alignment: .center, spacing: 10) {
                        ForEach(Array(page.body.enumerated()), id: \.offset) { index, text in
                            Text(text)
                                .font(.system(size: 20, weight: .regular, design: .serif))
                                .foregroundStyle(Color.noorTextSecondary)
                                .multilineTextAlignment(.center)
                                .opacity(restAppeared ? 1 : 0)
                                .offset(y: restAppeared ? 0 : 10)
                                .animation(.easeOut(duration: 0.6).delay(Double(index) * 0.1), value: restAppeared)
                        }
                    }
                    
                    Group {
                        switch page.id {
                        case 1:
                            OnboardingBoardingPassMockup()
                        case 2:
                            OnboardingNotificationMockup()
                        case 3:
                            OnboardingTaskCompletionMockup()
                        case 5:
                            OnboardingPassportMockup()
                        default:
                            EmptyView()
                        }
                    }
                    .opacity(mockupAppeared ? 1 : 0)
                    .scaleEffect(mockupAppeared ? 1 : 0.95)
                    .padding(.top, 8)
                }
                
                // Quote - fades in last (only if present)
                if let quote = page.quote {
                    Text("\"\(quote)\"")
                        .font(NoorFont.onboardingBody)
                        .italic()
                        .foregroundStyle(page.accentColor.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                        .opacity(restAppeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.6).delay(0.6), value: restAppeared)
                }
                
                Spacer().frame(height: 60)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, NoorLayout.horizontalPadding)
        }
        .onAppear {
            // Headline appears first with gentle fade
            withAnimation(.easeOut(duration: 0.7)) {
                headlineAppeared = true
            }
            // Rest fades in slowly after headline settles
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeOut(duration: 0.8)) {
                    restAppeared = true
                }
            }
            // Mockup appears with slight delay and scale animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    mockupAppeared = true
                }
            }
        }
        .onDisappear {
            headlineAppeared = false
            restAppeared = false
            mockupAppeared = false
        }
    }
}

// MARK: - Onboarding Mockup: Boarding Pass (Travel Agency)
private struct OnboardingBoardingPassMockup: View {
    var body: some View {
        VStack(spacing: 0) {
            // Top header
            HStack {
                Image(systemName: "airplane")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(white: 0.35))
                Text("BOARDING PASS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.35))
                    .tracking(1.5)
                Spacer()
                Text("NOOR AIRLINES")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(white: 0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(white: 0.92))
            
            // Main ticket body
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("FROM")
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .foregroundStyle(.black.opacity(0.6))
                            Text("Current You")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.black)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("TO")
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .foregroundStyle(.black.opacity(0.6))
                            Text("Your Dream")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.black)
                        }
                    }
                    
                    // Flight path
                    HStack(spacing: 6) {
                        Circle().fill(Color(white: 0.6)).frame(width: 5, height: 5)
                        Rectangle().fill(Color(white: 0.75)).frame(height: 1).frame(maxWidth: .infinity)
                        Image(systemName: "airplane").font(.system(size: 10)).foregroundStyle(Color.noorAccent)
                        Rectangle().fill(Color(white: 0.75)).frame(height: 1).frame(maxWidth: .infinity)
                        Circle().fill(Color.noorAccent).frame(width: 5, height: 5)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "calendar").font(.system(size: 8)).foregroundStyle(Color(white: 0.5))
                        Text("ETA: Your Timeline")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color(white: 0.4))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                
                // Perforation
                VStack(spacing: 3) {
                    ForEach(0..<8, id: \.self) { _ in
                        Circle().fill(Color.noorBackground).frame(width: 3, height: 3)
                    }
                }
                .padding(.vertical, 6)
                
                // Right stub with progress
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .stroke(Color(white: 0.8), lineWidth: 3)
                            .frame(width: 36, height: 36)
                        Circle()
                            .trim(from: 0, to: 0.45)
                            .stroke(Color.noorAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 36, height: 36)
                            .rotationEffect(.degrees(-90))
                        Text("45%")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                    }
                    Text("3/7")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                    Text("STEPS")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(Color(white: 0.5))
                }
                .frame(width: 60)
                .padding(.vertical, 10)
            }
            .background(Color.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Onboarding Mockup: Notification (Brain Prioritizes)
private struct OnboardingNotificationMockup: View {
    @State private var show1 = false
    @State private var show2 = false
    @State private var show3 = false

    private let appIcon: UIImage? = {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let name = files.last {
            return UIImage(named: name)
        }
        return UIImage(named: "AppIcon")
    }()

    var body: some View {
        VStack(spacing: 10) {
            // Notification 1
            notificationRow(
                title: "You're on a 7-day streak!",
                subtitle: "Keep the momentum going.",
                time: "now"
            )
            .opacity(show1 ? 1 : 0)
            .offset(y: show1 ? 0 : -30)

            // Notification 2
            notificationRow(
                title: "Today's challenge is ready",
                subtitle: "One step closer to your destination.",
                time: "9:00 AM"
            )
            .opacity(show2 ? 1 : 0)
            .offset(y: show2 ? 0 : -30)

            // Notification 3
            notificationRow(
                title: "You completed all habits!",
                subtitle: "Your future self thanks you.",
                time: "Yesterday"
            )
            .opacity(show3 ? 1 : 0)
            .offset(y: show3 ? 0 : -30)
        }
        .onAppear {
            // Staggered pop-in with haptics
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                    show1 = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                    show2 = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                    show3 = true
                }
            }
        }
        .onDisappear {
            show1 = false
            show2 = false
            show3 = false
        }
    }

    private func notificationRow(title: String, subtitle: String, time: String) -> some View {
        HStack(spacing: 10) {
            // Real app icon
            Group {
                if let icon = appIcon {
                    Image(uiImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    // Fallback
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.noorBackground)
                        .overlay(
                            Image(systemName: "sparkle")
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                        )
                }
            }
            .frame(width: 38, height: 38)
            .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Noor")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)
                    Spacer()
                    Text(time)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(white: 0.45))
                }
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.black)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.35))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .background(Color(white: 0.97).opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Onboarding Mockup: Task Completion (Dopamine) - Matches Home Page Exactly
private struct OnboardingTaskCompletionMockup: View {
    @State private var showRow1 = false
    @State private var showRow2 = false
    @State private var showRow3 = false
    @State private var task1Done = false
    @State private var task2Done = false
    @State private var task3Done = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                Text("Today's Itinerary")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)

                Spacer()

                Text(allDone ? "Done!" : "\(completedCount)/3")
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .foregroundStyle(allDone ? Color.noorSuccess : Color.noorAccent)
            }

            // Status line
            Text(allDone
                 ? "All done — you crushed it."
                 : "\(3 - completedCount) thing\(3 - completedCount == 1 ? "" : "s") left today")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.noorTextSecondary)

            // Task list — rows appear one at a time
            VStack(spacing: 0) {
                taskRow(title: "Journal for 5 minutes", subtitle: "Morning routine", kind: .habit, isCompleted: task3Done)
                    .opacity(showRow1 ? 1 : 0)
                    .offset(y: showRow1 ? 0 : 12)

                Divider().background(Color.white.opacity(0.08))

                taskRow(title: "Research Iceland flights", subtitle: "Solo Travel", kind: .mission, isCompleted: task2Done)
                    .opacity(showRow2 ? 1 : 0)
                    .offset(y: showRow2 ? 0 : 12)

                Divider().background(Color.white.opacity(0.08))

                taskRow(title: "Update LinkedIn headline", subtitle: "Career Growth", kind: .mission, isCompleted: task1Done)
                    .opacity(showRow3 ? 1 : 0)
                    .offset(y: showRow3 ? 0 : 12)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            // Rows pop in one at a time
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeOut(duration: 0.35)) { showRow1 = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeOut(duration: 0.35)) { showRow2 = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeOut(duration: 0.35)) { showRow3 = true }
            }

            // Auto-complete with haptics: top → bottom
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { task3Done = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { task2Done = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { task1Done = true }
            }
        }
        .onDisappear {
            showRow1 = false; showRow2 = false; showRow3 = false
            task1Done = false; task2Done = false; task3Done = false
        }
    }

    private var completedCount: Int {
        [task1Done, task2Done, task3Done].filter { $0 }.count
    }

    private var allDone: Bool { task1Done && task2Done && task3Done }

    private enum TaskKind { case habit, mission }

    private func taskRow(title: String, subtitle: String, kind: TaskKind, isCompleted: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(isCompleted ? Color.noorSuccess : Color.white.opacity(0.2), lineWidth: 2)
                    .frame(width: 28, height: 28)

                if isCompleted {
                    Circle()
                        .fill(Color.noorSuccess)
                        .frame(width: 28, height: 28)
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isCompleted ? Color.noorTextSecondary.opacity(0.5) : .white)
                    .strikethrough(isCompleted, color: Color.noorTextSecondary.opacity(0.4))
                    .lineLimit(1)

                Text(kind == .mission ? "Challenge · \(subtitle)" : "Habit · \(subtitle)")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(kind == .mission ? Color.noorAccent.opacity(0.7) : Color.noorSuccess.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(Color.noorTextSecondary.opacity(0.3))
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Onboarding Mockup: Vision Feature (Reduce Friction)
private struct OnboardingVisionMockup: View {
    @State private var show1 = false
    @State private var show2 = false
    @State private var show3 = false
    @State private var show4 = false

    // Same color scheme as the main app (noor theme)
    private let destinationColor = Color.noorAccent
    private let pinterestColor = Color.noorOrange
    private let instagramColor = Color.noorRoseGold
    private let actionColor = Color.noorSuccess

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Context header — ties to the boarding pass / journey
            HStack(spacing: 8) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.noorOrange)
                Text("Vision Board")
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                Spacer()
                Text("Solo Travel")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.noorOrange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.noorOrange.opacity(0.15))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 4)

            // Vision items
            VStack(spacing: 6) {
                visionRow(
                    icon: "globe.americas.fill",
                    color: destinationColor,
                    title: "Santorini, Greece",
                    subtitle: "Search flights & hotels",
                    actionIcon: "airplane",
                    actionLabel: "Book"
                )
                .opacity(show1 ? 1 : 0)
                .offset(x: show1 ? 0 : -20)

                visionRow(
                    icon: "photo.on.rectangle.angled",
                    color: pinterestColor,
                    title: "Travel outfit inspo",
                    subtitle: "pinterest.com/board",
                    actionIcon: "arrow.up.right",
                    actionLabel: "Open"
                )
                .opacity(show2 ? 1 : 0)
                .offset(x: show2 ? 0 : -20)

                visionRow(
                    icon: "camera.fill",
                    color: instagramColor,
                    title: "@santorini.guide",
                    subtitle: "instagram.com",
                    actionIcon: "arrow.up.right",
                    actionLabel: "Open"
                )
                .opacity(show3 ? 1 : 0)
                .offset(x: show3 ? 0 : -20)

                visionRow(
                    icon: "bolt.fill",
                    color: actionColor,
                    title: "Renew passport",
                    subtitle: "Next step to book trip",
                    actionIcon: "checkmark",
                    actionLabel: "Done"
                )
                .opacity(show4 ? 1 : 0)
                .offset(x: show4 ? 0 : -20)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 12)
        }
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.noorOrange.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeOut(duration: 0.35)) { show1 = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeOut(duration: 0.35)) { show2 = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeOut(duration: 0.35)) { show3 = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeOut(duration: 0.35)) { show4 = true }
            }
        }
        .onDisappear {
            show1 = false; show2 = false; show3 = false; show4 = false
        }
    }

    private func visionRow(icon: String, color: Color, title: String, subtitle: String, actionIcon: String, actionLabel: String) -> some View {
        HStack(spacing: 10) {
            // Icon badge
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Title + subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.noorTextSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            // Action button
            HStack(spacing: 3) {
                Image(systemName: actionIcon)
                    .font(.system(size: 10, weight: .semibold))
                Text(actionLabel)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Onboarding Mockup: Passport (Vacation tracking)
private struct OnboardingPassportMockup: View {
    @State private var showPin1 = false
    @State private var showPin2 = false
    @State private var showPin3 = false
    @State private var showPin4 = false
    @State private var showMetrics = false

    // Sample pin positions on the map image (x%, y%)
    private let samplePins: [(x: CGFloat, y: CGFloat, label: String)] = [
        (0.48, 0.30, "Paris"),      // Europe
        (0.72, 0.34, "Tokyo"),      // Japan
        (0.20, 0.36, "New York"),   // North America
        (0.52, 0.58, "Cape Town"), // Africa
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Mini airplane banner
            HStack(spacing: 5) {
                ForEach(0..<5) { _ in
                    Image(systemName: "airplane")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(Color.noorViolet.opacity(0.5))
                }
            }
            .padding(.vertical, 6)

            // Mini world map with pins
            GeometryReader { geo in
                ZStack {
                    Image("PassportWorldMapPurple")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Animated pins
                    pinDot(at: samplePins[0], in: geo.size, visible: showPin1)
                    pinDot(at: samplePins[1], in: geo.size, visible: showPin2)
                    pinDot(at: samplePins[2], in: geo.size, visible: showPin3)
                    pinDot(at: samplePins[3], in: geo.size, visible: showPin4)
                }
            }
            .frame(height: 130)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 8)

            // Metrics row
            HStack(spacing: 8) {
                mockupMetric(label: "PLACES VISITED", value: "4")
                mockupMetric(label: "COUNTRIES", value: "3")
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .opacity(showMetrics ? 1 : 0)
            .offset(y: showMetrics ? 0 : 10)
        }
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.noorViolet.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showPin1 = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showPin2 = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showPin3 = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showPin4 = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeOut(duration: 0.4)) { showMetrics = true }
            }
        }
        .onDisappear {
            showPin1 = false; showPin2 = false; showPin3 = false; showPin4 = false; showMetrics = false
        }
    }

    private func pinDot(at pin: (x: CGFloat, y: CGFloat, label: String), in size: CGSize, visible: Bool) -> some View {
        ZStack {
            Circle()
                .fill(Color.noorAccent.opacity(0.4))
                .frame(width: 16, height: 16)
            Circle()
                .fill(Color.noorAccent)
                .frame(width: 8, height: 8)
                .shadow(color: .black.opacity(0.4), radius: 2)
        }
        .scaleEffect(visible ? 1 : 0)
        .opacity(visible ? 1 : 0)
        .position(x: size.width * pin.x, y: size.height * pin.y)
    }

    private func mockupMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.noorTextSecondary)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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

private struct OnboardingDepartureInputView: View {
    @Binding var departure: String
    let onNext: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                Text("Where are you departing from?")
                    .font(NoorFont.largeTitle)
                    .foregroundStyle(.white)

                Text("This doesn't have to be a place.")
                    .font(.system(size: 20, weight: .regular, design: .serif))
                    .foregroundStyle(Color.noorRoseGold)
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
                .focused($isFocused)

            Spacer()

            OnboardingTextButton(
                title: "Continue",
                isDisabled: false,
                action: {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onNext()
                    }
                }
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
                    .font(NoorFont.onboardingBodyLarge)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(isDisabled ? Color.noorTextSecondary.opacity(0.5) : .white)
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
                    .foregroundStyle(isSelected ? .white : Color.noorAccent)
                    .frame(width: 40)

                Text(category.displayName)
                    .font(NoorFont.onboardingBody)
                    .foregroundStyle(isSelected ? .white : Color.noorTextSecondary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.noorSuccess)
                }
            }
            .padding(16)
            .background(isSelected ? Color.noorViolet.opacity(0.5) : Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
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
                        .font(NoorFont.onboardingCallout)
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
                    .font(NoorFont.onboardingBody)
                    .fontWeight(isFirstUnlocked ? .semibold : .regular)
                    .foregroundStyle(isUnlocked ? .white : Color.noorTextSecondary.opacity(0.5))

                if isUnlocked {
                    Text(challenge.description)
                        .font(NoorFont.onboardingCaption)
                        .foregroundStyle(Color.noorTextSecondary)
                        .lineLimit(2)

                    Text(challenge.estimatedTime)
                        .font(NoorFont.onboardingCaption)
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
                    .font(NoorFont.onboardingBody)
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
                .font(NoorFont.onboardingBody)
                .foregroundStyle(Color.noorCharcoal)
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .environment(PurchaseManager.shared)
}
