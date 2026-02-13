//
//  CompletionStore.swift
//  leap
//
//  UserDefaults-backed completed challenges and streak
//

import Foundation
import SwiftUI

@Observable
final class CompletionStore {
    static let shared = CompletionStore()

    var completedIds: Set<String> = []
    var streak: Int = 0
    var lastCompletionDate: Date?

    private let defaults = UserDefaults.standard

    private init() {
        load()
        updateStreakIfNeeded()
    }

    private func load() {
        completedIds = Set(defaults.stringArray(forKey: StorageKey.completedChallengeIds) ?? [])
        streak = defaults.integer(forKey: StorageKey.streakCount)
        lastCompletionDate = defaults.object(forKey: StorageKey.lastCompletionDate) as? Date
    }

    func save() {
        defaults.set(Array(completedIds), forKey: StorageKey.completedChallengeIds)
        defaults.set(streak, forKey: StorageKey.streakCount)
        defaults.set(lastCompletionDate, forKey: StorageKey.lastCompletionDate)
    }

    func isCompleted(_ challengeId: String) -> Bool {
        completedIds.contains(challengeId)
    }

    func markComplete(_ challengeId: String) {
        completedIds.insert(challengeId)
        let today = Calendar.current.startOfDay(for: Date())
        if let last = lastCompletionDate {
            let lastDay = Calendar.current.startOfDay(for: last)
            if lastDay == today {
                // already completed today, don't change streak
            } else if Calendar.current.isDate(lastDay, inSameDayAs: Calendar.current.date(byAdding: .day, value: -1, to: today)!) {
                streak += 1
            } else {
                streak = 1
            }
        } else {
            streak = 1
        }
        lastCompletionDate = Date()
        save()
    }

    private func updateStreakIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        guard let last = lastCompletionDate else { return }
        let lastDay = Calendar.current.startOfDay(for: last)
        if lastDay < today {
            let daysDiff = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if daysDiff > 1 {
                streak = 0
                save()
            }
        }
    }
    
    /// Returns the number of times a habit has been completed (stored per habit)
    func completionCount(for habitId: String) -> Int {
        defaults.integer(forKey: "habit_completion_count_\(habitId)")
    }
    
    /// Increment the completion count for a habit
    func incrementCompletionCount(for habitId: String) {
        let current = completionCount(for: habitId)
        defaults.set(current + 1, forKey: "habit_completion_count_\(habitId)")
    }
}
