import Foundation

struct SharedMemberMetrics: Identifiable, Equatable {
    let userId: String
    let currentStreak: Int
    let activeDays: Int
    let sessions: Int
    let totalLoggedMinutes: Int
    let consistencyPercentage: Double

    var id: String { userId }
}

struct SharedGoalMetrics: Equatable {
    let combinedLoggedMinutes: Int
    let totalSessions: Int
    let activeDays: Int
    let members: [SharedMemberMetrics]
}

enum SharedGoalAnalytics {
    static func compute(
        goal: SharedGoal,
        logs: [DailyLog],
        asOf: Date = Date(),
        calendar: Calendar = .current
    ) -> SharedGoalMetrics {
        var memberIds = goal.memberIds
        for userId in Set(logs.compactMap(\.authorId)).sorted() where !memberIds.contains(userId) {
            memberIds.append(userId)
        }
        let members = memberIds.map { userId -> SharedMemberMetrics in
            let memberGoal = PACEGoal(
                id: goal.id,
                userId: goal.ownerId,
                title: goal.title,
                createdAt: userId == goal.ownerId ? goal.startDate : (goal.memberJoinedAt ?? goal.startDate),
                targetDate: goal.targetDateForDisplay,
                status: .active,
                activityTypes: goal.activityTypes,
                scheduledWeekdays: goal.scheduledWeekdays
            )
            let memberLogs = logs.filter { $0.authorId == userId }
            let metrics = GoalAnalytics.compute(
                goal: memberGoal,
                logs: memberLogs,
                asOf: asOf,
                calendar: calendar
            )
            return SharedMemberMetrics(
                userId: userId,
                currentStreak: metrics.currentStreak,
                activeDays: metrics.activeDays,
                sessions: memberLogs.count,
                totalLoggedMinutes: metrics.totalLoggedMinutes,
                consistencyPercentage: metrics.consistencyPercentage
            )
        }
        return SharedGoalMetrics(
            combinedLoggedMinutes: logs.reduce(0) { $0 + $1.durationMinutes },
            totalSessions: logs.count,
            activeDays: Set(logs.map(\.dateString)).count,
            members: members
        )
    }
}
