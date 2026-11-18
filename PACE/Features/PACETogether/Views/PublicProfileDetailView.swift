import SwiftUI

struct PublicProfileDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let profile: PublicProfile
    @State private var isShowingInvitationFlow = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 14) {
                        PACEProfileAvatar(profile: profile, size: 72)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(profile.displayName)
                                .font(PACETextStyle.displayMedium)
                                .foregroundColor(PACETheme.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("@\(profile.username)")
                                .font(PACETextStyle.pixelLabel)
                                .foregroundColor(PACETheme.accent)
                        }
                    }

                    if !profile.bio.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ABOUT")
                                .font(PACETextStyle.pixelLabel)
                                .foregroundColor(PACETheme.secondaryText)
                                .tracking(1.5)
                            Text(profile.bio)
                                .font(PACETextStyle.body)
                                .foregroundColor(PACETheme.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(profile.lookingForPartner ? PACETheme.accent : PACETheme.border)
                            .frame(width: 8, height: 8)
                        Text(profile.lookingForPartner ? "LOOKING FOR A PARTNER" : "NOT CURRENTLY LOOKING")
                            .font(PACETextStyle.pixelMetadata)
                            .foregroundColor(profile.lookingForPartner ? PACETheme.accent : PACETheme.secondaryText)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PACETheme.surface)
                    .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))


                    Button {
                        isShowingInvitationFlow = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.2")
                            Text("INVITE TO A GOAL")
                        }
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(PACETheme.textOnAccent)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(PACETheme.accent)
                        .overlay(Rectangle().stroke(PACETheme.accent, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(profile.userId == AuthService.shared.currentUser?.id)

                    Text("PROFILE DETAILS ONLY. PRIVATE GOALS, LOGS, AND EVIDENCE STAY PRIVATE.")
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(PACETheme.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(PACETheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("CLOSE") { dismiss() }
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(PACETheme.accent)
                }
            }
            .sheet(isPresented: $isShowingInvitationFlow) {
                InvitationFlowView(profile: profile)
            }
        }
    }
}
