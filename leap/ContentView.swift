//
//  ContentView.swift
//  leap
//
//  App shell: onboarding gate then TabView (Home, Goals, Profile)
//

import SwiftUI

struct ContentView: View {
    @Environment(PurchaseManager.self) private var purchaseManager
    @Environment(DataManager.self) private var dataManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var showPurchaseErrorAlert = false

    var body: some View {
        if !hasCompletedOnboarding {
            WelcomeView(onFinish: {
                hasCompletedOnboarding = true
            })
        } else {
            TabView {
                DashboardView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                GoalsListView()
                    .tabItem {
                        Label("Goals", systemImage: "target")
                    }
                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.fill")
                    }
            }
            .tint(Color.noorPink)
            .onChange(of: purchaseManager.errorMessage) { _, newValue in
                showPurchaseErrorAlert = (newValue != nil && !(newValue?.isEmpty ?? true))
            }
            .alert("Error", isPresented: $showPurchaseErrorAlert) {
                Button("OK") {
                    showPurchaseErrorAlert = false
                    purchaseManager.errorMessage = nil
                }
            } message: {
                if let msg = purchaseManager.errorMessage {
                    Text(msg)
                }
            }
        }
    }
}
