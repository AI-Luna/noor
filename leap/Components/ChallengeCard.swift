//
//  ChallengeCard.swift
//  leap
//
//  Reusable challenge card: white bg, shadow, tap to complete, lock badge for premium
//

import SwiftUI

struct ChallengeCard: View {
    let challenge: Challenge
    let isCompleted: Bool
    let isLocked: Bool
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Check or lock
                ZStack {
                    Circle()
                        .fill(isCompleted ? Color.noorTeal : (isLocked ? Color.gray.opacity(0.3) : Color.noorPink.opacity(0.2)))
                        .frame(width: 44, height: 44)
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                    } else if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.noorTeal)
                    } else {
                        Image(systemName: "circle")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(Color.noorPink)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: isCompleted)

                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.title)
                        .font(NoorFont.body)
                        .foregroundStyle(Color.noorCharcoal)
                        .multilineTextAlignment(.leading)
                        .strikethrough(isCompleted, color: Color.noorCharcoal.opacity(0.5))
                    Text(challenge.durationText)
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorCharcoal.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isLocked && !isCompleted {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.noorPink)
                }
            }
            .padding(20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: NoorLayout.cornerRadius))
            .shadow(color: .black.opacity(0.06), radius: NoorLayout.cardShadowRadius, x: 0, y: NoorLayout.cardShadowY)
            .scaleEffect(isPressed ? 0.98 : 1)
        }
        .buttonStyle(.plain)
        .pressEvents {
            isPressed = true
        } onRelease: {
            isPressed = false
        }
    }
}

// Simple press feedback
private extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressModifier(onPress: onPress, onRelease: onRelease))
    }
}

private struct PressModifier: ViewModifier {
    let onPress: () -> Void
    let onRelease: () -> Void

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() }
            )
    }
}

#Preview {
    VStack {
        ChallengeCard(
            challenge: ChallengeCategory.career.challenges[0],
            isCompleted: false,
            isLocked: false,
            onTap: {}
        )
        ChallengeCard(
            challenge: ChallengeCategory.career.challenges[2],
            isCompleted: false,
            isLocked: true,
            onTap: {}
        )
    }
    .padding()
    .background(Color.noorCream)
}
