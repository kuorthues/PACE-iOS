//
//  DailyLoggingTests.swift
//  PACE
//
//  Comprehensive automated verification suite for Daily Logging and Goal Analytics:
//  - Every-day goal continuous streak
//  - Custom-weekday goal with planned rest days (Sat/Sun bridging)
//  - Broken streak after missed scheduled day
//  - Consistency calculation using scheduled days only
//  - Total and average time calculations
//  - Duplicate same-day log conversion
//  - Late entry recording
//  - Edit and delete persistence
//

import Foundation

struct DailyLoggingTestSuite {
    
    @MainActor
    static func runAllTests() async -> (success: Bool, logs: [String]) {
        var output: [String] = []
        var allPassed = true
        
        func assert(_ condition: Bool, _ testName: String) {
            if condition {
                output.append("PASS: \(testName)")
            } else {
                output.append("FAIL: \(testName)")
                allPassed = false
            }
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // ---------------------------------------------------------------
        // TEST 1: Every-Day Goal Continuous Streak
        // ---------------------------------------------------------------
        let everyDayGoal = PACEGoal(
            id: "test_goal_every_day",
            userId: "test_user",
            title: "Daily Coding",
            createdAt: calendar.date(byAdding: .day, value: -5, to: today)!,
            targetDate: calendar.date(byAdding: .day, value: 30, to: today)!,
            activityTypes: ["Practice"],
            scheduledWeekdays: [1, 2, 3, 4, 5, 6, 7]
        )
        
        // Logs for 4 consecutive days: today, yesterday, -2, -3
        var everyDayLogs: [DailyLog] = []
        for i in 0...3 {
            let logDate = calendar.date(byAdding: .day, value: -i, to: today)!
            everyDayLogs.append(
                DailyLog(
                    goalId: everyDayGoal.id,
                    date: logDate,
                    selectedActivities: ["Practice"],
                    durationMinutes: 60
                )
            )
        }
        
        let metrics1 = GoalAnalytics.compute(goal: everyDayGoal, logs: everyDayLogs, asOf: today)
        assert(metrics1.currentStreak == 4, "Every-day goal 4-day continuous streak equals 4 (got \(metrics1.currentStreak))")
        assert(metrics1.longestStreak == 4, "Every-day goal longest streak equals 4 (got \(metrics1.longestStreak))")
        assert(metrics1.activeDays == 4, "Every-day goal active days equals 4 (got \(metrics1.activeDays))")
        assert(metrics1.totalLoggedMinutes == 240, "Total minutes equals 240 (got \(metrics1.totalLoggedMinutes))")
        assert(metrics1.averageSessionMinutes == 60.0, "Average session equals 60.0 (got \(metrics1.averageSessionMinutes))")
        
        // ---------------------------------------------------------------
        // TEST 2: Custom-Weekday Goal (Mon-Fri) with Planned Rest Days (Sat/Sun)
        // ---------------------------------------------------------------
        // Simulate a fixed week:
        // Friday (day 0), Saturday (day 1, rest), Sunday (day 2, rest), Monday (day 3)
        // Set goal weekdays: [2, 3, 4, 5, 6] (Mon-Fri). Sat (7) and Sun (1) are rest days.
        var dateComponents = DateComponents()
        dateComponents.year = 2026
        dateComponents.month = 10
        dateComponents.day = 2 // Friday, Oct 2, 2026
        let friday = calendar.date(from: dateComponents)!
        let saturday = calendar.date(byAdding: .day, value: 1, to: friday)! // Oct 3 (Sat)
        let sunday = calendar.date(byAdding: .day, value: 2, to: friday)!   // Oct 4 (Sun)
        let monday = calendar.date(byAdding: .day, value: 3, to: friday)!   // Oct 5 (Mon)
        
        let weekdayGoal = PACEGoal(
            id: "test_goal_weekdays",
            userId: "test_user",
            title: "Study Weekdays",
            createdAt: friday,
            targetDate: calendar.date(byAdding: .day, value: 60, to: monday)!,
            activityTypes: ["Study"],
            scheduledWeekdays: [2, 3, 4, 5, 6] // Mon-Fri
        )
        
        // User logs on Friday and Monday. Saturday and Sunday are planned rest days!
        let logFriday = DailyLog(goalId: weekdayGoal.id, date: friday, selectedActivities: ["Study"], durationMinutes: 45)
        let logMonday = DailyLog(goalId: weekdayGoal.id, date: monday, selectedActivities: ["Study"], durationMinutes: 45)
        
        let metricsRest = GoalAnalytics.compute(goal: weekdayGoal, logs: [logFriday, logMonday], asOf: monday, calendar: calendar)
        assert(metricsRest.currentStreak == 2, "Planned rest days (Sat/Sun) do not break streak (Friday + Monday = streak 2, got \(metricsRest.currentStreak))")
        assert(metricsRest.missedScheduledDays == 0, "Planned rest days do not count as missed days (got \(metricsRest.missedScheduledDays))")
        assert(metricsRest.consistencyPercentage == 100.0, "Consistency is 100% since all scheduled days were logged (got \(metricsRest.consistencyPercentage)%)")
        
        // ---------------------------------------------------------------
        // TEST 3: Broken Streak After Missed Scheduled Day
        // ---------------------------------------------------------------
        // Add Tuesday (scheduled) which is missed, and evaluate on Wednesday
        let tuesday = calendar.date(byAdding: .day, value: 4, to: friday)! // Oct 6 (Tue) - NOT logged
        let wednesday = calendar.date(byAdding: .day, value: 5, to: friday)! // Oct 7 (Wed) - Logged
        let logWed = DailyLog(goalId: weekdayGoal.id, date: wednesday, selectedActivities: ["Study"], durationMinutes: 45)
        
        let metricsBroken = GoalAnalytics.compute(goal: weekdayGoal, logs: [logFriday, logMonday, logWed], asOf: wednesday, calendar: calendar)
        assert(metricsBroken.currentStreak == 1, "Missed scheduled Tuesday breaks prior streak; current streak restarts at 1 on Wednesday (got \(metricsBroken.currentStreak))")
        assert(metricsBroken.longestStreak == 2, "Longest streak preserves the earlier 2-day streak (got \(metricsBroken.longestStreak))")
        assert(metricsBroken.missedScheduledDays == 1, "Missed Tuesday increments missedScheduledDays to 1 (got \(metricsBroken.missedScheduledDays))")
        
        // ---------------------------------------------------------------
        // TEST 4: Consistency Uses Only Scheduled Days
        // ---------------------------------------------------------------
        // Total scheduled elapsed from Friday to Wednesday: Friday (1), Mon (2), Tue (3), Wed (4) = 4 scheduled days.
        // Scheduled days logged: Friday, Monday, Wed = 3.
        // Consistency = 3 / 4 = 75%
        assert(metricsBroken.consistencyPercentage == 75.0, "Consistency is exactly 75% for 3/4 scheduled days (got \(metricsBroken.consistencyPercentage)%)")
        
        // ---------------------------------------------------------------
        // TEST 5: DailyLogService CRUD, Duplicate Prevention & Late Entry
        // ---------------------------------------------------------------
        let service = DailyLogService.shared
        let testGoalId = "test_crud_goal_\(UUID().uuidString.prefix(6))"
        
        do {
            // A. Create initial log for today
            let log1 = try await service.saveLog(
                goalId: testGoalId,
                date: today,
                selectedActivities: ["Review"],
                durationMinutes: 30,
                note: "First session"
            )
            assert(log1.durationMinutes == 30, "Initial log created with duration 30m")
            
            // B. Duplicate same-day log: Updating same day modifies existing log
            let log2 = try await service.saveLog(
                goalId: testGoalId,
                date: today,
                selectedActivities: ["Review", "Practice"],
                durationMinutes: 50,
                note: "Updated session"
            )
            assert(log2.id == log1.id, "Duplicate same-day log converted to update on same document ID")
            assert(log2.durationMinutes == 50, "Updated duration persisted")
            
            let currentLogs = await service.fetchLogs(for: testGoalId)
            assert(currentLogs.count == 1, "Logs count remains 1 for same calendar day (no duplicate entries)")
            
            // C. Late Entry: Log for 2 days ago
            let lateDate = calendar.date(byAdding: .day, value: -2, to: today)!
            let lateLog = try await service.saveLog(
                goalId: testGoalId,
                date: lateDate,
                selectedActivities: ["Practice"],
                durationMinutes: 40,
                note: "Late backfilled entry"
            )
            assert(lateLog.dateString == DailyLog.dateFormatter.string(from: lateDate), "Late entry saved with correct past date")
            
            let updatedLogs = await service.fetchLogs(for: testGoalId)
            assert(updatedLogs.count == 2, "Late entry successfully added to goal logs")
            
            // D. Delete Log
            try await service.deleteLog(id: lateLog.id, goalId: testGoalId)
            let postDeleteLogs = await service.fetchLogs(for: testGoalId)
            assert(postDeleteLogs.count == 1, "Log deletion successfully removed entry")
            
            // Clean up
            try await service.deleteLog(id: log2.id, goalId: testGoalId)
            
        } catch {
            output.append("FAIL: Service CRUD threw error: \(error.localizedDescription)")
            allPassed = false
        }
        
        return (allPassed, output)
    }
}
