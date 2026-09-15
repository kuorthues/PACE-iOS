//
//  JourneyTests.swift
//  PACE
//
//  Automated test suite verifying the PACE Journey Timeline:
//  - Range coverage from goal creation/start through target date
//  - Accurate mapping to 7 day states: completed, completedWithEvidence, missed, rest, today, future, target
//  - Distinct target terminal node
//  - Today state resolution (pending vs completed vs evidence)
//  - Evidence association to correct day
//  - Consistency & timeline summary computation
//  - Zero Swift Charts dependency
//

import Foundation

@MainActor
final class JourneyTests {
    static var passedCount = 0
    static var totalCount = 0
    
    static func runAllTests() async -> (passed: Int, total: Int, failures: [String]) {
        passedCount = 0
        totalCount = 0
        var failures: [String] = []
        
        func assert(_ condition: Bool, _ name: String) {
            totalCount += 1
            if condition {
                passedCount += 1
                print("  ✅ [PASS] \(name)")
            } else {
                failures.append(name)
                print("  ❌ [FAIL] \(name)")
            }
        }
        
        print("\n==========================================")
        print("🧪 RUNNING JOURNEY TIMELINE TEST SUITE")
        print("==========================================")
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // ---------------------------------------------------------------
        // TEST 1: Goal Day Horizon Generation (Every day in range rendered)
        // ---------------------------------------------------------------
        // Goal starts 3 days ago and ends 4 days from now = 8 total calendar days (-3, -2, -1, 0, +1, +2, +3, +4)
        let startDate = calendar.date(byAdding: .day, value: -3, to: today)!
        let targetDate = calendar.date(byAdding: .day, value: 4, to: today)!
        
        let testGoal = PACEGoal(
            id: "goal_journey_test",
            userId: "test_user_789",
            title: "Journey Test Goal",
            createdAt: startDate,
            targetDate: targetDate,
            activityTypes: ["Coding", "Review"],
            scheduledWeekdays: [1, 2, 3, 4, 5, 6, 7] // Everyday
        )
        
        let days = JourneyTimelineBuilder.buildTimeline(
            goal: testGoal,
            logs: [],
            evidenceItems: [],
            asOf: today,
            calendar: calendar
        )
        
        assert(days.count == 8, "Journey renders every day in goal range (8 calendar days)")
        assert(days.first?.date == startDate, "First day matches goal start date")
        assert(days.last?.date == targetDate, "Last day matches goal target date")
        assert(days.first?.dayIndex == 1, "First day has index 1")
        assert(days.last?.dayIndex == 8, "Last day has index 8")
        
        // ---------------------------------------------------------------
        // TEST 2: Node State Mapping (Completed, CompletedWithEvidence, Missed, Today, Future, Target)
        // ---------------------------------------------------------------
        // Day -3: Completed with Evidence
        // Day -2: Completed without Evidence
        // Day -1: Missed (past scheduled day not logged)
        // Day 0 (Today): Not yet logged -> today
        // Day +1, +2, +3: Future scheduled -> future
        // Day +4 (Target): Target -> target
        
        let logDayMinus3 = calendar.date(byAdding: .day, value: -3, to: today)!
        let logDayMinus2 = calendar.date(byAdding: .day, value: -2, to: today)!
        
        let dateStringMinus3 = DailyLog.dateFormatter.string(from: logDayMinus3)
        
        let evidenceItem = EvidenceItem(
            id: "ev_day3",
            userId: "test_user_789",
            goalId: testGoal.id,
            logId: dateStringMinus3,
            caption: "Proof on day 3"
        )
        
        let log1 = DailyLog(
            goalId: testGoal.id,
            date: logDayMinus3,
            selectedActivities: ["Coding"],
            durationMinutes: 60,
            evidenceId: evidenceItem.id
        )
        
        let log2 = DailyLog(
            goalId: testGoal.id,
            date: logDayMinus2,
            selectedActivities: ["Review"],
            durationMinutes: 45
        )
        
        let resolvedDays = JourneyTimelineBuilder.buildTimeline(
            goal: testGoal,
            logs: [log1, log2],
            evidenceItems: [evidenceItem],
            asOf: today,
            calendar: calendar
        )
        
        // Check Day -3 (Index 0)
        assert(resolvedDays[0].state == .completedWithEvidence, "Day -3 resolved to .completedWithEvidence")
        assert(resolvedDays[0].evidence != nil, "Day -3 has evidence associated")
        assert(resolvedDays[0].evidence?.caption == "Proof on day 3", "Day -3 evidence caption matches")
        
        // Check Day -2 (Index 1)
        assert(resolvedDays[1].state == .completed, "Day -2 resolved to .completed")
        assert(resolvedDays[1].evidence == nil, "Day -2 has no evidence")
        
        // Check Day -1 (Index 2)
        assert(resolvedDays[2].state == .missed, "Day -1 resolved to .missed (unlogged past scheduled day)")
        
        // Check Day 0 / Today (Index 3)
        assert(resolvedDays[3].isToday == true, "Day 0 is identified as today")
        assert(resolvedDays[3].state == .today, "Unlogged today resolves to .today")
        
        // Check Day +1 (Index 4)
        assert(resolvedDays[4].state == .future, "Day +1 resolves to .future")
        
        // Check Target Day (Index 7)
        assert(resolvedDays[7].isTarget == true, "Day +4 is identified as target")
        assert(resolvedDays[7].state == .target, "Target terminal node resolves to .target")
        
        // ---------------------------------------------------------------
        // TEST 3: Rest Day Resolution on Custom Weekdays
        // ---------------------------------------------------------------
        // Goal only scheduled on Mon, Wed, Fri (weekdays 2, 4, 6)
        let weekdayGoal = PACEGoal(
            id: "goal_weekday_rest_test",
            userId: "test_user_789",
            title: "Rest Day Test",
            createdAt: calendar.date(byAdding: .day, value: -7, to: today)!,
            targetDate: calendar.date(byAdding: .day, value: 7, to: today)!,
            activityTypes: ["Sprint"],
            scheduledWeekdays: [2, 4, 6] // Mon, Wed, Fri
        )
        
        let weekdayTimeline = JourneyTimelineBuilder.buildTimeline(
            goal: weekdayGoal,
            logs: [],
            evidenceItems: [],
            asOf: today,
            calendar: calendar
        )
        
        var restDayCount = 0
        var scheduledPastCount = 0
        for day in weekdayTimeline where day.date < today {
            if day.state == .rest {
                restDayCount += 1
            } else if day.state == .missed {
                scheduledPastCount += 1
            }
        }
        
        assert(restDayCount > 0, "Non-scheduled days in past resolve to .rest (found \(restDayCount) rest days)")
        assert(scheduledPastCount > 0, "Scheduled days in past without log resolve to .missed (found \(scheduledPastCount))")
        
        // ---------------------------------------------------------------
        // TEST 4: Today Completed with Evidence Resolution
        // ---------------------------------------------------------------
        let todayEvidence = EvidenceItem(
            id: "ev_today",
            userId: "test_user_789",
            goalId: testGoal.id,
            logId: DailyLog.dateFormatter.string(from: today)
        )
        let todayLog = DailyLog(
            goalId: testGoal.id,
            date: today,
            selectedActivities: ["Coding"],
            durationMinutes: 90,
            evidenceId: todayEvidence.id
        )
        
        let todayLoggedTimeline = JourneyTimelineBuilder.buildTimeline(
            goal: testGoal,
            logs: [todayLog],
            evidenceItems: [todayEvidence],
            asOf: today,
            calendar: calendar
        )
        
        let todayResolved = todayLoggedTimeline.first(where: { $0.isToday })
        assert(todayResolved?.state == .completedWithEvidence, "Logged today with evidence resolves to .completedWithEvidence")
        
        // ---------------------------------------------------------------
        // TEST 5: Summary Metrics Calculation
        // ---------------------------------------------------------------
        let summary = JourneyTimelineBuilder.computeSummary(days: resolvedDays)
        assert(summary.totalDays == 8, "Summary total days is 8")
        assert(summary.completedCount == 2, "Summary completed count is 2")
        assert(summary.evidenceCount == 1, "Summary evidence count is 1")
        assert(summary.missedCount == 1, "Summary missed count is 1")
        
        // ---------------------------------------------------------------
        // TEST 6: Long Horizon Goal (e.g. 60 days)
        // ---------------------------------------------------------------
        let longGoal = PACEGoal(
            id: "goal_long",
            userId: "test_user",
            title: "Long Horizon",
            createdAt: today,
            targetDate: calendar.date(byAdding: .day, value: 60, to: today)!,
            activityTypes: ["Build"],
            scheduledWeekdays: [1, 2, 3, 4, 5, 6, 7]
        )
        let longTimeline = JourneyTimelineBuilder.buildTimeline(
            goal: longGoal,
            logs: [],
            asOf: today,
            calendar: calendar
        )
        assert(longTimeline.count == 61, "60-day target from today renders exactly 61 days (Day 1 to Day 61)")
        assert(longTimeline.last?.isTarget == true, "Terminal day is target")
        
        print("\n==========================================")
        print("🏁 JOURNEY RESULTS: \(passedCount)/\(totalCount) PASSED (Failures: \(failures.count))")
        print("==========================================\n")
        
        return (passedCount, totalCount, failures)
    }
}
