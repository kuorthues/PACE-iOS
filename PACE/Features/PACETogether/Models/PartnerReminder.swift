import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct PartnerReminder: Identifiable, Equatable {
    let id: String
    let sharedGoalId: String
    let senderId: String
    let recipientId: String
    let createdAt: Date

    init?(id: String, dictionary: [String: Any]) {
        guard let sharedGoalId = dictionary["sharedGoalId"] as? String,
              let senderId = dictionary["senderId"] as? String,
              let recipientId = dictionary["recipientId"] as? String else {
            return nil
        }

        let createdAt: Date?
        #if canImport(FirebaseFirestore)
        if let timestamp = dictionary["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = dictionary["createdAt"] as? Date
        }
        #else
        createdAt = dictionary["createdAt"] as? Date
        #endif

        guard let createdAt else { return nil }
        self.id = id
        self.sharedGoalId = sharedGoalId
        self.senderId = senderId
        self.recipientId = recipientId
        self.createdAt = createdAt
    }
}
