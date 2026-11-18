import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum SharedGoalStatus: String, Codable {
    case preparing
    case inviting
    case active
    case declined
    case cancelled
    case ended
}

struct SharedGoal: Identifiable, Equatable {
    let id: String
    var title: String
    var description: String
    var startDate: Date
    var targetDate: Date
    var targetDateString: String
    var activityTypes: [String]
    var scheduledWeekdays: [Int]
    let ownerId: String
    var memberIds: [String]
    var status: SharedGoalStatus
    var pendingInvitationId: String?
    var sourceGoalId: String?
    var memberJoinedAt: Date?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: String,
        title: String,
        description: String = "",
        startDate: Date,
        targetDate: Date,
        targetDateString: String? = nil,
        activityTypes: [String],
        scheduledWeekdays: [Int],
        ownerId: String,
        memberIds: [String],
        status: SharedGoalStatus,
        pendingInvitationId: String? = nil,
        sourceGoalId: String? = nil,
        memberJoinedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.startDate = startDate
        self.targetDate = targetDate
        self.targetDateString = targetDateString ?? DailyLog.dateFormatter.string(from: targetDate)
        self.activityTypes = activityTypes
        self.scheduledWeekdays = scheduledWeekdays
        self.ownerId = ownerId
        self.memberIds = memberIds
        self.status = status
        self.pendingInvitationId = pendingInvitationId
        self.sourceGoalId = sourceGoalId
        self.memberJoinedAt = memberJoinedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var countdownDays: Int {
        max(0, Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: targetDateForDisplay)
        ).day ?? 0)
    }
    var targetDateForDisplay: Date {
        DailyLog.dateFormatter.date(from: targetDateString) ?? targetDate
    }

    func asPACEGoal() -> PACEGoal {
        PACEGoal(
            id: id,
            userId: ownerId,
            title: title,
            createdAt: startDate,
            targetDate: targetDateForDisplay,
            status: .active,
            activityTypes: activityTypes,
            scheduledWeekdays: scheduledWeekdays
        )
    }

    var dictionary: [String: Any] {
        #if canImport(FirebaseFirestore)
        let start: Any = Timestamp(date: startDate)
        let target: Any = Timestamp(date: targetDate)
        let created: Any = Timestamp(date: createdAt)
        let updated: Any = Timestamp(date: updatedAt)
        #else
        let start: Any = startDate.timeIntervalSince1970
        let target: Any = targetDate.timeIntervalSince1970
        let created: Any = createdAt.timeIntervalSince1970
        let updated: Any = updatedAt.timeIntervalSince1970
        #endif

        var data: [String: Any] = [
            "title": title,
            "description": description,
            "startDate": start,
            "targetDate": target,
            "targetDateString": targetDateString,
            "activityTypes": activityTypes,
            "scheduledWeekdays": scheduledWeekdays,
            "ownerId": ownerId,
            "memberIds": memberIds,
            "status": status.rawValue,
            "createdAt": created,
            "updatedAt": updated
        ]
        if let pendingInvitationId { data["pendingInvitationId"] = pendingInvitationId }
        if let sourceGoalId { data["sourceGoalId"] = sourceGoalId }
        if let memberJoinedAt {
            #if canImport(FirebaseFirestore)
            data["memberJoinedAt"] = Timestamp(date: memberJoinedAt)
            #else
            data["memberJoinedAt"] = memberJoinedAt.timeIntervalSince1970
            #endif
        }
        return data
    }

    init?(id: String, dictionary: [String: Any]) {
        guard let title = dictionary["title"] as? String,
              let ownerId = dictionary["ownerId"] as? String,
              let memberIds = dictionary["memberIds"] as? [String],
              let rawStatus = dictionary["status"] as? String,
              let status = SharedGoalStatus(rawValue: rawStatus),
              let activityTypes = dictionary["activityTypes"] as? [String],
              let scheduledWeekdays = dictionary["scheduledWeekdays"] as? [Int],
              let startDate = Self.date(dictionary["startDate"]),
              let targetDate = Self.date(dictionary["targetDate"]) else { return nil }

        self.id = id
        self.title = title
        self.description = dictionary["description"] as? String ?? ""
        self.startDate = startDate
        self.targetDate = targetDate
        self.targetDateString = dictionary["targetDateString"] as? String ?? DailyLog.dateFormatter.string(from: targetDate)
        self.activityTypes = activityTypes
        self.scheduledWeekdays = scheduledWeekdays
        self.ownerId = ownerId
        self.memberIds = memberIds
        self.status = status
        self.pendingInvitationId = dictionary["pendingInvitationId"] as? String
        self.sourceGoalId = dictionary["sourceGoalId"] as? String
        self.memberJoinedAt = Self.date(dictionary["memberJoinedAt"])
        self.createdAt = Self.date(dictionary["createdAt"]) ?? Date()
        self.updatedAt = Self.date(dictionary["updatedAt"]) ?? Date()
    }

    private static func date(_ value: Any?) -> Date? {
        #if canImport(FirebaseFirestore)
        if let timestamp = value as? Timestamp { return timestamp.dateValue() }
        #endif
        if let date = value as? Date { return date }
        if let interval = value as? TimeInterval { return Date(timeIntervalSince1970: interval) }
        return nil
    }
}
