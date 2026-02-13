//
//  Theme.swift
//  leap
//
//  Noor brand colors, typography, and design system
//  "Travel agency for life" - luxury magazine aesthetic
//

import SwiftUI

// MARK: - Brand Colors (PRD spec)
extension Color {
    // Primary palette
    static let noorDeepPurple = Color(hex: "1E1B4B")    // Primary gradient start
    static let noorViolet = Color(hex: "9333EA")       // Primary gradient mid
    static let noorOrange = Color(hex: "F97316")       // Primary gradient end
    static let noorAccent = Color(hex: "FF2D75")       // Pink/magenta for CTAs
    static let noorRoseGold = Color(hex: "DD8625")     // Icons and highlights (warm amber)
    static let noorAmber = Color(hex: "DD8625")         // Warm amber for habits
    static let noorSuccess = Color(hex: "10B981")      // Green - completions
    static let noorBackground = Color(hex: "0F0A1E")   // Deep purple-black

    // Text colors
    static let noorTextPrimary = Color.white
    static let noorTextSecondary = Color(hex: "E9D5FF") // Light purple

    // Legacy aliases for compatibility
    static let noorPink = noorAccent
    static let noorTeal = Color(hex: "4ECDC4")
    static let noorCoral = Color(hex: "FF6B6B")
    static let noorCream = Color(hex: "FAF9F6")
    static let noorCharcoal = Color(hex: "333333")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Typography (Luxury magazine feel)
struct NoorFont {
    // Headings — keep serif for luxury feel
    static let hero = Font.system(size: 40, weight: .bold, design: .serif)
    static let largeTitle = Font.system(size: 32, weight: .bold, design: .serif)
    static let title = Font.system(size: 24, weight: .bold, design: .serif)
    static let title2 = Font.system(size: 18, weight: .semibold, design: .serif)
    static let button = Font.system(size: 18, weight: .bold, design: .serif)
    // Body/subtext — normal system font (matches FROM/TO content style)
    static let bodyText = Font.system(size: 15, weight: .regular)
    static let bodyLarge = Font.system(size: 18, weight: .regular)
    static let body = Font.system(size: 15, weight: .regular)
    static let callout = Font.system(size: 15, weight: .regular)
    static let caption = Font.system(size: 14, weight: .regular)
    // Onboarding only — keep original serif body fonts
    static let onboardingBodyLarge = Font.system(size: 18, weight: .regular, design: .serif)
    static let onboardingBody = Font.system(size: 16, weight: .regular, design: .serif)
    static let onboardingCallout = Font.system(size: 15, weight: .medium, design: .serif)
    static let onboardingCaption = Font.system(size: 14, weight: .regular, design: .serif)
}

// MARK: - Gradients (PRD spec)
extension LinearGradient {
    // Primary app gradient - deep purple to violet to orange
    static let noorPrimary = LinearGradient(
        colors: [
            Color.noorDeepPurple,
            Color.noorViolet,
            Color.noorOrange
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Simpler two-color gradient for cards
    static let noorPurpleOrange = LinearGradient(
        colors: [
            Color.noorDeepPurple,
            Color.noorViolet
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Background gradient
    static let noorDark = LinearGradient(
        colors: [
            Color.noorBackground,
            Color.noorDeepPurple.opacity(0.8)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    // Legacy alias
    static let noorPurpleBlue = noorPurpleOrange
}

// MARK: - Layout
struct NoorLayout {
    static let cornerRadius: CGFloat = 16
    static let cornerRadiusLarge: CGFloat = 24
    static let buttonHeight: CGFloat = 56
    static let cardShadowRadius: CGFloat = 8
    static let cardShadowY: CGFloat = 2
    static let horizontalPadding: CGFloat = 20
}

// MARK: - Goal Categories (PRD spec)
enum GoalCategory: String, CaseIterable, Identifiable {
    case travel = "travel"
    case career = "career"
    case finance = "finance"
    case growth = "growth"
    case relationship = "relationship"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .travel: return "Solo to a new continent"
        case .career: return "Career move to dream role"
        case .finance: return "Financial freedom territory"
        case .growth: return "Personal growth journey"
        case .relationship: return "New relationship era"
        }
    }

    var shortName: String {
        switch self {
        case .travel: return "Travel"
        case .career: return "Career"
        case .finance: return "Finance"
        case .growth: return "Growth"
        case .relationship: return "Relationship"
        }
    }

    var icon: String {
        switch self {
        case .travel: return "airplane"
        case .career: return "briefcase.fill"
        case .finance: return "dollarsign.circle.fill"
        case .growth: return "leaf.fill"
        case .relationship: return "heart.fill"
        }
    }

    var travelAgencyTitle: String {
        switch self {
        case .travel: return "Perfect. Where's your first destination?"
        case .career: return "What's the role you're moving into?"
        case .finance: return "What does financial freedom look like for you?"
        case .growth: return "What transformation are you stepping into?"
        case .relationship: return "What does your ideal relationship look like?"
        }
    }

    var destinationPlaceholder: String {
        switch self {
        case .travel: return "Iceland"
        case .career: return "Senior Product Manager at a tech startup"
        case .finance: return "$100K saved, debt-free"
        case .growth: return "Confident public speaker"
        case .relationship: return "Healthy, loving partnership"
        }
    }

    var storyPrompt: String {
        switch self {
        case .travel: return "What makes this trip special to you?"
        case .career: return "Why does this role matter to you?"
        case .finance: return "What will this freedom give you?"
        case .growth: return "Why is this transformation important?"
        case .relationship: return "What does this relationship mean to you?"
        }
    }
}
