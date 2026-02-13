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
