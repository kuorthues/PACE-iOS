//
//  EvidenceService.swift
//  PACE
//
// Service managing local photo evidence and its Firestore metadata:
// - Keeps image files in UID- and goal-scoped app storage
// - Caches images in memory for repeated thumbnail and detail rendering
// - Never stores image bytes in Firestore
//

import SwiftUI
import Combine
import UIKit

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

// NOTE / TODO: Firebase Storage cloud synchronization is deferred because the project
// is currently not on the Firebase Blaze billing plan. Evidence images are stored securely
// in local application sandbox storage partitioned by authenticated user ID.
// Do NOT attempt Firebase Storage uploads or create fake cloud storage behavior in this phase.
@MainActor
final class EvidenceService: ObservableObject {
    static let shared = EvidenceService()
    
    @Published var evidenceByGoal: [String: [EvidenceItem]] = [:]
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private let memoryCache = NSCache<NSString, UIImage>()
    
    private init() {
        memoryCache.countLimit = 100
    }
    
    // MARK: - User Scoping
    
    private func authoritativeUserId() -> String? {
        #if canImport(FirebaseAuth)
        if let authUid = Auth.auth().currentUser?.uid {
            return authUid
        }
        #endif
        return AuthService.shared.currentUser?.id
    }
    
    private func localKey(for goalId: String, uid: String) -> String {
        "pace_evidence_\(uid)_\(goalId)"
    }
    
    // MARK: - Local File System Directory
    
    private func localDirectoryURL(for goalId: String, uid: String) -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("evidence/\(uid)/\(goalId)", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private func localFileURL(for item: EvidenceItem, uid: String) -> URL {
        let dir = localDirectoryURL(for: item.goalId, uid: uid)
        let fileName = item.localFileName ?? "\(item.id).jpg"
        return dir.appendingPathComponent(fileName)
    }
    
    // MARK: - Local Metadata Storage
    
    private func loadLocalMetadata(for goalId: String, uid: String) -> [EvidenceItem] {
        guard let data = UserDefaults.standard.data(forKey: localKey(for: goalId, uid: uid)),
              let decoded = try? JSONDecoder().decode([EvidenceItem].self, from: data) else {
            return []
        }
        return decoded.sorted(by: { $0.createdAt > $1.createdAt })
    }
    
    private func saveLocalMetadata(_ items: [EvidenceItem], for goalId: String, uid: String) {
        let scopedItems = items.filter { $0.userId == uid && $0.goalId == goalId }
        if let encoded = try? JSONEncoder().encode(scopedItems) {
            UserDefaults.standard.set(encoded, forKey: localKey(for: goalId, uid: uid))
        }
        self.evidenceByGoal[goalId] = scopedItems.sorted(by: { $0.createdAt > $1.createdAt })
    }
    
    func clearInMemoryCache() {
        memoryCache.removeAllObjects()
        self.evidenceByGoal = [:]
        self.errorMessage = nil
    }
    // MARK: - Fetch Evidence
    
    func fetchEvidence(for goalId: String) async -> [EvidenceItem] {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        guard let uid = authoritativeUserId() else {
            self.evidenceByGoal[goalId] = []
            return []
        }
        
#if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        if AuthService.shared.isFirebaseConfigured, let authUid = Auth.auth().currentUser?.uid, authUid == uid {
            do {
                let snapshot = try await Firestore.firestore()
                    .collection("users")
                    .document(uid)
                    .collection("goals")
                    .document(goalId)
                    .collection("evidence")
                    .getDocuments()
                guard authoritativeUserId() == uid else { return [] }
                
                let fetched = snapshot.documents.compactMap { doc -> EvidenceItem? in
                    EvidenceItem(id: doc.documentID, dictionary: doc.data())
                }.sorted(by: { $0.createdAt > $1.createdAt })
                
                saveLocalMetadata(fetched, for: goalId, uid: uid)
                return fetched
            } catch {
                self.errorMessage = "Failed to sync evidence metadata: \(error.localizedDescription)"
            }
        }
        #endif
        guard authoritativeUserId() == uid else { return [] }
        let local = loadLocalMetadata(for: goalId, uid: uid)
            .filter { $0.userId == uid && $0.goalId == goalId }
        self.evidenceByGoal[goalId] = local
        return local
    }
    
    func fetchEvidenceItems(forGoal goalId: String, logId: String) -> [EvidenceItem] {
        guard let uid = authoritativeUserId() else { return [] }
        let items = evidenceByGoal[goalId] ?? loadLocalMetadata(for: goalId, uid: uid)
        return items
            .filter { $0.goalId == goalId && $0.logId == logId }
            .sorted {
                if $0.createdAt == $1.createdAt {
                    return $0.id < $1.id
                }
                return $0.createdAt < $1.createdAt
            }
    }
    
    // MARK: - Save / Upload Evidence
    
