import SwiftUI

struct PartnerDiscoveryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var profileService = PublicProfileService.shared

    @State private var searchText = ""
    @State private var hasSearched = false
    @State private var selectedProfile: PublicProfile?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("FIND PARTNERS")
                        .font(PACETextStyle.displayLarge)
                        .foregroundColor(PACETheme.primaryText)
                        .padding(.top, 4)

                    searchSection

                    if profileService.isLoading {
                        ProgressView()
                            .tint(PACETheme.accent)
                            .frame(maxWidth: .infinity, minHeight: 100)
                            .accessibilityLabel("Loading profiles")
                    } else if hasSearched {
                        resultSection
                    } else {
                        suggestionSection
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
                if profileService.suggestions.isEmpty {
                    await profileService.fetchSuggestions(limit: 6)
                }
            }
            .sheet(item: $selectedProfile) { profile in
                PublicProfileDetailView(profile: profile)
            }
        }
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SEARCH BY USERNAME")
                .font(PACETextStyle.pixelLabel)
                .foregroundColor(PACETheme.secondaryText)
                .tracking(1.5)

            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text("@")
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(PACETheme.accent)
                    TextField("USERNAME", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(PACETextStyle.body)
                        .foregroundColor(PACETheme.primaryText)
                        .submitLabel(.search)
                        .onSubmit { search() }
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 48)
                .background(Color.black)
                .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))

                Button("SEARCH") { search() }
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACETheme.textOnAccent)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 48)
                    .background(PACETheme.accent)
                    .overlay(Rectangle().stroke(PACETheme.accent, lineWidth: 1))
                    .buttonStyle(.plain)
                    .accessibilityLabel("Search usernames")
            }

            if !searchText.isEmpty {
                Button("CLEAR SEARCH") {
                    searchText = ""
                    hasSearched = false
                    profileService.searchResults = []
                    Task { await profileService.fetchSuggestions(limit: 6) }
                }
                .font(PACETextStyle.pixelMetadata)
                .foregroundColor(PACETheme.secondaryText)
                .buttonStyle(.plain)
            }
        }
    }

    private var suggestionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("PACE TOGETHER")
                    .font(PACETextStyle.pixelLabel)
                    .foregroundColor(PACETheme.secondaryText)
                    .tracking(1.5)
                Spacer()
                Text("DISCOVERABLE")
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACETheme.accent)
            }
            profileList(profileService.suggestions, emptyMessage: "NO DISCOVERABLE PROFILES YET.")
        }
    }

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SEARCH RESULTS")
                .font(PACETextStyle.pixelLabel)
                .foregroundColor(PACETheme.secondaryText)
                .tracking(1.5)
            profileList(profileService.searchResults, emptyMessage: "NO MATCHING DISCOVERABLE USERNAMES.")
        }
    }

    @ViewBuilder
    private func profileList(_ profiles: [PublicProfile], emptyMessage: String) -> some View {
        if let error = profileService.errorMessage {
            Text(error)
                .font(PACETextStyle.pixelMetadata)
                .foregroundColor(.red)
                .fixedSize(horizontal: false, vertical: true)
        } else if profiles.isEmpty {
            Text(emptyMessage)
                .font(PACETextStyle.body)
                .foregroundColor(PACETheme.secondaryText)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PACETheme.surface)
                .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
        } else {
            ForEach(profiles) { profile in
                PACEProfileCard(profile: profile) {
                    selectedProfile = profile
                }
            }
        }
    }

    private func search() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            hasSearched = false
            Task { await profileService.fetchSuggestions(limit: 6) }
            return
        }
        hasSearched = true
        Task { await profileService.searchProfiles(username: query) }
    }
}
