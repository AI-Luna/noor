//
//  ProfileView.swift
//  leap
//
//  Profile: user info, stats, subscription management
//  "Travel agency for life" - your traveler profile
//

import SwiftUI

struct ProfileView: View {
    @Environment(PurchaseManager.self) private var purchaseManager
    @Environment(DataManager.self) private var dataManager
    @State private var showPaywall = false
    @State private var isRestoring = false
    @State private var showRestoredAlert = false
    @State private var totalGoals: Int = 0
    @State private var completedChallenges: Int = 0

    private var userName: String {
        UserDefaults.standard.string(forKey: "userName") ?? "Traveler"
    }

    private var globalStreak: Int {
        UserDefaults.standard.integer(forKey: StorageKey.streakCount)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.noorBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        profileHeader
                        statsSection
                        subscriptionSection
                        aboutSection
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear { loadStats() }
            .sheet(isPresented: $showPaywall) {
                PaywallView(onDismiss: { showPaywall = false })
            }
            .alert("Restore", isPresented: $showRestoredAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(purchaseManager.isPro ? "Pro access restored." : "No active subscription found.")
            }
        }
    }

    // MARK: - Profile Header (compact; no large avatar)
    private var profileHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.noorViolet, Color.noorAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                Text(String(userName.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(userName)
                    .font(NoorFont.title2)
                    .foregroundStyle(.white)
                if purchaseManager.isPro {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.noorRoseGold)
                        Text("Pro Traveler")
                            .font(NoorFont.caption)
                            .foregroundStyle(Color.noorRoseGold)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 12)
    }

    // MARK: - Stats Section
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Journey")
                .font(NoorFont.title)
                .foregroundStyle(.white)

            HStack(spacing: 16) {
                StatCard(
                    icon: "flame.fill",
                    iconColor: Color.noorOrange,
                    value: "\(globalStreak)",
                    label: "Day Streak"
                )

                StatCard(
                    icon: "airplane",
                    iconColor: Color.noorRoseGold,
                    value: "\(totalGoals)",
                    label: "Flights Booked"
                )

                StatCard(
                    icon: "checkmark.circle.fill",
                    iconColor: Color.noorSuccess,
                    value: "\(completedChallenges)",
                    label: "Steps Complete"
                )
            }
        }
    }

    // MARK: - Subscription Section
    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Subscription")
                .font(NoorFont.title)
                .foregroundStyle(.white)

            VStack(spacing: 0) {
                if purchaseManager.isPro {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(Color.noorRoseGold)
                        Text("Noor Pro - Unlimited Flights")
                            .font(NoorFont.body)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.1))

                    Button {
                        // Open App Store subscription management
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Text("Manage Subscription")
                                .font(NoorFont.callout)
                                .foregroundStyle(Color.noorTextSecondary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(Color.noorTextSecondary.opacity(0.5))
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.05))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Free Plan")
                                    .font(NoorFont.body)
                                    .foregroundStyle(.white)
                                Text("1 flight included")
                                    .font(NoorFont.caption)
                                    .foregroundStyle(Color.noorTextSecondary)
                            }
                            Spacer()
                            Text("Upgrade")
                                .font(NoorFont.callout)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.noorAccent)
                                .clipShape(Capsule())
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.1))
                    }
                    .buttonStyle(.plain)
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
                            .font(NoorFont.callout)
                            .foregroundStyle(Color.noorTextSecondary)
                        Spacer()
                        if isRestoring {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.05))
                }
                .buttonStyle(.plain)
                .disabled(isRestoring)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - About Section
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About")
                .font(NoorFont.title)
                .foregroundStyle(.white)

            VStack(spacing: 0) {
                linkRow(title: "Contact Support", icon: "envelope") {
                    if let url = URL(string: "mailto:luna.app.studio@gmail.com") {
                        UIApplication.shared.open(url)
                    }
                }
                linkRow(title: "Terms of Service", icon: "doc.text") {
                    if let url = URL(string: "https://noor-website-virid.vercel.app/terms/") {
                        UIApplication.shared.open(url)
                    }
                }
                linkRow(title: "Privacy Policy", icon: "hand.raised") {
                    if let url = URL(string: "https://noor-website-virid.vercel.app/privacy/") {
                        UIApplication.shared.open(url)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Text("The woman who lives that life invests in herself.")
                .font(NoorFont.caption)
                .foregroundStyle(Color.noorTextSecondary.opacity(0.6))
                .italic()
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
        }
    }

    private func linkRow(title: String, icon: String, action: @escaping () -> Void = {}) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(Color.noorRoseGold)
                    .frame(width: 24, alignment: .center)
                Text(title)
                    .font(NoorFont.body)
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.noorTextSecondary.opacity(0.5))
            }
            .padding(16)
            .background(Color.white.opacity(0.08))
        }
        .buttonStyle(.plain)
    }

    private func loadStats() {
        Task { @MainActor in
            do {
                let goals = try await dataManager.fetchAllGoals()
                totalGoals = goals.count
                completedChallenges = goals.flatMap { $0.dailyTasks }.filter { $0.isCompleted }.count
            } catch {
                totalGoals = 0
                completedChallenges = 0
            }
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(iconColor)

            Text(value)
                .font(NoorFont.title)
                .foregroundStyle(.white)

            Text(label)
                .font(NoorFont.caption)
                .foregroundStyle(Color.noorTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    ProfileView()
        .environment(PurchaseManager.shared)
        .environment(DataManager.shared)
}
