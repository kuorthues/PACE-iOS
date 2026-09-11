//
//  EvidenceTests.swift
//  PACE
//
//  Comprehensive automated test suite for Photo Evidence module:
//  - Image compression & mobile resizing
//  - Evidence metadata and Firestore dictionary serialization (no raw bytes)
//  - Scoped storage paths
//  - Local persistence & image loading
//  - Evidence deletion & cache eviction
//  - Failed / aborted selection resilience
//

import UIKit

@MainActor
final class EvidenceTests {
    static var passedCount = 0
    static var totalCount = 0
    
    static func runAllTests() async -> (passed: Int, total: Int, failures: [String]) {
        passedCount = 0
        totalCount = 0
        var failures: [String] = []
        
        func assert(_ condition: Bool, _ name: String) {
            totalCount += 1
            if condition {
                passedCount += 1
                print("  ✅ [PASS] \(name)")
            } else {
                failures.append(name)
                print("  ❌ [FAIL] \(name)")
            }
        }
        
        print("\n==========================================")
        print("🧪 RUNNING EVIDENCE TEST SUITE")
        print("==========================================")
        
        // 1. Test Image Compression
        let largeImage = createTestImage(size: CGSize(width: 2400, height: 1600), color: .blue)
        let compressed = ImageCompressor.compress(image: largeImage, maxDimension: 1200)
        assert(compressed != nil, "Compression generates valid result")
        if let comp = compressed {
            assert(comp.image.size.width <= 1200 && comp.image.size.height <= 1200, "Image resized to max dimension 1200px")
            assert(comp.image.size.width == 1200 && comp.image.size.height == 800, "Aspect ratio preserved accurately (1200x800)")
            assert(!comp.data.isEmpty, "Compressed JPEG data is non-empty")
            assert(comp.compressedByteCount < comp.originalByteCount, "Compression reduces mobile file footprint")
        }
        
        // 2. Test Metadata Serialization & Firestore Scoping (NO raw bytes)
        let testUserId = "test_student_456"
        let testGoalId = "goal_ios_mastery"
        let testLogId = "2026-09-11"
        let testCaption = "Finished chapter on SwiftUI navigation"
        
        let evidence = EvidenceItem(
            id: "ev_12345",
            userId: testUserId,
            goalId: testGoalId,
            logId: testLogId,
            caption: testCaption
        )
        
        assert(evidence.storagePath == "users/\(testUserId)/goals/\(testGoalId)/evidence/ev_12345.jpg", "Storage path scoped to user and goal")
        assert(evidence.caption == testCaption, "Caption preserved")
        
        let dict = evidence.dictionary
        assert(dict["id"] as? String == "ev_12345", "Dictionary contains id")
        assert(dict["userId"] as? String == testUserId, "Dictionary contains userId")
        assert(dict["goalId"] as? String == testGoalId, "Dictionary contains goalId")
        assert(dict["logId"] as? String == testLogId, "Dictionary contains logId")
        assert(dict["caption"] as? String == testCaption, "Dictionary contains caption")
        assert(dict["imageBytes"] == nil && dict["data"] == nil, "No raw image bytes stored directly in Firestore dictionary")
        
        let reconstructed = EvidenceItem(id: "ev_12345", dictionary: dict)
        assert(reconstructed != nil, "Evidence reconstructed from dictionary successfully")
        assert(reconstructed?.storagePath == evidence.storagePath, "Reconstructed storage path matches")
        
        // 3. Test Save, Cache & Load Local Evidence
        let service = EvidenceService.shared
        let sampleImage = createTestImage(size: CGSize(width: 800, height: 800), color: .green)
        
        do {
            let saved = try await service.saveEvidence(
                goalId: testGoalId,
                logId: testLogId,
                image: sampleImage,
                caption: "Initial mock proof"
            )
            assert(saved.goalId == testGoalId, "Saved evidence goalId matches")
            assert(saved.logId == testLogId, "Saved evidence logId matches")
            
            // Check fetching by goal and log
            let fetched = service.fetchEvidence(forGoal: testGoalId, logId: testLogId)
            assert(fetched != nil && fetched?.id == saved.id, "Fetch evidence for goal/log succeeds")
            
            // Check loading image
            let loadedImage = await service.loadImage(for: saved)
            assert(loadedImage != nil, "Loaded image from local cache succeeds")
            
            // 4. Test Deletion
            try await service.deleteEvidence(saved)
            let afterDelete = service.fetchEvidence(forGoal: testGoalId, logId: testLogId)
            assert(afterDelete == nil, "Evidence removed from service metadata after deletion")
            
            let loadedAfterDelete = await service.loadImage(for: saved)
            assert(loadedAfterDelete == nil, "Evidence image binary deleted and cannot be loaded")
        } catch {
            assert(false, "Evidence service operations threw error: \(error.localizedDescription)")
        }
        
        // 5. Test Aborted / Zero-size Image Handling
        let emptyImage = UIImage()
        let invalidCompress = ImageCompressor.compress(image: emptyImage)
        assert(invalidCompress == nil, "Empty/aborted image gracefully returns nil without crash")
        
        print("\n==========================================")
        print("🏁 RESULTS: \(passedCount)/\(totalCount) PASSED (Failures: \(failures.count))")
        print("==========================================\n")
        
        return (passedCount, totalCount, failures)
    }
    
    private static func createTestImage(size: CGSize, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
