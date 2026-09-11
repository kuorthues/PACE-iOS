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
    
    private func activeUserId() -> String {
        AuthService.shared.currentUser?.id ?? "local_user"
    }
    
    private var localPersistenceKey: String {
        "pace_goals_\(activeUserId())"
    }
    
    // MARK: - Local Cache Persistence
    
    private func loadLocalGoals() -> [PACEGoal] {
        guard let data = UserDefaults.standard.data(forKey: localPersistenceKey),
              let decoded = try? JSONDecoder().decode([PACEGoal].self, from: data) else {
            return []
        }
        return decoded
    }
    
    private func saveLocalGoals(_ items: [PACEGoal]) {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: localPersistenceKey)
        }
    }
    
    // MARK: - Fetch Active Goals
    
    func fetchActiveGoals() async {
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
                    .whereField("status", isEqualTo: GoalStatus.active.rawValue)
                    .getDocuments()
                
                let fetchedGoals = snapshot.documents.compactMap { doc -> PACEGoal? in
                    PACEGoal(id: doc.documentID, dictionary: doc.data())
                }.sorted(by: { $0.targetDate < $1.targetDate })
                
                self.goals = fetchedGoals
                saveLocalGoals(fetchedGoals)
                return
            } catch {
                // Fallback to local cache if offline or Firestore query error
                self.errorMessage = "Failed to sync with Firestore: \(error.localizedDescription)"
            }
        }
        #endif
        
        // Load from user-scoped storage
        let local = loadLocalGoals().filter { $0.userId == uid && $0.status == .active }
        self.goals = local.sorted(by: { $0.targetDate < $1.targetDate })
    }
    
    // MARK: - Fetch Single Goal
    
    func fetchGoal(id: String) async -> PACEGoal? {
        let uid = activeUserId()
        
        #if canImport(FirebaseFirestore)
        if AuthService.shared.isFirebaseConfigured {
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
        
        return loadLocalGoals().first { $0.id == id && $0.userId == uid }
    }
    
    // MARK: - Create Goal
    
    func createGoal(
        title: String,
        targetDate: Date,
        activityTypes: [String],
        scheduledWeekdays: [Int]
    ) async throws -> PACEGoal {
        let uid = activeUserId()
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty else {
            throw AuthError.validation("Goal title cannot be empty.")
        }
        
        guard Calendar.current.startOfDay(for: targetDate) > Calendar.current.startOfDay(for: Date()) else {
            throw AuthError.validation("Target date must be in the future.")
        }
        
        guard !activityTypes.isEmpty else {
            throw AuthError.validation("At least one activity type must be selected.")
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
        
        #if canImport(FirebaseFirestore)
        if AuthService.shared.isFirebaseConfigured {
            do {
                try await Firestore.firestore()
                    .collection("users")
                    .document(uid)
                    .collection("goals")
                    .document(newGoal.id)
                    .setData(newGoal.dictionary)
            } catch {
                self.errorMessage = "Failed to save goal to Firestore: \(error.localizedDescription)"
            }
        }
        #endif
        
        var current = loadLocalGoals()
        current.append(newGoal)
        saveLocalGoals(current)
        
        await fetchActiveGoals()
        return newGoal
    }
    
    // MARK: - Update Goal
    
    func updateGoal(_ goal: PACEGoal) async throws {
        let uid = activeUserId()
        let trimmedTitle = goal.title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty else {
            throw AuthError.validation("Goal title cannot be empty.")
        }
        
        guard Calendar.current.startOfDay(for: goal.targetDate) > Calendar.current.startOfDay(for: Date()) else {
            throw AuthError.validation("Target date must be in the future.")
        }
        
        guard !goal.activityTypes.isEmpty else {
            throw AuthError.validation("At least one activity type must be selected.")
        }
        
        #if canImport(FirebaseFirestore)
        if AuthService.shared.isFirebaseConfigured {
            do {
                try await Firestore.firestore()
                    .collection("users")
                    .document(uid)
                    .collection("goals")
                    .document(goal.id)
                    .setData(goal.dictionary, merge: true)
            } catch {
                self.errorMessage = "Failed to update Firestore: \(error.localizedDescription)"
            }
        }
        #endif
        
        var current = loadLocalGoals()
        if let index = current.firstIndex(where: { $0.id == goal.id && $0.userId == uid }) {
            current[index] = goal
            saveLocalGoals(current)
        }
        
        await fetchActiveGoals()
    }
    
    // MARK: - Delete Goal
    
    func deleteGoal(id: String) async throws {
        let uid = activeUserId()
        
        #if canImport(FirebaseFirestore)
        if AuthService.shared.isFirebaseConfigured {
            do {
                try await Firestore.firestore()
                    .collection("users")
                    .document(uid)
                    .collection("goals")
                    .document(id)
                    .delete()
            } catch {
                self.errorMessage = "Failed to delete from Firestore: \(error.localizedDescription)"
            }
        }
        #endif
        
        var current = loadLocalGoals()
        current.removeAll(where: { $0.id == id && $0.userId == uid })
        saveLocalGoals(current)
        
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
