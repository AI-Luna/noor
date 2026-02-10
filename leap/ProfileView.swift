//
//  ProfileView.swift
//  leap
//
//  Profile / settings: user info, subscription, restore, about, terms & privacy
//

import SwiftUI

struct ProfileView: View {
    @Environment(PurchaseManager.self) private var purchaseManager
    @State private var showPaywall = false
    @State private var isRestoring = false
    @State private var showRestoredAlert = false

    private let store = CompletionStore.shared

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.noorPurpleBlue
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        userInfoSection
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

    // MARK: - User info
    private var userInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account")
                .font(NoorFont.title2)
                .foregroundStyle(.white)
            VStack(spacing: 12) {
                profileRow(icon: "person.fill", title: "Name", value: "Seeker")
                profileRow(icon: "envelope.fill", title: "Email", value: "Not signed in")
            }
            .padding(16)
            .background(Color.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func profileRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.noorPink)
                .frame(width: 24, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(NoorFont.caption)
                    .foregroundStyle(.white.opacity(0.8))
                Text(value)
                    .font(NoorFont.body)
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Subscription
    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subscription")
                .font(NoorFont.title2)
                .foregroundStyle(.white)
            Text(purchaseManager.isPro ? "Current plan: Pro" : "Current plan: Free")
                .font(NoorFont.caption)
                .foregroundStyle(.white.opacity(0.85))

            VStack(spacing: 0) {
                if purchaseManager.isPro {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(Color(hex: "FFD93D"))
                        Text("You're a Noor Pro member")
                            .font(NoorFont.callout)
                            .foregroundStyle(Color.noorCharcoal)
                        Spacer()
                    }
                    .padding(16)
                    .background(Color.white)
                } else {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack {
                            Text("Manage Subscription")
                                .font(NoorFont.callout)
                                .foregroundStyle(Color.noorCharcoal)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color.noorCharcoal.opacity(0.5))
                        }
                        .padding(16)
                        .background(Color.white)
                    }
                    .buttonStyle(.plain)
                }

                Divider()
                    .padding(.leading, 16)

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
                            .foregroundStyle(Color.noorCharcoal)
                        if isRestoring {
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                }
                .buttonStyle(.plain)
                .disabled(isRestoring)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
    }

    // MARK: - About
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(NoorFont.title2)
                .foregroundStyle(.white)

            VStack(spacing: 0) {
                linkRow(title: "Terms of Service", icon: "doc.text")
                Divider().padding(.leading, 16)
                linkRow(title: "Privacy Policy", icon: "hand.raised")
            }
            .background(Color.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Color.noorPink)
                Text("\(store.streak) day streak")
                    .font(NoorFont.caption)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.top, 8)
        }
    }

    private func linkRow(title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.noorPink)
                .frame(width: 24, alignment: .center)
            Text(title)
                .font(NoorFont.body)
                .foregroundStyle(.white)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(16)
        .contentShape(Rectangle())
        .onTapGesture {
            // Placeholder: open URL when you have terms/privacy links
        }
    }
}

#Preview {
    ProfileView()
        .environment(PurchaseManager.shared)
}
