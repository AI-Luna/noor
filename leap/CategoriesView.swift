//
//  CategoriesView.swift
//  leap
//
//  Browse challenges by category — free vs premium, lock badge
//

import SwiftUI

struct CategoriesView: View {
    private let store = CompletionStore.shared
    private let purchaseManager = PurchaseManager.shared
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.noorCream.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(ChallengeCategory.allCases) { category in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(category.id)
                                    .font(NoorFont.title2)
                                    .foregroundStyle(Color.noorCharcoal)
                                ForEach(category.challenges) { challenge in
                                    let isLocked = !purchaseManager.canAccess(challenge: challenge)
                                    ChallengeCard(
                                        challenge: challenge,
                                        isCompleted: store.isCompleted(challenge.id),
                                        isLocked: isLocked,
                                        onTap: {
                                            if isLocked {
                                                showPaywall = true
                                            } else {
                                                store.markComplete(challenge.id)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showPaywall) {
                PaywallView(onDismiss: { showPaywall = false })
            }
        }
    }
}

#Preview {
    CategoriesView()
}
