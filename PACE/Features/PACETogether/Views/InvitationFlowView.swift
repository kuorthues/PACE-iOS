import SwiftUI

struct InvitationFlowView: View {
    private enum GoalChoice: String, CaseIterable {
        case new = "NEW GOAL"
        case existing = "EXISTING GOAL"
    }

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var goalService = GoalService.shared

    let profile: PublicProfile

    @State private var draftSharedGoalId = UUID().uuidString
    @State private var invitationWasAccepted = false
    @State private var choice: GoalChoice = .new
    @State private var selectedGoalId: String?
    @State private var title = ""
    @State private var targetDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var activityInput = "Study, Practice"
    @State private var useWeekdays = false
    @State private var hasConfirmedHistorySharing = false
    @State private var isConfirmingSend = false
    @State private var isSending = false
    @State private var didSend = false
    @State private var errorMessage: String?

    private var selectedGoal: PACEGoal? {
        goalService.goals.first { $0.id == selectedGoalId && $0.status == .active }
    }

    private var currentTitle: String {
        choice == .existing ? (selectedGoal?.title ?? "") : title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var currentDeadline: Date {
        choice == .existing ? (selectedGoal?.targetDate ?? targetDate) : targetDate
    }

    private var parsedActivities: [String] {
        activityInput
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var canSend: Bool {
        guard !isSending else { return false }
        if choice == .existing {
            return selectedGoal != nil && hasConfirmedHistorySharing
        }
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !parsedActivities.isEmpty
            && Calendar.current.startOfDay(for: targetDate) > Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("INVITE A PARTNER")
                        .font(PACETextStyle.displayLarge)
                        .foregroundColor(PACETheme.primaryText)

                    recipientPanel
                    choicePicker

                    if choice == .existing {
                        existingGoalPicker
                        historyConsent
                    } else {
                        newGoalFields
                    }

                    confirmationSummary

                    if let errorMessage {
                        Text(errorMessage)
                            .font(PACETextStyle.pixelMetadata)
                            .foregroundColor(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if didSend {
                        Text(invitationWasAccepted
                             ? "INVITATION ACCEPTED. SHARED GOAL IS ACTIVE."
                             : "INVITATION SENT. YOUR PARTNER GAINS ACCESS ONLY AFTER ACCEPTING.")
                            .font(PACETextStyle.pixelMetadata)
                            .foregroundColor(PACETheme.accent)
                            .fixedSize(horizontal: false, vertical: true)
                        actionButton(title: "DONE", enabled: true) { dismiss() }
                    } else {
                        actionButton(title: isSending ? "SENDING…" : "REVIEW INVITATION", enabled: canSend) {
                            isConfirmingSend = true
                        }
                    }
                }
                .padding(20)
            }
            .background(PACETheme.background.ignoresSafeArea())
            .navigationTitle("PACE TOGETHER")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("CLOSE") { dismiss() }
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(PACETheme.accent)
                }
            }
            .task {
                await goalService.fetchActiveGoals()
            }
            .confirmationDialog(
                "Send this goal invitation?",
                isPresented: $isConfirmingSend,
                titleVisibility: .visible
            ) {
                Button("SEND TO @\(profile.username.uppercased())") {
                    sendInvitation()
                }
                Button("CANCEL", role: .cancel) {}
            } message: {
                Text("\(currentTitle) · TARGET \(currentDeadline.formatted(date: .abbreviated, time: .omitted)). \(choice == .existing ? "A private copy of your past progress is prepared; your partner sees it only after acceptance. The original personal goal is archived only after acceptance." : "The goal stays private until your partner accepts.")")
            }
        }
        .preferredColorScheme(.dark)
    }

    private var recipientPanel: some View {
        HStack(spacing: 12) {
            PACEProfileAvatar(profile: profile, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text("INVITING")
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACETheme.secondaryText)
                Text("@\(profile.username)")
                    .font(PACETextStyle.displaySmall)
                    .foregroundColor(PACETheme.accent)
            }
            Spacer()
        }
        .padding(12)
        .background(PACETheme.surface)
        .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
    }

    private var choicePicker: some View {
        HStack(spacing: 0) {
            ForEach(GoalChoice.allCases, id: \.self) { option in
                Button {
                    choice = option
                    errorMessage = nil
                } label: {
                    Text(option.rawValue)
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(choice == option ? PACETheme.textOnAccent : PACETheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(choice == option ? PACETheme.accent : PACETheme.surface)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
    }

    private var existingGoalPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SELECT AN ACTIVE SOLO GOAL")
                .font(PACETextStyle.pixelLabel)
                .foregroundColor(PACETheme.secondaryText)
            if goalService.goals.isEmpty {
                Text("NO ACTIVE SOLO GOALS. CREATE A NEW SHARED GOAL INSTEAD.")
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACETheme.mutedText)
            } else {
                ForEach(goalService.goals.filter { $0.status == .active }) { goal in
                    Button {
                        selectedGoalId = goal.id
                        hasConfirmedHistorySharing = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(goal.title.uppercased())
                                    .font(PACETextStyle.displaySmall)
                                    .foregroundColor(PACETheme.primaryText)
                                Text("TARGET \(goal.formattedTargetDate.uppercased()) · \(goal.scheduleDescription)")
                                    .font(PACETextStyle.pixelMetadata)
                                    .foregroundColor(PACETheme.secondaryText)
                            }
                            Spacer()
                            Image(systemName: selectedGoalId == goal.id ? "checkmark.square.fill" : "square")
                                .foregroundColor(selectedGoalId == goal.id ? PACETheme.accent : PACETheme.secondaryText)
                        }
                        .padding(12)
                        .background(PACETheme.surface)
                        .overlay(Rectangle().stroke(selectedGoalId == goal.id ? PACETheme.accent : PACETheme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var historyConsent: some View {
        Button {
            hasConfirmedHistorySharing.toggle()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: hasConfirmedHistorySharing ? "checkmark.square.fill" : "square")
                    .foregroundColor(hasConfirmedHistorySharing ? PACETheme.accent : PACETheme.secondaryText)
                VStack(alignment: .leading, spacing: 5) {
                    Text("SHARE PAST PROGRESS AFTER ACCEPTANCE")
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(PACETheme.primaryText)
                    Text("Your logs, notes, and evidence references are copied into an owner-only pending goal. The recipient can read them only after accepting. After acceptance, your original personal goal is archived; its private records and local photos stay unchanged. Local photos are not sent to the other device.")
                        .font(PACETextStyle.body)
                        .foregroundColor(PACETheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(PACETheme.surface)
            .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(selectedGoal == nil)
    }

    private var newGoalFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            labeledField("GOAL TITLE") {
                TextField("WHAT ARE YOU WORKING TOWARD?", text: $title)
                    .textInputAutocapitalization(.words)
            }
            labeledField("ACTIVITIES · COMMA SEPARATED") {
                TextField("STUDY, PRACTICE", text: $activityInput)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("TARGET DEADLINE")
                    .font(PACETextStyle.pixelLabel)
                    .foregroundColor(PACETheme.secondaryText)
                DatePicker("TARGET DATE", selection: $targetDate, in: Date()..., displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(PACETheme.accent)
                    .colorScheme(.dark)
            }
            Button {
                useWeekdays.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: useWeekdays ? "checkmark.square.fill" : "square")
                        .foregroundColor(PACETheme.accent)
                    Text(useWeekdays ? "WEEKDAYS · MON–FRI" : "EVERY DAY")
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(PACETheme.primaryText)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(PACETheme.surface)
        .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
    }

    private var confirmationSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PROPOSED GOAL")
                .font(PACETextStyle.pixelLabel)
                .foregroundColor(PACETheme.secondaryText)
            Text(currentTitle.isEmpty ? "GOAL TITLE" : currentTitle.uppercased())
                .font(PACETextStyle.displaySmall)
                .foregroundColor(PACETheme.primaryText)
            Text("TARGET \(currentDeadline.formatted(date: .abbreviated, time: .omitted).uppercased())")
                .font(PACETextStyle.pixelMetadata)
                .foregroundColor(PACETheme.accent)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PACETheme.surface)
        .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
    }

    private func labeledField<Field: View>(_ title: String, @ViewBuilder content: () -> Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
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

    private func actionButton(title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(PACETextStyle.pixelMetadata)
                .foregroundColor(PACETheme.textOnAccent)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(enabled ? PACETheme.accent : PACETheme.border)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func sendInvitation() {
        guard canSend else { return }
        isSending = true
        errorMessage = nil
        let source = choice == .existing ? selectedGoal : nil
        let chosenTitle = choice == .existing ? (source?.title ?? "") : title
        let chosenDeadline = choice == .existing ? (source?.targetDate ?? targetDate) : targetDate
        let activities = source?.activityTypes ?? parsedActivities
        let schedule = source?.scheduledWeekdays ?? (useWeekdays ? [2, 3, 4, 5, 6] : [1, 2, 3, 4, 5, 6, 7])
        Task {
            defer { isSending = false }
            do {
                let invitation = try await SharedGoalService.shared.createAndInvite(
                    profile: profile,
                    title: chosenTitle,
                    targetDate: chosenDeadline,
                    activityTypes: activities,
                    scheduledWeekdays: schedule,
                    sourceGoal: source,
                    draftSharedGoalId: draftSharedGoalId
                )
                invitationWasAccepted = invitation.status == .accepted
                didSend = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
