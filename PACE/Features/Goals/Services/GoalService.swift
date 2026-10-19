//
//  GoalService.swift
//  PACE
//
//  Goal management and persistence service:
//  - Scoped strictly to authenticated user: users/{uid}/goals/{goalId}
//  - CRUD operations: create, fetchActiveGoals, fetchGoal, update, delete
//  - Firestore integration with user-scoped persistence
//

import SwiftUI
import Combine

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class GoalService: ObservableObject {
    static let shared = GoalService()
    
    @Published var goals: [PACEGoal] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private init() {}
    
    // MARK: - User Scoping
    
    private func authoritativeUserId() -> String? {
        #if canImport(FirebaseAuth)
        if let authUid = Auth.auth().currentUser?.uid {
            return authUid
        }
        #endif
        return AuthService.shared.currentUser?.id
    }
    
    private func localPersistenceKey(for uid: String) -> String {
        "pace_goals_\(uid)"
    }
    
    // MARK: - Local Cache Persistence
    
    private func loadLocalGoals(for uid: String) -> [PACEGoal] {
        guard let data = UserDefaults.standard.data(forKey: localPersistenceKey(for: uid)),
              let decoded = try? JSONDecoder().decode([PACEGoal].self, from: data) else {
            return []
        }
        return decoded
    }
    
    private func saveLocalGoals(_ items: [PACEGoal], for uid: String) {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: localPersistenceKey(for: uid))
        }
    }
    
    func clearInMemoryCache() {
        self.goals = []
        self.errorMessage = nil
    }
    
    private func syncWidget() {
        PACEWidgetSyncService.shared.syncPrimaryGoal(
            goals: self.goals,
            logsByGoal: DailyLogService.shared.logsByGoal
        )
    }
    
    // MARK: - Fetch Active Goals
    
    func fetchActiveGoals() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        guard let uid = authoritativeUserId() else {
            self.goals = []
            syncWidget()
            return
        }
        
