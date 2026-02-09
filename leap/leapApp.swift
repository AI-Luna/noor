//
//  leapApp.swift
//  leap
//
//  Noor: Goal & Habit Tracker — RevenueCat on launch, onboarding gate
//

import SwiftUI

@main
struct leapApp: App {
    @State private var hasSeenOnboarding: Bool = UserDefaults.standard.bool(forKey: StorageKey.hasSeenOnboarding)

    init() {
        PurchaseManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            if hasSeenOnboarding {
                ContentView()
            } else {
                WelcomeView(onFinish: {
                    UserDefaults.standard.set(true, forKey: StorageKey.hasSeenOnboarding)
                    hasSeenOnboarding = true
                })
            }
        }
    }
}
