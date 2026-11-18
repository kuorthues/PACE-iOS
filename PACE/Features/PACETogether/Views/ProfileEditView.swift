import SwiftUI

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authService = AuthService.shared
    @ObservedObject private var profileService = PublicProfileService.shared

    @State private var displayName = ""
    @State private var username = ""
    @State private var bio = ""
    @State private var isDiscoverable = false
    @State private var lookingForPartner = false
    @State private var isSaving = false
    @State private var hasLoaded = false
    @State private var localError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("PACE PROFILE")
                        .font(PACETextStyle.displayLarge)
                        .foregroundColor(PACETheme.primaryText)
                        .padding(.top, 4)

                    Text("CONTROL WHAT OTHER PACE USERS CAN DISCOVER.")
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(PACETheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    PACETextField(placeholder: "YOUR DISPLAY NAME", text: $displayName, label: "DISPLAY NAME")

                    VStack(alignment: .leading, spacing: 8) {
                        PACETextField(placeholder: "UNIQUE USERNAME", text: $username, label: "USERNAME")
                            .disabled(profileService.currentProfile != nil)
                            .opacity(profileService.currentProfile != nil ? 0.65 : 1)
                        if profileService.currentProfile != nil {
                            Text("USERNAME IS LOCKED AFTER PROFILE CREATION.")
                                .font(PACETextStyle.pixelMetadata)
                                .foregroundColor(PACETheme.mutedText)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("BIO")
                                .font(PACETextStyle.pixelLabel)
                                .foregroundColor(PACETheme.secondaryText)
                                .tracking(1.5)
                            Spacer()
                            Text("\(bio.count)/\(PublicProfile.maxBioLength)")
                                .font(PACETextStyle.pixelMetadata)
                                .foregroundColor(bio.count == PublicProfile.maxBioLength ? PACETheme.accent : PACETheme.mutedText)
                        }
                        TextEditor(text: $bio)
                            .font(PACETextStyle.body)
                            .foregroundColor(PACETheme.primaryText)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .frame(minHeight: 92)
                            .background(Color.black)
                            .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
                            .accessibilityLabel("Profile bio")
                    }

                    visibilityControls
                    profilePreview

                    if let message = localError ?? profileService.errorMessage {
                        Text(message)
                            .font(PACETextStyle.pixelMetadata)
                            .foregroundColor(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let status = profileService.statusMessage {
                        Text(status)
                            .font(PACETextStyle.pixelMetadata)
                            .foregroundColor(PACETheme.accent)
                    }

                    PACEButton(
                        title: isSaving ? "SAVING..." : "SAVE PROFILE",
                        variant: .primary,
                        isEnabled: !isSaving
                    ) {
                        save()
                    }
                }
                .padding(.horizontal, 20)
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
            .task {
                guard !hasLoaded else { return }
                hasLoaded = true
                await profileService.fetchCurrentProfile()
                if let profile = profileService.currentProfile {
                    displayName = profile.displayName
                    username = profile.username
                    bio = profile.bio
                    isDiscoverable = profile.isDiscoverable
                    lookingForPartner = profile.lookingForPartner
                } else {
                    displayName = authService.currentUser?.displayName ?? ""
                }
            }
            .onChange(of: bio) { _, newValue in
                if newValue.count > PublicProfile.maxBioLength {
                    bio = String(newValue.prefix(PublicProfile.maxBioLength))
                }
            }
        }
    }

    private var visibilityControls: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("DISCOVERY SETTINGS")
                .font(PACETextStyle.pixelLabel)
                .foregroundColor(PACETheme.secondaryText)
                .tracking(1.5)
                .padding(.bottom, 10)

            profileToggle(
                title: "DISCOVERABLE PROFILE",
                detail: "Appear in PACE Together search results.",
                isOn: $isDiscoverable
            )
            Rectangle().fill(PACETheme.border).frame(height: 1)
            profileToggle(
                title: "LOOKING FOR A PARTNER",
                detail: "Show that you are open to accountability partners.",
                isOn: $lookingForPartner
            )
        }
        .padding(14)
        .background(PACETheme.surface)
        .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
    }

    private func profileToggle(title: String, detail: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACETheme.primaryText)
                Text(detail)
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACETheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: PACETheme.accent))
        .padding(.vertical, 10)
        .accessibilityHint(detail)
    }

    private var profilePreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LIVE PREVIEW")
                .font(PACETextStyle.pixelLabel)
                .foregroundColor(PACETheme.secondaryText)
                .tracking(1.5)
            let preview = PublicProfile(
                userId: authService.currentUser?.id ?? "preview",
                username: username.isEmpty ? "username" : username,
                displayName: displayName.isEmpty ? "PACE USER" : displayName,
                bio: bio,
                isDiscoverable: isDiscoverable,
                lookingForPartner: lookingForPartner
            )
            PACEProfileCard(profile: preview) {}
                .allowsHitTesting(false)
        }
    }

    private func save() {
        localError = nil
        isSaving = true
        Task {
            do {
                try await profileService.saveProfile(
                    displayName: displayName,
                    username: username,
                    bio: bio,
                    isDiscoverable: isDiscoverable,
                    lookingForPartner: lookingForPartner
                )
                isSaving = false
                dismiss()
            } catch {
                isSaving = false
                localError = error.localizedDescription
            }
        }
    }
}
