//
//  Models.swift
//  leap
//
//  Challenge data and app state models
//

import Foundation

// MARK: - Challenge
struct Challenge: Identifiable {
    let id: String
    let title: String
    let durationMinutes: Int
    let categoryId: ChallengeCategory.Id
    let isFree: Bool

    var durationText: String { "\(durationMinutes) min" }
}

// MARK: - Category
enum ChallengeCategory: String, CaseIterable, Identifiable {
    typealias Id = String
    case career = "Career Growth"
    case solo = "Solo Confidence"
    case financial = "Financial Freedom"

    var id: String { rawValue }

    var challenges: [Challenge] {
        switch self {
        case .career:
            return [
                Challenge(id: "career_1", title: "Text someone you admire and ask one question", durationMinutes: 2, categoryId: id, isFree: true),
                Challenge(id: "career_2", title: "Update your LinkedIn headline to your dream role", durationMinutes: 3, categoryId: id, isFree: false),
                Challenge(id: "career_3", title: "Calculate exactly what your time is worth per hour", durationMinutes: 5, categoryId: id, isFree: false),
            ]
        case .solo:
            return [
                Challenge(id: "solo_1", title: "Book a table for one at a restaurant this week", durationMinutes: 2, categoryId: id, isFree: true),
                Challenge(id: "solo_2", title: "Take yourself on a solo coffee date today", durationMinutes: 1, categoryId: id, isFree: false),
                Challenge(id: "solo_3", title: "Message one person on social media you admire", durationMinutes: 2, categoryId: id, isFree: false),
            ]
        case .financial:
            return [
                Challenge(id: "financial_1", title: "Calculate your monthly expenses down to the dollar", durationMinutes: 10, categoryId: id, isFree: true),
                Challenge(id: "financial_2", title: "Open a high-yield savings account", durationMinutes: 10, categoryId: id, isFree: false),
                Challenge(id: "financial_3", title: "Unsubscribe from 3 brands tempting you to spend", durationMinutes: 3, categoryId: id, isFree: false),
            ]
        }
    }
}

// MARK: - All challenges (flat for "today's challenge" pick)
var allChallenges: [Challenge] {
    ChallengeCategory.allCases.flatMap { $0.challenges }
}

// MARK: - Completion & Streak (UserDefaults keys)
enum StorageKey {
    static let hasSeenOnboarding = "noor_has_seen_onboarding"
    static let completedChallengeIds = "noor_completed_ids"
    static let lastCompletionDate = "noor_last_completion_date"
    static let streakCount = "noor_streak"
}
