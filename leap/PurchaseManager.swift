//
//  PurchaseManager.swift
//  leap
//
//  RevenueCat subscription logic and pro status
//

import Foundation
import RevenueCat
import SwiftUI

@Observable
final class PurchaseManager {
    static let shared = PurchaseManager()

    /// Bypass paywall in DEBUG builds only (TestFlight/Release will enforce the real paywall).
    private static var bypassPaywall: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    private(set) var _isPro: Bool = false
    var isPro: Bool {
        Self.bypassPaywall || _isPro
    }
    var currentOffering: Offering?
    var isLoading: Bool = false
    var errorMessage: String?

    private init() {}

    func configure() {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: "appl_AVqBhmgwruxAfUtlyqDyuPcTNNT")
        Task { await checkProStatus() }
        Task { await loadOfferings() }
    }

    /// Check and log pro status - single source of truth
    @MainActor
    func checkProStatus() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            let proEntitlement = customerInfo.entitlements["Noor Pro"]
            _isPro = proEntitlement?.isActive == true
            
            // Debug logging
            debugLog("=== RevenueCat Status Check ===")
            debugLog("App User ID: \(customerInfo.originalAppUserId)")
            debugLog("Active Entitlements: \(customerInfo.entitlements.active.keys.joined(separator: ", "))")
            debugLog("Pro entitlement active: \(proEntitlement?.isActive ?? false)")
            debugLog("isPro (final): \(_isPro)")
            debugLog("===============================")
        } catch {
            errorMessage = error.localizedDescription
            _isPro = false
            debugLog("checkProStatus error: \(error.localizedDescription)")
        }
    }

    @MainActor
    func loadOfferings() async {
        isLoading = true
        defer { isLoading = false }
        do {
            currentOffering = try await Purchases.shared.offerings().current
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Attempt purchase with proper handling for already-subscribed users
    @MainActor
    func purchase(package: Package) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        // First check if user is already subscribed
        debugLog("Purchase requested - checking current status first...")
        await checkProStatus()
        if _isPro {
            debugLog("User already has active subscription - skipping purchase")
            return true
        }
        
        do {
            debugLog("Attempting purchase for package: \(package.identifier)")
            let result = try await Purchases.shared.purchase(package: package)
            
            if !result.userCancelled {
                // Use the CustomerInfo from the purchase result directly
                let proActive = result.customerInfo.entitlements["Noor Pro"]?.isActive == true
                _isPro = proActive
                debugLog("Purchase completed - pro active: \(proActive)")
                return proActive || Self.bypassPaywall
            } else {
                debugLog("Purchase cancelled by user")
            }
        } catch let error as ErrorCode {
            debugLog("Purchase error code: \(error)")
            
            // Handle "already subscribed" type errors by restoring
            if error == .productAlreadyPurchasedError ||
               error == .receiptAlreadyInUseError {
                debugLog("Already purchased - attempting restore...")
                return await restoreAndCheck()
            }
            errorMessage = error.localizedDescription
        } catch {
            debugLog("Purchase error: \(error.localizedDescription)")
            
            // If purchase fails with any error, try restore as fallback
            // This catches cases where Apple shows "already subscribed" popup
            let nsError = error as NSError
            if nsError.domain == "SKErrorDomain" {
                // SKError codes: 0 = unknown, but user might already own it
                debugLog("StoreKit error - attempting restore as fallback...")
                return await restoreAndCheck()
            }
            errorMessage = error.localizedDescription
        }
        return false
    }

    /// Restore purchases and return whether pro is now active
    @MainActor
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        _ = await restoreAndCheck()
    }
    
    /// Restore and check status - returns true if pro is active after restore
    @MainActor
    func restoreAndCheck() async -> Bool {
        debugLog("Restoring purchases...")
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            let proActive = customerInfo.entitlements["Noor Pro"]?.isActive == true
            _isPro = proActive
            debugLog("Restore completed - pro active: \(proActive)")
            debugLog("Active entitlements after restore: \(customerInfo.entitlements.active.keys.joined(separator: ", "))")
            return proActive || Self.bypassPaywall
        } catch {
            errorMessage = error.localizedDescription
            debugLog("Restore error: \(error.localizedDescription)")
            // Even if restore fails, check current status
            await checkProStatus()
            return _isPro
        }
    }

    func canAccess(challenge: Challenge) -> Bool {
        challenge.isFree || isPro
    }
    
    /// Debug logging helper
    private func debugLog(_ message: String) {
        #if DEBUG
        print("[PurchaseManager] \(message)")
        #endif
        // Also log in TestFlight/Release for debugging subscription issues
        NSLog("[PurchaseManager] %@", message)
    }
}
