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
                LinearGradient(
                    colors: [
                        Color(red: 0.58, green: 0.2, blue: 0.8),
                        Color(red: 0.2, green: 0.4, blue: 0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
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
        Text("Unlock unlimited goals & features")
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
    }

    // MARK: - Hero
    private var heroSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.9))
            Text("Build habits that stick.")
                .font(NoorFont.title2)
                .foregroundStyle(.white.opacity(0.95))
            if let message = proGateMessage {
                Text(message)
                    .font(NoorFont.callout)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    // MARK: - Pricing cards
    private var pricingSection: some View {
        VStack(spacing: 16) {
            if let monthly = monthlyPackage {
                MonthlyPlanCard(package: monthly) {
                    purchase(monthly)
                }
            }
            if let yearly = yearlyPackage {
                YearlyPlanCard(package: yearly) {
                    purchase(yearly)
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
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.75))

            Button(action: restore) {
                Text("Restore Purchases")
                    .font(NoorFont.callout)
                    .foregroundStyle(.white.opacity(0.95))
            }
            .buttonStyle(.plain)
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

// MARK: - Monthly plan card
private struct MonthlyPlanCard: View {
    let package: Package
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(package.localizedPriceString)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.noorCharcoal)
                    Text("Billed monthly")
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorCharcoal.opacity(0.7))
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                paywallFeatureRow("Unlimited goals")
                paywallFeatureRow("Daily challenges")
                paywallFeatureRow("Analytics")
            }

            Button(action: action) {
                Text("Subscribe Monthly")
                    .font(NoorFont.title2)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(red: 0.2, green: 0.4, blue: 0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Yearly plan card (recommended)
private struct YearlyPlanCard: View {
    let package: Package
    let action: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(package.localizedPriceString)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.noorCharcoal)
                        Text("Save 58%")
                            .font(NoorFont.caption)
                            .foregroundStyle(Color.noorTeal)
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    paywallFeatureRow("Everything in Monthly")
                    paywallFeatureRow("Priority support")
                }

                Button(action: action) {
                    Text("Get Yearly Plan")
                        .font(NoorFont.title2)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.noorPink)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)

            Text("5 DAYS FREE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "27AE60"))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(12)
        }
    }
}

private func paywallFeatureRow(_ text: String) -> some View {
    HStack(alignment: .center, spacing: 10) {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 16))
            .foregroundStyle(Color.noorTeal)
        Text(text)
            .font(NoorFont.body)
            .foregroundStyle(Color.noorCharcoal)
    }
}

#Preview {
    PaywallView(onDismiss: {})
}
