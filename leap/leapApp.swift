//
//  leapApp.swift
//  leap
//
//  Noor: Goal & Habit Tracker — RevenueCat on launch, onboarding gate
//

import SwiftUI
import RevenueCat

@main
struct LeapApp: App {
    @State private var purchaseManager = PurchaseManager.shared
    @State private var dataManager = DataManager.shared

    init() {
        PurchaseManager.shared.configure()
        DataManager.shared.initialize()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(purchaseManager)
                .environment(dataManager)
                .preferredColorScheme(.dark)
        }
    }
}
