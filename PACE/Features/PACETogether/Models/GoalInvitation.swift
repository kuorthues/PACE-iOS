import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum GoalInvitationStatus: String, Codable {
    case pending
    case accepted
    case declined
    case cancelled
}

struct GoalInvitation: Identifiable, Equatable {
    let id: String
    let sharedGoalId: String
    let senderId: String
    let recipientId: String
    var status: GoalInvitationStatus
    let goalTitle: String
    let targetDate: Date
    let targetDateString: String
    let createdAt: Date
    var respondedAt: Date?

    init(
        id: String,
        sharedGoalId: String,
        senderId: String,
        recipientId: String,
        status: GoalInvitationStatus,
        goalTitle: String,
        targetDate: Date,
        targetDateString: String? = nil,
        createdAt: Date = Date(),
        respondedAt: Date? = nil
    ) {
        self.id = id
        self.sharedGoalId = sharedGoalId
        self.senderId = senderId
        self.recipientId = recipientId
        self.status = status
        self.goalTitle = goalTitle
        self.targetDate = targetDate
        self.targetDateString = targetDateString ?? DailyLog.dateFormatter.string(from: targetDate)
        self.createdAt = createdAt
        self.respondedAt = respondedAt
    }
    var targetDateForDisplay: Date {
        DailyLog.dateFormatter.date(from: targetDateString) ?? targetDate
    }

    var dictionary: [String: Any] {
        #if canImport(FirebaseFirestore)
        let target: Any = Timestamp(date: targetDate)
        let created: Any = Timestamp(date: createdAt)
        #else
        let target: Any = targetDate.timeIntervalSince1970
        let created: Any = createdAt.timeIntervalSince1970
        #endif
        var data: [String: Any] = [
            "sharedGoalId": sharedGoalId,
            "senderId": senderId,
            "recipientId": recipientId,
            "status": status.rawValue,
            "goalTitle": goalTitle,
            "targetDate": target,
            "targetDateString": targetDateString,
            "createdAt": created
        ]
        if let respondedAt {
            #if canImport(FirebaseFirestore)
            data["respondedAt"] = Timestamp(date: respondedAt)
            #else
            data["respondedAt"] = respondedAt.timeIntervalSince1970
            #endif
        }
        return data
    }

    init?(id: String, dictionary: [String: Any]) {
        guard let sharedGoalId = dictionary["sharedGoalId"] as? String,
              let senderId = dictionary["senderId"] as? String,
              let recipientId = dictionary["recipientId"] as? String,
              let rawStatus = dictionary["status"] as? String,
              let status = GoalInvitationStatus(rawValue: rawStatus),
              let goalTitle = dictionary["goalTitle"] as? String,
              let targetDate = Self.date(dictionary["targetDate"]),
              let createdAt = Self.date(dictionary["createdAt"]) else { return nil }
        self.id = id
        self.sharedGoalId = sharedGoalId
        self.senderId = senderId
        self.recipientId = recipientId
        self.status = status
        self.goalTitle = goalTitle
        self.targetDate = targetDate
        self.targetDateString = dictionary["targetDateString"] as? String ?? DailyLog.dateFormatter.string(from: targetDate)
        self.createdAt = createdAt
        self.respondedAt = Self.date(dictionary["respondedAt"])
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
