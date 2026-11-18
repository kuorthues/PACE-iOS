import SwiftUI

struct SharedGoalCard: View {
    let goal: SharedGoal
    let onSelect: () -> Void

    @State private var collaboratorName = "PARTNER"

    private var currentUserId: String? {
        AuthService.shared.currentUser?.id
    }
    private var collaborationStatusText: String {
        if goal.status == .ended { return "COLLABORATION ENDED" }
        return goal.memberIds.count > 1 ? "WITH \(collaboratorName.uppercased())" : "PARTNER LEFT"
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(PACETheme.accent)
                    Text(goal.status == .ended ? "ENDED" : "SHARED")
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(PACETheme.accent)
                        .tracking(1)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(PACETheme.accent)
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(goal.title.uppercased())
                        .font(PACETextStyle.displaySmall)
                        .foregroundColor(PACETheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    Text(String(format: "%02d DAYS", goal.countdownDays))
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(PACETheme.accent)
                }
                HStack(spacing: 8) {
                    Text("TARGET \(goal.targetDateForDisplay.formatted(date: .abbreviated, time: .omitted).uppercased())")
                    Text("·")
                    Text(collaborationStatusText)
                        .lineLimit(1)
                }
                .font(PACETextStyle.pixelMetadata)
                .foregroundColor(PACETheme.secondaryText)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PACETheme.surface)
            .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Shared goal \(goal.title), \(goal.countdownDays) days remaining")
        .task(id: goal.memberIds) {
            guard let currentUserId,
                  let partnerId = goal.memberIds.first(where: { $0 != currentUserId }) else {
                collaboratorName = "PARTNER"
                return
            }
            if let profile = await PublicProfileService.shared.fetchPublicProfile(userId: partnerId) {
                collaboratorName = profile.displayName.isEmpty ? "@\(profile.username)" : profile.displayName
            } else {
                collaboratorName = "PACE MEMBER"
            }
        }
    }
}
