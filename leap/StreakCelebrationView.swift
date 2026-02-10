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
            // Dark gradient background
            LinearGradient(
                colors: [
                    Color.noorDeepPurple,
                    Color.noorBackground,
                    Color.noorBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Sparkles
            SparkleOverlay()

            VStack(spacing: 0) {
                Spacer()

                // Flame with number (number centered in flame)
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

                    Text("\(streakCount)")
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4)
                        .offset(y: -8)
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
                        .foregroundStyle(Color.noorDeepPurple)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(hex: "A8B5CD"))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 32)

                Spacer()
                    .frame(height: 48)
            }
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
