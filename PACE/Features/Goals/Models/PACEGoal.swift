//
//  PACEGoal.swift
//  PACE
//
//  Minimum Goal domain model adhering to PACE requirements:
//  - id, userId, title, createdAt, targetDate, status, activityTypes, scheduledWeekdays
//

import Foundation

enum GoalStatus: String, Codable, CaseIterable {
    case active = "active"
    case completed = "completed"
    case archived = "archived"
}

struct PACEGoal: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    var title: String
    let createdAt: Date
    var targetDate: Date
    var status: GoalStatus
    var activityTypes: [String]
    var scheduledWeekdays: [Int] // 1 = Sunday, 2 = Monday, ... 7 = Saturday
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        title: String,
        createdAt: Date = Date(),
        targetDate: Date,
        status: GoalStatus = .active,
        activityTypes: [String],
        scheduledWeekdays: [Int] = [1, 2, 3, 4, 5, 6, 7]
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.createdAt = createdAt
        self.targetDate = targetDate
        self.status = status
        self.activityTypes = activityTypes
        self.scheduledWeekdays = scheduledWeekdays
    }
    
    // MARK: - Computed Properties
    
    var daysRemaining: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTarget = calendar.startOfDay(for: targetDate)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfTarget)
        return max(0, components.day ?? 0)
    }
    
    var isScheduledForToday: Bool {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return scheduledWeekdays.contains(weekday)
    }
    
    var formattedTargetDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: targetDate)
    }
    
    var scheduleDescription: String {
        if scheduledWeekdays.count == 7 {
            return "EVERY DAY"
        } else if scheduledWeekdays.sorted() == [2, 3, 4, 5, 6] {
            return "WEEKDAYS (MON-FRI)"
        } else {
            let dayNames = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
            let selectedNames = scheduledWeekdays.sorted().compactMap { day -> String? in
                guard day >= 1 && day <= 7 else { return nil }
                return dayNames[day - 1]
            }
            return selectedNames.joined(separator: ", ")
        }
    }
    
    // MARK: - Dictionary Mapping for Firestore
    
    var dictionary: [String: Any] {
        [
            "id": id,
            "userId": userId,
            "title": title,
            "createdAt": createdAt.timeIntervalSince1970,
            "targetDate": targetDate.timeIntervalSince1970,
            "status": status.rawValue,
            "activityTypes": activityTypes,
            "scheduledWeekdays": scheduledWeekdays
        ]
    }
    
    init?(id: String, dictionary: [String: Any]) {
        guard let userId = dictionary["userId"] as? String,
              let title = dictionary["title"] as? String else {
            return nil
        }
        
        self.id = id
        self.userId = userId
        self.title = title
        
        if let createdTime = dictionary["createdAt"] as? TimeInterval {
            self.createdAt = Date(timeIntervalSince1970: createdTime)
        } else {
            self.createdAt = Date()
        }
        
        if let targetTime = dictionary["targetDate"] as? TimeInterval {
            self.targetDate = Date(timeIntervalSince1970: targetTime)
        } else {
            self.targetDate = Date()
        }
        
        if let statusString = dictionary["status"] as? String,
           let status = GoalStatus(rawValue: statusString) {
            self.status = status
        } else {
            self.status = .active
        }
        
        self.activityTypes = dictionary["activityTypes"] as? [String] ?? []
        self.scheduledWeekdays = dictionary["scheduledWeekdays"] as? [Int] ?? [1, 2, 3, 4, 5, 6, 7]
    }
}
