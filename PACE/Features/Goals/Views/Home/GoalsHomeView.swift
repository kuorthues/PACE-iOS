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
    @State private var selectedJourneyDay: JourneyDay? = nil
    
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
        HStack(alignment: .center) {
            Text("GOALS")
                .font(PACETextStyle.displayLarge)
                .foregroundColor(PACETheme.primaryText)
            
            Spacer()
            
            Button(action: {
                showCreateGoalSheet = true
            }) {
                Text("+ NEW GOAL")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(PACETheme.accent)
                    .tracking(1.5)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(PACETheme.surface)
                    .overlay(
                        Rectangle().stroke(PACETheme.accent, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Primary Goal Section
    
    private func primaryGoalSection(_ goal: PACEGoal) -> some View {
        let logs = logService.logsByGoal[goal.id] ?? []
        let metrics = GoalAnalytics.compute(goal: goal, logs: logs)
        let hasLoggedToday = logs.contains(where: { $0.dateString == DailyLog.dateFormatter.string(from: Date()) })
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
            
            // Huge #A7FF19 Days Remaining
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%02d", metrics.daysRemaining))
                    .font(.system(size: 64, weight: .black, design: .monospaced))
                    .foregroundColor(PACETheme.accent)
                    .tracking(1.0)
                
                Text("DAYS REMAINING")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(PACETheme.secondaryText)
                    .tracking(2.0)
            }
            
            // Today Status
            HStack(spacing: 8) {
                Rectangle()
                    .fill(hasLoggedToday ? PACETheme.accent : PACETheme.border)
                    .frame(width: 8, height: 8)
                
                Text(hasLoggedToday ? "TODAY LOGGED" : "TODAY NOT LOGGED")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(hasLoggedToday ? PACETheme.accent : PACETheme.secondaryText)
                    .tracking(1.5)
            }
            
            // Primary CTA
            PACEButton(
                title: hasLoggedToday ? "EDIT TODAY'S LOG →" : "LOG TODAY →",
                variant: .primary
            ) {
                selectedGoalForLog = goal
            }
            
            // Metrics Directly in Layout (NO CARDS)
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CURRENT STREAK")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(PACETheme.secondaryText)
                        .tracking(1.0)
                    Text(String(format: "%02d", metrics.currentStreak))
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundColor(PACETheme.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Rectangle()
                    .fill(PACETheme.border)
                    .frame(width: 1, height: 36)
                    .padding(.horizontal, 10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("CONSISTENCY")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
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
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
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
            
            // Current Journey Preview Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("CURRENT JOURNEY")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(PACETheme.secondaryText)
                        .tracking(1.5)
                    
                    Spacer()
                    
                    Button(action: {
                        selectedGoalForJourney = goal
                        navigateToJourney = true
                    }) {
                        Text("VIEW →")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(PACETheme.accent)
                            .tracking(1.5)
                    }
                    .buttonStyle(.plain)
                }
                
                if !days.isEmpty {
                    JourneyTimelineView(
                        days: days,
                        selectedDay: $selectedJourneyDay,
                        isCompact: true
                    )
                    .frame(height: 80)
                    .background(PACETheme.surface)
                    .overlay(
                        Rectangle().stroke(PACETheme.border, lineWidth: 1)
                    )
                }
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
