//
//  EvidenceItem.swift
//  PACE
//
//  Domain model for verified photo evidence.
//  Metadata is associated with user, goal, and DailyLog:
//  - id, userId, goalId, logId, storagePath, optional caption, createdAt
//  - Strictly excludes raw image bytes from metadata/Firestore
//

import Foundation

struct EvidenceItem: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let goalId: String
    let logId: String // Maps to DailyLog dateString or id
    let storagePath: String // Scoped storage path: users/{userId}/goals/{goalId}/evidence/{id}.jpg
    var caption: String?
    let createdAt: Date
    var localFileName: String? // Local cache filename for offline / local-test persistence
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        goalId: String,
        logId: String,
        storagePath: String? = nil,
        caption: String? = nil,
        createdAt: Date = Date(),
        localFileName: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.goalId = goalId
        self.logId = logId
        self.storagePath = storagePath ?? "users/\(userId)/goals/\(goalId)/evidence/\(id).jpg"
        self.caption = caption?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? caption?.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        self.createdAt = createdAt
        self.localFileName = localFileName ?? "\(id).jpg"
    }
    
    var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    // MARK: - Firestore Dictionary Representation (NO image bytes stored)
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "userId": userId,
            "goalId": goalId,
            "logId": logId,
            "storagePath": storagePath,
            "createdAt": createdAt.timeIntervalSince1970
        ]
        if let caption = caption {
            dict["caption"] = caption
        }
        return dict
    }
    
    init?(id: String, dictionary: [String: Any]) {
        guard let userId = dictionary["userId"] as? String,
              let goalId = dictionary["goalId"] as? String,
              let logId = dictionary["logId"] as? String,
              let storagePath = dictionary["storagePath"] as? String else {
            return nil
        }
        
        self.id = id
        self.userId = userId
        self.goalId = goalId
        self.logId = logId
        self.storagePath = storagePath
        self.caption = dictionary["caption"] as? String
        
        if let timestamp = dictionary["createdAt"] as? TimeInterval {
            self.createdAt = Date(timeIntervalSince1970: timestamp)
        } else {
            self.createdAt = Date()
        }
        self.localFileName = "\(id).jpg"
    }
}
