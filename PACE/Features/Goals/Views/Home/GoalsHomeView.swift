//
//  GoalsHomeView.swift
//  PACE
//
//  Goals Home screen matching Figma prototype:
//  - Header: GOALS ... + NEW GOAL
//  - Primary goal:
//    - Title
//    - Huge #A7FF19 days remaining (43 / DAYS REMAINING)
//    - TODAY NOT LOGGED indicator
//    - Primary CTA: LOG TODAY →
//    - Metrics directly in layout: CURRENT STREAK / CONSISTENCY / ACTIVE DAYS (no cards)
//    - CURRENT JOURNEY ... VIEW → with embedded Journey timeline
//  - Secondary goals: plain rows separated by thin lines (e.g. SPANISH FINAL / 19 DAYS — STREAK 04)
//  - All zero-radius, pure black canvas, #A7FF19 single accent
//

import SwiftUI

struct GoalsHomeView: View {
    @ObservedObject var goalService = GoalService.shared
    @ObservedObject var logService = DailyLogService.shared
    @ObservedObject var evidenceService = EvidenceService.shared
    @ObservedObject var profileService = PublicProfileService.shared
    @ObservedObject var sharedGoalService = SharedGoalService.shared
    @ObservedObject var invitationService = GoalInvitationService.shared
    @ObservedObject private var notificationService = NotificationCenterService.shared
    @ObservedObject private var authService = AuthService.shared
    
    @State private var showCreateGoalSheet = false
    @State private var selectedGoalForDetail: PACEGoal? = nil
    @State private var selectedGoalForLog: PACEGoal? = nil
    @State private var selectedGoalForJourney: PACEGoal? = nil
    @State private var selectedPartnerProfile: PublicProfile? = nil
    @State private var selectedProfileForInvite: PublicProfile? = nil
    @State private var selectedSharedGoal: SharedGoal? = nil
    @State private var activePartnerProfiles: [String: PublicProfile] = [:]
    @State private var navigateToDetail = false
    @State private var navigateToJourney = false
    @State private var showPartnerDiscovery = false
    @State private var navigateToSharedGoal = false
    @State private var showInvitationManagement = false
    @State private var showNotificationCenter = false
    @ScaledMetric(relativeTo: .largeTitle) private var countdownFontSize: CGFloat = 64
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Header: GOALS ... + NEW GOAL
                    headerSection
                    
