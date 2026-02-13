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
    
    var body: some View {
        RevenueCatUI.PaywallView(displayCloseButton: true)
            .onPurchaseCompleted { customerInfo in
                print("Purchase completed: \(customerInfo.entitlements)")
                showSuccess = true
            }
            .onRestoreCompleted { customerInfo in
                print("Restore completed: \(customerInfo.entitlements)")
                if customerInfo.entitlements["pro"]?.isActive == true {
                    showSuccess = true
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
