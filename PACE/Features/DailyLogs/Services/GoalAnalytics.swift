//
//  GoalAnalytics.swift
//  PACE
//
//  Pure calculation engine computing goal metrics from Goal + DailyLogs.
//  Metrics are never duplicated into Firestore at this stage.
//
//  Rules:
//  - Only scheduled days count toward consistency.
//  - Planned rest days do not count as missed and do not break streaks.
//

import Foundation

struct GoalMetrics: Equatable {
    let daysRemaining: Int
    let currentStreak: Int
    let longestStreak: Int
    let activeDays: Int
    let missedScheduledDays: Int
    let consistencyPercentage: Double
    let totalLoggedMinutes: Int
    let averageSessionMinutes: Double
}

enum GoalAnalytics {
    
    static func compute(
        goal: PACEGoal,
        logs: [DailyLog],
        asOf: Date = Date(),
        calendar: Calendar = .current
    ) -> GoalMetrics {
        let today = calendar.startOfDay(for: asOf)
        let targetStart = calendar.startOfDay(for: goal.targetDate)
        
        // 1. Days Remaining
        let daysComponents = calendar.dateComponents([.day], from: today, to: targetStart)
        let daysRemaining = max(0, daysComponents.day ?? 0)
        
        // 2. Active Days
        let loggedDates = Set(logs.map { $0.dateString })
        let activeDays = loggedDates.count
        
        // 3. Total & Average Minutes
        let totalMinutes = logs.reduce(0) { $0 + $1.durationMinutes }
        let avgMinutes = logs.isEmpty ? 0.0 : Double(totalMinutes) / Double(logs.count)
        
        // 4. Determine Date Horizon
        let goalStart = calendar.startOfDay(for: goal.createdAt)
        var earliestDate = goalStart
        for log in logs {
            if log.date < earliestDate {
                earliestDate = log.date
            }
        }
        
        // 5. Missed Scheduled Days & Consistency
        var totalScheduledDays = 0
        var scheduledDaysLogged = 0
        var missedDays = 0
        
        var iterDate = earliestDate
        while iterDate <= today {
            let weekday = calendar.component(.weekday, from: iterDate)
            let isScheduled = goal.scheduledWeekdays.contains(weekday)
            let dString = DailyLog.dateFormatter.string(from: iterDate)
            let isLogged = loggedDates.contains(dString)
            
            if isScheduled {
                totalScheduledDays += 1
                if isLogged {
                    scheduledDaysLogged += 1
                } else if iterDate < today {
                    // Strictly before today is considered missed
                    missedDays += 1
                }
            }
            
            guard let next = calendar.date(byAdding: .day, value: 1, to: iterDate) else { break }
            iterDate = next
        }
        
        let consistency: Double
        if totalScheduledDays == 0 {
            consistency = 100.0
        } else {
            let ratio = Double(scheduledDaysLogged) / Double(totalScheduledDays)
            consistency = min(100.0, max(0.0, (ratio * 100.0).rounded()))
        }
        
        // 6. Current Streak (Walking backward from today)
        var streak = 0
        var checkDate = today
        let todayString = DailyLog.dateFormatter.string(from: today)
        let hasTodayLog = loggedDates.contains(todayString)
        
        if hasTodayLog {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        } else {
            // Today not logged yet:
            // If today is scheduled, it is still pending (does not break streak earned through yesterday)
            // If today is a rest day, streak earned through yesterday continues
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }
        
        while checkDate >= earliestDate {
            let dString = DailyLog.dateFormatter.string(from: checkDate)
            let isLogged = loggedDates.contains(dString)
            let isScheduled = goal.scheduledWeekdays.contains(calendar.component(.weekday, from: checkDate))
            
            if isLogged {
                streak += 1
            } else if isScheduled {
                // A scheduled day was missed strictly before today -> streak broken
                break
            } else {
                // Planned rest day: does NOT break streak
            }
            
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        
        // 7. Longest Streak (Walking forward from earliestDate to today)
        var longestStreak = 0
        var runningStreak = 0
        var walkDate = earliestDate
        
        while walkDate <= today {
            let dString = DailyLog.dateFormatter.string(from: walkDate)
            let isLogged = loggedDates.contains(dString)
            let isScheduled = goal.scheduledWeekdays.contains(calendar.component(.weekday, from: walkDate))
            
            if isLogged {
                runningStreak += 1
                longestStreak = max(longestStreak, runningStreak)
            } else if isScheduled {
                if walkDate == today {
                    // Today is still open
                    longestStreak = max(longestStreak, runningStreak)
                } else {
                    runningStreak = 0
                }
            } else {
                // Planned rest day bridges the streak forward
            }
            
            guard let next = calendar.date(byAdding: .day, value: 1, to: walkDate) else { break }
            walkDate = next
        }
        
        longestStreak = max(longestStreak, streak)
        
        return GoalMetrics(
            daysRemaining: daysRemaining,
            currentStreak: streak,
            longestStreak: longestStreak,
            activeDays: activeDays,
            missedScheduledDays: missedDays,
            consistencyPercentage: consistency,
            totalLoggedMinutes: totalMinutes,
            averageSessionMinutes: (avgMinutes * 10).rounded() / 10
        )
    }
}
