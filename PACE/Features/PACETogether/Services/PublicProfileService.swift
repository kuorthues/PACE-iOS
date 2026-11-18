import SwiftUI
import Combine

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class PublicProfileService: ObservableObject {
    static let shared = PublicProfileService()

    @Published private(set) var currentProfile: PublicProfile?
    @Published private(set) var suggestions: [PublicProfile] = []
    @Published var searchResults: [PublicProfile] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?

    private init() {}

    func clearInMemoryCache() {
        currentProfile = nil
        suggestions = []
        searchResults = []
        isLoading = false
        errorMessage = nil
        statusMessage = nil
    }

    func fetchCurrentProfile() async -> PublicProfile? {
        guard let uid = authoritativeUserId() else {
            currentProfile = nil
            return nil
        }

        errorMessage = nil
        statusMessage = nil
        #if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        if AuthService.shared.isFirebaseConfigured,
           let authUid = Auth.auth().currentUser?.uid,
           authUid == uid {
            do {
                let snapshot = try await Firestore.firestore()
                    .collection("publicProfiles")
                    .document(uid)
                    .getDocument()
                currentProfile = snapshot.data().flatMap { PublicProfile(id: uid, dictionary: $0) }
                return currentProfile
            } catch {
                errorMessage = "Could not load your PACE profile."
                currentProfile = nil
                return nil
            }
        }
        #endif

        currentProfile = loadLocalProfile(for: uid)
        return currentProfile
    }

    func saveProfile(
        displayName: String,
        username: String,
        bio: String,
        isDiscoverable: Bool,
        lookingForPartner: Bool
    ) async throws {
        guard let uid = authoritativeUserId() else {
            throw PublicProfileError.notAuthenticated
        }
        guard let validationError = PublicProfile.validationError(
            username: username,
            displayName: displayName,
            bio: bio
        ) else {
            // Continue with the normalized, trimmed values below.
            let normalizedUsername = PublicProfile.normalizeUsername(username)
            let now = Date()
            let existing = currentProfile

            if let existing, existing.usernameNormalized != normalizedUsername {
                throw PublicProfileError.usernameImmutable
            }

            let profile = PublicProfile(
                userId: uid,
                username: existing?.username ?? username,
                displayName: displayName,
                bio: bio,
                isDiscoverable: isDiscoverable,
                lookingForPartner: lookingForPartner,
                createdAt: existing?.createdAt ?? now,
                updatedAt: now
            )

            #if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
            if AuthService.shared.isFirebaseConfigured,
               let authUid = Auth.auth().currentUser?.uid,
               authUid == uid {
                do {
                    let db = Firestore.firestore()
                    let profileRef = db.collection("publicProfiles").document(uid)
                    var profileData = profile.dictionary
                    profileData["updatedAt"] = FieldValue.serverTimestamp()

                    if existing == nil {
                        profileData["createdAt"] = FieldValue.serverTimestamp()
                        let reservationRef = db.collection("usernames").document(profile.usernameNormalized)
                        let reservationData: [String: Any] = [
                            "userId": uid,
                            "usernameNormalized": profile.usernameNormalized,
                            "createdAt": FieldValue.serverTimestamp()
                        ]
                        let batch = db.batch()
                        batch.setData(profileData, forDocument: profileRef)
                        batch.setData(reservationData, forDocument: reservationRef)
                        try await batch.commit()
                    } else {
                        try await profileRef.updateData([
                            "displayName": profile.displayName,
                            "bio": profile.bio,
                            "isDiscoverable": profile.isDiscoverable,
                            "lookingForPartner": profile.lookingForPartner,
                            "updatedAt": FieldValue.serverTimestamp()
                        ])

                    }
                    currentProfile = profile
                    saveLocalProfile(profile, for: uid)
                    statusMessage = "PROFILE SAVED"
                    return
                } catch {
                    throw mapSaveError(error)
                }
            }
            #endif

            currentProfile = profile
            saveLocalProfile(profile, for: uid)
            statusMessage = "PROFILE SAVED LOCALLY"
            return
        }
        throw PublicProfileError.validation(validationError)
    }

    func fetchSuggestions(limit: Int = 3) async {
        guard let uid = authoritativeUserId() else {
            suggestions = []
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        #if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        if AuthService.shared.isFirebaseConfigured,
           let authUid = Auth.auth().currentUser?.uid,
           authUid == uid {
            do {
                let snapshot = try await Firestore.firestore()
                    .collection("publicProfiles")
                    .whereField("isDiscoverable", isEqualTo: true)
                    .limit(to: max(1, min(limit * 2, 12)))
                    .getDocuments()
                suggestions = decodeProfiles(snapshot.documents)
                    .filter { $0.userId != uid }
                    .sorted { $0.usernameNormalized < $1.usernameNormalized }
                    .prefix(limit)
                    .map { $0 }
                return
            } catch {
                errorMessage = "Could not load PACE Together profiles."
                suggestions = []
                return
            }
        }
        #endif

        suggestions = []
    }

    func searchProfiles(username: String, limit: Int = 20) async {
        let normalized = PublicProfile.normalizeUsername(username)
        guard !normalized.isEmpty, let uid = authoritativeUserId() else {
            searchResults = []
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        #if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        if AuthService.shared.isFirebaseConfigured,
           let authUid = Auth.auth().currentUser?.uid,
           authUid == uid {
            do {
                let end = normalized + "\u{f8ff}"
                let snapshot = try await Firestore.firestore()
                    .collection("publicProfiles")
                    .whereField("isDiscoverable", isEqualTo: true)
                    .whereField("usernameNormalized", isGreaterThanOrEqualTo: normalized)
                    .whereField("usernameNormalized", isLessThan: end)
                    .limit(to: max(1, min(limit, 50)))
                    .getDocuments()
                searchResults = decodeProfiles(snapshot.documents)
                    .filter { $0.userId != uid }
                    .sorted { $0.usernameNormalized < $1.usernameNormalized }
                return
            } catch {
                errorMessage = "Search is unavailable right now."
                searchResults = []
                return
            }
        }
        #endif

        searchResults = []
    }

    func fetchPublicProfile(userId: String) async -> PublicProfile? {
        guard let uid = authoritativeUserId() else { return nil }

        #if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        if AuthService.shared.isFirebaseConfigured,
           let authUid = Auth.auth().currentUser?.uid,
           authUid == uid {
            do {
                let snapshot = try await Firestore.firestore()
                    .collection("publicProfiles")
                    .document(userId)
                    .getDocument()
                guard let data = snapshot.data(), let profile = PublicProfile(id: userId, dictionary: data) else {
                    return nil
                }
                guard profile.userId == uid || profile.isDiscoverable else { return nil }
                return profile
            } catch {
                errorMessage = "This profile is unavailable."
                return nil
            }
        }
        #endif

        return nil
    }

    private func authoritativeUserId() -> String? {
        #if canImport(FirebaseAuth)
        if let authUid = Auth.auth().currentUser?.uid {
            return authUid
        }
        #endif
        return AuthService.shared.currentUser?.id
    }
#if canImport(FirebaseFirestore)
    private func decodeProfiles(_ documents: [QueryDocumentSnapshot]) -> [PublicProfile] {
        documents.compactMap { PublicProfile(id: $0.documentID, dictionary: $0.data()) }
    }
#endif

    private func localKey(for uid: String) -> String {
        "pace_public_profile_\(uid)"
    }

    private func loadLocalProfile(for uid: String) -> PublicProfile? {
        guard let data = UserDefaults.standard.data(forKey: localKey(for: uid)) else { return nil }
        return try? JSONDecoder().decode(PublicProfile.self, from: data)
    }

    private func saveLocalProfile(_ profile: PublicProfile, for uid: String) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: localKey(for: uid))
        }
    }

    private func mapSaveError(_ error: Error) -> PublicProfileError {
        let nsError = error as NSError
        if nsError.code == 7 || nsError.localizedDescription.localizedCaseInsensitiveContains("permission") {
            return .usernameUnavailable
        }
        return .server(nsError.localizedDescription)
    }
}

enum PublicProfileError: LocalizedError, Equatable {
    case notAuthenticated
    case validation(String)
    case usernameImmutable
    case usernameUnavailable
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to create a PACE profile."
        case .validation(let message):
            return message
        case .usernameImmutable:
            return "Username cannot be changed after your profile is created."
        case .usernameUnavailable:
            return "That username is unavailable. Choose another username."
        case .server(let message):
            return message
        }
    }
}
