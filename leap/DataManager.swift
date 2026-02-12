//
//  DataManager.swift
//  leap
//
//  SwiftData persistence manager for Noor (Goal, DailyTask, Streak)
//  "Travel agency for life" - flight booking system
//

import Foundation
import SwiftData

@Observable
@MainActor
final class DataManager {
    static let shared = DataManager()

    private(set) var modelContainer: ModelContainer?
    private(set) var mainContext: ModelContext?

    private init() {}

    func initialize() {
        guard modelContainer == nil else { return }
        let schema = Schema([
            Goal.self,
            DailyTask.self,
            Streak.self,
            Microhabit.self
        ])
        let config = ModelConfiguration(
            isStoredInMemoryOnly: false,
            groupContainer: .automatic
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            modelContainer = container
            mainContext = context
        } catch {
            fatalError("SwiftData failed to initialize: \(error)")
        }
    }

    private func requireContext() throws -> ModelContext {
        guard let ctx = mainContext else {
            throw DataManagerError.notInitialized
        }
        return ctx
    }

    // MARK: - Goals

    func saveGoal(_ goal: Goal) async throws {
        let ctx = try requireContext()
        ctx.insert(goal)
        for task in goal.dailyTasks {
            ctx.insert(task)
        }
        try ctx.save()
    }

    func fetchAllGoals() async throws -> [Goal] {
        let ctx = try requireContext()
        let descriptor = FetchDescriptor<Goal>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try ctx.fetch(descriptor).filter { !$0.isArchived }
    }

    func fetchArchivedGoals() async throws -> [Goal] {
        let ctx = try requireContext()
        let descriptor = FetchDescriptor<Goal>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try ctx.fetch(descriptor).filter { $0.isArchived }
    }

    func archiveGoal(_ id: String) async throws {
        guard let uuid = UUID(uuidString: id) else {
            throw DataManagerError.invalidID(id)
        }
        let ctx = try requireContext()
        let descriptor = FetchDescriptor<Goal>(
            predicate: #Predicate<Goal> { $0.id == uuid }
        )
        let goals = try ctx.fetch(descriptor)
        guard let goal = goals.first else {
            throw DataManagerError.notFound("Goal", id: id)
        }
        goal.isArchived = true
        goal.archivedAt = Date()
        try ctx.save()
    }

    func unarchiveGoal(_ id: String) async throws {
        guard let uuid = UUID(uuidString: id) else {
            throw DataManagerError.invalidID(id)
        }
        let ctx = try requireContext()
        let descriptor = FetchDescriptor<Goal>(
            predicate: #Predicate<Goal> { $0.id == uuid }
        )
        let goals = try ctx.fetch(descriptor)
        guard let goal = goals.first else {
            throw DataManagerError.notFound("Goal", id: id)
        }
        goal.isArchived = false
        goal.archivedAt = nil
        try ctx.save()
    }

    func deleteGoal(_ id: String) async throws {
        guard let uuid = UUID(uuidString: id) else {
            throw DataManagerError.invalidID(id)
        }
        let ctx = try requireContext()
        let descriptor = FetchDescriptor<Goal>(
            predicate: #Predicate<Goal> { $0.id == uuid }
        )
        let goals = try ctx.fetch(descriptor)
        guard let goal = goals.first else {
            throw DataManagerError.notFound("Goal", id: id)
        }
        ctx.delete(goal)
        try ctx.save()
    }

    // MARK: - Daily task completion

    func addDailyTaskCompletion(goalID: String, taskID: String, date: Date) async throws {
        guard let taskUUID = UUID(uuidString: taskID) else {
            throw DataManagerError.invalidID(taskID)
        }
        let ctx = try requireContext()
        let descriptor = FetchDescriptor<DailyTask>(
            predicate: #Predicate<DailyTask> { $0.id == taskUUID }
        )
        let tasks = try ctx.fetch(descriptor)
        guard let task = tasks.first else {
            throw DataManagerError.notFound("DailyTask", id: taskID)
        }
        let dayStart = Calendar.current.startOfDay(for: date)
        if !task.completedDates.contains(where: { Calendar.current.isDate($0, inSameDayAs: dayStart) }) {
            task.completedDates.append(date)
        }
        try ctx.save()
    }

    func removeDailyTaskCompletion(goalID: String, taskID: String, date: Date) async throws {
        guard let taskUUID = UUID(uuidString: taskID) else {
            throw DataManagerError.invalidID(taskID)
        }
        let ctx = try requireContext()
        let descriptor = FetchDescriptor<DailyTask>(
            predicate: #Predicate<DailyTask> { $0.id == taskUUID }
        )
        let tasks = try ctx.fetch(descriptor)
        guard let task = tasks.first else {
            throw DataManagerError.notFound("DailyTask", id: taskID)
        }
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        task.completedDates.removeAll { cal.isDate($0, inSameDayAs: dayStart) }
        try ctx.save()
    }

