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
    
    @State private var showCreateGoalSheet = false
    @State private var selectedGoalForDetail: PACEGoal? = nil
    @State private var selectedGoalForLog: PACEGoal? = nil
    @State private var selectedGoalForJourney: PACEGoal? = nil
    @State private var navigateToDetail = false
    @State private var navigateToJourney = false
    @ScaledMetric(relativeTo: .largeTitle) private var countdownFontSize: CGFloat = 64
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Header: GOALS ... + NEW GOAL
                    headerSection
                    
                    if goalService.goals.isEmpty {
                        emptyStateView
                    } else {
                        // Primary Goal Section
                        if let primaryGoal = goalService.goals.first {
                            primaryGoalSection(primaryGoal)
                        }
                        
                        // Secondary Goals Section
                        if goalService.goals.count > 1 {
                            secondaryGoalsSection
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .background(PACETheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .task {
                await goalService.fetchActiveGoals()
                for g in goalService.goals {
                    _ = await logService.fetchLogs(for: g.id)
                }
                PACEWidgetSyncService.shared.syncPrimaryGoal(goals: goalService.goals, logsByGoal: logService.logsByGoal)
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
                            PACEWidgetSyncService.shared.syncPrimaryGoal(goals: goalService.goals, logsByGoal: logService.logsByGoal)
                        }
                    }
                )
            }
            .sheet(item: $selectedGoalForLog) { goal in
                LogProgressView(goal: goal) {
                    Task {
                        _ = await logService.fetchLogs(for: goal.id)
                        PACEWidgetSyncService.shared.syncPrimaryGoal(goals: goalService.goals, logsByGoal: logService.logsByGoal)
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
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(alignment: .center, spacing: 12) {
            PACEBrandMark(logoSize: 30)
            
            Spacer(minLength: 8)
            
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
            
            // Metrics Directly in Layout (NO CARDS)
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CURRENT STREAK")
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(PACETheme.secondaryText)
                        .tracking(1.0)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(PACETheme.accent)
                            .accessibilityHidden(true)
                        Text(String(format: "%02d", metrics.currentStreak))
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundColor(PACETheme.primaryText)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Current streak, \(metrics.currentStreak) days")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Rectangle()
                    .fill(PACETheme.border)
                    .frame(width: 1, height: 36)
                    .padding(.horizontal, 10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("CONSISTENCY")
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(PACETheme.secondaryText)
                        .tracking(1.0)
                    Text(String(format: "%.0f%%", metrics.consistencyPercentage))
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundColor(PACETheme.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Rectangle()
                    .fill(PACETheme.border)
                    .frame(width: 1, height: 36)
                    .padding(.horizontal, 10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("ACTIVE DAYS")
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(PACETheme.secondaryText)
                        .tracking(1.0)
                    Text(String(format: "%02d", metrics.activeDays))
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundColor(PACETheme.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
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
    
    // MARK: - Secondary Goals Section
    
    private var secondaryGoalsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SECONDARY TARGETS")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(PACETheme.secondaryText)
                .tracking(2.0)
                .padding(.bottom, 12)
            
            ForEach(goalService.goals.dropFirst()) { goal in
                let logs = logService.logsByGoal[goal.id] ?? []
                let metrics = GoalAnalytics.compute(goal: goal, logs: logs)
                
                Button(action: {
                    selectedGoalForDetail = goal
                    navigateToDetail = true
                }) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(goal.title.uppercased())
                                .font(.system(size: 15, weight: .bold, design: .default))
                                .foregroundColor(PACETheme.primaryText)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(PACETheme.secondaryText)
                        }
                        
                        Text(String(format: "%02d DAYS — STREAK %02d", metrics.daysRemaining, metrics.currentStreak))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(PACETheme.secondaryText)
                            .tracking(1.0)
                    }
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                
                Rectangle()
                    .fill(PACETheme.border)
                    .frame(height: 1)
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
