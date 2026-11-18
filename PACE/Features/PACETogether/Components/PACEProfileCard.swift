import SwiftUI

struct PACEProfileCard: View {
    let profile: PublicProfile
    let onViewProfile: () -> Void
    var onInvite: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onViewProfile) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        PACEProfileAvatar(profile: profile, size: 48)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.displayName)
                                .font(PACETextStyle.displaySmall)
                                .foregroundColor(PACETheme.primaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text("@\(profile.username)")
                                .font(PACETextStyle.pixelMetadata)
                                .foregroundColor(PACETheme.accent)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(PACETheme.accent)
                            .accessibilityHidden(true)
                    }

                    if !profile.bio.isEmpty {
                        Text(profile.bio)
                            .font(PACETextStyle.body)
                            .foregroundColor(PACETheme.secondaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(profile.lookingForPartner ? PACETheme.accent : PACETheme.border)
                            .frame(width: 7, height: 7)
                        Text(profile.lookingForPartner ? "LOOKING FOR A PARTNER" : "PACE PROFILE")
                            .font(PACETextStyle.pixelMetadata)
                            .foregroundColor(profile.lookingForPartner ? PACETheme.accent : PACETheme.secondaryText)
                            .tracking(0.7)
                        Spacer()
                        Text("VIEW PROFILE")
                            .font(PACETextStyle.pixelMetadata)
                            .foregroundColor(PACETheme.primaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View profile for \(profile.displayName), @\(profile.username)")
            .accessibilityHint("Opens the public PACE profile")

            if let onInvite {
                Rectangle()
                    .fill(PACETheme.border)
                    .frame(height: 1)
                    .padding(.vertical, 10)
                Button(action: onInvite) {
                    HStack(spacing: 7) {
                        Image(systemName: "person.2")
                        Text("INVITE")
                    }
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACETheme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Invite \(profile.displayName) to a shared goal")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PACETheme.surface)
        .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
    }
}
