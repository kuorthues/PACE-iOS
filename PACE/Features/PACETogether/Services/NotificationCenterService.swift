import Combine
import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class NotificationCenterService: ObservableObject {
    static let shared = NotificationCenterService()

    @Published private(set) var notifications: [PACENotification] = []
    @Published private(set) var unreadCount = 0
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var listeningUserId: String?
    private var sourceSubscriptions = Set<AnyCancellable>()
    private var readEventIds = Set<String>()
    private var optimisticReadEventIds = Set<String>()
    private var remindersByGoal: [String: [PartnerReminder]] = [:]
    private var hasLoadedReadState = false

    #if canImport(FirebaseFirestore)
    private var readStateListener: ListenerRegistration?
    private var reminderListeners: [String: ListenerRegistration] = [:]
    #endif

    private init() {}

    func startListening(for userId: String?) {
        guard listeningUserId != userId else { return }
        clearInMemoryCache()
        listeningUserId = userId
        guard let userId else { return }

        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard AuthService.shared.isFirebaseConfigured,
              Auth.auth().currentUser?.uid == userId else {
            isLoading = false
            return
        }
        isLoading = true

        let db = Firestore.firestore()
        readStateListener = db.collection("users")
            .document(userId)
            .collection("notificationState")
            .order(by: "updatedAt", descending: true)
            .limit(to: 500)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self, self.listeningUserId == userId else { return }
                    if let error {
                        self.errorMessage = "Notification read status could not sync."
                        self.hasLoadedReadState = true
                        self.updateLoadingState()
                        return
                    }
                    let syncedReadIds = Set((snapshot?.documents ?? []).compactMap { document in
                        (document.data()["isRead"] as? Bool == true) ? document.documentID : nil
                    })
                    self.readEventIds = syncedReadIds.union(self.optimisticReadEventIds)
                    self.errorMessage = nil
                    self.hasLoadedReadState = true
                    self.updateLoadingState()
                    self.rebuildNotifications()
                }
            }

        GoalInvitationService.shared.$invitations
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.rebuildNotifications() }
            }
            .store(in: &sourceSubscriptions)

        GoalInvitationService.shared.$hasLoaded
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.updateLoadingState() }
            }
            .store(in: &sourceSubscriptions)

        SharedGoalService.shared.$goals
            .sink { [weak self] goals in
                Task { @MainActor [weak self] in
                    guard let self, self.listeningUserId == userId else { return }
                    self.updateReminderListeners(for: goals, userId: userId)
                    self.rebuildNotifications()
                }
            }
            .store(in: &sourceSubscriptions)

        SharedGoalService.shared.$hasLoaded
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.updateLoadingState() }
            }
            .store(in: &sourceSubscriptions)

        SharedGoalService.shared.$logsByGoal
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.rebuildNotifications() }
            }
            .store(in: &sourceSubscriptions)

        updateReminderListeners(for: SharedGoalService.shared.goals, userId: userId)
        rebuildNotifications()
        #endif
    }

    func clearInMemoryCache() {
        #if canImport(FirebaseFirestore)
        readStateListener?.remove()
        readStateListener = nil
        reminderListeners.values.forEach { $0.remove() }
        reminderListeners.removeAll()
        #endif
        sourceSubscriptions.removeAll()
        listeningUserId = nil
        readEventIds = []
        optimisticReadEventIds = []
        remindersByGoal = [:]
        hasLoadedReadState = false
        notifications = []
        unreadCount = 0
        isLoading = false
        errorMessage = nil
    }

    func markAsRead(_ notification: PACENotification) {
        guard !readEventIds.contains(notification.id),
              !optimisticReadEventIds.contains(notification.id),
              let userId = listeningUserId else { return }

        optimisticReadEventIds.insert(notification.id)
        readEventIds.insert(notification.id)
        rebuildNotifications()

        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard Auth.auth().currentUser?.uid == userId else { return }
        let reference = Firestore.firestore()
            .collection("users")
            .document(userId)
            .collection("notificationState")
            .document(Self.readStateDocumentId(for: notification.id))
        Task { [weak self] in
            do {
                try await reference.setData([
                    "isRead": true,
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)
            } catch {
                await MainActor.run {
                    guard let self, self.listeningUserId == userId else { return }
                    self.optimisticReadEventIds.remove(notification.id)
                    self.readEventIds.remove(notification.id)
                    self.errorMessage = "This notification could not be marked as read."
                    self.rebuildNotifications()
                }
            }
        }
        #endif
    }

    func markAllRead() {
        let unread = notifications.filter { !$0.isRead }
        guard !unread.isEmpty, let userId = listeningUserId else { return }

        let ids = unread.map(\.id)
        optimisticReadEventIds.formUnion(ids)
        readEventIds.formUnion(ids)
        rebuildNotifications()

        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard Auth.auth().currentUser?.uid == userId else { return }
        let db = Firestore.firestore()
        let batch = db.batch()
        for notification in unread {
            let reference = db.collection("users")
                .document(userId)
                .collection("notificationState")
                .document(Self.readStateDocumentId(for: notification.id))
            batch.setData([
                "isRead": true,
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: reference, merge: true)
        }
        Task { [weak self] in
            do {
                try await batch.commit()
            } catch {
                await MainActor.run {
                    guard let self, self.listeningUserId == userId else { return }
                    self.optimisticReadEventIds.subtract(ids)
                    self.readEventIds.subtract(ids)
                    self.errorMessage = "Notifications could not all be marked as read."
                    self.rebuildNotifications()
                }
            }
        }
        #endif
    }

    private func updateReminderListeners(for goals: [SharedGoal], userId: String) {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        let activeGoalIds = Set(goals.filter {
            $0.status == .active && $0.memberIds.contains(userId)
        }.map(\.id))

        for goalId in Array(reminderListeners.keys) where !activeGoalIds.contains(goalId) {
            reminderListeners.removeValue(forKey: goalId)?.remove()
            remindersByGoal.removeValue(forKey: goalId)
        }

        for goalId in activeGoalIds where reminderListeners[goalId] == nil {
            reminderListeners[goalId] = Firestore.firestore()
                .collection("sharedGoals")
                .document(goalId)
                .collection("reminders")
                .order(by: "createdAt", descending: true)
                .limit(to: 100)
                .addSnapshotListener { [weak self] snapshot, error in
                    Task { @MainActor [weak self] in
                        guard let self,
                              self.listeningUserId == userId,
                              activeGoalIds.contains(goalId) else { return }
                        if error != nil {
                            self.remindersByGoal.removeValue(forKey: goalId)
                            self.errorMessage = "Some partner reminders could not sync."
                        } else {
                            self.remindersByGoal[goalId] = (snapshot?.documents ?? []).compactMap {
                                PartnerReminder(id: $0.documentID, dictionary: $0.data())
                            }
                        }
                        self.rebuildNotifications()
                    }
                }
        }
        #endif
    }

    private func rebuildNotifications() {
        guard let userId = listeningUserId else {
            notifications = []
            unreadCount = 0
            return
        }

        var events: [PACENotification] = []
        for invitation in GoalInvitationService.shared.invitations {
            if invitation.recipientId == userId, invitation.status == .pending {
                events.append(PACENotification(
                    id: Self.eventId("invitation", invitation.id, "received"),
                    kind: .goalInvitation,
                    title: "GOAL INVITATION",
                    message: "You have an invitation to work on \(invitation.goalTitle).",
                    createdAt: invitation.createdAt,
                    destination: .invitations,
                    isRead: false
                ))
            } else if invitation.senderId == userId, invitation.status == .accepted {
                events.append(PACENotification(
                    id: Self.eventId("invitation", invitation.id, "accepted"),
                    kind: .invitationAccepted,
                    title: "INVITATION ACCEPTED",
                    message: "Your invitation to \(invitation.goalTitle) was accepted.",
                    createdAt: invitation.respondedAt ?? invitation.createdAt,
                    destination: .sharedGoal(invitation.sharedGoalId),
                    isRead: false
                ))
            } else if invitation.senderId == userId, invitation.status == .declined {
                events.append(PACENotification(
                    id: Self.eventId("invitation", invitation.id, "declined"),
                    kind: .invitationDeclined,
                    title: "INVITATION DECLINED",
                    message: "Your invitation to \(invitation.goalTitle) was declined.",
                    createdAt: invitation.respondedAt ?? invitation.createdAt,
                    destination: .invitations,
                    isRead: false
                ))
            }
        }

        let goals = SharedGoalService.shared.goals.filter { $0.status == .active }
        for goal in goals {
            let collaborationStart = goal.memberJoinedAt ?? goal.createdAt
            for log in SharedGoalService.shared.logsByGoal[goal.id] ?? [] {
                guard let authorId = log.authorId,
                      authorId != userId,
                      goal.memberIds.contains(authorId),
                      log.createdAt >= collaborationStart else { continue }
                events.append(PACENotification(
                    id: Self.eventId("activity", goal.id, log.id),
                    kind: .partnerActivity,
                    title: "PARTNER ACTIVITY",
                    message: "Your partner logged progress for \(goal.title).",
                    createdAt: log.createdAt,
                    destination: .sharedJourney(goal.id, logId: log.id),
                    isRead: false
                ))
            }

            for reminder in remindersByGoal[goal.id] ?? [] where reminder.recipientId == userId && reminder.senderId != userId {
                events.append(PACENotification(
                    id: Self.eventId("reminder", goal.id, reminder.id),
                    kind: .partnerReminder,
                    title: "PARTNER REMINDER",
                    message: "Your partner reminded you to log today's progress for \(goal.title).",
                    createdAt: reminder.createdAt,
                    destination: .sharedGoalLog(goal.id),
                    isRead: false
                ))
            }
        }

        let sorted = events
            .sorted {
                if $0.createdAt == $1.createdAt { return $0.id < $1.id }
                return $0.createdAt > $1.createdAt
            }
            .prefix(500)

        notifications = sorted.map { event in
            var value = event
            value.isRead = readEventIds.contains(event.id)
            return value
        }
        unreadCount = notifications.reduce(into: 0) { count, event in
            if !event.isRead { count += 1 }
        }
    }

    private func updateLoadingState() {
        guard listeningUserId != nil else {
            isLoading = false
            return
        }
        isLoading = !(hasLoadedReadState
            && GoalInvitationService.shared.hasLoaded
            && SharedGoalService.shared.hasLoaded)
    }

    private static func eventId(_ components: String...) -> String {
        components
            .map {
                Data($0.utf8)
                    .base64EncodedString()
                    .replacingOccurrences(of: "+", with: "-")
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: "=", with: "")
            }
            .joined(separator: ".")
    }

    private static func readStateDocumentId(for eventId: String) -> String {
        eventId
    }
}
