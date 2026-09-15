//
//  JourneyTimelineBuilder.swift
//  PACE
//
//  Deterministic calculation service generating JourneyDay representations
//  for every calendar day in the goal horizon (from start through target date).
//  Zero Swift Charts dependency.
//

import Foundation

struct JourneySummaryMetrics: Equatable {
    let totalDays: Int
    let completedCount: Int
    let evidenceCount: Int
    let missedCount: Int
    let restCount: Int
    let futureCount: Int
    let daysRemaining: Int
    let consistencyPercentage: Double
}

enum JourneyTimelineBuilder {
    
    /// Generates a complete sequence of `JourneyDay` items spanning every day from goal start to target date.
    static func buildTimeline(
        goal: PACEGoal,
        logs: [DailyLog],
        evidenceItems: [EvidenceItem] = [],
        asOf: Date = Date(),
        calendar: Calendar = .current
    ) -> [JourneyDay] {
        let today = calendar.startOfDay(for: asOf)
        let goalStart = calendar.startOfDay(for: goal.createdAt)
        
        // Find earliest date if any log was recorded prior to goal creation
        var startDate = goalStart
        for log in logs {
            let logStart = calendar.startOfDay(for: log.date)
            if logStart < startDate {
                startDate = logStart
            }
        }
        
        var targetDate = calendar.startOfDay(for: goal.targetDate)
        if targetDate < startDate {
            targetDate = startDate
        }
        
        // Calculate total days count
        let components = calendar.dateComponents([.day], from: startDate, to: targetDate)
        let totalDays = max(1, (components.day ?? 0) + 1)
        
        // Map logs by date string
        var logsByDate: [String: DailyLog] = [:]
        for log in logs {
            // If multiple logs on same date, prefer one with evidence
            if let existing = logsByDate[log.dateString] {
                if existing.evidenceId == nil && log.evidenceId != nil {
                    logsByDate[log.dateString] = log
                }
            } else {
                logsByDate[log.dateString] = log
            }
        }
        
        // Map evidence by id and logId
        var evidenceById: [String: EvidenceItem] = [:]
        var evidenceByLogId: [String: EvidenceItem] = [:]
        for item in evidenceItems {
            evidenceById[item.id] = item
            evidenceByLogId[item.logId] = item
        }
        
        var journeyDays: [JourneyDay] = []
        var currentDay = startDate
        var dayIndex = 1
        
        while currentDay <= targetDate {
            let dString = DailyLog.dateFormatter.string(from: currentDay)
            let weekday = calendar.component(.weekday, from: currentDay)
            let isScheduled = goal.scheduledWeekdays.contains(weekday)
            let isToday = calendar.isDate(currentDay, inSameDayAs: today)
            let isTarget = calendar.isDate(currentDay, inSameDayAs: targetDate)
            let isPast = currentDay < today
            let isFuture = currentDay > today
            
            let log = logsByDate[dString]
            
            // Resolve attached evidence
            var evidence: EvidenceItem? = nil
            if let log = log {
                if let evId = log.evidenceId, let ev = evidenceById[evId] {
                    evidence = ev
                } else if let ev = evidenceByLogId[log.id] {
                    evidence = ev
                } else if let ev = evidenceByLogId[dString] {
                    evidence = ev
                }
            } else {
                evidence = evidenceByLogId[dString]
            }
            
            // State resolution
            let state: JourneyDayState
            if isTarget && (isFuture || log == nil) {
                state = .target
            } else if isToday && log == nil {
                state = .today
            } else if let log = log {
                let hasEvidence = (evidence != nil || log.evidenceId != nil)
                state = hasEvidence ? .completedWithEvidence : .completed
            } else if isPast {
                state = isScheduled ? .missed : .rest
            } else {
                // Future
                state = isScheduled ? .future : .rest
            }
            
            let day = JourneyDay(
                id: dString,
                date: currentDay,
                dateString: dString,
                dayIndex: dayIndex,
                totalDays: totalDays,
                state: state,
                isScheduled: isScheduled,
                isToday: isToday,
                isTarget: isTarget,
                log: log,
                evidence: evidence
            )
            journeyDays.append(day)
            
            guard let next = calendar.date(byAdding: .day, value: 1, to: currentDay) else { break }
            currentDay = next
            dayIndex += 1
        }
        
        return journeyDays
    }
    
    /// Computes summary metrics for a generated journey timeline
    static func computeSummary(days: [JourneyDay]) -> JourneySummaryMetrics {
        let total = days.count
        var completed = 0
        var evidenceCount = 0
        var missed = 0
        var rest = 0
        var future = 0
        var scheduledPastCount = 0
        
        for day in days {
            switch day.state {
            case .completed:
                completed += 1
                if day.isScheduled { scheduledPastCount += 1 }
            case .completedWithEvidence:
                completed += 1
                evidenceCount += 1
                if day.isScheduled { scheduledPastCount += 1 }
            case .missed:
                missed += 1
                scheduledPastCount += 1
            case .rest:
                rest += 1
            case .today:
                if day.isScheduled { scheduledPastCount += 1 }
            case .future, .target:
                future += 1
            }
        }
        
        let consistency: Double
        if scheduledPastCount == 0 {
            consistency = completed > 0 ? 100.0 : 0.0
        } else {
            let ratio = Double(completed) / Double(scheduledPastCount)
            consistency = min(100.0, max(0.0, (ratio * 100.0).rounded()))
        }
        
        return JourneySummaryMetrics(
            totalDays: total,
            completedCount: completed,
            evidenceCount: evidenceCount,
            missedCount: missed,
            restCount: rest,
            futureCount: future,
            daysRemaining: future,
            consistencyPercentage: consistency
        )
    }
}
