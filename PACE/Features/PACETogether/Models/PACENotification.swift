import Foundation

enum PACENotificationKind: Hashable {
    case goalInvitation
    case invitationAccepted
    case invitationDeclined
    case partnerReminder
    case partnerActivity

    var symbolName: String {
        switch self {
        case .goalInvitation: return "envelope.badge"
        case .invitationAccepted: return "checkmark.circle"
        case .invitationDeclined: return "xmark.circle"
        case .partnerReminder: return "bell.badge"
        case .partnerActivity: return "figure.walk"
        }
    }
}

enum PACENotificationDestination: Hashable, Identifiable {
    case invitations
    case sharedGoal(String)
    case sharedJourney(String, logId: String)
    case sharedGoalLog(String)

    var id: String {
        switch self {
        case .invitations: return "invitations"
        case .sharedGoal(let goalId): return "goal:\(goalId)"
        case .sharedJourney(let goalId, let logId): return "journey:\(goalId):\(logId)"
        case .sharedGoalLog(let goalId): return "log:\(goalId)"
        }
    }
}

struct PACENotification: Identifiable, Hashable {
    let id: String
    let kind: PACENotificationKind
    let title: String
    let message: String
    let createdAt: Date
    let destination: PACENotificationDestination
    var isRead: Bool
}
