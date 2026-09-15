//
//  JourneyDay.swift
//  PACE
//
//  Domain model representing a single calendar day in a PACE Goal Journey Timeline.
//  Strictly adheres to PACE requirements:
//  - Resolves each day to: completed, completedWithEvidence, missed, rest, today, future, or target
//  - Associates log data, evidence, schedule commitment, and day ordering
//  - Zero Swift Charts dependency
//

import Foundation

// MARK: - Journey Day State Enum

enum JourneyDayState: String, CaseIterable, Codable, Equatable {
    case completed               // Filled #A7FF19
    case completedWithEvidence   // Filled #A7FF19 + connected square evidence thumbnail
    case missed                  // Gray outlined node
    case rest                    // Neutral marker
    case today                   // Emphasized #A7FF19 outline
    case future                  // Faint marker
    case target                  // Square terminal node
    
    var title: String {
        switch self {
        case .completed:
            return "COMPLETED"
        case .completedWithEvidence:
            return "COMPLETED + PROOF"
        case .missed:
            return "MISSED"
        case .rest:
            return "REST DAY"
        case .today:
            return "TODAY"
        case .future:
            return "SCHEDULED"
        case .target:
            return "TARGET"
        }
    }
}

// MARK: - Journey Day Model

struct JourneyDay: Identifiable, Equatable {
    let id: String // Unique ID: dateString (YYYY-MM-DD)
    let date: Date
    let dateString: String
    let dayIndex: Int // 1-based index (e.g. Day 1, Day 2...)
    let totalDays: Int // Total days in goal horizon
    let state: JourneyDayState
    let isScheduled: Bool // Whether this weekday is in goal.scheduledWeekdays
    let isToday: Bool
    let isTarget: Bool
    let log: DailyLog?
    let evidence: EvidenceItem?
    
    // MARK: - Formatting Helpers
    
    var formattedDayIndex: String {
        "DAY \(dayIndex)"
    }
    
    var formattedDayProgress: String {
        "DAY \(dayIndex) OF \(totalDays)"
    }
    
    var weekdayShort: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
    
    var weekdaySingleLetter: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date).uppercased()
    }
    
    var formattedShortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
    
    var formattedFullDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date).uppercased()
    }
    
    var formattedMediumDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date).uppercased()
    }
}
