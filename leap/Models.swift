//
//  Models.swift
//  leap
//
//  SwiftData models + challenge data and app state
//  "Travel agency for life" - goals as flights, challenges as itinerary steps
//

import Foundation
import SwiftData

// MARK: - SwiftData Models

@Model
final class Goal {
    @Attribute(.unique) var id: UUID
    var title: String
    var goalDescription: String
    var category: String // GoalCategory rawValue
    var createdAt: Date

    // Travel agency framing
    var destination: String // The specific goal (e.g., "Iceland", "Senior PM", "$100K")
    var timeline: String // When (e.g., "June 2026")
    var userStory: String // Why it matters to them
    var boardingPass: String // AI-generated encouragement message

    // Progress tracking
    var currentStreak: Int
    var longestStreak: Int
    var lastActionDate: Date?

    // Challenges (sequential unlocking)
    @Relationship(inverse: \DailyTask.goal) var dailyTasks: [DailyTask] = []

    // Legacy support
    var targetDaysPerWeek: Int
    var isPremiumFeature: Bool = false

    // Computed progress
    var progress: Double {
        guard !dailyTasks.isEmpty else { return 0 }
        let completed = dailyTasks.filter { $0.isCompleted }.count
        return Double(completed) / Double(dailyTasks.count) * 100
    }

    var isComplete: Bool {
        progress >= 100
    }

    // Current challenge (first unlocked, uncompleted)
    var currentChallenge: DailyTask? {
        dailyTasks
            .sorted { $0.order < $1.order }
            .first { $0.isUnlocked && !$0.isCompleted }
    }

    init(
        id: UUID = UUID(),
        title: String,
        goalDescription: String,
        category: String,
        destination: String = "",
        timeline: String = "",
        userStory: String = "",
        boardingPass: String = "",
        createdAt: Date = .now,
        targetDaysPerWeek: Int = 7,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastActionDate: Date? = nil,
        isPremiumFeature: Bool = false
    ) {
        self.id = id
        self.title = title
        self.goalDescription = goalDescription
        self.category = category
        self.destination = destination
        self.timeline = timeline
        self.userStory = userStory
        self.boardingPass = boardingPass
        self.createdAt = createdAt
        self.targetDaysPerWeek = targetDaysPerWeek
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastActionDate = lastActionDate
        self.isPremiumFeature = isPremiumFeature
    }
}

@Model
final class DailyTask {
    @Attribute(.unique) var id: UUID
    var goalID: String
    var title: String
    var taskDescription: String
    var estimatedTime: String // e.g., "5 min", "15 min"
    var completedDates: [Date]
    var createdAt: Date
    var order: Int // 0-6 for sequential unlocking
    var isUnlocked: Bool // Sequential unlocking
    var goal: Goal?

    // Computed properties
    var isCompleted: Bool {
        !completedDates.isEmpty
    }

    var completedAt: Date? {
        completedDates.first
    }

