# Noor Technical Documentation

## Tech Stack

**Language:** Swift  
**UI Framework:** SwiftUI  
**Data Persistence:** SwiftData (local first architecture)  
**Data Models:** Goal, DailyTask, Streak, Microhabit, TravelPin  
**Platform:** iOS (native)  
**Subscriptions:** RevenueCat (SDK purchases-ios, integrated via SPM)  
**Paywall UI:** RevenueCatUI (remote paywall from RevenueCat dashboard)  
**AI:** Anthropic Claude API (REST) for generating 7-step challenge itineraries  
**Additional Frameworks:** UserNotifications, MapKit, MessageUI  

## Architecture

**App Entry:** leapApp.swift creates PurchaseManager.shared and DataManager.shared, injecting them via .environment() into the SwiftUI view hierarchy.

**Data Layer:** DataManager (@Observable, @MainActor) owns the SwiftData ModelContainer and ModelContext. All persistence operations (goals, tasks, habits, travel pins) flow through DataManager for a single source of truth.

**Subscription State:** PurchaseManager (@Observable) is the single source of truth for Pro status. It's configured at app launch, exposes isPro and currentOffering properties, and provides purchase() and restore() methods.

**UI Structure:** Tab-based navigation (Home, Progress, Passport, Habits). Main flows include Onboarding, Dashboard (home screen), CreateGoalView (add journey), and detail views for habits and journeys. No separate backend; Claude API calls go directly from the app to Anthropic.

## RevenueCat Implementation

RevenueCat is configured at app launch via a single shared PurchaseManager that holds Pro status and current offerings. The app uses one entitlement, `pro`, and gates creation of additional journeys (goals) after the first one. Paywalls use RevenueCatUI's remote paywall (onboarding displays without a close button; in-app sheets include a close button). Purchase and restore callbacks check `customerInfo.entitlements["pro"]?.isActive` and refresh Pro status; the rest of the app reads `PurchaseManager.isPro` from the SwiftUI environment. Offerings and products are managed in the RevenueCat dashboard.

### Configuration

RevenueCat API key is stored in the app's configuration (e.g., Xcode build settings or environment variables). Configuration happens once at app launch in PurchaseManager.configure(), called from leapApp.init().

### Entitlements

Single entitlement: `pro`  
Pro status is determined by: `customerInfo.entitlements["pro"]?.isActive == true`

### Where RevenueCat Is Used

| Location | Use |
|----------|-----|
| leapApp.swift | Injects PurchaseManager into the SwiftUI environment |
| OnboardingView | Post-onboarding paywall (RevenueCatUI.PaywallView with displayCloseButton: false); on purchase/restore success, checks entitlements and completes onboarding |
| CreateGoalView | Presents paywall when user tries to create a second goal and is not Pro |
| DashboardView | "Book a Flight" button gated by purchaseManager.isPro \|\| goals.count < 1; presents paywall when needed |
| PaywallView.swift | Wraps RevenueCatUI.PaywallView (displayCloseButton: true); handles purchase and restore callbacks, dismisses and shows success confirmation |
| SettingsView / ProfileView | Restore purchases button; displays Pro status and opens paywall for upgrade |
| CategoriesView | Presents paywall when accessing locked content |

### Purchase Flow

Offerings are loaded at app launch via `Purchases.shared.offerings().current`.  
Packages (annual and monthly) are configured in the RevenueCat dashboard.  
Purchase: `Purchases.shared.purchase(package:)` triggers the purchase flow; on success, `checkProStatus()` is called and `PurchaseManager.isPro` updates the UI.  
Restore: `Purchases.shared.restorePurchases()` followed by `checkProStatus()`.  
Paywall content (products, copy, trial duration) is configured remotely in the RevenueCat dashboard.

### Pro Gating Logic

First journey is free; additional journeys require Pro.  
Gate: `existingGoalCount >= 1 && !purchaseManager.isPro`  
Dashboard create button: `purchaseManager.isPro || goals.count < 1`
