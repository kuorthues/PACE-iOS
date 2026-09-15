//
//  PACEWidgetSnapshot.swift
//  PACE
//
//  Shared snapshot model transferred via shared App Group / UserDefaults.
//

import Foundation

struct PACEWidgetSnapshot: Codable, Equatable {
    let goalId: String
    let goalTitle: String
    let targetDateString: String
    let daysRemaining: Int
    let currentStreak: Int
    let hasLoggedToday: Bool
    let isScheduledToday: Bool
    let totalInvestedMinutes: Int
    let lastUpdated: Date
    
    static var mock: PACEWidgetSnapshot {
        PACEWidgetSnapshot(
            goalId: "mock_primary_goal",
            goalTitle: "IOS MASTERY",
            targetDateString: "OCT 30",
            daysRemaining: 45,
            currentStreak: 12,
            hasLoggedToday: false,
            isScheduledToday: true,
            totalInvestedMinutes: 540,
            lastUpdated: Date()
        )
    }
}

enum PACEWidgetSnapshotManager {
    static let appGroupSuite = "group.mseud.edu.ph.PACE"
    static let snapshotKey = "pace_primary_goal_widget_snapshot"
    
    static func readSnapshot() -> PACEWidgetSnapshot? {
        if let sharedDefaults = UserDefaults(suiteName: appGroupSuite),
           let data = sharedDefaults.data(forKey: snapshotKey),
           let snapshot = try? JSONDecoder().decode(PACEWidgetSnapshot.self, from: data) {
            return snapshot
        }
        if let standardData = UserDefaults.standard.data(forKey: snapshotKey),
           let snapshot = try? JSONDecoder().decode(PACEWidgetSnapshot.self, from: standardData) {
            return snapshot
        }
        return nil
    }
    
    static func writeSnapshot(_ snapshot: PACEWidgetSnapshot?) {
        let data = snapshot != nil ? try? JSONEncoder().encode(snapshot) : nil
        if let sharedDefaults = UserDefaults(suiteName: appGroupSuite) {
            sharedDefaults.set(data, forKey: snapshotKey)
        }
        UserDefaults.standard.set(data, forKey: snapshotKey)
    }
}
