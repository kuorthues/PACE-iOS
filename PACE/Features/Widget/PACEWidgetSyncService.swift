//
//  PACEWidgetSyncService.swift
//  PACE
//
//  Main app service that synchronizes the nearest active goal state
//  into the shared snapshot for WidgetKit consumption.
//

import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
final class PACEWidgetSyncService {
    static let shared = PACEWidgetSyncService()
    private init() {}
    
    func syncPrimaryGoal(goals: [PACEGoal], logsByGoal: [String: [DailyLog]]) {
        let activeGoals = goals.filter { $0.status == .active }
        // Nearest active goal sorted by targetDate
        let primaryGoal = activeGoals.sorted(by: { $0.targetDate < $1.targetDate }).first
        
        guard let goal = primaryGoal else {
            PACEWidgetSnapshotManager.writeSnapshot(nil)
            reloadWidgets()
            return
        }
        
        let logs = logsByGoal[goal.id] ?? []
        let metrics = GoalAnalytics.compute(goal: goal, logs: logs)
        
        let todayString = DailyLog.dateFormatter.string(from: Date())
        let hasLoggedToday = logs.contains(where: { $0.dateString == todayString })
        
        let snapshot = PACEWidgetSnapshot(
            goalId: goal.id,
            goalTitle: goal.title,
            targetDateString: goal.formattedTargetDate,
            daysRemaining: goal.daysRemaining,
            currentStreak: metrics.currentStreak,
            hasLoggedToday: hasLoggedToday,
            isScheduledToday: goal.isScheduledForToday,
            totalInvestedMinutes: metrics.totalLoggedMinutes,
            lastUpdated: Date()
        )
        
        PACEWidgetSnapshotManager.writeSnapshot(snapshot)
        reloadWidgets()
    }
    
    private func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