    // MARK: - Streak & lookup

    func getCurrentStreak(_ goalID: String) async -> Int {
        guard let uuid = UUID(uuidString: goalID) else { return 0 }
        do {
            let ctx = try requireContext()
            let descriptor = FetchDescriptor<Goal>(
                predicate: #Predicate<Goal> { $0.id == uuid }
            )
            let goals = try ctx.fetch(descriptor)
            return goals.first?.currentStreak ?? 0
        } catch {
            return 0
        }
    }

    func getGoalByID(_ id: String) async -> Goal? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        do {
            let ctx = try requireContext()
            let descriptor = FetchDescriptor<Goal>(
                predicate: #Predicate<Goal> { $0.id == uuid }
            )
            let goals = try ctx.fetch(descriptor)
            return goals.first
        } catch {
            return nil
        }
    }

    // MARK: - Task Unlocking (Sequential Challenges)

    func unlockNextTask(goalID: String, afterOrder: Int) async throws {
        guard UUID(uuidString: goalID) != nil else {
            throw DataManagerError.invalidID(goalID)
        }
        let ctx = try requireContext()

        // Fetch all tasks for this goal
        let descriptor = FetchDescriptor<DailyTask>(
            predicate: #Predicate<DailyTask> { $0.goalID == goalID }
        )
        let tasks = try ctx.fetch(descriptor)

        // Find the next task and unlock it
        if let nextTask = tasks.first(where: { $0.order == afterOrder + 1 }) {
            nextTask.isUnlocked = true
            try ctx.save()
        }
    }

    // MARK: - Goal Updates

    func updateGoalStreak(goalID: String, streak: Int, lastActionDate: Date) async throws {
        guard let uuid = UUID(uuidString: goalID) else {
            throw DataManagerError.invalidID(goalID)
        }
        let ctx = try requireContext()
        let descriptor = FetchDescriptor<Goal>(
            predicate: #Predicate<Goal> { $0.id == uuid }
        )
        let goals = try ctx.fetch(descriptor)
        guard let goal = goals.first else {
            throw DataManagerError.notFound("Goal", id: goalID)
        }

        goal.currentStreak = streak
        goal.lastActionDate = lastActionDate
        if streak > goal.longestStreak {
            goal.longestStreak = streak
        }

        try ctx.save()
    }

    // MARK: - Microhabits

    func saveMicrohabit(_ microhabit: Microhabit) async throws {
        let ctx = try requireContext()
        ctx.insert(microhabit)
        try ctx.save()
    }

    func fetchMicrohabits() async throws -> [Microhabit] {
        let ctx = try requireContext()
        let descriptor = FetchDescriptor<Microhabit>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try ctx.fetch(descriptor)
    }

    func deleteMicrohabit(_ id: UUID) async throws {
        let ctx = try requireContext()
        let descriptor = FetchDescriptor<Microhabit>(
            predicate: #Predicate<Microhabit> { $0.id == id }
        )
        let habits = try ctx.fetch(descriptor)
        guard let habit = habits.first else {
            throw DataManagerError.notFound("Microhabit", id: id.uuidString)
        }
        ctx.delete(habit)
        try ctx.save()
    }

    func addMicrohabitCompletion(_ habitID: UUID, date: Date) async throws {
        let ctx = try requireContext()
        let descriptor = FetchDescriptor<Microhabit>(
            predicate: #Predicate<Microhabit> { $0.id == habitID }
        )
        let habits = try ctx.fetch(descriptor)
        guard let habit = habits.first else {
            throw DataManagerError.notFound("Microhabit", id: habitID.uuidString)
        }
        let dayStart = Calendar.current.startOfDay(for: date)
        if !habit.completedDates.contains(where: { Calendar.current.isDate($0, inSameDayAs: dayStart) }) {
            habit.completedDates.append(date)
        }
        try ctx.save()
    }

    /// Call after modifying an already-fetched model (e.g. edit microhabit).
    func saveContext() async throws {
        try requireContext().save()
    }
}

// MARK: - Errors

enum DataManagerError: LocalizedError {
    case notInitialized
    case invalidID(String)
    case notFound(String, id: String)

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "DataManager has not been initialized. Call initialize() first."
        case .invalidID(let id):
            return "Invalid ID: \(id)"
        case .notFound(let type, let id):
            return "\(type) not found for id: \(id)"
        }
    }
}
