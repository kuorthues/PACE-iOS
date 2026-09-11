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

#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

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
    
    private func activeUserId() -> String {
        AuthService.shared.currentUser?.id ?? "student_user"
    }
    
    private func localKey(for goalId: String) -> String {
        "pace_evidence_\(activeUserId())_\(goalId)"
    }
    
    // MARK: - Local File System Directory
    
    private func localDirectoryURL(for goalId: String) -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("evidence/\(activeUserId())/\(goalId)", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private func localFileURL(for item: EvidenceItem) -> URL {
        let dir = localDirectoryURL(for: item.goalId)
        let fileName = item.localFileName ?? "\(item.id).jpg"
        return dir.appendingPathComponent(fileName)
    }
    
    // MARK: - Local Metadata Storage
    
    private func loadLocalMetadata(for goalId: String) -> [EvidenceItem] {
        guard let data = UserDefaults.standard.data(forKey: localKey(for: goalId)),
              let decoded = try? JSONDecoder().decode([EvidenceItem].self, from: data) else {
            return []
        }
        return decoded.sorted(by: { $0.createdAt > $1.createdAt })
    }
    
    private func saveLocalMetadata(_ items: [EvidenceItem], for goalId: String) {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: localKey(for: goalId))
        }
        self.evidenceByGoal[goalId] = items.sorted(by: { $0.createdAt > $1.createdAt })
    }
    
    // MARK: - Fetch Evidence
    
    func fetchEvidence(for goalId: String) async -> [EvidenceItem] {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        let uid = activeUserId()
        
        #if canImport(FirebaseFirestore)
        if AuthService.shared.isFirebaseConfigured {
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
                
                saveLocalMetadata(fetched, for: goalId)
                return fetched
            } catch {
                self.errorMessage = "Failed to sync evidence metadata: \(error.localizedDescription)"
            }
        }
        #endif
        
        let local = loadLocalMetadata(for: goalId)
        self.evidenceByGoal[goalId] = local
        return local
    }
    
    func fetchEvidence(forGoal goalId: String, logId: String) -> EvidenceItem? {
        let items = evidenceByGoal[goalId] ?? loadLocalMetadata(for: goalId)
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
        
        let uid = activeUserId()
        
        // 1. Compress image to sensible mobile dimensions
        guard let compressed = ImageCompressor.compress(image: image) else {
            throw AuthError.validation("Unable to compress selected image.")
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
        
        // 2. Cache compressed image in memory and local sandbox disk
        let fileURL = localFileURL(for: item)
        do {
            try compressed.data.write(to: fileURL, options: .atomic)
        } catch {
            print("Warning: failed to write local evidence file: \(error)")
        }
        memoryCache.setObject(compressed.image, forKey: item.id as NSString)
        
        // 3. Upload to Firebase Storage if available and configured
        #if canImport(FirebaseStorage)
        if AuthService.shared.isFirebaseConfigured {
            let storageRef = Storage.storage().reference().child(storagePath)
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            _ = try await storageRef.putDataAsync(compressed.data, metadata: metadata)
        }
        #endif
        
        // 4. Save metadata to Firestore (No image bytes in Firestore)
        #if canImport(FirebaseFirestore)
        if AuthService.shared.isFirebaseConfigured {
            try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .collection("goals")
                .document(goalId)
                .collection("evidence")
                .document(evidenceId)
                .setData(item.dictionary)
        }
        #endif
        
        // 5. Update local metadata cache
        var currentItems = loadLocalMetadata(for: goalId)
        // Replace existing evidence for same log if present
        currentItems.removeAll(where: { $0.logId == logId })
        currentItems.insert(item, at: 0)
        saveLocalMetadata(currentItems, for: goalId)
        
        return item
    }
    
    // MARK: - Load Image
    
    func loadImage(for item: EvidenceItem) async -> UIImage? {
        // 1. Check memory cache
        if let cached = memoryCache.object(forKey: item.id as NSString) {
            return cached
        }
        
        // 2. Check local disk sandbox
        let fileURL = localFileURL(for: item)
        if FileManager.default.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            memoryCache.setObject(image, forKey: item.id as NSString)
            return image
        }
        
        // 3. Download from Firebase Storage if configured
        #if canImport(FirebaseStorage)
        if AuthService.shared.isFirebaseConfigured {
            let storageRef = Storage.storage().reference().child(item.storagePath)
            do {
                let data = try await storageRef.data(maxSize: 10 * 1024 * 1024)
                if let downloaded = UIImage(data: data) {
                    try? data.write(to: fileURL, options: .atomic)
                    memoryCache.setObject(downloaded, forKey: item.id as NSString)
                    return downloaded
                }
            } catch {
                print("Failed to download evidence image from storage: \(error.localizedDescription)")
            }
        }
        #endif
        
        return nil
    }
    
    // MARK: - Delete Evidence
    
    func deleteEvidence(_ item: EvidenceItem) async throws {
        let uid = activeUserId()
        
        // 1. Delete from Firebase Storage
        #if canImport(FirebaseStorage)
        if AuthService.shared.isFirebaseConfigured {
            let storageRef = Storage.storage().reference().child(item.storagePath)
            try? await storageRef.delete()
        }
        #endif
        
        // 2. Delete from Firestore
        #if canImport(FirebaseFirestore)
        if AuthService.shared.isFirebaseConfigured {
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
        
        // 3. Remove from memory and disk
        memoryCache.removeObject(forKey: item.id as NSString)
        let fileURL = localFileURL(for: item)
        try? FileManager.default.removeItem(at: fileURL)
        
        // 4. Update local metadata
        var currentItems = loadLocalMetadata(for: item.goalId)
        currentItems.removeAll(where: { $0.id == item.id })
        saveLocalMetadata(currentItems, for: item.goalId)
    }
    
    func clearEvidence(for goalId: String, logId: String) async {
        if let item = fetchEvidence(forGoal: goalId, logId: logId) {
            try? await deleteEvidence(item)
        }
    }
}
