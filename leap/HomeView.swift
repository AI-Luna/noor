//
//  HomeView.swift
//  leap
//
//  Today's Challenge — one daily micro-challenge, tap to complete, streak
//

import SwiftUI

struct HomeView: View {
    @State private var todayChallenge: Challenge?
    @State private var showCompleteAnimation = false
    private let store = CompletionStore.shared
    private let purchaseManager = PurchaseManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.noorCream.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Streak
                        HStack(spacing: 6) {
                            Text("🔥")
                            Text("\(store.streak) day streak")
                                .font(NoorFont.callout)
                                .foregroundStyle(Color.noorCharcoal)
                        }
                        .padding(.horizontal, 4)

                        // Today's challenge
                        if let challenge = todayChallenge {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Today's Challenge")
                                    .font(NoorFont.title2)
                                    .foregroundStyle(Color.noorCharcoal)
                                let isCompleted = store.isCompleted(challenge.id)
                                let isLocked = !purchaseManager.canAccess(challenge: challenge)
                                ChallengeCard(
                                    challenge: challenge,
                                    isCompleted: isCompleted,
                                    isLocked: isLocked,
                                    onTap: {
                                        if isLocked { return }
                                        if !isCompleted {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                store.markComplete(challenge.id)
                                                showCompleteAnimation = true
                                            }
                                        }
                                    }
                                )
                            }
                        } else {
                            Text("Pick a challenge from Categories to get started.")
                                .font(NoorFont.body)
                                .foregroundStyle(Color.noorCharcoal.opacity(0.7))
                                .padding()
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Noor")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                pickTodaysChallenge()
            }
        }
    }

    private func pickTodaysChallenge() {
        let accessible = allChallenges.filter { purchaseManager.canAccess(challenge: $0) }
        guard !accessible.isEmpty else {
            todayChallenge = allChallenges.first
            return
        }
        // Deterministic per day: same challenge all day
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        todayChallenge = accessible[dayIndex % accessible.count]
    }
}

#Preview {
    HomeView()
}
