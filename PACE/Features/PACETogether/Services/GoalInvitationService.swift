import SwiftUI
import Combine

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class GoalInvitationService: ObservableObject {
    static let shared = GoalInvitationService()

    @Published private(set) var invitations: [GoalInvitation] = []
    @Published private(set) var hasLoaded = false
    @Published var errorMessage: String?

    #if canImport(FirebaseFirestore)
    private var receivedListener: ListenerRegistration?
    private var sentListener: ListenerRegistration?
    #endif
    private var listeningUserId: String?
    private var receivedById: [String: GoalInvitation] = [:]
    private var sentById: [String: GoalInvitation] = [:]
    private var hasLoadedReceived = false
    private var hasLoadedSent = false

    private init() {}

    var pendingReceived: [GoalInvitation] {
        invitations.filter { $0.recipientId == listeningUserId && $0.status == .pending }
    }

    var received: [GoalInvitation] {
        invitations.filter { $0.recipientId == listeningUserId }
    }

    var sent: [GoalInvitation] {
        invitations.filter { $0.senderId == listeningUserId }
    }

    func startListening(for userId: String?) {
        guard listeningUserId != userId else { return }
        clearInMemoryCache()
        listeningUserId = userId
        guard let userId else { return }

        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard AuthService.shared.isFirebaseConfigured,
              Auth.auth().currentUser?.uid == userId else { return }
        let collection = Firestore.firestore().collection("goalInvitations")
        receivedListener = collection.whereField("recipientId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self, self.listeningUserId == userId else { return }
                    if let error {
                        self.errorMessage = "Received invitations could not sync: \(error.localizedDescription)"
                        self.receivedById = [:]
                    } else {
                        self.receivedById = Dictionary(uniqueKeysWithValues: (snapshot?.documents ?? []).compactMap {
                            guard let invitation = GoalInvitation(id: $0.documentID, dictionary: $0.data()) else { return nil }
                            return (invitation.id, invitation)
                        })
                        self.errorMessage = nil
                    }
                    self.hasLoadedReceived = true
                    self.updateLoadedState()
                    self.publishInvitations()
                }
            }
        sentListener = collection.whereField("senderId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self, self.listeningUserId == userId else { return }
                    if let error {
                        self.errorMessage = "Sent invitations could not sync: \(error.localizedDescription)"
                        self.sentById = [:]
                    } else {
                        self.sentById = Dictionary(uniqueKeysWithValues: (snapshot?.documents ?? []).compactMap {
                            guard let invitation = GoalInvitation(id: $0.documentID, dictionary: $0.data()) else { return nil }
                            return (invitation.id, invitation)
                        })
                        self.errorMessage = nil
                    }
                    self.hasLoadedSent = true
                    self.updateLoadedState()
                    self.publishInvitations()
                }
            }
        #endif
    }

    func clearInMemoryCache() {
        #if canImport(FirebaseFirestore)
        receivedListener?.remove()
        sentListener?.remove()
        receivedListener = nil
        sentListener = nil
        #endif
        listeningUserId = nil
        receivedById = [:]
        sentById = [:]
        invitations = []
        hasLoadedReceived = false
        hasLoadedSent = false
        hasLoaded = false
        errorMessage = nil
    }

    private func updateLoadedState() {
        hasLoaded = hasLoadedReceived && hasLoadedSent
    }

    private func publishInvitations() {
        var merged = receivedById
        for (id, invitation) in sentById { merged[id] = invitation }
        invitations = merged.values.sorted {
            if $0.createdAt == $1.createdAt { return $0.id < $1.id }
            return $0.createdAt > $1.createdAt
        }
    }
}
