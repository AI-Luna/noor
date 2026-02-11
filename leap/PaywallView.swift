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
    @State private var selectedPlan: PlanType = .monthly

    private enum PlanType {
        case monthly, annual
    }

    private var monthlyPackage: Package? {
        purchaseManager.currentOffering?.availablePackages.first { $0.packageType == .monthly }
    }

    private var yearlyPackage: Package? {
        purchaseManager.currentOffering?.availablePackages.first { $0.packageType == .annual }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient matching portal image: deep purple/magenta → fuchsia → warm peach
                LinearGradient(
                    colors: [
                        Color(hex: "5B21B6"), // Deep purple (top of portal)
                        Color(hex: "7C3AED"), // Rich purple
                        Color(hex: "A855F7"), // Magenta
                        Color(hex: "C026D3"), // Fuchsia
                        Color(hex: "D946EF"), // Pink-magenta
                        Color(hex: "EA580C").opacity(0.85) // Warm orange/peach (portal light)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Hero: portal image
                    Image("PaywallPortal")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 220, maxHeight: 220)
                        .padding(.top, 8)

                    Spacer(minLength: 16)

                    // Headline
                    Text("Unlock Unlimited Goals")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.bottom, 16)

                    // Features list
                    featuresSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)

                    // Pricing cards
                    pricingSection
                        .padding(.horizontal, 20)

                    Spacer(minLength: 12)

                    // Footer
                    footerSection
                        .padding(.bottom, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
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

    // MARK: - Features
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow("sparkles", "Create unlimited journeys")
            featureRow("chart.line.uptrend.xyaxis", "Track your progress beautifully")
            featureRow("bell.badge.fill", "Personalized daily reminders")
            featureRow("heart.circle.fill", "Access all vision board features")
        }
    }

    private func featureRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(hex: "FBBF24")) // Warm yellow from portal light
                .frame(width: 24)
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
            Spacer()
        }
    }

    // MARK: - Pricing cards
    private var pricingSection: some View {
        VStack(spacing: 12) {
            // Monthly with free trial (top, highlighted)
            if let monthly = monthlyPackage {
                PaywallPlanCard(
                    title: "3 days Free Trial",
                    subtitle: "Then \(monthly.localizedPriceString) per month. No payment now",
                    isSelected: selectedPlan == .monthly,
                    badge: nil
                ) {
                    selectedPlan = .monthly
                }
            }

            // Annual (below)
            if let yearly = yearlyPackage {
                PaywallPlanCard(
                    title: "Annual Access",
                    subtitle: "Billed yearly at \(yearly.localizedPriceString)",
                    isSelected: selectedPlan == .annual,
                    badge: "SAVE 52%"
                ) {
                    selectedPlan = .annual
                }
            }

            if monthlyPackage == nil && yearlyPackage == nil {
                ProgressView()
                    .tint(.white)
                    .frame(height: 100)
            }
        }
    }

    // MARK: - Footer
    private var footerSection: some View {
        VStack(spacing: 12) {
            Text("Cancel anytime before your trial ends.\nNo risks, no charges.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            // Primary CTA button
            Button(action: purchaseSelected) {
                HStack {
                    Spacer()
                    Text("Try for $0.00")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 24)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "C026D3"), Color(hex: "EA580C").opacity(0.9)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 28))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            Button(action: restore) {
                Text("Restore Purchases")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)

            if let error = purchaseManager.errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.noorCoral)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
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

    private func purchaseSelected() {
        let package: Package?
        switch selectedPlan {
        case .monthly:
            package = monthlyPackage
        case .annual:
            package = yearlyPackage
        }
        guard let pkg = package else { return }
        purchase(pkg)
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

// MARK: - Plan Card
private struct PaywallPlanCard: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "1F2937"))
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "6B7280"))
                }

                Spacer()

                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "C026D3"), Color(hex: "D946EF")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color(hex: "C026D3") : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaywallView(onDismiss: {})
}
