//
//  PACEUser.swift
//  PACE
//
//  Lightweight user model representing an authenticated PACE user.
//

import Foundation

struct PACEUser: Identifiable, Codable, Equatable {
    let id: String
    let email: String
    let displayName: String?
    
    init(id: String, email: String, displayName: String? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
    }
}
