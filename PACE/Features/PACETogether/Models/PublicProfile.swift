import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct PublicProfile: Identifiable, Codable, Equatable {
    static let maxBioLength = 120
    static let maxDisplayNameLength = 60
    static let minUsernameLength = 3
    static let maxUsernameLength = 20

    let userId: String
    var username: String
    var usernameNormalized: String
    var displayName: String
    var bio: String
    var isDiscoverable: Bool
    var lookingForPartner: Bool
    let createdAt: Date
    var updatedAt: Date

    var id: String { userId }

    var initials: String {
        let parts = displayName.split(whereSeparator: { $0 == " " || $0 == "-" })
        let letters = parts.prefix(2).compactMap { $0.first.map(String.init) }
        return letters.joined().uppercased().isEmpty ? "P" : letters.joined().uppercased()
    }

    init(
        userId: String,
        username: String,
        displayName: String,
        bio: String = "",
        isDiscoverable: Bool = false,
        lookingForPartner: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.userId = userId
        self.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        self.usernameNormalized = Self.normalizeUsername(username)
        self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.bio = String(bio.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxBioLength))
        self.isDiscoverable = isDiscoverable
        self.lookingForPartner = lookingForPartner
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func normalizeUsername(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: Locale(identifier: "en_US_POSIX"))
    }

    static func validationError(
        username: String,
        displayName: String,
        bio: String
    ) -> String? {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedUsername = normalizeUsername(trimmedUsername)
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.")

        guard trimmedUsername.count >= minUsernameLength && trimmedUsername.count <= maxUsernameLength else {
            return "Username must be 3–20 characters."
        }
        guard trimmedUsername.unicodeScalars.allSatisfy(allowedCharacters.contains) else {
            return "Username can use letters, numbers, underscores, and periods only."
        }
        guard normalizedUsername == trimmedUsername.lowercased(with: Locale(identifier: "en_US_POSIX")) else {
            return "Username contains unsupported characters."
        }
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Display name cannot be empty."
        }
        guard displayName.trimmingCharacters(in: .whitespacesAndNewlines).count <= maxDisplayNameLength else {
            return "Display name must be 60 characters or fewer."
        }
        guard bio.count <= maxBioLength else {
            return "Bio must be 120 characters or fewer."
        }
        return nil
    }

    var dictionary: [String: Any] {
        [
            "userId": userId,
            "username": username,
            "usernameNormalized": usernameNormalized,
            "displayName": displayName,
            "bio": bio,
            "isDiscoverable": isDiscoverable,
            "lookingForPartner": lookingForPartner,
            "createdAt": createdAt,
            "updatedAt": updatedAt
        ]
    }

    init?(id: String, dictionary: [String: Any]) {
        guard let userId = dictionary["userId"] as? String,
              userId == id,
              let username = dictionary["username"] as? String,
              let usernameNormalized = dictionary["usernameNormalized"] as? String,
              let displayName = dictionary["displayName"] as? String,
              let isDiscoverable = dictionary["isDiscoverable"] as? Bool,
              let lookingForPartner = dictionary["lookingForPartner"] as? Bool else {
            return nil
        }

        self.userId = userId
        self.username = username
        self.usernameNormalized = usernameNormalized
        self.displayName = displayName
        self.bio = String((dictionary["bio"] as? String ?? "").prefix(Self.maxBioLength))
        self.isDiscoverable = isDiscoverable
        self.lookingForPartner = lookingForPartner

        #if canImport(FirebaseFirestore)
        if let timestamp = dictionary["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else if let date = dictionary["createdAt"] as? Date {
            self.createdAt = date
        } else {
            self.createdAt = Date()
        }
        if let timestamp = dictionary["updatedAt"] as? Timestamp {
            self.updatedAt = timestamp.dateValue()
        } else if let date = dictionary["updatedAt"] as? Date {
            self.updatedAt = date
        } else {
            self.updatedAt = Date()
        }
        #else
        self.createdAt = dictionary["createdAt"] as? Date ?? Date()
        self.updatedAt = dictionary["updatedAt"] as? Date ?? Date()
        #endif
    }
}
