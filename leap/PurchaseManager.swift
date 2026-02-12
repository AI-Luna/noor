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

    @MainActor
    func checkProStatus() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            _isPro = customerInfo.entitlements["pro"]?.isActive == true
        } catch {
            errorMessage = error.localizedDescription
            _isPro = false
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

    @MainActor
    func purchase(package: Package) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if !result.userCancelled {
                await checkProStatus()
                return _isPro || Self.bypassPaywall
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        return false
    }

    @MainActor
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            _ = try await Purchases.shared.restorePurchases()
            await checkProStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func canAccess(challenge: Challenge) -> Bool {
        challenge.isFree || isPro
    }
}
