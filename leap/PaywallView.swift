//
//  PaywallView.swift
//  leap
//
//  RevenueCat Paywalls UI wrapper - uses remotely configured paywalls
//

import SwiftUI
import RevenueCat
import RevenueCatUI

/// Wrapper around RevenueCatUI's PaywallView for use in sheets
struct NoorPaywallView: View {
    var onDismiss: () -> Void
    var proGateMessage: String? = nil
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSuccess = false
    @State private var isCheckingStatus = true
    
    var body: some View {
        ZStack {
            if isCheckingStatus {
                // Show loading while checking subscription status
                Color.black
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView()
                            .tint(.white)
                    }
            } else {
                RevenueCatUI.PaywallView(displayCloseButton: true)
                    .onPurchaseCompleted { customerInfo in
                        handlePurchaseOrRestore(customerInfo: customerInfo, source: "Purchase")
                    }
                    .onRestoreCompleted { customerInfo in
                        handlePurchaseOrRestore(customerInfo: customerInfo, source: "Restore")
                    }
            }
        }
        .alert("Welcome to Noor Pro!", isPresented: $showSuccess) {
            Button("Continue") {
                showSuccess = false
                onDismiss()
            }
        } message: {
            Text("Your premium features are now active. Create unlimited goals and unlock all features.")
        }
        .task {
            await checkAndDismissIfSubscribed()
        }
        // Re-check when app becomes active (catches "already subscribed" dialog dismissal)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active && oldPhase == .inactive {
                NSLog("[PaywallView] App became active - re-checking subscription status")
                Task {
                    await recheckAfterStoreInteraction()
                }
            }
        }
        // Also listen for notification from RevenueCat about customer info updates
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("com.revenuecat.purchases.customerInfo.updated"))) { _ in
            NSLog("[PaywallView] CustomerInfo updated notification received")
            Task {
                await recheckAfterStoreInteraction()
            }
        }
    }
    
    /// Check subscription status on appear - dismiss immediately if already Pro
    private func checkAndDismissIfSubscribed() async {
        NSLog("[PaywallView] Checking subscription status on appear...")
        await PurchaseManager.shared.checkProStatus()
        
        if PurchaseManager.shared._isPro {
            NSLog("[PaywallView] User already has active subscription - dismissing paywall")
            await MainActor.run {
                onDismiss()
            }
        } else {
            NSLog("[PaywallView] No active subscription - showing paywall")
            await MainActor.run {
                isCheckingStatus = false
            }
        }
    }
    
    /// Re-check status after Store Kit interaction (e.g., "already subscribed" dialog)
    private func recheckAfterStoreInteraction() async {
        // Small delay to let StoreKit/RevenueCat sync
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await PurchaseManager.shared.checkProStatus()
        
        if PurchaseManager.shared._isPro {
            NSLog("[PaywallView] User now has active subscription after re-check - dismissing")
            await MainActor.run {
                showSuccess = true
            }
        }
    }
    
    /// Handle purchase or restore completion
    private func handlePurchaseOrRestore(customerInfo: CustomerInfo, source: String) {
        NSLog("[PaywallView] \(source) completed")
        NSLog("[PaywallView] Active entitlements: \(customerInfo.entitlements.active.keys.joined(separator: ", "))")
        
        let proActive = customerInfo.entitlements["pro"]?.isActive == true
        
        if proActive {
            // Refresh global state
            Task { await PurchaseManager.shared.checkProStatus() }
            showSuccess = true
        } else {
            NSLog("[PaywallView] \(source) completed but pro not active - checking again...")
            // Sometimes the callback info is stale, refetch
            Task {
                await PurchaseManager.shared.checkProStatus()
                if PurchaseManager.shared._isPro {
                    await MainActor.run {
                        showSuccess = true
                    }
                }
            }
        }
    }
}

// MARK: - Legacy PaywallView (alias for backwards compatibility)
/// Use this in existing .sheet() presentations
struct PaywallView: View {
    var onDismiss: () -> Void
    var proGateMessage: String? = nil
    
    var body: some View {
        NoorPaywallView(onDismiss: onDismiss, proGateMessage: proGateMessage)
    }
}

#Preview {
    PaywallView(onDismiss: {})
}
