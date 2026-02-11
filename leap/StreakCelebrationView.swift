//
//  StreakCelebrationView.swift
//  leap
//
//  Fullscreen streak pop-up: flame, number, sparkles, "It begins!" / "X day streak"
//  Matches reference: dark gradient, clean button, centered copy.
//

import SwiftUI

struct StreakCelebrationView: View {
    let streakCount: Int
    let userName: String
    let onDismiss: () -> Void

    @State private var flameScale: CGFloat = 1.0

    private var heading: String {
        if streakCount == 1 {
            return "It begins!"
        } else {
            return "\(streakCount) day streak"
        }
    }

    private var subtitle: String {
        if streakCount == 1 {
            return "\(userName), your streak is building. What would you like it to be now?"
        } else {
            return "The streak tallies each day you triumph over a routine."
        }
    }

    var body: some View {
        ZStack {
            Color.noorBackground
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.noorDeepPurple.opacity(0.8),
                    Color.noorBackground,
                    Color.noorBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            SparkleOverlay()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 0) {
                    // Animated flame with number
                    ZStack {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 140))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.noorOrange,
                                        Color.noorOrange.opacity(0.9),
                                        Color(hex: "DC2626")
                                    ],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .shadow(color: Color.noorOrange.opacity(0.6), radius: 24)
                            .scaleEffect(flameScale)

                        Text("\(streakCount)")
                            .font(.system(size: 80, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 4)
                            .offset(y: -8)
                            .scaleEffect(flameScale)
                    }
                    .padding(.bottom, 28)

                    Text(heading)
                        .font(NoorFont.largeTitle)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 12)

                    Text(subtitle)
                        .font(NoorFont.body)
                        .foregroundStyle(Color.noorTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 40)

                    Button(action: onDismiss) {
                        Text("Tap to continue")
                            .font(NoorFont.button)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [Color.noorViolet.opacity(0.9), Color.noorAccent.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.noorRoseGold.opacity(0.4), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 0)
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.2)
                .repeatForever(autoreverses: true)
            ) {
                flameScale = 1.05
            }
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
                        .font(NoorFont.body)
                        .foregroundStyle(Color.noorTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .opacity(textOpacity)
                        .padding(.bottom, 32)

                    Button(action: onDismiss) {
                        Text("Tap to continue")
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
        }
        .onAppear {
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
            return "\(userName), you showed up. That's how it starts."
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
    StreakCelebrationView(streakCount: 1, userName: "Luna", onDismiss: {})
}

#Preview("Streak 3") {
    StreakCelebrationView(streakCount: 3, userName: "Luna", onDismiss: {})
}
