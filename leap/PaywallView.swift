//
//  PaywallView.swift
//  leap
//
//  RevenueCat subscription — Become a Seeker, monthly/yearly, restore
//

import SwiftUI
import RevenueCat

struct PaywallView: View {
    var onDismiss: () -> Void

    private let purchaseManager = PurchaseManager.shared
    @State private var selectedPackage: Package?
    @State private var isPurchasing = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.noorCream.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 28) {
                        VStack(spacing: 8) {
                            Text("Become a Seeker")
                                .font(NoorFont.largeTitle)
                                .foregroundStyle(Color.noorCharcoal)
                            Text("Your boldest year starts now")
                                .font(NoorFont.body)
                                .foregroundStyle(Color.noorCharcoal.opacity(0.8))
                        }
                        .padding(.top, 20)

                        VStack(alignment: .leading, spacing: 12) {
                            featureRow("50+ micro-challenges across all categories")
                            featureRow("Career, money, travel & confidence growth")
                            featureRow("Streak rewards & insights")
                            featureRow("Community challenges")
                            featureRow("Monthly progress report")
                        }
                        .padding(.horizontal)

                        // Pricing
                        if let packages = purchaseManager.currentOffering?.availablePackages, !packages.isEmpty {
                            VStack(spacing: 12) {
                                ForEach(Array(packages.enumerated()), id: \.element.identifier) { _, pkg in
                                    let isYearly = pkg.packageType == .annual
                                    Button {
                                        selectedPackage = pkg
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(isYearly ? "Yearly" : "Monthly")
                                                    .font(NoorFont.callout)
                                                    .foregroundStyle(Color.noorCharcoal)
                                                if isYearly {
                                                    Text("Save 33%")
                                                        .font(NoorFont.caption)
                                                        .foregroundStyle(Color.noorTeal)
                                                }
                                            }
                                            Spacer()
                                            Text(pkg.localizedPriceString)
                                                .font(NoorFont.title2)
                                                .foregroundStyle(Color.noorCharcoal)
                                        }
                                        .padding(16)
                                        .background(selectedPackage?.identifier == pkg.identifier ? Color.noorPink.opacity(0.15) : Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: NoorLayout.cornerRadius))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: NoorLayout.cornerRadius)
                                                .stroke(selectedPackage?.identifier == pkg.identifier ? Color.noorPink : Color.clear, lineWidth: 2)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            ProgressView()
                                .padding()
                        }

                        if let error = purchaseManager.errorMessage {
                            Text(error)
                                .font(NoorFont.caption)
                                .foregroundStyle(Color.noorCoral)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        VStack(spacing: 12) {
                            PrimaryButton(
                                title: selectedPackage?.packageType == .annual ? "Start 7-Day Free Trial" : "Subscribe",
                                action: purchase
                            )
                            .disabled(selectedPackage == nil || isPurchasing)

                            SecondaryButton(title: "Restore Purchases", action: restore)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onDismiss() }
                        .foregroundStyle(Color.noorPink)
                }
            }
            .onAppear {
                if purchaseManager.currentOffering == nil {
                    Task { await purchaseManager.loadOfferings() }
                }
                selectedPackage = purchaseManager.currentOffering?.availablePackages.first
            }
        }
    }

    private func featureRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.noorTeal)
            Text(text)
                .font(NoorFont.body)
                .foregroundStyle(Color.noorCharcoal)
        }
    }

    private func purchase() {
        guard let package = selectedPackage else { return }
        isPurchasing = true
        Task { @MainActor in
            let success = await purchaseManager.purchase(package: package)
            isPurchasing = false
            if success { onDismiss() }
        }
    }

    private func restore() {
        isPurchasing = true
        Task { @MainActor in
            await purchaseManager.restorePurchases()
            isPurchasing = false
            if purchaseManager.isPro { onDismiss() }
        }
    }
}

#Preview {
    PaywallView(onDismiss: {})
}