    func saveEvidence(
        goalId: String,
        logId: String,
        image: UIImage,
        caption: String?
    ) async throws -> EvidenceItem {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        guard let uid = authoritativeUserId() else {
            let error = AuthError.validation("You must be logged in to save evidence.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        guard !SharedGoalService.shared.sourceGoalIdsInProgress.contains(goalId) else {
            throw AuthError.validation("Evidence is locked while this goal is being shared.")
        }
        
        // 1. Compress image to sensible mobile dimensions
        guard let compressed = ImageCompressor.compress(image: image) else {
            let error = AuthError.validation("Unable to compress selected image.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        let evidenceId = UUID().uuidString
        let storagePath = "users/\(uid)/goals/\(goalId)/evidence/\(evidenceId).jpg"
        
        let item = EvidenceItem(
            id: evidenceId,
            userId: uid,
            goalId: goalId,
            logId: logId,
            storagePath: storagePath,
            caption: caption,
            createdAt: Date(),
            localFileName: "\(evidenceId).jpg"
        )
        
        // 2. Cache compressed image in memory and local sandbox disk partitioned by UID
        let fileURL = localFileURL(for: item, uid: uid)
        do {
            try compressed.data.write(to: fileURL, options: .atomic)
        } catch {
            let writeError = AuthError.validation("Unable to persist photo evidence locally.")
            self.errorMessage = writeError.localizedDescription
            throw writeError
        }
        memoryCache.setObject(compressed.image, forKey: "\(uid)|\(item.id)" as NSString)
        
        // 3. Save metadata to Firestore (No image bytes in Firestore)
#if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        if AuthService.shared.isFirebaseConfigured, let authUid = Auth.auth().currentUser?.uid, authUid == uid {
            do {
                try await Firestore.firestore()
                    .collection("users")
                    .document(uid)
                    .collection("goals")
                    .document(goalId)
                    .collection("evidence")
                    .document(evidenceId)
                    .setData(item.dictionary)
            } catch {
                self.errorMessage = "Failed to sync evidence metadata: \(error.localizedDescription)"
            }
        }
        #endif
        guard authoritativeUserId() == uid else {
            throw AuthError.validation("Account changed while photo evidence was saving.")
        }
        
        // 4. Append local metadata; multiple proofs may belong to one daily log.
        var currentItems = loadLocalMetadata(for: goalId, uid: uid)
        currentItems.append(item)
        saveLocalMetadata(currentItems, for: goalId, uid: uid)
        
        return item
    }
    
    // MARK: - Load Image
    
    func loadImage(for item: EvidenceItem) async -> UIImage? {
        // 1. Check memory cache
        if let cached = memoryCache.object(forKey: "\(item.userId)|\(item.id)" as NSString) {
            return cached
        }
        
        // 2. Check local disk sandbox for owner UID
        let fileURL = localFileURL(for: item, uid: item.userId)
        if FileManager.default.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            memoryCache.setObject(image, forKey: "\(item.userId)|\(item.id)" as NSString)
            return image
        }
        
        return nil
    }
    
    // MARK: - Delete Evidence
    
    func deleteEvidence(_ item: EvidenceItem) async throws {
        guard let uid = authoritativeUserId() else {
            let error = AuthError.validation("You must be logged in to delete evidence.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        guard item.userId == uid else {
            let error = AuthError.validation("You cannot delete evidence owned by another user.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        guard !SharedGoalService.shared.sourceGoalIdsInProgress.contains(item.goalId) else {
            throw AuthError.validation("Evidence is locked while this goal is being shared.")
        }
        
        // 1. Delete from Firestore
#if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        if AuthService.shared.isFirebaseConfigured, let authUid = Auth.auth().currentUser?.uid, authUid == uid {
            do {
                try await Firestore.firestore()
                    .collection("users")
                    .document(uid)
                    .collection("goals")
                    .document(item.goalId)
                    .collection("evidence")
                    .document(item.id)
                    .delete()
            } catch {
                self.errorMessage = "Failed to delete evidence metadata: \(error.localizedDescription)"
                throw error
            }
        }
        #endif
        guard authoritativeUserId() == uid else {
            throw AuthError.validation("Account changed while photo evidence was deleting.")
        }
        
        // 2. Remove from memory and user-scoped disk
        memoryCache.removeObject(forKey: "\(item.userId)|\(item.id)" as NSString)
        let fileURL = localFileURL(for: item, uid: item.userId)
        try? FileManager.default.removeItem(at: fileURL)
        
        // 3. Update local metadata and remove any stale DailyLog reference.
        var currentItems = loadLocalMetadata(for: item.goalId, uid: uid)
        currentItems.removeAll(where: { $0.id == item.id })
        saveLocalMetadata(currentItems, for: item.goalId, uid: uid)
        await DailyLogService.shared.clearEvidenceReference(
            goalId: item.goalId,
            logId: item.logId,
            evidenceId: item.id
        )
    }
    func clearEvidence(for goalId: String, logId: String) async {
        for item in fetchEvidenceItems(forGoal: goalId, logId: logId) {
            try? await deleteEvidence(item)
        }
    }

    func deleteAllEvidence(for goalId: String) async {
        guard let uid = authoritativeUserId() else { return }
        guard !SharedGoalService.shared.sourceGoalIdsInProgress.contains(goalId) else { return }
        let cached = evidenceByGoal[goalId] ?? []
        let fetched = await fetchEvidence(for: goalId)
        var itemsById: [String: EvidenceItem] = [:]
        for item in cached + fetched where item.userId == uid && item.goalId == goalId {
            itemsById[item.id] = item
        }
        let items = Array(itemsById.values)
        for item in items {
            try? await deleteEvidence(item)
        }
        evidenceByGoal[goalId] = []
        UserDefaults.standard.removeObject(forKey: localKey(for: goalId, uid: uid))
        let directory = localDirectoryURL(for: goalId, uid: uid)
        try? FileManager.default.removeItem(at: directory)
    }
}