                    if visibleSoloGoals.isEmpty && sharedGoalService.goals.isEmpty && sharedGoalService.errorMessage == nil {
                        emptyStateView
                    } else {
                        if let primaryGoal = visibleSoloGoals.first {
                            primaryGoalSection(primaryGoal)
                        }
                        if visibleSoloGoals.count > 1 {
                            secondaryGoalsSection
                        }
                        sharedGoalsSection
                    }
                    paceTogetherSection
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .background(PACETheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .task(id: authService.currentUser?.id) {
                let userId = AuthService.shared.currentUser?.id
                PACEWidgetSyncService.shared.markNeedsSync(for: userId)
                sharedGoalService.startListening(for: userId)
                invitationService.startListening(for: userId)
                notificationService.startListening(for: userId)
                await goalService.fetchActiveGoals()
                for goal in goalService.goals {
                    _ = await logService.fetchLogs(for: goal.id)
                }
                PACEWidgetSyncService.shared.requestSync()
                await profileService.fetchSuggestions(limit: 3)
            }
            .task(id: sharedGoalService.goals) {
                guard let userId = authService.currentUser?.id else {
                    activePartnerProfiles = [:]
                    return
                }
                let partnerIds = Set(sharedGoalService.goals.flatMap(\.memberIds).filter { $0 != userId })
                var profiles: [String: PublicProfile] = [:]
                for partnerId in partnerIds {
                    if let profile = await PublicProfileService.shared.fetchPublicProfile(userId: partnerId) {
                        profiles[partnerId] = profile
                    }
                }
                guard !Task.isCancelled, authService.currentUser?.id == userId else { return }
                activePartnerProfiles = profiles
            }
            .onChange(of: authService.currentUser?.id) { _, _ in
                showCreateGoalSheet = false
                selectedGoalForDetail = nil
                selectedGoalForLog = nil
                selectedGoalForJourney = nil
                selectedPartnerProfile = nil
                selectedProfileForInvite = nil
                selectedSharedGoal = nil
                navigateToDetail = false
                navigateToJourney = false
                showPartnerDiscovery = false
                navigateToSharedGoal = false
                showInvitationManagement = false
                showNotificationCenter = false
                activePartnerProfiles = [:]
            }
            .sheet(isPresented: $showCreateGoalSheet) {
                CreateGoalFlowView(
                    onLogFirstDay: { goal in
                        selectedGoalForDetail = goal
                        navigateToDetail = true
                    },
                    onFinish: {
                        Task {
                            await goalService.fetchActiveGoals()
                            PACEWidgetSyncService.shared.requestSync()
                        }
                    }
                )
            }
            .sheet(item: $selectedGoalForLog) { goal in
                LogProgressView(goal: goal) {
                    Task {
                        _ = await logService.fetchLogs(for: goal.id)
                        PACEWidgetSyncService.shared.requestSync()
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToDetail) {
                if let goal = selectedGoalForDetail {
                    GoalDetailView(goal: goal)
                }
            }
            .navigationDestination(isPresented: $navigateToJourney) {
                if let goal = selectedGoalForJourney {
                    JourneyDetailView(goal: goal)
                }
            }
            .navigationDestination(isPresented: $navigateToSharedGoal) {
                if let goal = selectedSharedGoal {
                    SharedGoalDetailView(goal: goal)
                }
            }
            .navigationDestination(isPresented: $showInvitationManagement) {
                InvitationManagementView()
            }
            .navigationDestination(isPresented: $showNotificationCenter) {
                NotificationCenterView(service: notificationService)
            }
            .navigationDestination(isPresented: $showPartnerDiscovery) {
                PartnerDiscoveryView()
            }
            .sheet(item: $selectedPartnerProfile) { profile in
                PublicProfileDetailView(profile: profile)
            }
            .sheet(item: $selectedProfileForInvite) { profile in
                InvitationFlowView(profile: profile)
            }
        }
    }

    private var visibleSoloGoals: [PACEGoal] {
        goalService.goals.filter { !sharedGoalService.sourceGoalIdsInProgress.contains($0.id) }
    }
    private var activePartnerIds: [String] {
        guard let userId = authService.currentUser?.id else { return [] }
        return Array(Set(sharedGoalService.goals.flatMap(\.memberIds).filter { $0 != userId })).sorted()
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(alignment: .center, spacing: 12) {
            PACEBrandMark(logoSize: 30)
            
            Spacer(minLength: 8)

            Button(action: {
                showNotificationCenter = true
            }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(PACETheme.primaryText)
                        .frame(width: 36, height: 36)
                        .background(PACETheme.surface)
                        .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))

                    if notificationService.unreadCount > 0 {
                        Circle()
                            .fill(PACETheme.accent)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(PACETheme.background, lineWidth: 1.5))
                            .offset(x: -3, y: 3)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(notificationService.unreadCount > 0
                ? "Notifications, \(notificationService.unreadCount) unread"
                : "Notifications")
            .accessibilityHint("Opens the in-app notification center")
            
            Button(action: {
                showCreateGoalSheet = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .black))
                    Text("NEW GOAL")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                }
                .foregroundColor(PACETheme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(PACETheme.surface)
                .overlay(Rectangle().stroke(PACETheme.accent, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Create new goal")
        }
    }

    private func weeklyActivitySnapshot(for goal: PACEGoal, logs: [DailyLog]) -> some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dates = (0..<7).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }
        let loggedDates = Set(logs.map(\.dateString))

        return VStack(alignment: .leading, spacing: 6) {
            Text("THIS WEEK")
                .font(PACETextStyle.pixelMetadata)
                .foregroundColor(PACETheme.secondaryText)
                .tracking(1.0)

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(dates, id: \.self) { date in
                    let dateString = DailyLog.dateFormatter.string(from: date)
                    let isLogged = loggedDates.contains(dateString)
                    let isScheduled = goal.scheduledWeekdays.contains(calendar.component(.weekday, from: date))
                    VStack(spacing: 3) {
                        Rectangle()
                            .fill(isLogged ? PACETheme.accent : (isScheduled ? PACETheme.border : PACETheme.surfaceElevated))
                            .frame(width: 7, height: isLogged ? 24 : (isScheduled ? 14 : 7))
                        Text(date.formatted(.dateTime.weekday(.narrow)))
                            .font(PACETextStyle.pixelMetadata)
                            .foregroundColor(calendar.isDateInToday(date) ? PACETheme.accent : PACETheme.mutedText)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(date.formatted(date: .complete, time: .omitted)), \(isLogged ? "logged" : (isScheduled ? "scheduled and pending" : "rest day"))")
                }
            }
            .frame(width: 104, height: 42, alignment: .bottom)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Seven day activity snapshot")
    }
    
    // MARK: - Primary Goal Section
    
    private func primaryGoalSection(_ goal: PACEGoal) -> some View {
        let logs = logService.logsByGoal[goal.id] ?? []
        let metrics = GoalAnalytics.compute(goal: goal, logs: logs)
        let hasLoggedToday = logs.contains(where: { $0.dateString == DailyLog.dateFormatter.string(from: Date()) })
        let isScheduledToday = goal.isScheduledForToday
        let deadline = deadlinePresentation(for: goal)
        let todayStatus = hasLoggedToday ? "TODAY LOGGED" : (isScheduledToday ? "TODAY PENDING" : "TODAY · REST DAY")
        let evidenceList = evidenceService.evidenceByGoal[goal.id] ?? []
        let days = JourneyTimelineBuilder.buildTimeline(goal: goal, logs: logs, evidenceItems: evidenceList)
        
        return VStack(alignment: .leading, spacing: 20) {
            // Goal Title
            Button(action: {
                selectedGoalForDetail = goal
                navigateToDetail = true
            }) {
                HStack {
                    Text(goal.title.uppercased())
                        .font(PACETextStyle.displayMedium)
                        .foregroundColor(PACETheme.primaryText)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(PACETheme.secondaryText)
                }
            }
            .buttonStyle(.plain)
            
            // Deadline state and real seven-day activity snapshot.
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(deadline.value)
                        .font(.system(size: countdownFontSize, weight: .black, design: .monospaced))
                        .foregroundColor(PACETheme.accent)
                        .tracking(1.0)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityLabel(deadline.spokenValue)

                    Text(deadline.label)
                        .font(PACETextStyle.pixelLabel)
                        .foregroundColor(PACETheme.secondaryText)
                        .tracking(1.5)

                    Text("TARGET: \(goal.formattedTargetDate.uppercased())")
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(PACETheme.secondaryText)
                        .tracking(0.5)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                weeklyActivitySnapshot(for: goal, logs: logs)
            }
            
            // Contextual status and action for today.
            HStack(spacing: 8) {
                Rectangle()
                    .fill(hasLoggedToday ? PACETheme.accent : (isScheduledToday ? PACETheme.border : PACETheme.mutedText))
                    .frame(width: 8, height: 8)
                
                Text(todayStatus)
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(hasLoggedToday ? PACETheme.accent : (isScheduledToday ? PACETheme.secondaryText : PACETheme.mutedText))
                    .tracking(1.0)
            }
            .accessibilityElement(children: .combine)
            
            PACEButton(
                title: hasLoggedToday ? "EDIT TODAY'S LOG →" : (isScheduledToday ? "LOG TODAY'S PROGRESS →" : "LOG OPTIONAL SESSION →"),
                variant: hasLoggedToday ? .secondary : .primary
            ) {
                selectedGoalForLog = goal
            }
            
            // Compact statistics strip with aligned icon, label, and value columns.
            HStack(alignment: .top, spacing: 0) {
                dashboardMetric(
                    icon: "flame.fill",
                    label: "CURRENT STREAK",
                    value: String(format: "%02d", metrics.currentStreak),
                    accessibilityValue: "\(metrics.currentStreak) days",
                    isAccent: metrics.currentStreak > 0
                )
                
                Rectangle()
                    .fill(PACETheme.border)
                    .frame(width: 1, height: 54)
                    .padding(.horizontal, 8)
                
                dashboardMetric(
                    icon: "chart.bar.fill",
                    label: "CONSISTENCY",
                    value: String(format: "%.0f%%", metrics.consistencyPercentage),
                    accessibilityValue: "\(Int(metrics.consistencyPercentage.rounded())) percent",
                    isAccent: true
                )
                
                Rectangle()
                    .fill(PACETheme.border)
                    .frame(width: 1, height: 54)
                    .padding(.horizontal, 8)
                
                dashboardMetric(
                    icon: "calendar.badge.checkmark",
                    label: "ACTIVE DAYS",
                    value: String(format: "%02d", metrics.activeDays),
                    accessibilityValue: "\(metrics.activeDays) days",
                    isAccent: false
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            
            // Thin divider
            Rectangle()
                .fill(PACETheme.border)
                .frame(height: 1)
            
            CompactJourneyPreview(goal: goal, days: days) {
                selectedGoalForJourney = goal
                navigateToJourney = true
            }
            
            // Thin divider separating from secondary goals
            Rectangle()
                .fill(PACETheme.border)
                .frame(height: 1)
        }
    }

    private func dashboardMetric(
        icon: String,
        label: String,
        value: String,
        accessibilityValue: String,
        isAccent: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isAccent ? PACETheme.accent : PACETheme.secondaryText)
                    .accessibilityHidden(true)
                Text(label)
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACETheme.secondaryText)
                    .tracking(0.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Text(value)
                .font(PACETextStyle.metricMedium)
                .foregroundColor(isAccent ? PACETheme.accent : PACETheme.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(accessibilityValue)")
    }
    
    // MARK: - Secondary Goals Section
    
    private var secondaryGoalsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SECONDARY TARGETS")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(PACETheme.secondaryText)
                .tracking(2.0)
                .padding(.bottom, 12)
            
            ForEach(visibleSoloGoals.dropFirst()) { goal in
                let logs = logService.logsByGoal[goal.id] ?? []
                let metrics = GoalAnalytics.compute(goal: goal, logs: logs)
                
                Button(action: {
                    selectedGoalForDetail = goal
                    navigateToDetail = true
                }) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(goal.title.uppercased())
                                .font(PACETextStyle.displaySmall)
                                .foregroundColor(PACETheme.primaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            
                            Spacer(minLength: 4)
                            
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(PACETheme.accent)
                                .accessibilityHidden(true)
                        }
                        
                        HStack(spacing: 8) {
                            Image(systemName: "target")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(PACETheme.secondaryText)
                                .accessibilityHidden(true)
                            Text(String(format: "%02d DAYS", metrics.daysRemaining))
                            Text("·")
                            Text(String(format: "STREAK %02d", metrics.currentStreak))
                        }
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(PACETheme.secondaryText)
                        .tracking(0.8)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PACETheme.surface)
                    .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                
                Rectangle()
                    .fill(PACETheme.border)
                    .frame(height: 1)
            }
        }
    }

    private var sharedGoalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let error = sharedGoalService.errorMessage {
                Text(error)
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !sharedGoalService.goals.isEmpty {
                Text("SHARED TARGETS")
                    .font(PACETextStyle.pixelLabel)
                    .foregroundColor(PACETheme.secondaryText)
                    .tracking(1.5)
                ForEach(sharedGoalService.goals) { goal in
                    SharedGoalCard(goal: goal) {
                        selectedSharedGoal = goal
                        navigateToSharedGoal = true
                    }
                }
            }
        }
    }

    // MARK: - PACE Together

    private var paceTogetherSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("PACE TOGETHER")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(PACETheme.secondaryText)
                    .tracking(2.0)
                Spacer()
                Button("INVITATIONS \(invitationService.invitations.filter { $0.status == .pending }.count)") {
                    showInvitationManagement = true
                }
                .font(PACETextStyle.pixelMetadata)
                .foregroundColor(PACETheme.primaryText)
                .buttonStyle(.plain)
                Button("FIND PARTNERS") {
                    showPartnerDiscovery = true
                }
                .font(PACETextStyle.pixelMetadata)
                .foregroundColor(PACETheme.accent)
                .buttonStyle(.plain)
                .accessibilityHint("Opens username search for discoverable PACE profiles")
            }
            if !activePartnerIds.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ACTIVE PARTNERS")
                        .font(PACETextStyle.pixelLabel)
                        .foregroundColor(PACETheme.secondaryText)
                    ForEach(activePartnerIds, id: \.self) { partnerId in
                        let sharedCount = sharedGoalService.goals.filter { $0.memberIds.contains(partnerId) }.count
                        Button {
                            if let profile = activePartnerProfiles[partnerId] {
                                selectedPartnerProfile = profile
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "person.2.fill")
                                    .foregroundColor(PACETheme.accent)
                                Text(activePartnerProfiles[partnerId].map {
                                    $0.displayName.isEmpty ? "@\($0.username)" : $0.displayName
                                } ?? "PACE MEMBER")
                                    .font(PACETextStyle.displaySmall)
                                    .foregroundColor(PACETheme.primaryText)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(sharedCount) SHARED")
                                    .font(PACETextStyle.pixelMetadata)
                                    .foregroundColor(PACETheme.secondaryText)
                            }
                            .padding(10)
                            .background(PACETheme.surface)
                            .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(activePartnerProfiles[partnerId] == nil)
                    }
                }
            }


            if profileService.isLoading && profileService.suggestions.isEmpty {
                ProgressView()
                    .tint(PACETheme.accent)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .accessibilityLabel("Loading PACE Together profiles")
            } else if profileService.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(profileService.errorMessage ?? "NO DISCOVERABLE PROFILES YET.")
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(profileService.errorMessage == nil ? PACETheme.secondaryText : .red)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("CREATE A PROFILE IN SETTINGS TO CONTROL YOUR VISIBILITY.")
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(PACETheme.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PACETheme.surface)
                .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
            } else {
                ForEach(profileService.suggestions.prefix(3)) { profile in
                    PACEProfileCard(
                        profile: profile,
                        onViewProfile: { selectedPartnerProfile = profile },
                        onInvite: { selectedProfileForInvite = profile }
                    )
                }
            }
        }
    }

    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("NO ACTIVE TARGETS")
                .font(PACETextStyle.displayMedium)
                .foregroundColor(PACETheme.primaryText)
            
            Text("Lock in a date. Show up consistently.\nKeep the proof.")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(PACETheme.secondaryText)
                .lineSpacing(3)
            
            PACEButton(
                title: "CREATE YOUR FIRST GOAL →",
                variant: .primary
            ) {
                showCreateGoalSheet = true
            }
            .padding(.top, 12)
        }
        .padding(24)
        .background(PACETheme.surface)
        .overlay(
            Rectangle().stroke(PACETheme.border, lineWidth: 1)
        )
        .padding(.top, 20)
    }
}

private func deadlinePresentation(for goal: PACEGoal) -> GoalDeadlinePresentation {
    if goal.status == .completed {
        return GoalDeadlinePresentation(value: "DONE", label: "GOAL COMPLETED", spokenValue: "Goal completed")
    }
    if goal.status == .archived {
        return GoalDeadlinePresentation(value: "—", label: "GOAL ARCHIVED", spokenValue: "Goal archived")
    }
    
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let target = calendar.startOfDay(for: goal.targetDate)
    let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0
    
    if days > 0 {
        return GoalDeadlinePresentation(
            value: String(format: "%02d", days),
            label: days == 1 ? "DAY LEFT" : "DAYS LEFT",
            spokenValue: "\(days) days left"
        )
    }
    if days < 0 {
        let overdueDays = abs(days)
        return GoalDeadlinePresentation(
            value: String(format: "%02d", overdueDays),
            label: overdueDays == 1 ? "DAY OVERDUE" : "DAYS OVERDUE",
            spokenValue: "\(overdueDays) days overdue"
        )
    }
    return GoalDeadlinePresentation(value: "00", label: "DUE TODAY", spokenValue: "Due today")
}

private struct GoalDeadlinePresentation {
    let value: String
    let label: String
    let spokenValue: String
}
