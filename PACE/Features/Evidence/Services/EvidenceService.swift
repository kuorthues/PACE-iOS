//
//  EvidenceService.swift
//  PACE
//
//  Service managing photo evidence binaries and metadata:
//  - Stores image binaries in Firebase Storage (scoped to users/{uid}/goals/{goalId}/evidence/{id}.jpg)
//  - Stores metadata in Firestore (scoped to users/{uid}/goals/{goalId}/evidence/{id})
//  - Local disk sandbox caching for reliable offline / local-test persistence
//  - In-memory NSCache for instantaneous square thumbnail and detail rendering
//  - Strictly prevents storing raw image bytes in Firestore
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
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: localKey(for: goalId, uid: uid))
        }
        self.evidenceByGoal[goalId] = items.sorted(by: { $0.createdAt > $1.createdAt })
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
        
        let local = loadLocalMetadata(for: goalId, uid: uid)
        self.evidenceByGoal[goalId] = local
        return local
    }
    
    func fetchEvidence(forGoal goalId: String, logId: String) -> EvidenceItem? {
        guard let uid = authoritativeUserId() else { return nil }
        let items = evidenceByGoal[goalId] ?? loadLocalMetadata(for: goalId, uid: uid)
        return items.first { $0.logId == logId }
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
            print("Warning: failed to write local evidence file: \(error)")
        }
        memoryCache.setObject(compressed.image, forKey: item.id as NSString)
        
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
        
        // 4. Update local metadata cache
        var currentItems = loadLocalMetadata(for: goalId, uid: uid)
        currentItems.removeAll(where: { $0.logId == logId })
        currentItems.insert(item, at: 0)
        saveLocalMetadata(currentItems, for: goalId, uid: uid)
        
        return item
    }
    
    // MARK: - Load Image
    
    func loadImage(for item: EvidenceItem) async -> UIImage? {
        // 1. Check memory cache
        if let cached = memoryCache.object(forKey: item.id as NSString) {
            return cached
        }
        
        // 2. Check local disk sandbox for owner UID
        let fileURL = localFileURL(for: item, uid: item.userId)
        if FileManager.default.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            memoryCache.setObject(image, forKey: item.id as NSString)
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
        
        // 1. Delete from Firestore
#if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        if AuthService.shared.isFirebaseConfigured, let authUid = Auth.auth().currentUser?.uid, authUid == uid {
            try? await Firestore.firestore()
                .collection("users")
                .document(uid)
                .collection("goals")
                .document(item.goalId)
                .collection("evidence")
                .document(item.id)
                .delete()
        }
        #endif
        
        // 2. Remove from memory and user-scoped disk
        memoryCache.removeObject(forKey: item.id as NSString)
        let fileURL = localFileURL(for: item, uid: item.userId)
        try? FileManager.default.removeItem(at: fileURL)
        
        // 3. Update local metadata
        var currentItems = loadLocalMetadata(for: item.goalId, uid: uid)
        currentItems.removeAll(where: { $0.id == item.id })
        saveLocalMetadata(currentItems, for: item.goalId, uid: uid)
    }
    func clearEvidence(for goalId: String, logId: String) async {
        if let item = fetchEvidence(forGoal: goalId, logId: logId) {
            try? await deleteEvidence(item)
        }
    }
}