    init(
        id: UUID = UUID(),
        goalID: String,
        title: String,
        taskDescription: String,
        estimatedTime: String = "",
        completedDates: [Date] = [],
        createdAt: Date = .now,
        order: Int,
        isUnlocked: Bool = false,
        goal: Goal? = nil
    ) {
        self.id = id
        self.goalID = goalID
        self.title = title
        self.taskDescription = taskDescription
        self.estimatedTime = estimatedTime
        self.completedDates = completedDates
        self.createdAt = createdAt
        self.order = order
        self.isUnlocked = isUnlocked
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

// MARK: - Microhabit (timeframe, vision tag, custom tag, focus timer, reminder frequency)
@Model
final class Microhabit {
    @Attribute(.unique) var id: UUID
    var title: String
    var habitDescription: String
    var goalID: String? // tag to a vision (journey/goal)
    var customTag: String? // optional label e.g. "Health", "Morning routine"
    var focusDurationMinutes: Int
    var typeRaw: String
    var timeframeRaw: String? // "morning" | "afternoon" | "nightly" | "rightNow" | nil = anytime
    var reminderFrequencyRaw: String?
    var reminderHour: Int?    // 0–23, when to remind (optional for backward compatibility)
    var reminderMinute: Int?  // 0–59
    var completedDates: [Date]
    var createdAt: Date

    @Transient
    var type: MicrohabitType {
        MicrohabitType(rawValue: typeRaw) ?? .create
    }

    @Transient
    var timeframe: HabitTimeframe {
        get { timeframeRaw.flatMap { HabitTimeframe(rawValue: $0) } ?? .anytime }
        set { timeframeRaw = newValue.rawValue }
    }

    @Transient
    var reminderFrequency: HabitReminderFrequency {
        get { reminderFrequencyRaw.flatMap { HabitReminderFrequency(rawValue: $0) } ?? .never }
        set { reminderFrequencyRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        habitDescription: String = "",
        goalID: String? = nil,
        customTag: String? = nil,
        focusDurationMinutes: Int = 5,
        type: MicrohabitType = .create,
        timeframe: HabitTimeframe = .anytime,
        reminderFrequency: HabitReminderFrequency = .never,
        reminderHour: Int? = 9,
        reminderMinute: Int? = 0,
        completedDates: [Date] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.habitDescription = habitDescription
        self.goalID = goalID
        self.customTag = customTag
        self.focusDurationMinutes = focusDurationMinutes
        self.typeRaw = type.rawValue
        self.timeframeRaw = timeframe.rawValue
        self.reminderFrequencyRaw = reminderFrequency.rawValue
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.completedDates = completedDates
        self.createdAt = createdAt
    }

    @Transient
    var hasFocusTimer: Bool { focusDurationMinutes > 0 }
}

enum HabitTimeframe: String, CaseIterable {
    case anytime = "anytime"
    case morning = "morning"
    case afternoon = "afternoon"
    case nightly = "nightly"
    case rightNow = "rightNow"

    var displayName: String {
        switch self {
        case .anytime: return "Anytime"
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .nightly: return "Nightly"
        case .rightNow: return "Right now"
        }
    }

    var icon: String {
        switch self {
        case .anytime: return "sun.max"
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.noon.fill"
        case .nightly: return "moon.stars.fill"
        case .rightNow: return "bolt.fill"
        }
    }

    /// Order for grouping (same order as CaseIterable)
    static var displayOrder: [HabitTimeframe] { [.rightNow, .morning, .afternoon, .nightly, .anytime] }
}

enum HabitReminderFrequency: String, CaseIterable {
    case never = "never"
    case daily = "daily"
    case weekdays = "weekdays"
    case weekends = "weekends"

    var displayName: String {
        switch self {
        case .never: return "No reminders"
        case .daily: return "Every day"
        case .weekdays: return "Weekdays"
        case .weekends: return "Weekends"
        }
    }

    var icon: String {
        switch self {
        case .never: return "bell.slash"
        case .daily: return "bell.fill"
        case .weekdays: return "calendar"
        case .weekends: return "calendar.badge.clock"
        }
    }
}

enum MicrohabitType: String, CaseIterable {
    case create = "create"
    case replace = "replace"

    var displayName: String {
        switch self {
        case .create: return "Create a habit"
        case .replace: return "Replace a bad habit"
        }
    }

    var subtitle: String {
        switch self {
        case .create: return "Start a new habit that will have remarkable results."
        case .replace: return "Redirect the time and energy towards a good habit instead."
        }
    }
}

// MARK: - User Profile (stored in UserDefaults)
struct UserProfile: Codable {
    var name: String
    var gender: Gender
    var hasSubscription: Bool
    var subscriptionType: SubscriptionType?
    var freeGoalsRemaining: Int // For annual plan (starts at 3)
    var streak: Int
    var lastActionDate: Date?
    var onboardingCompleted: Bool
    var createdAt: Date

    enum Gender: String, Codable {
        case woman, man, nonBinary = "non-binary"
    }

    enum SubscriptionType: String, Codable {
        case annual, monthly
    }

    static var `default`: UserProfile {
        UserProfile(
            name: "",
            gender: .woman,
            hasSubscription: false,
            subscriptionType: nil,
            freeGoalsRemaining: 3,
            streak: 0,
            lastActionDate: nil,
            onboardingCompleted: false,
            createdAt: .now
        )
    }
}

// MARK: - Storage Keys
enum StorageKey {
    static let hasSeenOnboarding = "noor_has_seen_onboarding"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let userProfile = "noor_user_profile"
    static let completedChallengeIds = "noor_completed_ids"
    static let lastCompletionDate = "noor_last_completion_date"
    static let streakCount = "noor_streak"
    static let freeGoalsRemaining = "noor_free_goals"
    static let firstGoalData = "noor_first_goal"
    static let visionBoards = "noor_vision_boards"
    static let visionItems = "noor_vision_items"
    static let guestPassCount = "noor_guest_pass_count"
    static let lastDailyFlameDate = "noor_last_daily_flame_date"
}

// MARK: - Vision item: inspiration + action (Pinterest, destination, or link); can link to a journey
struct VisionItem: Codable, Identifiable {
    var id: UUID
    var kindRaw: String // "pinterest" | "destination" | "action" | "instagram"
    var title: String
    var url: String?
    var placeName: String? // for destination
    var goalID: String?   // link to a journey/dream
    var completedAt: Date? // accountability: marked done

    var kind: VisionItemKind {
        get { VisionItemKind(rawValue: kindRaw) ?? .pinterest }
        set { kindRaw = newValue.rawValue }
    }

    var isCompleted: Bool { completedAt != nil }

    init(id: UUID = UUID(), kind: VisionItemKind, title: String, url: String? = nil, placeName: String? = nil, goalID: String? = nil, completedAt: Date? = nil) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.title = title
        self.url = url
        self.placeName = placeName
        self.goalID = goalID
        self.completedAt = completedAt
    }
}

// Suggested actions for "choose your own" to get ideas going
enum VisionActionSuggestion: String, CaseIterable {
    case messageSomeone = "Message someone"
    case updateLinkedIn = "Update LinkedIn"
    case bookFlight = "Book a flight"
    case researchCourse = "Research a course"
    case scheduleCall = "Schedule a call"
    case sendEmail = "Send an email"
    case buySomething = "Buy something I need"
    case applyToJob = "Apply to a job"
    case other = "Other (custom)"

    var urlPlaceholder: String? {
        switch self {
        case .updateLinkedIn: return "https://linkedin.com"
        case .other, .messageSomeone, .bookFlight, .researchCourse, .scheduleCall, .sendEmail, .buySomething, .applyToJob: return nil
        }
    }
}

enum VisionItemKind: String, CaseIterable {
    case pinterest = "pinterest"
    case instagram = "instagram"
    case destination = "destination"
    case action = "action"

    var displayName: String {
        switch self {
        case .pinterest: return "Pinterest board"
        case .instagram: return "Instagram post or profile"
        case .destination: return "Place to travel"
        case .action: return "Action / link"
        }
    }

    var icon: String {
        switch self {
        case .pinterest: return "photo.on.rectangle.angled"
        case .instagram: return "camera.fill"
        case .destination: return "globe.americas.fill"
        case .action: return "bolt.fill"
        }
    }
}

// Legacy: keep for migration if needed
struct VisionBoardItem: Codable, Identifiable {
    var id: UUID
    var title: String
    var url: String

    init(id: UUID = UUID(), title: String, url: String) {
        self.id = id
        self.title = title
        self.url = url
    }
}

// MARK: - Legacy Challenge Types (for backward compatibility)

struct Challenge: Identifiable {
    let id: String
    let title: String
    let durationMinutes: Int
    let categoryId: ChallengeCategory.Id
    let isFree: Bool

    var durationText: String { "\(durationMinutes) min" }
}

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

var allChallenges: [Challenge] {
    ChallengeCategory.allCases.flatMap { $0.challenges }
}
