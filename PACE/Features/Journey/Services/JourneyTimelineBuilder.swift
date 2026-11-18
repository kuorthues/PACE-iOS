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
        
        // Preserve every saved session by calendar date; the Journey UI groups
        // same-day sessions instead of dropping all but one.
        var logsByDate: [String: [DailyLog]] = [:]
        for log in logs {
            logsByDate[log.dateString, default: []].append(log)
        }
        for dateString in logsByDate.keys {
            logsByDate[dateString]?.sort {
                if ($0.evidenceId != nil) != ($1.evidenceId != nil) {
                    return $0.evidenceId != nil
                }
                return $0.updatedAt > $1.updatedAt
            }
        }
        
        // Index evidence once so long journeys do not rescan every photo for every day.
        var evidenceById: [String: EvidenceItem] = [:]
        for item in evidenceItems where item.goalId == goal.id {
            if let existing = evidenceById[item.id] {
                if item.createdAt < existing.createdAt {
                    evidenceById[item.id] = item
                }
            } else {
                evidenceById[item.id] = item
            }
        }
        let evidenceByLogId = Dictionary(grouping: evidenceById.values, by: \.logId)
        
        
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
            
            let dayLogs = logsByDate[dString] ?? []
            let log = dayLogs.first
            
            let attachedEvidence: [EvidenceItem]
            if !dayLogs.isEmpty {
                var candidates: [EvidenceItem] = []
                for dayLog in dayLogs {
                    candidates.append(contentsOf: evidenceByLogId[dayLog.id] ?? [])
                    if dayLog.id != dString {
                        candidates.append(contentsOf: evidenceByLogId[dString] ?? [])
                    }
                    if let evidenceId = dayLog.evidenceId,
                       let linkedEvidence = evidenceById[evidenceId] {
                        candidates.append(linkedEvidence)
                    }
                }
                attachedEvidence = candidates
            } else {
                attachedEvidence = evidenceByLogId[dString] ?? []
            }
            var seenEvidenceIds = Set<String>()
            let sortedEvidence = attachedEvidence
                .filter { seenEvidenceIds.insert($0.id).inserted }
                .sorted {
                    if $0.createdAt == $1.createdAt { return $0.id < $1.id }
                    return $0.createdAt < $1.createdAt
                }
            
            
            // State resolution
            let state: JourneyDayState
            if isTarget && (isFuture || log == nil) {
                state = .target
            } else if isToday && log == nil {
                state = .today
            } else if log != nil {
                let hasEvidence = !sortedEvidence.isEmpty
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
                logs: dayLogs,
                evidenceItems: sortedEvidence
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
                evidenceCount += day.evidenceItems.count
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
