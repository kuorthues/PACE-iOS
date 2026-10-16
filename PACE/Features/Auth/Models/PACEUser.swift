//
//  PACEUser.swift
//  PACE
//
//  Lightweight user model representing an authenticated PACE user.
//

import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct PACEUser: Identifiable, Codable, Equatable {
    let id: String
    let email: String
    let displayName: String?
    let createdAt: Date?
    let updatedAt: Date?
    
    init(
        id: String,
        email: String,
        displayName: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Firestore Dictionary Mapping
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "uid": id,
            "email": email
        ]
        if let displayName = displayName {
            dict["displayName"] = displayName
        }
        if let createdAt = createdAt {
            dict["createdAt"] = createdAt
        }
        if let updatedAt = updatedAt {
            dict["updatedAt"] = updatedAt
        }
        return dict
    }
    
    init?(id: String, dictionary: [String: Any]) {
        guard let email = dictionary["email"] as? String else {
            return nil
        }
        self.id = id
        self.email = email
        self.displayName = dictionary["displayName"] as? String
        
        #if canImport(FirebaseFirestore)
        if let ts = dictionary["createdAt"] as? Timestamp {
            self.createdAt = ts.dateValue()
        } else if let date = dictionary["createdAt"] as? Date {
            self.createdAt = date
        } else {
            self.createdAt = nil
        }
        
        if let ts = dictionary["updatedAt"] as? Timestamp {
            self.updatedAt = ts.dateValue()
        } else if let date = dictionary["updatedAt"] as? Date {
            self.updatedAt = date
        } else {
            self.updatedAt = nil
        }
        #else
        self.createdAt = dictionary["createdAt"] as? Date
        self.updatedAt = dictionary["updatedAt"] as? Date
        #endif
    }
}
