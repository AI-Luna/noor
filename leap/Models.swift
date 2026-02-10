//
//  Models.swift
//  leap
//
//  SwiftData models + challenge data and app state
//

import Foundation
import SwiftData

// MARK: - SwiftData Models

@Model
final class Goal {
    @Attribute(.unique) var id: UUID
    var title: String
    var goalDescription: String
    var category: String
    var createdAt: Date
    var targetDaysPerWeek: Int // 1-7
    var currentStreak: Int
    var longestStreak: Int
    @Relationship(inverse: \DailyTask.goal) var dailyTasks: [DailyTask] = []
    var isPremiumFeature: Bool = false

    init(id: UUID = UUID(), title: String, goalDescription: String, category: String, createdAt: Date = .now, targetDaysPerWeek: Int, currentStreak: Int = 0, longestStreak: Int = 0, isPremiumFeature: Bool = false) {
        self.id = id
        self.title = title
        self.goalDescription = goalDescription
        self.category = category
        self.createdAt = createdAt
        self.targetDaysPerWeek = targetDaysPerWeek
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.isPremiumFeature = isPremiumFeature
    }
}

@Model
final class DailyTask {
    @Attribute(.unique) var id: UUID
    var goalID: String
    var title: String
    var taskDescription: String
    var completedDates: [Date]
    var createdAt: Date
    var order: Int
    var goal: Goal?

    init(id: UUID = UUID(), goalID: String, title: String, taskDescription: String, completedDates: [Date] = [], createdAt: Date = .now, order: Int, goal: Goal? = nil) {
        self.id = id
        self.goalID = goalID
        self.title = title
        self.taskDescription = taskDescription
        self.completedDates = completedDates
        self.createdAt = createdAt
        self.order = order
        self.goal = goal
    }
}

@Model
final class Streak {
    @Attribute(.unique) var id: UUID
    var goalID: String
    var currentCount: Int
    var longestCount: Int
    var lastCompletedDate: Date
    var startDate: Date

    init(id: UUID = UUID(), goalID: String, currentCount: Int, longestCount: Int, lastCompletedDate: Date, startDate: Date) {
        self.id = id
        self.goalID = goalID
        self.currentCount = currentCount
        self.longestCount = longestCount
        self.lastCompletedDate = lastCompletedDate
        self.startDate = startDate
    }
}

@Model
final class PremiumChallenge {
    @Attribute(.unique) var id: UUID
    var title: String
    var challengeDescription: String
    var durationDays: Int // 3, 7, 14, 30
    var category: String
    var isFree: Bool
    var tasks: [String]

    init(id: UUID = UUID(), title: String, challengeDescription: String, durationDays: Int, category: String, isFree: Bool, tasks: [String]) {
        self.id = id
        self.title = title
        self.challengeDescription = challengeDescription
        self.durationDays = durationDays
        self.category = category
        self.isFree = isFree
        self.tasks = tasks
    }
}

// MARK: - Challenge (micro-challenges for Today / Categories)
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
