//
//  SettingsView.swift
//  leap
//
//  Restore purchases, streak display
//

import SwiftUI

struct SettingsView: View {
    private let store = CompletionStore.shared
    private let purchaseManager = PurchaseManager.shared
    @State private var showPaywall = false
    @State private var isRestoring = false
    @State private var showRestoredAlert = false
    @State private var showRestartOnboardingConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.noorCream.ignoresSafeArea()
                List {
                    Section {
                        HStack {
                            Text("🔥")
                            Text("Current streak")
                            Spacer()
                            Text("\(store.streak) days")
                                .foregroundStyle(Color.noorCharcoal.opacity(0.8))
                        }
                        .listRowBackground(Color.white)
                    }

                    Section {
                        Button {
                            showRestartOnboardingConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Restart onboarding")
                            }
                        }
                        .foregroundStyle(Color.noorCharcoal)
                        .listRowBackground(Color.white)
                    }

                    Section {
                        if purchaseManager.isPro {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(Color.noorPink)
                                Text("Pro member")
                            }
                            .listRowBackground(Color.white)
                        } else {
                            Button {
                                showPaywall = true
                            } label: {
                                HStack {
                                    Text("Upgrade to Pro")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .foregroundStyle(Color.noorCharcoal)
                            .listRowBackground(Color.white)
                        }

                        Button {
                            isRestoring = true
                            Task { @MainActor in
                                await purchaseManager.restorePurchases()
                                isRestoring = false
                                showRestoredAlert = true
                            }
                        } label: {
                            HStack {
                                Text("Restore Purchases")
                                if isRestoring {
                                    Spacer()
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                        }
                        .foregroundStyle(Color.noorCharcoal)
                        .listRowBackground(Color.white)
                        .disabled(isRestoring)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showPaywall) {
                PaywallView(onDismiss: { showPaywall = false })
            }
            .alert("Restore", isPresented: $showRestoredAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(purchaseManager.isPro ? "Pro access restored." : "No active subscription found.")
            }
            .alert("Restart onboarding?", isPresented: $showRestartOnboardingConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Restart", role: .destructive) {
                    UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                }
            } message: {
                Text("You'll see the onboarding flow again. The app will restart to the first screen.")
            }
        }
    }
}

#Preview {
    SettingsView()
}
