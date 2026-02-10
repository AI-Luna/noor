//
//  StreakCalendarSheet.swift
//  leap
//
//  Streak pop-up with calendar, next milestone, record streak.
//

import SwiftUI

struct StreakCalendarSheet: View {
    let streakCount: Int
    let onDismiss: () -> Void

    private var nextMilestoneDays: Int {
        if streakCount < 2 { return 2 }
        if streakCount < 7 { return 7 }
        if streakCount < 30 { return 30 }
        return streakCount + 7
    }

    private var daysToNextMilestone: Int {
        max(0, nextMilestoneDays - streakCount)
    }

    private var streakDates: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<streakCount).compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
    }

    var body: some View {
        ZStack {
            Color.noorBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.noorTextSecondary)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .padding(.top, 12)
                }

                VStack(spacing: 20) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(streakCount)")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("day streak!")
                                .font(NoorFont.title2)
                                .foregroundStyle(Color.noorTextSecondary)
                        }
                        Spacer()
                        Image(systemName: "flame.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.noorOrange, Color.noorAccent],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.noorDeepPurple.opacity(0.8), Color.noorViolet.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Calendar")
                        .font(NoorFont.title2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)

                    StreakCalendarMonthView(
                        month: Date(),
                        streakDates: streakDates
                    )
                }
                .padding(20)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Overview")
                        .font(NoorFont.title2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)

                    HStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.noorRoseGold)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Next Milestone")
                                    .font(NoorFont.caption)
                                    .foregroundStyle(Color.noorTextSecondary)
                                Text("\(daysToNextMilestone) days")
                                    .font(NoorFont.title2)
                                    .foregroundStyle(Color.noorRoseGold)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        HStack(spacing: 12) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.noorOrange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Record Streak")
                                    .font(NoorFont.caption)
                                    .foregroundStyle(Color.noorTextSecondary)
                                Text("\(streakCount) day\(streakCount == 1 ? "" : "s")")
                                    .font(NoorFont.title2)
                                    .foregroundStyle(Color.noorOrange)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(20)
                .padding(.top, 16)

                Spacer(minLength: 20)
            }
        }
    }
}

private struct StreakCalendarMonthView: View {
    let month: Date
    let streakDates: [Date]

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    private var monthYear: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: month)
    }

    private var firstDayOfMonth: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
    }

    private var lastDayOfMonth: Date {
        calendar.date(byAdding: DateComponents(month: 1, day: -1), to: firstDayOfMonth)!
    }

    private var startWeekday: Int {
        (calendar.component(.weekday, from: firstDayOfMonth) - calendar.firstWeekday + 7) % 7
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: month)!.count
    }

    private var leadingEmpty: Int { startWeekday }
    private var totalCells: Int { leadingEmpty + daysInMonth }

    private func isStreakDay(_ day: Int) -> Bool {
        guard day >= 1, day <= daysInMonth else { return false }
        guard let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) else { return false }
        let dayStart = calendar.startOfDay(for: date)
        return streakDates.contains { calendar.isDate($0, inSameDayAs: dayStart) }
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(monthYear)
                .font(NoorFont.title2)
                .foregroundStyle(.white)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { d in
                    Text(d)
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorTextSecondary)
                }
                ForEach(0..<totalCells, id: \.self) { i in
                    if i < leadingEmpty {
                        Text("")
                            .font(NoorFont.caption)
                            .frame(height: 36)
                    } else {
                        let day = i - leadingEmpty + 1
                        let isStreak = isStreakDay(day)
                        ZStack {
                            if isStreak {
                                Circle()
                                    .fill(Color.noorOrange.opacity(0.3))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.noorOrange)
                            }
                            Text("\(day)")
                                .font(NoorFont.caption)
                                .foregroundStyle(isStreak ? .white : Color.noorTextSecondary)
                        }
                        .frame(height: 36)
                    }
                }
            }
        }
        .padding(16)
    }
}

#Preview {
    StreakCalendarSheet(streakCount: 3, onDismiss: {})
}
