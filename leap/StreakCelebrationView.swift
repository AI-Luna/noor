//
//  StreakCelebrationView.swift
//  leap
//
//  Popup streak celebration: animated flame, contextual encouragement, tap anywhere to dismiss
//

import SwiftUI

struct StreakCelebrationView: View {
    let streakCount: Int
    let userName: String
    var completedTaskTitle: String? = nil
    let onDismiss: () -> Void

    @State private var flameScale: CGFloat = 0.5
    @State private var flameOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var backgroundOpacity: Double = 0

    private var heading: String {
        if streakCount == 1 {
            return "You're on fire!"
        } else {
            return "\(streakCount) day streak!"
        }
    }

    private var subtitle: String {
        if let task = completedTaskTitle, !task.isEmpty {
            // Contextual message about what was completed
            if streakCount == 1 {
                return "\"\(task)\" complete. This is how momentum starts."
            } else {
                return "\"\(task)\" done. \(streakCount) days of showing up. Keep it going!"
            }
        } else {
            // Generic encouragement
            if streakCount == 1 {
                return "First step done. This is how momentum starts, \(userName)."
            } else {
                return "\(streakCount) days of showing up. You're building something real."
            }
        }
    }

    var body: some View {
        ZStack {
            // Dim background - tap to dismiss
            Color.black.opacity(0.7 * backgroundOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissWithAnimation()
                }

            // Centered popup card
            VStack(spacing: 0) {
                // Animated flame with streak number
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.noorOrange.opacity(0.4), Color.clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 100
                            )
                        )
                        .frame(width: 180, height: 180)
                        .scaleEffect(flameScale)
                    
                    Image(systemName: "flame.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(hex: "FF6B35"),
                                    Color.noorOrange,
                                    Color(hex: "DC2626")
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .shadow(color: Color.noorOrange.opacity(0.8), radius: 20)
                        .scaleEffect(flameScale)
                        .opacity(flameOpacity)

                    Text("\(streakCount)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 4)
                        .offset(y: -4)
                        .scaleEffect(flameScale)
                        .opacity(flameOpacity)
                }
                .padding(.bottom, 20)

                Text(heading)
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .opacity(contentOpacity)
                    .padding(.bottom, 8)

                Text(subtitle)
                    .font(NoorFont.body)
                    .foregroundStyle(Color.noorTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .opacity(contentOpacity)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 24)

                // Dismiss button
                Button(action: dismissWithAnimation) {
                    Text("Keep Going")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: [Color.noorOrange, Color(hex: "DC2626")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .opacity(contentOpacity)
            }
            .padding(28)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.noorBackground)
                    .shadow(color: Color.noorOrange.opacity(0.3), radius: 40, x: 0, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.noorOrange.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(contentOpacity)
        }
        .onAppear {
            // Animate in
            withAnimation(.easeOut(duration: 0.3)) {
                backgroundOpacity = 1
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                flameScale = 1.0
                flameOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                contentOpacity = 1
            }
            // Pulsing flame animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true)
                ) {
                    flameScale = 1.08
                }
            }
        }
    }
    
    private func dismissWithAnimation() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeIn(duration: 0.2)) {
            contentOpacity = 0
            flameOpacity = 0
            backgroundOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

// MARK: - Daily flame (shown once per day when user opens app and has a streak — positive reinforcement)
struct DailyFlameView: View {
    let streakCount: Int
    let userName: String
    let onDismiss: () -> Void

    @State private var flameScale: CGFloat = 0.6
    @State private var flameOpacity: Double = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.noorBackground
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.noorOrange.opacity(0.15),
                    Color.noorDeepPurple.opacity(0.6),
                    Color.noorBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            SparkleOverlay()
                .opacity(0.6)

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 0) {
                    ZStack {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 120))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.noorOrange,
                                        Color.noorOrange.opacity(0.95),
                                        Color(hex: "EA580C")
                                    ],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .shadow(color: Color.noorOrange.opacity(0.7), radius: 32)
                            .scaleEffect(flameScale)
                            .opacity(flameOpacity)

                        Text("\(streakCount)")
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.4), radius: 6)
                            .scaleEffect(flameScale)
                            .opacity(flameOpacity)
                    }
                    .padding(.bottom, 24)

                    Text("You're here.")
                        .font(NoorFont.largeTitle)
                        .foregroundStyle(.white)
                        .opacity(textOpacity)
                        .padding(.bottom, 8)

                    Text(phraseForStreak)
                        .font(.system(size: 20, weight: .regular, design: .serif))
                        .foregroundStyle(Color.noorTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .opacity(textOpacity)
                        .padding(.bottom, 32)

                    Button(action: onDismiss) {
                        Text("Tap to begin")
                            .font(NoorFont.button)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                LinearGradient(
                                    colors: [Color.noorViolet.opacity(0.9), Color.noorAccent.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.noorRoseGold.opacity(0.5), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 28)
                    .opacity(textOpacity)
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 0)
            }

            ConfettiView(isActive: true, pieceCount: 220, duration: 5.0, style: .pink, fromAllSides: true)
                .allowsHitTesting(false)
        }
        .onAppear {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            withAnimation(.easeOut(duration: 0.5)) {
                flameOpacity = 1
                flameScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.25)) {
                textOpacity = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(
                    .easeInOut(duration: 1.4)
                    .repeatForever(autoreverses: true)
                ) {
                    flameScale = 1.08
                }
            }
        }
    }

    private var phraseForStreak: String {
        if streakCount == 1 {
            return "\(userName), You Showed Up."
        } else {
            return "\(streakCount) days in a row you've taken a step. You're building something real."
        }
    }
}

// MARK: - Sparkle overlay (subtle stars / particles)
private struct SparkleOverlay: View {
    @State private var positions: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Array(positions.enumerated()), id: \.offset) { _, p in
                    Circle()
                        .fill(Color.white)
                        .frame(width: p.size, height: p.size)
                        .opacity(p.opacity)
                        .position(x: p.x * geo.size.width, y: p.y * geo.size.height)
                }
            }
        }
        .onAppear {
            var p: [(CGFloat, CGFloat, CGFloat, Double)] = []
            for _ in 0..<40 {
                p.append((
                    CGFloat.random(in: 0...1),
                    CGFloat.random(in: 0...1),
                    CGFloat.random(in: 1...3),
                    Double.random(in: 0.2...0.7)
                ))
            }
            positions = p
        }
    }
}

#Preview("Streak 1") {
    ZStack {
        Color.noorBackground.ignoresSafeArea()
        StreakCelebrationView(streakCount: 1, userName: "Luna", completedTaskTitle: "Journal for 5 minutes", onDismiss: {})
    }
}

#Preview("Streak 7") {
    ZStack {
        Color.noorBackground.ignoresSafeArea()
        StreakCelebrationView(streakCount: 7, userName: "Luna", completedTaskTitle: "Research flights to Iceland", onDismiss: {})
    }
}
