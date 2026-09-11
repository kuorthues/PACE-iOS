//
//  DailyLog.swift
//  PACE
//
//  Domain model for daily goal progress entries.
//  Enforces one normal log per goal/calendar day.
//

import Foundation

struct DailyLog: Identifiable, Codable, Equatable {
    let id: String // Unique ID, typically \(dateString) or \(goalId)_\(dateString)
    let goalId: String
    let date: Date
    let dateString: String // "YYYY-MM-DD"
    var selectedActivities: [String]
    var durationMinutes: Int
    var note: String?
    let createdAt: Date
    var updatedAt: Date
    
    init(
        id: String? = nil,
        goalId: String,
        date: Date = Date(),
        selectedActivities: [String],
        durationMinutes: Int,
        note: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let formatter = DailyLog.dateFormatter
        let dString = formatter.string(from: startOfDay)
        
        self.id = id ?? "\(goalId)_\(dString)"
        self.goalId = goalId
        self.date = startOfDay
        self.dateString = dString
        self.selectedActivities = selectedActivities
        self.durationMinutes = max(1, durationMinutes)
        self.note = note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? note?.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = Calendar.current.timeZone
        return formatter
    }()
    
    var formattedDisplayDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var formattedDuration: String {
        let hours = durationMinutes / 60
        let mins = durationMinutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
    
    // MARK: - Dictionary Representation for Firestore
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "goalId": goalId,
            "date": date.timeIntervalSince1970,
            "dateString": dateString,
            "selectedActivities": selectedActivities,
            "durationMinutes": durationMinutes,
            "createdAt": createdAt.timeIntervalSince1970,
            "updatedAt": updatedAt.timeIntervalSince1970
        ]
        if let note = note {
            dict["note"] = note
        }
        return dict
    }
    
    init?(id: String, dictionary: [String: Any]) {
        guard let goalId = dictionary["goalId"] as? String,
              let dateString = dictionary["dateString"] as? String,
              let selectedActivities = dictionary["selectedActivities"] as? [String],
              let durationMinutes = dictionary["durationMinutes"] as? Int else {
            return nil
        }
        
        self.id = id
        self.goalId = goalId
        self.dateString = dateString
        
        if let dateTime = dictionary["date"] as? TimeInterval {
            self.date = Date(timeIntervalSince1970: dateTime)
        } else if let parsedDate = DailyLog.dateFormatter.date(from: dateString) {
            self.date = parsedDate
        } else {
            self.date = Date()
        }
        
        self.selectedActivities = selectedActivities
        self.durationMinutes = durationMinutes
        self.note = dictionary["note"] as? String
        
        if let createdTime = dictionary["createdAt"] as? TimeInterval {
            self.createdAt = Date(timeIntervalSince1970: createdTime)
        } else {
            self.createdAt = Date()
        }
        
        if let updatedTime = dictionary["updatedAt"] as? TimeInterval {
            self.updatedAt = Date(timeIntervalSince1970: updatedTime)
        } else {
            self.updatedAt = Date()
        }
    }
}
