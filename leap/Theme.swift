//
//  Theme.swift
//  leap
//
//  Noor brand colors and typography
//

import SwiftUI

// MARK: - Brand Colors (exact hex)
extension Color {
    static let noorPink = Color(hex: "E91E8C")      // Hot pink - primary
    static let noorTeal = Color(hex: "4ECDC4")     // Teal - secondary
    static let noorCoral = Color(hex: "FF6B6B")     // Coral - accents
    static let noorCream = Color(hex: "FAF9F6")     // Off-white background
    static let noorCharcoal = Color(hex: "333333")  // Text color

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

// MARK: - Typography
struct NoorFont {
    static let largeTitle = Font.system(size: 28, weight: .bold)
    static let title = Font.system(size: 22, weight: .bold)
    static let title2 = Font.system(size: 18, weight: .semibold)
    static let body = Font.system(size: 16, weight: .regular)
    static let callout = Font.system(size: 15, weight: .medium)
    static let caption = Font.system(size: 13, weight: .regular)
}

// MARK: - Gradients (Dashboard / design system)
extension LinearGradient {
    static let noorPurpleBlue = LinearGradient(
        colors: [
            Color(red: 0.58, green: 0.2, blue: 0.8),   // deep purple
            Color(red: 0.2, green: 0.4, blue: 0.9)     // deep blue
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Layout
struct NoorLayout {
    static let cornerRadius: CGFloat = 16
    static let buttonHeight: CGFloat = 56
    static let cardShadowRadius: CGFloat = 8
    static let cardShadowY: CGFloat = 2
}
