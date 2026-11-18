import SwiftUI

struct SharedGoalDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var sharedService = SharedGoalService.shared
    @State private var goal: SharedGoal
    @State private var profilesById: [String: PublicProfile] = [:]
    @State private var showLogSheet = false
    @State private var logDate = Date()
    @State private var showEditSheet = false
    @State private var showManageConfirmation = false
    @State private var actionError: String?
    @State private var isManaging = false

    init(goal: SharedGoal) {
        _goal = State(initialValue: goal)
    }

    private var currentUserId: String? {
        AuthService.shared.currentUser?.id
    }

    private var goalLogs: [DailyLog] {
        sharedService.logsByGoal[goal.id] ?? []
    }
    private var participantIds: [String] {
        Array(Set(goal.memberIds + goalLogs.compactMap(\.authorId))).sorted()
    }

    private var metrics: SharedGoalMetrics {
        SharedGoalAnalytics.compute(goal: goal, logs: goalLogs)
    }

    private var isOwner: Bool {
        currentUserId == goal.ownerId
    }

    private var hasLoggedToday: Bool {
        guard let currentUserId else { return false }
        let today = DailyLog.dateFormatter.string(from: Date())
        return goalLogs.contains { $0.authorId == currentUserId && $0.dateString == today }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(isOwner ? "SHARED GOAL · OWNER" : "SHARED GOAL · MEMBER")
                            .font(PACETextStyle.pixelMetadata)
                            .foregroundColor(PACETheme.accent)
                        Spacer()
                        Image(systemName: "person.2.fill")
                            .foregroundColor(PACETheme.accent)
                    }
                    Text(goal.title.uppercased())
                        .font(PACETextStyle.displayLarge)
                        .foregroundColor(PACETheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("TARGET \(goal.targetDateForDisplay.formatted(date: .complete, time: .omitted).uppercased()) · \(goal.countdownDays) DAYS REMAINING")
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(PACETheme.secondaryText)
                    Text(goal.scheduleDescription)
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(PACETheme.mutedText)
                }

                if !goal.description.isEmpty {
                    Text(goal.description)
                        .font(PACETextStyle.body)
                        .foregroundColor(PACETheme.secondaryText)
                }

                teamProgressSection
                memberProgressSection
                journeyLink
                if goal.status == .active {
                    progressLoggingSection
                } else {
                    Text("COLLABORATION ENDED · HISTORICAL CONTRIBUTIONS REMAIN AVAILABLE TO THE OWNER.")
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(PACETheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PACETheme.surface)
                        .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
                }
                logHistorySection
                if goal.status == .active {
                    collaborationControls
                }

                if let syncError = sharedService.errorMessage {
                    Text(syncError)
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let actionError {
                    Text(actionError)
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
        }
        .background(PACETheme.background.ignoresSafeArea())
        .navigationTitle("SHARED GOAL")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(PACETheme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task(id: participantIds) {
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
        .sheet(isPresented: $showLogSheet) {
            LogProgressView(
                goal: goal.asPACEGoal(),
                initialDate: logDate,
                sharedGoalId: goal.id,
                onSaved: {}
            )
        }
        .sheet(isPresented: $showEditSheet) {
            SharedGoalEditView(goal: goal) { updatedGoal in
                goal = updatedGoal
            }
        }
        .confirmationDialog(
            isOwner ? "End this collaboration?" : "Leave this collaboration?",
            isPresented: $showManageConfirmation,
            titleVisibility: .visible
        ) {
            Button(isOwner ? "END SHARED GOAL" : "LEAVE SHARED GOAL", role: .destructive) {
                manageCollaboration()
            }
            Button("KEEP COLLABORATION", role: .cancel) {}
        } message: {
            Text(isOwner
                 ? "The goal and all historical contributions remain stored for you. Ending removes the other member's future access; nothing is deleted."
                 : "Your access ends immediately after this change. The owner retains the goal and all recorded contributions; nothing is deleted.")
        }
        .onChange(of: sharedService.goals) { _, goals in
            guard let updatedGoal = goals.first(where: { $0.id == goal.id }) else {
                dismiss()
                return
            }
            goal = updatedGoal
            if updatedGoal.status != .active {
                showLogSheet = false
                showEditSheet = false
            }
        }
    }

    private var teamProgressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TEAM TOTAL")
                .font(PACETextStyle.pixelLabel)
                .foregroundColor(PACETheme.secondaryText)
                .tracking(1.5)
            HStack(spacing: 8) {
                metric("LOGGED TIME", value: "\(metrics.combinedLoggedMinutes)", unit: "MIN")
                metric("SESSIONS", value: "\(metrics.totalSessions)", unit: nil)
                metric("ACTIVE DAYS", value: "\(metrics.activeDays)", unit: nil)
            }
        }
    }

    private var memberProgressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INDIVIDUAL CONTRIBUTIONS")
                .font(PACETextStyle.pixelLabel)
                .foregroundColor(PACETheme.secondaryText)
                .tracking(1.5)
            ForEach(metrics.members) { member in
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(displayName(member.userId))
                            .font(PACETextStyle.displaySmall)
                            .foregroundColor(PACETheme.primaryText)
                        Spacer()
                        Text(member.userId == currentUserId ? "YOU" : "MEMBER")
                            .font(PACETextStyle.pixelMetadata)
                            .foregroundColor(PACETheme.accent)
                    }
                    HStack(spacing: 8) {
                        metric("STREAK", value: "\(member.currentStreak)", unit: "DAYS")
                        metric("ACTIVE", value: "\(member.activeDays)", unit: "DAYS")
                        metric("SESSIONS", value: "\(member.sessions)", unit: nil)
                    }
                    HStack {
                        Text("\(member.totalLoggedMinutes) MINUTES")
                        Spacer()
                        Text(String(format: "%.0f%% CONSISTENCY", member.consistencyPercentage))
                    }
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACETheme.secondaryText)
                }
                .padding(12)
                .background(PACETheme.surface)
                .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
            }
        }
    }

    private var journeyLink: some View {
        NavigationLink {
            SharedJourneyView(goal: goal)
        } label: {
            HStack {
                Image(systemName: "figure.walk")
                Text("OPEN SHARED JOURNEY")
                Spacer()
                Image(systemName: "arrow.up.right")
            }
            .font(PACETextStyle.pixelMetadata)
            .foregroundColor(PACETheme.accent)
            .padding(12)
            .background(PACETheme.surface)
            .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var progressLoggingSection: some View {
        Button {
            logDate = Date()
            showLogSheet = true
        } label: {
            HStack {
                Image(systemName: hasLoggedToday ? "pencil.square" : "plus.square")
                Text(hasLoggedToday ? "EDIT YOUR ENTRY TODAY" : "LOG YOUR WORK TODAY")
                Spacer()
            }
            .font(PACETextStyle.pixelMetadata)
            .foregroundColor(PACETheme.textOnAccent)
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(PACETheme.accent)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var logHistorySection: some View {
        if !goalLogs.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("RECORDED CONTRIBUTIONS · \(goalLogs.count)")
                    .font(PACETextStyle.pixelLabel)
                    .foregroundColor(PACETheme.secondaryText)
                    .tracking(1.5)
                ForEach(goalLogs) { log in
                    if log.authorId == currentUserId && goal.status == .active {
                        Button {
                            logDate = log.date
                            showLogSheet = true
                        } label: {
                            logRow(log)
                        }
                        .buttonStyle(.plain)
                    } else {
                        logRow(log)
                    }
                }
            }
        }
    }

    private func logRow(_ log: DailyLog) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("\(log.formattedDisplayDate.uppercased()) · \(displayName(log.authorId))")
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
            if let note = log.note {
                Text(note)
                    .font(PACETextStyle.body)
                    .foregroundColor(PACETheme.secondaryText)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PACETheme.surface)
        .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
    }

    private var collaborationControls: some View {
        VStack(spacing: 10) {
            if isOwner {
                actionButton("EDIT SHARED GOAL") { showEditSheet = true }
            }
            actionButton(isOwner ? "END COLLABORATION" : "LEAVE COLLABORATION") {
                showManageConfirmation = true
            }
            .foregroundColor(.red)
        }
        .padding(.top, 4)
    }

    private func metric(_ label: String, value: String, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(PACETextStyle.pixelMetadata)
                .foregroundColor(PACETheme.mutedText)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(PACETextStyle.displaySmall)
                    .foregroundColor(PACETheme.primaryText)
                if let unit {
                    Text(unit)
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(PACETheme.secondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(PACETheme.surface)
        .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(PACETextStyle.pixelMetadata)
                .foregroundColor(PACETheme.primaryText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func displayName(_ userId: String?) -> String {
        guard let userId else { return "PACE MEMBER" }
        if userId == currentUserId { return "YOU · \(profilesById[userId]?.username ?? "OWNER")" }
        if let profile = profilesById[userId] {
            return profile.displayName.isEmpty ? "@\(profile.username)" : profile.displayName
        }
        return "PACE MEMBER"
    }

    private func manageCollaboration() {
        guard !isManaging else { return }
        isManaging = true
        actionError = nil
        Task {
            defer { isManaging = false }
            do {
                try await sharedService.leaveOrEnd(goalId: goal.id)
                dismiss()
            } catch {
                actionError = error.localizedDescription
            }
        }
    }
}

private struct SharedGoalEditView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (SharedGoal) -> Void
    let goal: SharedGoal

    @State private var title: String
    @State private var deadline: Date
    @State private var activityInput: String
    @State private var selectedWeekdays: Set<Int>
    @State private var errorMessage: String?
    @State private var isSaving = false

    private let weekdayNames = [("SUN", 1), ("MON", 2), ("TUE", 3), ("WED", 4), ("THU", 5), ("FRI", 6), ("SAT", 7)]

    init(goal: SharedGoal, onSave: @escaping (SharedGoal) -> Void) {
        self.goal = goal
        self.onSave = onSave
        _title = State(initialValue: goal.title)
        _deadline = State(initialValue: goal.targetDateForDisplay)
        _activityInput = State(initialValue: goal.activityTypes.joined(separator: ", "))
        _selectedWeekdays = State(initialValue: Set(goal.scheduledWeekdays))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    field("GOAL TITLE") {
                        TextField("GOAL TITLE", text: $title)
                    }
                    field("ACTIVITIES · COMMA SEPARATED") {
                        TextField("ACTIVITIES", text: $activityInput)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TARGET DEADLINE")
                            .font(PACETextStyle.pixelLabel)
                            .foregroundColor(PACETheme.secondaryText)
                        DatePicker("TARGET DATE", selection: $deadline, in: Date()..., displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .tint(PACETheme.accent)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SCHEDULE")
                            .font(PACETextStyle.pixelLabel)
                            .foregroundColor(PACETheme.secondaryText)
                        HStack(spacing: 6) {
                            ForEach(weekdayNames, id: \.1) { day in
                                Button(day.0) {
                                    if selectedWeekdays.contains(day.1) {
                                        selectedWeekdays.remove(day.1)
                                    } else {
                                        selectedWeekdays.insert(day.1)
                                    }
                                }
                                .font(PACETextStyle.pixelMetadata)
                                .foregroundColor(selectedWeekdays.contains(day.1) ? PACETheme.textOnAccent : PACETheme.secondaryText)
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .background(selectedWeekdays.contains(day.1) ? PACETheme.accent : PACETheme.surface)
                                .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
                            }
                        }
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(PACETextStyle.pixelMetadata)
                            .foregroundColor(.red)
                    }
                    Button(isSaving ? "SAVING…" : "SAVE SHARED GOAL") { save() }
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(PACETheme.textOnAccent)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(PACETheme.accent)
                        .disabled(isSaving)
                }
                .padding(20)
            }
            .background(PACETheme.background.ignoresSafeArea())
            .navigationTitle("EDIT GOAL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("CANCEL") { dismiss() }
                        .foregroundColor(PACETheme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func field<Field: View>(_ label: String, @ViewBuilder content: () -> Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(PACETextStyle.pixelLabel)
                .foregroundColor(PACETheme.secondaryText)
            content()
                .font(PACETextStyle.body)
                .foregroundColor(PACETheme.primaryText)
                .padding(10)
                .background(Color.black)
                .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
        }
    }

    private func save() {
        let activities = activityInput.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !activities.isEmpty,
              !selectedWeekdays.isEmpty else {
            errorMessage = "Add a title, one or more activities, and at least one scheduled day."
            return
        }
        isSaving = true
        errorMessage = nil
        var updated = goal
        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.targetDate = deadline
        updated.targetDateString = DailyLog.dateFormatter.string(from: Calendar.current.startOfDay(for: deadline))
        updated.activityTypes = activities
        updated.scheduledWeekdays = selectedWeekdays.sorted()
        Task {
            defer { isSaving = false }
            do {
                try await SharedGoalService.shared.updateGoal(updated)
                onSave(updated)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
