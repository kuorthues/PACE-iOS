import SwiftUI

struct SharedJourneyView: View {
    let goal: SharedGoal
    var focusLogId: String? = nil

    @ObservedObject private var evidenceService = EvidenceService.shared
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var sharedService = SharedGoalService.shared
    @State private var profilesById: [String: PublicProfile] = [:]

    private var currentUserId: String? {
        AuthService.shared.currentUser?.id
    }
    private var currentGoal: SharedGoal {
        sharedService.goals.first(where: { $0.id == goal.id }) ?? goal
    }

    private var logs: [DailyLog] {
        sharedService.logsByGoal[goal.id] ?? []
    }
    private var participantIds: [String] {
        Array(Set(currentGoal.memberIds + logs.compactMap(\.authorId))).sorted()
    }

    private var entries: [SharedJourneyEntry] {
        JourneyTimelineBuilder.buildSharedTimeline(goal: currentGoal.asPACEGoal(), logs: logs)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SHARED JOURNEY")
                            .font(PACETextStyle.displayLarge)
                            .foregroundColor(PACETheme.primaryText)
                        Text("COMPLETED CONTRIBUTIONS ONLY · \(currentGoal.title.uppercased())")
                            .font(PACETextStyle.pixelMetadata)
                            .foregroundColor(PACETheme.secondaryText)
                    }
                    .padding(.bottom, 4)

                    if logs.isEmpty {
                        Text("NO COMPLETED ENTRIES YET. THE TARGET DEADLINE IS SHOWN BELOW.")
                            .font(PACETextStyle.pixelMetadata)
                            .foregroundColor(PACETheme.mutedText)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(PACETheme.surface)
                            .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
                    }

                    ForEach(entries) { entry in
                        if entry.isDeadline {
                            deadlineMarker(entry)
                        } else {
                            contributionDay(entry)
                        }
                    }
                }
                .padding(20)
            }
            .onAppear { scrollToFocusedLog(using: proxy) }
            .onChange(of: logs.map(\.id)) { _, _ in scrollToFocusedLog(using: proxy) }
        }
        .background(PACETheme.background.ignoresSafeArea())
        .navigationTitle("SHARED JOURNEY")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(PACETheme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task(id: participantIds) {
            if let sourceGoalId = currentGoal.sourceGoalId, currentGoal.ownerId == currentUserId {
                _ = await evidenceService.fetchEvidence(for: sourceGoalId)
            }
            _ = await evidenceService.fetchEvidence(for: currentGoal.id)
            for memberId in participantIds {
                if memberId == currentUserId {
                    if let profile = await PublicProfileService.shared.fetchCurrentProfile() {
                        profilesById[memberId] = profile
                    }
                } else if let profile = await PublicProfileService.shared.fetchPublicProfile(userId: memberId) {
                    profilesById[memberId] = profile
                }
            }
        }
        .onChange(of: sharedService.goals) { _, goals in
            if !goals.contains(where: { $0.id == goal.id }) {
                dismiss()
            }
        }
    }

    private func contributionDay(_ entry: SharedJourneyEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(entry.date.formatted(date: .complete, time: .omitted).uppercased())
                    .font(PACETextStyle.pixelLabel)
                    .foregroundColor(PACETheme.accent)
                Spacer()
                Text("\(entry.logs.count) \(entry.logs.count == 1 ? "ENTRY" : "ENTRIES")")
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACETheme.secondaryText)
            }
            ForEach(entry.logs) { log in
                contribution(log)
            }
        }
        .padding(12)
        .background(PACETheme.surface)
        .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
    }

    private func contribution(_ log: DailyLog) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(contributorName(log.authorId))
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACETheme.accent)
                Spacer()
                Text(log.formattedDuration.uppercased())
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACETheme.primaryText)
            }
            Text(log.selectedActivities.joined(separator: " · ").uppercased())
                .font(PACETextStyle.displaySmall)
                .foregroundColor(PACETheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            if let note = log.note, !note.isEmpty {
                Text(note)
                    .font(PACETextStyle.body)
                    .foregroundColor(PACETheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            evidenceContent(for: log)
        }
        .padding(.top, 8)
        .id(log.id)
        .overlay(alignment: .top) {
            Rectangle().fill(PACETheme.border).frame(height: 1)
        }
    }

    private func scrollToFocusedLog(using proxy: ScrollViewProxy) {
        guard let focusLogId,
              logs.contains(where: { $0.id == focusLogId }) else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(focusLogId, anchor: .center)
        }
    }

    @ViewBuilder
    private func evidenceContent(for log: DailyLog) -> some View {
        let evidence = localEvidence(for: log)
        if !evidence.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                SquareEvidenceMiniThumbnail(evidenceItems: evidence, size: 40, stemHeight: 0)
                Text("PHOTO AVAILABLE ON THIS DEVICE")
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACETheme.secondaryText)
            }
            .padding(.top, 4)
        } else if log.evidenceId != nil {
            Text(log.authorId == currentUserId
                 ? "PHOTO UNAVAILABLE ON THIS DEVICE"
                 : "PHOTO SAVED ON CONTRIBUTOR'S DEVICE · NOT SHARED")
                .font(PACETextStyle.pixelMetadata)
                .foregroundColor(PACETheme.mutedText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
    }

    private func localEvidence(for log: DailyLog) -> [EvidenceItem] {
        guard log.authorId == currentUserId else { return [] }
        let evidenceGoalId = log.sourceLogId == nil ? currentGoal.id : (currentGoal.sourceGoalId ?? currentGoal.id)
        let evidenceLogId = log.sourceLogId ?? log.id
        var items = evidenceService.fetchEvidenceItems(forGoal: evidenceGoalId, logId: evidenceLogId)
        if items.isEmpty, evidenceLogId != log.dateString {
            items = evidenceService.fetchEvidenceItems(forGoal: evidenceGoalId, logId: log.dateString)
        }
        if let evidenceId = log.evidenceId {
            items = items.filter { $0.id == evidenceId }
        }
        return items
    }

    private func contributorName(_ userId: String?) -> String {
        guard let userId else { return "PACE MEMBER" }
        if userId == currentUserId { return "YOU" }
        if let profile = profilesById[userId] {
            return profile.displayName.isEmpty ? "@\(profile.username)" : profile.displayName
        }
        return "PACE MEMBER"
    }

    private func deadlineMarker(_ entry: SharedJourneyEntry) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(PACETheme.accent)
                .frame(width: 14, height: 14)
            VStack(alignment: .leading, spacing: 4) {
                Text("TARGET DEADLINE")
                    .font(PACETextStyle.pixelLabel)
                    .foregroundColor(PACETheme.accent)
                Text(entry.date.formatted(date: .complete, time: .omitted).uppercased())
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACETheme.primaryText)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PACETheme.surface)
        .overlay(Rectangle().stroke(PACETheme.accent, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
