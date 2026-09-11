//
//  DailyLogService.swift
//  PACE
//
//  Manages persistence and retrieval of DailyLog entries.
//  Enforces one normal log per goal/calendar day:
//  Firestore document ID: users/{uid}/goals/{goalId}/logs/{dateString}
//

import SwiftUI
import Combine

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class DailyLogService: ObservableObject {
    static let shared = DailyLogService()
    
    @Published var logsByGoal: [String: [DailyLog]] = [:]
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private init() {}
    
    private func activeUserId() -> String {
        AuthService.shared.currentUser?.id ?? "local_user"
    }
    
    private func localKey(for goalId: String) -> String {
        "pace_logs_\(activeUserId())_\(goalId)"
    }
    
    // MARK: - Local Persistence
    
    private func loadLocalLogs(for goalId: String) -> [DailyLog] {
        guard let data = UserDefaults.standard.data(forKey: localKey(for: goalId)),
              let decoded = try? JSONDecoder().decode([DailyLog].self, from: data) else {
            return []
        }
        return decoded.sorted(by: { $0.date > $1.date })
    }
    
    private func saveLocalLogs(_ logs: [DailyLog], for goalId: String) {
        if let encoded = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(encoded, forKey: localKey(for: goalId))
        }
        self.logsByGoal[goalId] = logs.sorted(by: { $0.date > $1.date })
    }
    
    // MARK: - Fetch Logs
    
    func fetchLogs(for goalId: String) async -> [DailyLog] {
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
                    .collection("logs")
                    .getDocuments()
                
                let fetchedLogs = snapshot.documents.compactMap { doc -> DailyLog? in
                    DailyLog(id: doc.documentID, dictionary: doc.data())
                }.sorted(by: { $0.date > $1.date })
                
                saveLocalLogs(fetchedLogs, for: goalId)
                return fetchedLogs
            } catch {
                self.errorMessage = "Failed to sync logs with Firestore: \(error.localizedDescription)"
            }
        }
        #endif
        
        let local = loadLocalLogs(for: goalId)
        self.logsByGoal[goalId] = local
        return local
    }
    
    func fetchLog(for goalId: String, date: Date) -> DailyLog? {
        let dateString = DailyLog.dateFormatter.string(from: Calendar.current.startOfDay(for: date))
        let currentLogs = logsByGoal[goalId] ?? loadLocalLogs(for: goalId)
        return currentLogs.first { $0.dateString == dateString }
    }
    
    // MARK: - Save / Create / Update Log
    
    func saveLog(
        goalId: String,
        date: Date = Date(),
        selectedActivities: [String],
        durationMinutes: Int,
        note: String? = nil,
        evidenceId: String? = nil
    ) async throws -> DailyLog {
        errorMessage = nil
        let uid = activeUserId()
        
        guard !selectedActivities.isEmpty else {
            throw AuthError.validation("Please select at least one activity.")
        }
        
        guard durationMinutes > 0 else {
            throw AuthError.validation("Duration must be at least 1 minute.")
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        // Prevent logging in the future
        guard startOfDay <= calendar.startOfDay(for: Date()) else {
            throw AuthError.validation("Cannot log entries for future dates.")
        }
        
        let dateString = DailyLog.dateFormatter.string(from: startOfDay)
        
        var currentLogs = loadLocalLogs(for: goalId)
        var existingIndex: Int? = nil
        for (i, log) in currentLogs.enumerated() {
            if log.dateString == dateString {
                existingIndex = i
                break
            }
        }
        
        let logToSave: DailyLog
        if let index = existingIndex {
            // Update existing same-day log (prevents duplicates)
            var existing = currentLogs[index]
            existing.selectedActivities = selectedActivities
            existing.durationMinutes = durationMinutes
            existing.note = note
            if evidenceId != nil {
                existing.evidenceId = evidenceId
            }
            existing.updatedAt = Date()
            currentLogs[index] = existing
            logToSave = existing
        } else {
            // Create new log entry
            let newLog = DailyLog(
                id: dateString,
                goalId: goalId,
                date: startOfDay,
                selectedActivities: selectedActivities,
                durationMinutes: durationMinutes,
                note: note,
                evidenceId: evidenceId,
                createdAt: Date(),
                updatedAt: Date()
            )
            currentLogs.append(newLog)
            logToSave = newLog
        }
        
        #if canImport(FirebaseFirestore)
        if AuthService.shared.isFirebaseConfigured {
            do {
                try await Firestore.firestore()
                    .collection("users")
                    .document(uid)
                    .collection("goals")
                    .document(goalId)
                    .collection("logs")
                    .document(dateString)
                    .setData(logToSave.dictionary, merge: true)
            } catch {
                self.errorMessage = "Failed to write log to Firestore: \(error.localizedDescription)"
            }
        }
        #endif
        
        saveLocalLogs(currentLogs, for: goalId)
        return logToSave
    }
    
    // MARK: - Delete Log
    
    func deleteLog(id: String, goalId: String) async throws {
        let uid = activeUserId()
        
        #if canImport(FirebaseFirestore)
        if AuthService.shared.isFirebaseConfigured {
            do {
                try await Firestore.firestore()
                    .collection("users")
                    .document(uid)
                    .collection("goals")
                    .document(goalId)
                    .collection("logs")
                    .document(id)
                    .delete()
            } catch {
                self.errorMessage = "Failed to delete log from Firestore: \(error.localizedDescription)"
            }
        }
        #endif
        
        var currentLogs = loadLocalLogs(for: goalId)
        currentLogs.removeAll(where: { $0.id == id || $0.dateString == id })
        saveLocalLogs(currentLogs, for: goalId)
        
        // Clean up associated evidence
        await EvidenceService.shared.clearEvidence(for: goalId, logId: id)
    }
}
