import SwiftUI
import Combine

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class SharedGoalService: ObservableObject {
    static let shared = SharedGoalService()

    @Published private(set) var goals: [SharedGoal] = []
    @Published private(set) var logsByGoal: [String: [DailyLog]] = [:]
    @Published private(set) var sourceGoalIdsInProgress: Set<String> = []
    @Published private(set) var hasLoaded = false
    @Published var errorMessage: String?

    #if canImport(FirebaseFirestore)
    private var goalsListener: ListenerRegistration?
    private var logListeners: [String: ListenerRegistration] = [:]
    #endif
    private var listeningUserId: String?

    private init() {}

    func clearInMemoryCache() {
        #if canImport(FirebaseFirestore)
        goalsListener?.remove()
        goalsListener = nil
        logListeners.values.forEach { $0.remove() }
        logListeners.removeAll()
        #endif
        listeningUserId = nil
        goals = []
        logsByGoal = [:]
        sourceGoalIdsInProgress = []
        hasLoaded = false
        errorMessage = nil
    }

    func startListening(for userId: String?) {
        guard listeningUserId != userId else { return }
        clearInMemoryCache()
        listeningUserId = userId
        guard let userId else { return }

        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard AuthService.shared.isFirebaseConfigured,
              Auth.auth().currentUser?.uid == userId else { return }

        goalsListener = Firestore.firestore()
            .collection("sharedGoals")
            .whereField("memberIds", arrayContains: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self, self.listeningUserId == userId else { return }
                    if let error {
                        self.errorMessage = "Shared goals could not sync: \(error.localizedDescription)"
                        self.goals = []
                        self.hasLoaded = true
                        self.updateLogListeners(for: [])
                        PACEWidgetSyncService.shared.requestSync()
                        return
                    }
                    let allGoals = (snapshot?.documents ?? []).compactMap {
                        SharedGoal(id: $0.documentID, dictionary: $0.data())
                    }.filter { $0.memberIds.contains(userId) }
                    self.sourceGoalIdsInProgress = Set(
                        allGoals
                            .filter { [.preparing, .inviting, .active, .ended].contains($0.status) }
                            .compactMap(\.sourceGoalId)
                    )
                    self.goals = allGoals
                        .filter { $0.status == .active || ($0.status == .ended && $0.ownerId == userId) }
                        .sorted { $0.targetDate < $1.targetDate }
                    self.hasLoaded = true
                    self.errorMessage = nil
                    self.updateLogListeners(for: self.goals)
                    PACEWidgetSyncService.shared.requestSync()
                    for goal in self.goals where goal.ownerId == userId {
                        guard let sourceGoalId = goal.sourceGoalId else { continue }
                        Task { @MainActor in
                            do {
                                try await GoalService.shared.archiveConvertedGoal(id: sourceGoalId)
                            } catch {
                                self.errorMessage = "Shared goal is active, but its private source goal could not be archived: \(error.localizedDescription)"
                            }
                        }
                    }
                }
            }
        #endif
    }

    private func updateLogListeners(for visibleGoals: [SharedGoal]) {
        #if canImport(FirebaseFirestore)
        let visibleIds = Set(visibleGoals.map(\.id))
        let removedGoalIds = logListeners.keys.filter { !visibleIds.contains($0) }
        for goalId in removedGoalIds {
            logListeners.removeValue(forKey: goalId)?.remove()
            logsByGoal.removeValue(forKey: goalId)
        }

        for goal in visibleGoals where logListeners[goal.id] == nil {
            let userId = listeningUserId
            logListeners[goal.id] = Firestore.firestore()
                .collection("sharedGoals")
                .document(goal.id)
                .collection("logs")
                .addSnapshotListener { [weak self] snapshot, error in
                    Task { @MainActor [weak self] in
                        guard let self,
                              self.listeningUserId == userId,
                              self.goals.contains(where: { $0.id == goal.id }) else { return }
                        if let error {
                            self.logsByGoal[goal.id] = []
                            self.errorMessage = "Shared progress could not sync: \(error.localizedDescription)"
                            PACEWidgetSyncService.shared.requestSync()
                            return
                        }
                        self.logsByGoal[goal.id] = (snapshot?.documents ?? [])
                            .compactMap { DailyLog(id: $0.documentID, dictionary: $0.data()) }
                            .sorted {
                                if $0.date == $1.date { return $0.createdAt < $1.createdAt }
                                return $0.date > $1.date
                            }
                        PACEWidgetSyncService.shared.requestSync()
                    }
                }
        }
        #endif
    }

    func createAndInvite(
        profile: PublicProfile,
        title: String,
        targetDate: Date,
        activityTypes: [String],
        scheduledWeekdays: [Int],
        sourceGoal: PACEGoal? = nil,
        draftSharedGoalId: String? = nil
    ) async throws -> GoalInvitation {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        let uid = try authenticatedUserId()
        guard profile.userId != uid else { throw AuthError.validation("You cannot invite yourself.") }
        guard profile.isDiscoverable else { throw AuthError.validation("This profile is no longer discoverable.") }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !activityTypes.isEmpty,
              Calendar.current.startOfDay(for: targetDate) > Calendar.current.startOfDay(for: Date()) else {
            throw AuthError.validation("Add a title, at least one activity, and a future deadline.")
        }

        let db = Firestore.firestore()
        var goalTargetDateString = DailyLog.dateFormatter.string(from: Calendar.current.startOfDay(for: targetDate))
        var sourceCreatedAt: Timestamp?
        var sourceTargetDate: Timestamp?
        if let sourceGoal {
            guard sourceGoal.userId == uid, sourceGoal.status == .active else {
                throw AuthError.validation("Choose an active solo goal that you own.")
            }
            let sourceSnapshot = try await db.collection("users")
                .document(uid)
                .collection("goals")
                .document(sourceGoal.id)
                .getDocument(source: .server)
            guard let data = sourceSnapshot.data(),
                  let createdAt = data["createdAt"] as? Timestamp,
                  let storedTargetDate = data["targetDate"] as? Timestamp,
                  let storedGoal = PACEGoal(id: sourceGoal.id, dictionary: data),
                  storedGoal.userId == uid,
                  storedGoal.status == .active else {
                throw AuthError.validation("This solo goal is no longer available or has invalid dates.")
            }
            guard storedGoal.title == sourceGoal.title,
                  storedGoal.createdAt == sourceGoal.createdAt,
                  storedGoal.targetDate == sourceGoal.targetDate,
                  storedGoal.activityTypes == sourceGoal.activityTypes,
                  storedGoal.scheduledWeekdays == sourceGoal.scheduledWeekdays else {
                throw AuthError.validation("This goal changed. Review it and try again.")
            }
            sourceCreatedAt = createdAt
            sourceTargetDate = storedTargetDate
            goalTargetDateString = DailyLog.dateFormatter.string(from: Calendar.current.startOfDay(for: storedGoal.targetDate))
            try await db.collection("users").document(uid).collection("goals")
                .document(sourceGoal.id)
                .updateData(["targetDateString": goalTargetDateString])
        }

        let goalId: String
        if let sourceGoal {
            goalId = "converted_\(uid)_\(sourceGoal.id)"
        } else {
            goalId = draftSharedGoalId ?? UUID().uuidString
        }
        let invitationId = sourceGoal == nil
            ? "\(goalId)_\(profile.userId)"
            : UUID().uuidString
        let now = Date()
        let goal = SharedGoal(
            id: goalId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: sourceGoal?.createdAt ?? now,
            targetDate: targetDate,
            targetDateString: goalTargetDateString,
            activityTypes: activityTypes,
            scheduledWeekdays: scheduledWeekdays.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : scheduledWeekdays,
            ownerId: uid,
            memberIds: [uid],
            status: sourceGoal == nil ? .inviting : .preparing,
            pendingInvitationId: sourceGoal == nil ? invitationId : nil,
            sourceGoalId: sourceGoal?.id,
            createdAt: now,
            updatedAt: now
        )
        let invitation = GoalInvitation(
            id: invitationId,
            sharedGoalId: goalId,
            senderId: uid,
            recipientId: profile.userId,
            status: .pending,
            goalTitle: goal.title,
            targetDate: targetDate,
            targetDateString: goalTargetDateString,
            createdAt: now
        )
        let goalRef = db.collection("sharedGoals").document(goalId)
        let invitationRef = db.collection("goalInvitations").document(invitationId)

        if let sourceGoal, let sourceCreatedAt, let sourceTargetDate {
            let existing = try? await goalRef.getDocument(source: .server)
            if let existing, existing.exists {
                guard let existingGoal = SharedGoal(id: goalId, dictionary: existing.data() ?? [:]),
                      existingGoal.ownerId == uid,
                      existingGoal.sourceGoalId == sourceGoal.id,
                      existingGoal.memberIds == [uid],
                      [.preparing, .declined, .cancelled].contains(existingGoal.status) else {
                    throw AuthError.validation("This goal already has a collaboration or pending invitation.")
                }
                var update: [String: Any] = [
                    "title": goal.title,
                    "description": goal.description,
                    "startDate": sourceCreatedAt,
                    "targetDate": sourceTargetDate,
                    "targetDateString": goalTargetDateString,
                    "activityTypes": goal.activityTypes,
                    "scheduledWeekdays": goal.scheduledWeekdays,
                    "updatedAt": FieldValue.serverTimestamp()
                ]
                if existingGoal.status != .preparing {
                    update["status"] = SharedGoalStatus.preparing.rawValue
                    update["memberIds"] = [uid]
                    update["pendingInvitationId"] = FieldValue.delete()
                }
                try await goalRef.updateData(update)
            } else {
                var preparingData = goal.dictionary
                preparingData["startDate"] = sourceCreatedAt
                preparingData["targetDate"] = sourceTargetDate
                preparingData["createdAt"] = FieldValue.serverTimestamp()
                preparingData["updatedAt"] = FieldValue.serverTimestamp()
                try await goalRef.setData(preparingData)
            }
            try await copyHistoricalLogs(from: sourceGoal.id, to: goalId, ownerId: uid)
            try await finishExistingGoalInvitation(
                goalRef: goalRef,
                invitationRef: invitationRef,
                invitation: invitation,
                targetDate: sourceTargetDate
            )
        } else {
            let goalSnapshot = try? await goalRef.getDocument(source: .server)
            let invitationSnapshot = try? await invitationRef.getDocument(source: .server)
            if goalSnapshot?.exists == true || invitationSnapshot?.exists == true {
                guard let goalSnapshot,
                      goalSnapshot.exists,
                      let invitationSnapshot,
                      invitationSnapshot.exists,
                      let savedGoal = SharedGoal(id: goalId, dictionary: goalSnapshot.data() ?? [:]),
                      let savedInvitation = GoalInvitation(id: invitationId, dictionary: invitationSnapshot.data() ?? [:]),
                      savedGoal.ownerId == uid,
                      savedGoal.title == goal.title,
                      savedGoal.targetDateString == goalTargetDateString,
                      savedGoal.activityTypes == goal.activityTypes,
                      savedGoal.scheduledWeekdays == goal.scheduledWeekdays,
                      savedInvitation.senderId == uid,
                      savedInvitation.recipientId == profile.userId,
                      savedInvitation.sharedGoalId == goalId,
                      savedInvitation.targetDateString == goalTargetDateString,
                      (savedInvitation.status == .pending
                        && savedGoal.status == .inviting
                        && savedGoal.pendingInvitationId == invitationId
                        && savedGoal.memberIds == [uid])
                        || (savedInvitation.status == .accepted
                          && savedGoal.status == .active
                          && savedGoal.memberIds == [uid, profile.userId]
                          && savedGoal.pendingInvitationId == nil) else {
                    throw AuthError.validation("This invitation already has a final state or conflicts with the current draft.")
                }
                return savedInvitation
            }
            var goalData = goal.dictionary
            goalData["createdAt"] = FieldValue.serverTimestamp()
            goalData["updatedAt"] = FieldValue.serverTimestamp()
            var invitationData = invitation.dictionary
            invitationData["createdAt"] = FieldValue.serverTimestamp()
            let batch = db.batch()
            batch.setData(goalData, forDocument: goalRef)
            batch.setData(invitationData, forDocument: invitationRef)
            try await batch.commit()
        }
        return invitation
        #else
        throw AuthError.firebaseNotConfigured("PACE Together requires Firebase Authentication and Firestore.")
        #endif
    }

    #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
    private func authenticatedUserId() throws -> String {
        guard AuthService.shared.isFirebaseConfigured,
              let uid = Auth.auth().currentUser?.uid else {
            throw AuthError.firebaseNotConfigured("Sign in to use PACE Together.")
        }
        return uid
    }

    private func copyHistoricalLogs(from sourceGoalId: String, to sharedGoalId: String, ownerId: String) async throws {
        let db = Firestore.firestore()
        let sourceLogs = try await db.collection("users")
            .document(ownerId)
            .collection("goals")
            .document(sourceGoalId)
            .collection("logs")
            .getDocuments(source: .server)
        let destination = db.collection("sharedGoals").document(sharedGoalId).collection("logs")
        var batch = db.batch()
        var writes = 0

        for sourceDocument in sourceLogs.documents {
            guard let source = DailyLog(id: sourceDocument.documentID, dictionary: sourceDocument.data()) else {
                throw AuthError.validation("A saved solo log could not be read, so the goal was not shared.")
            }
            let destinationId = "migration_\(sourceDocument.documentID)"
            var data = sourceDocument.data()
            data["id"] = destinationId
            data["goalId"] = sharedGoalId
            data["authorId"] = ownerId
            data["sourceLogId"] = source.id
            batch.setData(data, forDocument: destination.document(destinationId))
            writes += 1
            if writes == 8 {
                try await batch.commit()
                batch = db.batch()
                writes = 0
            }
        }
        if writes > 0 { try await batch.commit() }
    }

    private func finishExistingGoalInvitation(
        goalRef: DocumentReference,
        invitationRef: DocumentReference,
        invitation: GoalInvitation,
        targetDate: Timestamp
    ) async throws {
        try await runTransaction { transaction, errorPointer in
            do {
                let goalSnapshot = try transaction.getDocument(goalRef)
                guard goalSnapshot.exists,
                      let goal = SharedGoal(id: goalRef.documentID, dictionary: goalSnapshot.data() ?? [:]),
                      goal.status == .preparing,
                      goal.ownerId == invitation.senderId,
                      goal.memberIds == [invitation.senderId] else {
                    throw AuthError.validation("The goal conversion is no longer available.")
                }
                transaction.updateData([
                    "status": SharedGoalStatus.inviting.rawValue,
                    "pendingInvitationId": invitation.id,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: goalRef)
                var data = invitation.dictionary
                data["targetDate"] = targetDate
                data["createdAt"] = FieldValue.serverTimestamp()
                transaction.setData(data, forDocument: invitationRef)
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }

    private func runTransaction(_ update: @escaping (Transaction, NSErrorPointer) -> Any?) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Firestore.firestore().runTransaction(update) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    #endif

    func fetchLog(for goalId: String, date: Date) async throws -> DailyLog? {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        let uid = try authenticatedUserId()
        guard goals.contains(where: { $0.id == goalId && $0.memberIds.contains(uid) }) else {
            throw AuthError.validation("You no longer have access to this shared goal.")
        }
        let dateString = DailyLog.dateFormatter.string(from: Calendar.current.startOfDay(for: date))
        let snapshot = try await Firestore.firestore()
            .collection("sharedGoals")
            .document(goalId)
            .collection("logs")
            .whereField("dateString", isEqualTo: dateString)
            .getDocuments(source: .server)
        guard Auth.auth().currentUser?.uid == uid else {
            throw AuthError.validation("Account changed while shared progress was loading.")
        }
        return snapshot.documents
            .filter { ($0.data()["authorId"] as? String) == uid }
            .sorted { $0.documentID < $1.documentID }
            .first
            .flatMap { DailyLog(id: $0.documentID, dictionary: $0.data()) }
        #else
        throw AuthError.firebaseNotConfigured("Shared progress requires Firebase.")
        #endif
    }

    func fetchGoal(id goalId: String) async -> SharedGoal? {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let userId = AuthService.shared.currentUser?.id,
              AuthService.shared.isFirebaseConfigured,
              Auth.auth().currentUser?.uid == userId else { return nil }

        if let cached = goals.first(where: { $0.id == goalId && $0.memberIds.contains(userId) }) {
            return cached
        }

        do {
            let snapshot = try await Firestore.firestore()
                .collection("sharedGoals")
                .document(goalId)
                .getDocument(source: .server)
            guard Auth.auth().currentUser?.uid == userId,
                  let goal = snapshot.data().flatMap({ SharedGoal(id: goalId, dictionary: $0) }),
                  goal.memberIds.contains(userId),
                  goal.status == .active || (goal.status == .ended && goal.ownerId == userId) else {
                return nil
            }
            return goal
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    func saveLog(
        goalId: String,
        date: Date,
        selectedActivities: [String],
        durationMinutes: Int,
        note: String?,
        evidenceId: String? = nil,
        clearEvidenceReference: Bool = false
    ) async throws -> DailyLog {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        let uid = try authenticatedUserId()
        guard let goal = goals.first(where: { $0.id == goalId }),
              goal.memberIds.contains(uid),
              goal.status == .active else {
            throw AuthError.validation("You no longer have access to add progress to this shared goal.")
        }
        guard !selectedActivities.isEmpty, durationMinutes > 0 else {
            throw AuthError.validation("Select an activity and enter a positive duration.")
        }
        let startOfDay = Calendar.current.startOfDay(for: date)
        guard startOfDay <= Calendar.current.startOfDay(for: Date()) else {
            throw AuthError.validation("Cannot log entries for future dates.")
        }
        let dateString = DailyLog.dateFormatter.string(from: startOfDay)
        let logsCollection = Firestore.firestore()
            .collection("sharedGoals")
            .document(goalId)
            .collection("logs")
        let sameDaySnapshot = try await logsCollection
            .whereField("dateString", isEqualTo: dateString)
            .getDocuments(source: .server)
        guard Auth.auth().currentUser?.uid == uid else {
            throw AuthError.validation("Account changed while shared progress was saving.")
        }
        let existingDocument = sameDaySnapshot.documents.first {
            ($0.data()["authorId"] as? String) == uid
        }
        let existing = existingDocument.flatMap {
            DailyLog(id: $0.documentID, dictionary: $0.data())
        }
        let logId = existingDocument?.documentID ?? "\(uid)_\(dateString)"
        let log = DailyLog(
            id: logId,
            goalId: goalId,
            authorId: uid,
            sourceLogId: existing?.sourceLogId,
            date: existing?.date ?? startOfDay,
            selectedActivities: selectedActivities,
            durationMinutes: durationMinutes,
            note: note,
            evidenceId: clearEvidenceReference ? nil : (evidenceId ?? existing?.evidenceId),
            createdAt: existing?.createdAt ?? Date(),
            updatedAt: Date()
        )
        var data: [String: Any]
        if let existingDocument {
            data = existingDocument.data()
            data["selectedActivities"] = selectedActivities
            data["durationMinutes"] = durationMinutes
            data["updatedAt"] = FieldValue.serverTimestamp()
            if let note = log.note {
                data["note"] = note
            } else {
                data["note"] = FieldValue.delete()
            }
            if clearEvidenceReference {
                data["evidenceId"] = FieldValue.delete()
            } else if let evidenceId {
                data["evidenceId"] = evidenceId
            }
        } else {
            data = log.dictionary
            data["createdAt"] = FieldValue.serverTimestamp()
            data["updatedAt"] = FieldValue.serverTimestamp()
        }
        try await logsCollection.document(logId).setData(data, merge: false)
        guard Auth.auth().currentUser?.uid == uid else {
            throw AuthError.validation("Account changed while shared progress was saving.")
        }
        PACEWidgetSyncService.shared.requestSync()
        return log
        #else
        throw AuthError.firebaseNotConfigured("Shared progress requires Firebase.")
        #endif
    }

    func deleteLog(goalId: String, logId: String) async throws {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        let uid = try authenticatedUserId()
        guard goals.contains(where: { $0.id == goalId && $0.memberIds.contains(uid) && $0.status == .active }) else {
            throw AuthError.validation("You no longer have access to edit progress in this shared goal.")
        }
        let logRef = Firestore.firestore()
            .collection("sharedGoals")
            .document(goalId)
            .collection("logs")
            .document(logId)
        let snapshot = try await logRef.getDocument(source: .server)
        guard Auth.auth().currentUser?.uid == uid else {
            throw AuthError.validation("Account changed while shared progress was deleting.")
        }
        guard let log = snapshot.data().flatMap({ DailyLog(id: logId, dictionary: $0) }),
              log.authorId == uid else {
            throw AuthError.validation("You can delete only your own shared progress.")
        }
        try await logRef.delete()
        PACEWidgetSyncService.shared.requestSync()
        #else
        throw AuthError.firebaseNotConfigured("Shared progress requires Firebase.")
        #endif
    }

    func updateGoal(_ goal: SharedGoal) async throws {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        let uid = try authenticatedUserId()
        guard goal.ownerId == uid else { throw AuthError.validation("Only the goal owner can edit its settings.") }
        guard !goal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              goal.title.count <= 120,
              goal.description.count <= 500,
              !goal.activityTypes.isEmpty,
              goal.activityTypes.count <= 20,
              !goal.scheduledWeekdays.isEmpty,
              goal.scheduledWeekdays.allSatisfy { (1...7).contains($0) },
              Calendar.current.startOfDay(for: goal.targetDate) > Calendar.current.startOfDay(for: Date()) else {
            throw AuthError.validation("Add a valid title, activities, schedule, and future deadline.")
        }
        try await Firestore.firestore().collection("sharedGoals").document(goal.id).updateData([
            "title": goal.title.trimmingCharacters(in: .whitespacesAndNewlines),
            "description": goal.description,
            "targetDate": Timestamp(date: goal.targetDate),
            "targetDateString": DailyLog.dateFormatter.string(from: Calendar.current.startOfDay(for: goal.targetDate)),
            "activityTypes": goal.activityTypes,
            "scheduledWeekdays": goal.scheduledWeekdays,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        #else
        throw AuthError.firebaseNotConfigured("Shared goal editing requires Firebase.")
        #endif
    }

    func leaveOrEnd(goalId: String) async throws {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        let uid = try authenticatedUserId()
        let goalRef = Firestore.firestore().collection("sharedGoals").document(goalId)
        try await runTransaction { transaction, errorPointer in
            do {
                let snapshot = try transaction.getDocument(goalRef)
                guard let goal = SharedGoal(id: goalId, dictionary: snapshot.data() ?? [:]),
                      goal.status == .active,
                      goal.memberIds.contains(uid) else {
                    throw AuthError.validation("This collaboration is no longer active.")
                }
                if uid == goal.ownerId {
                    transaction.updateData([
                        "status": SharedGoalStatus.ended.rawValue,
                        "memberIds": [uid],
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: goalRef)
                } else {
                    guard goal.memberIds.count == 2 else {
                        throw AuthError.validation("You are no longer a member of this collaboration.")
                    }
                    transaction.updateData([
                        "memberIds": [goal.ownerId],
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: goalRef)
                }
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
        #else
        throw AuthError.firebaseNotConfigured("Collaboration management requires Firebase.")
        #endif
    }

    func respondToInvitation(id: String, with status: GoalInvitationStatus) async throws {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        let uid = try authenticatedUserId()
        guard [.accepted, .declined, .cancelled].contains(status) else {
            throw AuthError.validation("Invalid invitation response.")
        }
        let db = Firestore.firestore()
        let invitationRef = db.collection("goalInvitations").document(id)
        try await runTransaction { transaction, errorPointer in
            do {
                let invitationSnapshot = try transaction.getDocument(invitationRef)
                guard let invitation = GoalInvitation(id: id, dictionary: invitationSnapshot.data() ?? [:]),
                      invitation.status == .pending else {
                    throw AuthError.validation("This invitation is no longer pending.")
                }
                let isRecipient = status == .accepted || status == .declined
                guard (isRecipient && invitation.recipientId == uid)
                        || (status == .cancelled && invitation.senderId == uid) else {
                    throw AuthError.validation("You cannot change this invitation.")
                }
                let goalRef = db.collection("sharedGoals").document(invitation.sharedGoalId)
                let goalSnapshot = try transaction.getDocument(goalRef)
                guard let goal = SharedGoal(id: invitation.sharedGoalId, dictionary: goalSnapshot.data() ?? [:]),
                      goal.status == .inviting,
                      goal.pendingInvitationId == id,
                      goal.memberIds == [invitation.senderId] else {
                    throw AuthError.validation("The proposed goal is no longer available.")
                }

                let goalStatus: SharedGoalStatus
                var members = goal.memberIds
                if status == .accepted {
                    guard members.count == 1, !members.contains(invitation.recipientId) else {
                        throw AuthError.validation("This goal already has two members.")
                    }
                    members.append(invitation.recipientId)
                    goalStatus = .active
                } else if status == .declined {
                    goalStatus = .declined
                } else {
                    goalStatus = .cancelled
                }
                var goalUpdate: [String: Any] = [
                    "status": goalStatus.rawValue,
                    "memberIds": members,
                    "pendingInvitationId": FieldValue.delete(),
                    "updatedAt": FieldValue.serverTimestamp()
                ]
                if status == .accepted {
                    goalUpdate["memberJoinedAt"] = FieldValue.serverTimestamp()
                }
                transaction.updateData(goalUpdate, forDocument: goalRef)
                transaction.updateData([
                    "status": status.rawValue,
                    "respondedAt": FieldValue.serverTimestamp()
                ], forDocument: invitationRef)
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
        #else
        throw AuthError.firebaseNotConfigured("Invitation management requires Firebase.")
        #endif
    }
}
