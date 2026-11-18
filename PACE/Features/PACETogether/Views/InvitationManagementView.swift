import SwiftUI

struct InvitationManagementView: View {
    @ObservedObject private var invitationService = GoalInvitationService.shared
    @State private var selectedProfile: PublicProfile?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("GOAL INVITATIONS")
                    .font(PACETextStyle.displayLarge)
                    .foregroundColor(PACETheme.primaryText)

                if let error = invitationService.errorMessage {
                    Text(error)
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                invitationSection(title: "RECEIVED", items: invitationService.received, received: true)
                invitationSection(title: "SENT", items: invitationService.sent, received: false)
            }
            .padding(20)
        }
        .background(PACETheme.background.ignoresSafeArea())
        .navigationTitle("INVITATIONS")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(PACETheme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            invitationService.startListening(for: AuthService.shared.currentUser?.id)
        }
        .sheet(item: $selectedProfile) { profile in
            PublicProfileDetailView(profile: profile)
        }
    }

    @ViewBuilder
    private func invitationSection(title: String, items: [GoalInvitation], received: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(PACETextStyle.pixelLabel)
                .foregroundColor(PACETheme.secondaryText)
                .tracking(1.5)
            if items.isEmpty {
                Text("NO \(title) INVITATIONS.")
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACETheme.mutedText)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PACETheme.surface)
                    .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
            } else {
                ForEach(items) { invitation in
                    InvitationRowView(invitation: invitation, received: received) { profile in
                        selectedProfile = profile
                    }
                }
            }
        }
    }
}

private struct InvitationRowView: View {
    let invitation: GoalInvitation
    let received: Bool
    let showProfile: (PublicProfile) -> Void

    @State private var otherProfile: PublicProfile?
    @State private var isUpdating = false
    @State private var errorMessage: String?
    @State private var confirmsCancellation = false

    private var otherUserId: String {
        received ? invitation.senderId : invitation.recipientId
    }

    private var otherUserName: String {
        otherProfile.map { "@\($0.username)" } ?? "PACE MEMBER"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(invitation.goalTitle.uppercased())
                        .font(PACETextStyle.displaySmall)
                        .foregroundColor(PACETheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(received ? "FROM" : "TO") \(otherUserName) · \(invitation.targetDateForDisplay.formatted(date: .abbreviated, time: .omitted).uppercased())")
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(PACETheme.secondaryText)
                    Text(invitation.status.rawValue.uppercased())
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(invitation.status == .pending ? PACETheme.accent : PACETheme.mutedText)
                }
                Spacer(minLength: 4)
                Image(systemName: invitation.status == .pending ? "envelope.badge" : "person.2")
                    .foregroundColor(invitation.status == .pending ? PACETheme.accent : PACETheme.secondaryText)
            }

            if received, let otherProfile {
                Button("VIEW SENDER PROFILE") { showProfile(otherProfile) }
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACETheme.accent)
                    .buttonStyle(.plain)
            }

            if invitation.status == .pending {
                if received {
                    HStack(spacing: 10) {
                        actionButton("ACCEPT", enabled: !isUpdating) {
                            updateInvitation(to: .accepted)
                        }
                        actionButton("DECLINE", enabled: !isUpdating) {
                            updateInvitation(to: .declined)
                        }
                    }
                } else {
                    actionButton("CANCEL INVITATION", enabled: !isUpdating) {
                        confirmsCancellation = true
                    }
                    .foregroundColor(.red)
                }
            }

            if isUpdating {
                ProgressView().tint(PACETheme.accent)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PACETheme.surface)
        .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
        .task(id: otherUserId) {
            otherProfile = await PublicProfileService.shared.fetchPublicProfile(userId: otherUserId)
        }
        .confirmationDialog("Cancel this invitation?", isPresented: $confirmsCancellation, titleVisibility: .visible) {
            Button("CANCEL INVITATION", role: .destructive) { updateInvitation(to: .cancelled) }
            Button("KEEP INVITATION", role: .cancel) {}
        } message: {
            Text("The recipient will no longer be able to accept this invitation.")
        }
    }

    private func actionButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(PACETextStyle.pixelMetadata)
                .foregroundColor(PACETheme.textOnAccent)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(PACETheme.accent)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func updateInvitation(to status: GoalInvitationStatus) {
        guard !isUpdating else { return }
        isUpdating = true
        errorMessage = nil
        Task {
            defer { isUpdating = false }
            do {
                try await SharedGoalService.shared.respondToInvitation(id: invitation.id, with: status)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
