//
//  WelcomeView.swift
//  leap
//
//  Quick onboarding — skippable, brand voice
//

import SwiftUI

struct WelcomeView: View {
    var onFinish: () -> Void

    var body: some View {
        ZStack {
            Color.noorCream.ignoresSafeArea()
            VStack(spacing: 32) {
                Spacer()
                Text("Noor")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(Color.noorPink)
                Text("Your comfort zone is a cage.\nTake the leap. ✨")
                    .font(NoorFont.title2)
                    .foregroundStyle(Color.noorCharcoal)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal)
                Text("One micro-challenge a day.\nSeeker, not dreamer.")
                    .font(NoorFont.body)
                    .foregroundStyle(Color.noorCharcoal.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer()
                VStack(spacing: 16) {
                    PrimaryButton(title: "Let's go", action: onFinish)
                    Button("Skip", action: onFinish)
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorCharcoal.opacity(0.6))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
    }
}

#Preview {
    WelcomeView(onFinish: {})
}
