//
//  PaywallView.swift
//  leap
//
//  Premium paywall: unlimited goals, monthly/yearly plans, restore
//

import SwiftUI
import RevenueCat

struct PaywallView: View {
    var onDismiss: () -> Void
    /// When set, show this message (e.g. "Pro members can create unlimited goals") above pricing.
    var proGateMessage: String? = nil

    private let purchaseManager = PurchaseManager.shared
    @State private var showSuccess = false
    @State private var showErrorAlert = false

    private var monthlyPackage: Package? {
        purchaseManager.currentOffering?.availablePackages.first { $0.packageType == .monthly }
    }

    private var yearlyPackage: Package? {
        purchaseManager.currentOffering?.availablePackages.first { $0.packageType == .annual }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.noorBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        heroSection
                        pricingSection
                        footerSection
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onDismiss() }
                        .foregroundStyle(.white)
                }
            }
            .onAppear {
                if purchaseManager.currentOffering == nil {
                    Task { await purchaseManager.loadOfferings() }
                }
            }
            .overlay {
                if purchaseManager.isLoading {
                    loadingOverlay
                }
            }
            .alert("Welcome to Noor Pro!", isPresented: $showSuccess) {
                Button("Continue") {
                    showSuccess = false
                    onDismiss()
                }
            } message: {
                Text("Your premium features are now active. Create unlimited goals and unlock daily challenges.")
            }
            .onChange(of: purchaseManager.errorMessage) { _, newValue in
                showErrorAlert = (newValue != nil && !(newValue?.isEmpty ?? true))
            }
            .alert("Purchase Error", isPresented: $showErrorAlert) {
                Button("OK") {
                    showErrorAlert = false
                    purchaseManager.errorMessage = nil
                }
            } message: {
                if let msg = purchaseManager.errorMessage {
                    Text(msg)
                }
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 48))
                .foregroundStyle(Color.noorRoseGold)

            Text("Your ticket is ready.")
                .font(NoorFont.hero)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Rectangle()
                .fill(Color.noorRoseGold.opacity(0.5))
                .frame(width: 60, height: 1)
        }
        .padding(.top, 8)
    }

    // MARK: - Hero
    private var heroSection: some View {
        VStack(spacing: 12) {
            Text("Unlock unlimited flights.")
                .font(NoorFont.title2)
                .foregroundStyle(Color.noorTextSecondary)
            if let message = proGateMessage {
                Text(message)
                    .font(NoorFont.body)
                    .foregroundStyle(Color.noorRoseGold)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Pricing cards
    private var pricingSection: some View {
        VStack(spacing: 16) {
            // Annual (highlighted) first
            if let yearly = yearlyPackage {
                YearlyPlanCard(package: yearly) {
                    purchase(yearly)
                }
            }
            // Monthly second
            if let monthly = monthlyPackage {
                MonthlyPlanCard(package: monthly) {
                    purchase(monthly)
                }
            }
            if monthlyPackage == nil && yearlyPackage == nil {
                ProgressView()
                    .tint(.white)
                    .frame(height: 120)
            }
        }
    }

    // MARK: - Footer
    private var footerSection: some View {
        VStack(spacing: 16) {
            if let error = purchaseManager.errorMessage {
                Text(error)
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorCoral)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Text("Auto-renews. Cancel anytime in Settings.")
                .font(NoorFont.caption)
                .foregroundStyle(Color.noorTextSecondary.opacity(0.7))

            Button(action: restore) {
                Text("Restore Purchases")
                    .font(NoorFont.callout)
                    .foregroundStyle(Color.noorTextSecondary)
            }
            .buttonStyle(.plain)

            Text("The woman who lives that life invests in herself.")
                .font(NoorFont.caption)
                .foregroundStyle(Color.noorTextSecondary.opacity(0.5))
                .italic()
                .padding(.top, 8)
        }
        .padding(.top, 8)
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            ProgressView()
                .scaleEffect(1.2)
                .tint(.white)
        }
        .allowsHitTesting(true)
    }

    private func purchase(_ package: Package) {
        purchaseManager.errorMessage = nil
        Task { @MainActor in
            let success = await purchaseManager.purchase(package: package)
            if success {
                showSuccess = true
            }
        }
    }

    private func restore() {
        purchaseManager.errorMessage = nil
        Task { @MainActor in
            await purchaseManager.restorePurchases()
            if purchaseManager.isPro {
                showSuccess = true
            }
        }
    }
}

// MARK: - Annual plan card (highlighted)
private struct YearlyPlanCard: View {
    let package: Package
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Annual Pass")
                    .font(NoorFont.title)
                    .foregroundStyle(Color.noorCharcoal)

                Spacer()

                Text("BEST VALUE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.noorSuccess)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(package.localizedPriceString + "/year")
                    .font(NoorFont.largeTitle)
                    .foregroundStyle(Color.noorCharcoal)

                Text("Only $3.33/month")
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorSuccess)
            }

            VStack(alignment: .leading, spacing: 8) {
                paywallFeatureRow("Board 3 flights immediately")
                paywallFeatureRow("Unlimited destinations after")
                paywallFeatureRow("Daily itinerary updates")
                paywallFeatureRow("Progress tracking & proof")
            }

            Button(action: action) {
                Text("Purchase Annual Pass")
                    .font(NoorFont.button)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.noorAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.noorRoseGold, lineWidth: 2)
        )
    }
}

// MARK: - Monthly plan card
private struct MonthlyPlanCard: View {
    let package: Package
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Monthly Pass")
                .font(NoorFont.title)
                .foregroundStyle(Color.noorCharcoal)

            Text(package.localizedPriceString + "/month")
                .font(NoorFont.title2)
                .foregroundStyle(Color.noorCharcoal)

            paywallFeatureRow("Unlimited flights immediately")

            Button(action: action) {
                Text("Purchase Monthly Pass")
                    .font(NoorFont.button)
                    .foregroundStyle(Color.noorViolet)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.noorViolet, lineWidth: 2)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

private func paywallFeatureRow(_ text: String) -> some View {
    HStack(alignment: .center, spacing: 10) {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 16))
            .foregroundStyle(Color.noorSuccess)
        Text(text)
            .font(NoorFont.body)
            .foregroundStyle(Color.noorCharcoal)
    }
}

#Preview {
    PaywallView(onDismiss: {})
}