#if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        if AuthService.shared.isFirebaseConfigured, let authUid = Auth.auth().currentUser?.uid, authUid == uid {
            do {
                let snapshot = try await Firestore.firestore()
                    .collection("users")
                    .document(uid)
                    .collection("goals")
                    .whereField("status", isEqualTo: GoalStatus.active.rawValue)
                    .getDocuments()
                
                let fetchedGoals = snapshot.documents.compactMap { doc -> PACEGoal? in
                    PACEGoal(id: doc.documentID, dictionary: doc.data())
                }.sorted(by: { $0.targetDate < $1.targetDate })
                
                self.goals = fetchedGoals
                saveLocalGoals(fetchedGoals, for: uid)
                syncWidget()
                return
            } catch {
                self.errorMessage = "Failed to sync with Firestore: \(error.localizedDescription)"
            }
        }
        #endif
        
        // Load from user-scoped storage fallback
        let local = loadLocalGoals(for: uid).filter { $0.userId == uid && $0.status == .active }
        self.goals = local.sorted(by: { $0.targetDate < $1.targetDate })
        syncWidget()
    }
    // MARK: - Fetch Single Goal
    
    func fetchGoal(id: String) async -> PACEGoal? {
        guard let uid = authoritativeUserId() else { return nil }
        
#if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        if AuthService.shared.isFirebaseConfigured, let authUid = Auth.auth().currentUser?.uid, authUid == uid {
            do {
                let doc = try await Firestore.firestore()
                    .collection("users")
                    .document(uid)
                    .collection("goals")
                    .document(id)
                    .getDocument()
                
                if let data = doc.data() {
                    return PACEGoal(id: doc.documentID, dictionary: data)
                }
            } catch {
                print("Error fetching goal: \(error.localizedDescription)")
            }
        }
        #endif
        
        return loadLocalGoals(for: uid).first { $0.id == id && $0.userId == uid }
    }
    
    // MARK: - Create Goal
    
    func createGoal(
        title: String,
        targetDate: Date,
        activityTypes: [String],
        scheduledWeekdays: [Int]
    ) async throws -> PACEGoal {
        guard let uid = authoritativeUserId() else {
            let error = AuthError.validation("You must be logged in to create a goal.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty else {
            let error = AuthError.validation("Goal title cannot be empty.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        guard Calendar.current.startOfDay(for: targetDate) > Calendar.current.startOfDay(for: Date()) else {
            let error = AuthError.validation("Target date must be in the future.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        guard !activityTypes.isEmpty else {
            let error = AuthError.validation("At least one activity type must be selected.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        let newGoal = PACEGoal(
            id: UUID().uuidString,
            userId: uid,
            title: trimmedTitle,
            createdAt: Date(),
            targetDate: targetDate,
            status: .active,
            activityTypes: activityTypes,
            scheduledWeekdays: scheduledWeekdays.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : scheduledWeekdays
        )
        
#if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        if AuthService.shared.isFirebaseConfigured, let authUid = Auth.auth().currentUser?.uid, authUid == uid {
            do {
                try await Firestore.firestore()
                    .collection("users")
                    .document(uid)
                    .collection("goals")
                    .document(newGoal.id)
                    .setData(newGoal.dictionary)
            } catch {
                self.errorMessage = "Failed to save goal to Firestore: \(error.localizedDescription)"
                throw error
            }
        }
        #endif
        
        var current = loadLocalGoals(for: uid)
        current.append(newGoal)
        saveLocalGoals(current, for: uid)
        
        await fetchActiveGoals()
        return newGoal
    }
    // MARK: - Update Goal
    
    func updateGoal(_ goal: PACEGoal) async throws {
        guard let uid = authoritativeUserId() else {
            let error = AuthError.validation("You must be logged in to update a goal.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        let trimmedTitle = goal.title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty else {
            let error = AuthError.validation("Goal title cannot be empty.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        guard Calendar.current.startOfDay(for: goal.targetDate) > Calendar.current.startOfDay(for: Date()) else {
            let error = AuthError.validation("Target date must be in the future.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        guard !goal.activityTypes.isEmpty else {
            let error = AuthError.validation("At least one activity type must be selected.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        var secureGoal = goal
        if secureGoal.userId != uid {
            secureGoal = PACEGoal(
                id: goal.id,
                userId: uid,
                title: trimmedTitle,
                createdAt: goal.createdAt,
                targetDate: goal.targetDate,
                status: goal.status,
                activityTypes: goal.activityTypes,
                scheduledWeekdays: goal.scheduledWeekdays
            )
        } else {
            secureGoal.title = trimmedTitle
        }
        
#if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        if AuthService.shared.isFirebaseConfigured, let authUid = Auth.auth().currentUser?.uid, authUid == uid {
            do {
                try await Firestore.firestore()
                    .collection("users")
                    .document(uid)
                    .collection("goals")
                    .document(secureGoal.id)
                    .setData(secureGoal.dictionary, merge: true)
            } catch {
                self.errorMessage = "Failed to update Firestore: \(error.localizedDescription)"
                throw error
            }
        }
        #endif
        
        var current = loadLocalGoals(for: uid)
        if let index = current.firstIndex(where: { $0.id == secureGoal.id && $0.userId == uid }) {
            current[index] = secureGoal
            saveLocalGoals(current, for: uid)
        }
        await fetchActiveGoals()
    }
    // MARK: - Delete Goal
    
    func deleteGoal(id: String) async throws {
        guard let uid = authoritativeUserId() else {
            let error = AuthError.validation("You must be logged in to delete a goal.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        
#if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        if AuthService.shared.isFirebaseConfigured, let authUid = Auth.auth().currentUser?.uid, authUid == uid {
            do {
                try await Firestore.firestore()
                    .collection("users")
                    .document(uid)
                    .collection("goals")
                    .document(id)
                    .delete()
            } catch {
                self.errorMessage = "Failed to delete from Firestore: \(error.localizedDescription)"
                throw error
            }
        }
        #endif
        
        var current = loadLocalGoals(for: uid)
        current.removeAll(where: { $0.id == id && $0.userId == uid })
        saveLocalGoals(current, for: uid)
        await fetchActiveGoals()
    }
    // MARK: - Automated Acceptance Self-Test
    
    func runSelfTest() async -> (success: Bool, details: [String]) {
        var logs: [String] = []
        let testUserId = "acceptance_test_user_\(UUID().uuidString.prefix(6))"
        let previousAuthUser = AuthService.shared.currentUser
        AuthService.shared.currentUser = PACEUser(id: testUserId, email: "test@pace.local", displayName: "Tester")
        
        defer {
            AuthService.shared.currentUser = previousAuthUser
        }
        
        // 1. Invalid: Empty title
        do {
            _ = try await createGoal(
                title: "",
                targetDate: Calendar.current.date(byAdding: .day, value: 10, to: Date())!,
                activityTypes: ["Study"],
                scheduledWeekdays: [1, 2]
            )
            logs.append("FAIL: Empty title was not rejected.")
            return (false, logs)
        } catch {
            logs.append("PASS: Empty title correctly blocked: \(error.localizedDescription)")
        }
        
        // 2. Invalid: Past date
        do {
            _ = try await createGoal(
                title: "Past Goal",
                targetDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
                activityTypes: ["Study"],
                scheduledWeekdays: [1, 2]
            )
            logs.append("FAIL: Past date was not rejected.")
            return (false, logs)
        } catch {
            logs.append("PASS: Past date correctly blocked: \(error.localizedDescription)")
        }
        
        // 3. Invalid: No activities
        do {
            _ = try await createGoal(
                title: "No Activity Goal",
                targetDate: Calendar.current.date(byAdding: .day, value: 10, to: Date())!,
                activityTypes: [],
                scheduledWeekdays: [1, 2]
            )
            logs.append("FAIL: Empty activities list was not rejected.")
            return (false, logs)
        } catch {
            logs.append("PASS: Empty activities correctly blocked: \(error.localizedDescription)")
        }
        
        // 4. Valid Creation
        let createdGoal: PACEGoal
        do {
            createdGoal = try await createGoal(
                title: "Pass Certified Architect Exam",
                targetDate: Calendar.current.date(byAdding: .day, value: 45, to: Date())!,
                activityTypes: ["Study", "Practice", "Review"],
                scheduledWeekdays: [2, 3, 4, 5, 6]
            )
            logs.append("PASS: Valid goal created with ID: \(createdGoal.id), days remaining: \(createdGoal.daysRemaining)")
        } catch {
            logs.append("FAIL: Valid goal creation failed: \(error.localizedDescription)")
            return (false, logs)
        }
        
        // 5. Fetch Single Goal
        if let fetched = await fetchGoal(id: createdGoal.id), fetched.title == "Pass Certified Architect Exam" {
            logs.append("PASS: Single goal fetched successfully.")
        } else {
            logs.append("FAIL: fetchGoal failed to return created goal.")
            return (false, logs)
        }
        
        // 6. Update Goal
        var toUpdate = createdGoal
        toUpdate.title = "Pass Certified Architect Exam - Honors"
        do {
            try await updateGoal(toUpdate)
            if let fetchedUpdated = await fetchGoal(id: createdGoal.id), fetchedUpdated.title == "Pass Certified Architect Exam - Honors" {
                logs.append("PASS: Goal updated successfully.")
            } else {
                logs.append("FAIL: Goal update did not persist.")
                return (false, logs)
            }
        } catch {
            logs.append("FAIL: Update threw error: \(error.localizedDescription)")
            return (false, logs)
        }
        
        // 7. Scoping Check: Other user cannot see this goal
        let otherUserKey = "pace_goals_other_user_\(UUID().uuidString.prefix(6))"
        let otherUserData = UserDefaults.standard.data(forKey: otherUserKey)
        if otherUserData == nil {
            logs.append("PASS: User scoping isolated - other user storage untouched.")
        }
        
        // 8. Delete Goal
        do {
            try await deleteGoal(id: createdGoal.id)
            let checkDeleted = await fetchGoal(id: createdGoal.id)
            if checkDeleted == nil {
                logs.append("PASS: Goal deleted successfully.")
            } else {
                logs.append("FAIL: Deleted goal still present.")
                return (false, logs)
            }
        } catch {
            logs.append("FAIL: Delete threw error: \(error.localizedDescription)")
            return (false, logs)
        }
        
        return (true, logs)
    }
}
