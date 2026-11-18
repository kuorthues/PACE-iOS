import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum PartnerReminderError: LocalizedError {
    case firebaseUnavailable
    case authenticationChanged
    case inactiveGoal
    case noPartner
    case restDay
    case outsideGoalDates
    case partnerAlreadyLogged
    case cooldown(until: Date)

    var errorDescription: String? {
        switch self {
        case .firebaseUnavailable:
            return "Partner reminders need an active Firebase connection."
        case .authenticationChanged:
            return "Your account changed. Reopen the shared goal and try again."
        case .inactiveGoal:
            return "This shared goal is no longer active."
        case .noPartner:
            return "A current partner could not be found for this goal."
        case .restDay:
            return "Today is a rest day for this shared goal."
        case .outsideGoalDates:
            return "Today is outside this shared goal's active dates."
        case .partnerAlreadyLogged:
            return "Your partner has already logged today's progress."
        case .cooldown(let until):
            return "You can remind your partner again \(until.formatted(.relative(presentation: .numeric)))."
        }
    }
}

@MainActor
final class PartnerReminderService {
    static let shared = PartnerReminderService()
    static let cooldownInterval: TimeInterval = 24 * 60 * 60

    private init() {}

    func cooldownUntil(goalId: String, recipientId: String) async throws -> Date? {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        let userId = try authenticatedUserId()
        let reference = Firestore.firestore()
            .collection("sharedGoals")
            .document(goalId)
            .collection("reminderCooldowns")
            .document(recipientId)
        let snapshot = try await reference.getDocument(source: .server)
        guard Auth.auth().currentUser?.uid == userId else {
            throw PartnerReminderError.authenticationChanged
        }
        guard let timestamp = snapshot.data()?["lastReminderAt"] as? Timestamp else { return nil }
        let until = timestamp.dateValue().addingTimeInterval(Self.cooldownInterval)
        return until > Date() ? until : nil
        #else
        throw PartnerReminderError.firebaseUnavailable
        #endif
    }

    func sendReminder(for goal: SharedGoal) async throws {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        let userId = try authenticatedUserId()
        guard goal.status == .active else { throw PartnerReminderError.inactiveGoal }
        guard let recipientId = goal.memberIds.first(where: { $0 != userId }) else {
            throw PartnerReminderError.noPartner
        }

        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let todayString = DailyLog.dateFormatter.string(from: today)
        let weekday = calendar.component(.weekday, from: today)
        guard goal.scheduledWeekdays.contains(weekday) else { throw PartnerReminderError.restDay }
        guard today >= calendar.startOfDay(for: goal.startDate),
              today <= calendar.startOfDay(for: goal.targetDateForDisplay) else {
            throw PartnerReminderError.outsideGoalDates
        }

        let db = Firestore.firestore()
        let goalRef = db.collection("sharedGoals").document(goal.id)
        let partnerLogRef = goalRef.collection("logs").document("\(recipientId)_\(todayString)")
        let cooldownRef = goalRef.collection("reminderCooldowns").document(recipientId)
        let reminderId = UUID().uuidString
        let reminderRef = goalRef.collection("reminders").document(reminderId)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.runTransaction({ transaction, errorPointer -> Any? in
                do {
                    // Read authoritative goal, partner log, and cooldown state before writing.
                    let goalSnapshot = try transaction.getDocument(goalRef)
                    guard goalSnapshot.exists,
                          let currentGoal = SharedGoal(id: goal.id, dictionary: goalSnapshot.data() ?? [:]),
                          currentGoal.status == .active,
                          currentGoal.memberIds.count == 2,
                          currentGoal.memberIds.contains(userId),
                          currentGoal.memberIds.contains(recipientId) else {
                        throw PartnerReminderError.inactiveGoal
                    }
                    guard currentGoal.scheduledWeekdays.contains(weekday) else {
                        throw PartnerReminderError.restDay
                    }
                    guard today >= calendar.startOfDay(for: currentGoal.startDate),
                          today <= calendar.startOfDay(for: currentGoal.targetDateForDisplay) else {
                        throw PartnerReminderError.outsideGoalDates
                    }

                    let partnerLogSnapshot = try transaction.getDocument(partnerLogRef)
                    guard !partnerLogSnapshot.exists else {
                        throw PartnerReminderError.partnerAlreadyLogged
                    }

                    let cooldownSnapshot = try transaction.getDocument(cooldownRef)
                    if let timestamp = cooldownSnapshot.data()?["lastReminderAt"] as? Timestamp {
                        let availableAt = timestamp.dateValue().addingTimeInterval(Self.cooldownInterval)
                        guard availableAt <= Date() else {
                            throw PartnerReminderError.cooldown(until: availableAt)
                        }
                    }

                    let reminderData: [String: Any] = [
                        "id": reminderId,
                        "sharedGoalId": goal.id,
                        "senderId": userId,
                        "recipientId": recipientId,
                        "createdAt": FieldValue.serverTimestamp()
                    ]
                    let cooldownData: [String: Any] = [
                        "recipientId": recipientId,
                        "lastSenderId": userId,
                        "lastReminderId": reminderId,
                        "lastReminderAt": FieldValue.serverTimestamp(),
                        "updatedAt": FieldValue.serverTimestamp()
                    ]
                    transaction.setData(reminderData, forDocument: reminderRef)
                    transaction.setData(cooldownData, forDocument: cooldownRef)
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }

        guard Auth.auth().currentUser?.uid == userId else {
            throw PartnerReminderError.authenticationChanged
        }
        #else
        throw PartnerReminderError.firebaseUnavailable
        #endif
    }

    #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
    private func authenticatedUserId() throws -> String {
        guard AuthService.shared.isFirebaseConfigured,
              let sessionUserId = AuthService.shared.currentUser?.id,
              let authUserId = Auth.auth().currentUser?.uid,
              sessionUserId == authUserId else {
            throw PartnerReminderError.firebaseUnavailable
        }
        return authUserId
    }
    #endif
}
