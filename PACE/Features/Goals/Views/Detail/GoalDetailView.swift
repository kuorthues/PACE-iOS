//
//  GoalDetailView.swift
//  PACE
//
//  Goal detail screen showing:
//  - Real-time GoalAnalytics metrics (streak, consistency, active days, time)
//  - Log Progress action and recent logs history
//  - Destinations: Journey, Activities, Evidence
//  - Edit Goal & Delete Goal with confirmation
//

import SwiftUI

struct GoalDetailView: View {
    @ObservedObject var goalService = GoalService.shared
    @ObservedObject var logService = DailyLogService.shared
    @ObservedObject var evidenceService = EvidenceService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State var goal: PACEGoal
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showLogSheet = false
    @State private var selectedLogForEdit: DailyLog? = nil
    
    @State private var navigateToJourney = false
    @State private var navigateToActivities = false
    @State private var navigateToEvidence = false
    
    private var goalLogs: [DailyLog] {
        logService.logsByGoal[goal.id] ?? []
    }
    
    private var metrics: GoalMetrics {
        GoalAnalytics.compute(goal: goal, logs: goalLogs)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Goal Title & Status Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("TARGET OBJECTIVE")
                            .font(PACETypography.caption())
                            .foregroundColor(PACEColor.textSecondary)
                        Spacer()
                        if goal.isScheduledForToday {
                            Text("SCHEDULED TODAY")
                                .font(PACETypography.metricSmall())
                                .foregroundColor(PACEColor.background)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(PACEColor.accent)
                        } else {
                            Text("REST DAY")
                                .font(PACETypography.metricSmall())
                                .foregroundColor(PACEColor.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(PACEColor.surfaceElevated)
                        }
                    }
                    
                    Text(goal.title.uppercased())
                        .font(PACETypography.titleLarge())
                        .foregroundColor(PACEColor.textPrimary)
                }
                .padding(.top, 8)
                
                PACEDivider()
                
                // Countdown & Target Date
                HStack(spacing: 12) {
                    PACEMetricView(
                        label: "Days Remaining",
                        value: String(format: "%02d", metrics.daysRemaining),
                        unit: "DAYS",
                        isAccentValue: true
                    )
                    
                    PACEMetricView(
                        label: "Target Date",
                        value: goal.formattedTargetDate,
                        unit: nil
                    )
                }
                
                // Real-time Velocity & Performance Metrics
                VStack(alignment: .leading, spacing: 12) {
                    Text("PERFORMANCE & STREAK")
                        .font(PACETypography.sectionHeader())
                        .foregroundColor(PACEColor.textPrimary)
                    
                    HStack(spacing: 12) {
                        PACEMetricView(
                            label: "Current Streak",
                            value: String(format: "%02d", metrics.currentStreak),
                            unit: "DAYS",
                            isAccentValue: metrics.currentStreak > 0
                        )
                        PACEMetricView(
                            label: "Longest Streak",
                            value: String(format: "%02d", metrics.longestStreak),
                            unit: "DAYS"
                        )
                    }
                    
                    HStack(spacing: 12) {
                        PACEMetricView(
                            label: "Consistency",
                            value: String(format: "%.0f", metrics.consistencyPercentage),
                            unit: "%"
                        )
                        PACEMetricView(
                            label: "Active Days",
                            value: String(format: "%02d", metrics.activeDays),
                            unit: "DAYS"
                        )
                    }
                    
                    HStack(spacing: 12) {
                        PACEMetricView(
                            label: "Total Invested",
                            value: "\(metrics.totalLoggedMinutes)",
                            unit: "MINUTES"
                        )
                        PACEMetricView(
                            label: "Avg Session",
                            value: String(format: "%.0f", metrics.averageSessionMinutes),
                            unit: "MIN"
                        )
                    }
                }
                .padding(16)
                .paceCard()
                
                // Compact Journey Timeline Preview
                JourneyPreviewSection(goal: goal, logs: goalLogs) {
                    navigateToJourney = true
                }
                
                // Log Progress Action
                VStack(alignment: .leading, spacing: 10) {
                    Text("PROGRESS LOGGING")
                        .font(PACETypography.sectionHeader())
                        .foregroundColor(PACEColor.textPrimary)
                    
                    PACEButton(
                        title: hasLoggedToday ? "EDIT TODAY'S LOG" : "LOG TODAY'S WORK",
                        icon: hasLoggedToday ? "pencil.square" : "plus.square",
                        variant: .primary
                    ) {
                        showLogSheet = true
                    }
                }
                
                // Recent Evidence Logs List
                if !goalLogs.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("RECORDED ENTRIES (\(goalLogs.count))")
                            .font(PACETypography.sectionHeader())
                            .foregroundColor(PACEColor.textPrimary)
                        
                        ForEach(goalLogs) { log in
                            Button(action: {
                                selectedLogForEdit = log
                            }) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 8) {
                                        Text(log.formattedDisplayDate.uppercased())
                                            .font(PACETypography.metricSmall())
                                            .foregroundColor(PACEColor.accent)
                                        
                                        if log.evidenceId != nil || evidenceService.fetchEvidence(forGoal: goal.id, logId: log.dateString) != nil {
                                            HStack(spacing: 3) {
                                                Image(systemName: "camera.fill")
                                                Text("PROOF")
                                            }
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(PACEColor.background)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(PACEColor.accent)
                                        }
                                        
                                        Spacer()
                                        Text(log.formattedDuration)
                                            .font(PACETypography.metricSmall())
                                            .foregroundColor(PACEColor.textPrimary)
                                    }
                                    
                                    Text(log.selectedActivities.joined(separator: " • ").uppercased())
                                        .font(PACETypography.caption())
                                        .foregroundColor(PACEColor.textSecondary)
                                    
                                    if let note = log.note {
                                        Text(note)
                                            .font(PACETypography.caption())
                                            .foregroundColor(PACEColor.textPrimary)
                                            .padding(.top, 2)
                                    }
                                }
                                .padding(12)
                                .paceCard()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                PACEDivider()
                
                // Quick Navigation Destinations
                VStack(alignment: .leading, spacing: 10) {
                    Text("VAULT DESTINATIONS")
                        .font(PACETypography.sectionHeader())
                        .foregroundColor(PACEColor.textPrimary)
                    
                    HStack(spacing: 10) {
                        PACEButton(
                            title: "JOURNEY",
                            icon: "figure.walk",
                            variant: .secondary
                        ) {
                            navigateToJourney = true
                        }
                        
                        PACEButton(
                            title: "EVIDENCE",
                            icon: "photo.stack",
                            variant: .secondary
                        ) {
                            navigateToEvidence = true
                        }
                    }
                    
                    PACEButton(
                        title: "ACTIVITIES & SCHEDULE",
                        icon: "list.bullet.rectangle",
                        variant: .secondary
                    ) {
                        navigateToActivities = true
                    }
                }
                
                PACEDivider()
                
                // Edit & Delete Actions
                VStack(spacing: 10) {
                    PACEButton(
                        title: "EDIT GOAL",
                        icon: "pencil",
                        variant: .secondary
                    ) {
                        showEditSheet = true
                    }
                    
                    PACEButton(
                        title: "DELETE GOAL",
                        icon: "trash",
                        variant: .outline
                    ) {
                        showDeleteConfirmation = true
                    }
                }
                .padding(.bottom, 20)
            }
            .padding(20)
        }
        .background(PACEColor.background.ignoresSafeArea())
        .navigationTitle("GOAL DETAIL")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(PACEColor.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            _ = await logService.fetchLogs(for: goal.id)
        }
        .sheet(isPresented: $showLogSheet) {
            LogProgressView(goal: goal) {
                Task {
                    _ = await logService.fetchLogs(for: goal.id)
                    PACEWidgetSyncService.shared.syncPrimaryGoal(goals: goalService.goals, logsByGoal: logService.logsByGoal)
                }
            }
        }
        .sheet(item: $selectedLogForEdit) { log in
            LogProgressView(goal: goal, initialDate: log.date) {
                Task {
                    _ = await logService.fetchLogs(for: goal.id)
                    PACEWidgetSyncService.shared.syncPrimaryGoal(goals: goalService.goals, logsByGoal: logService.logsByGoal)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditGoalView(goal: goal) { updated in
                self.goal = updated
                Task {
                    await goalService.fetchActiveGoals()
                    PACEWidgetSyncService.shared.syncPrimaryGoal(goals: goalService.goals, logsByGoal: logService.logsByGoal)
                }
            }
        }
        .confirmationDialog(
            "Delete this goal?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("DELETE GOAL", role: .destructive) {
                Task {
                    try? await goalService.deleteGoal(id: goal.id)
                    PACEWidgetSyncService.shared.syncPrimaryGoal(goals: goalService.goals, logsByGoal: logService.logsByGoal)
                    dismiss()
                }
            }
            Button("CANCEL", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete '\(goal.title)'? All associated logs will also be removed.")
        }
        .navigationDestination(isPresented: $navigateToJourney) {
            JourneyDetailView(goal: goal)
        }
        .navigationDestination(isPresented: $navigateToActivities) {
            ActivitiesDestinationView(goal: goal)
        }
        .navigationDestination(isPresented: $navigateToEvidence) {
            EvidenceArchiveView(goal: goal)
        }
    }
    
    private var hasLoggedToday: Bool {
        let todayString = DailyLog.dateFormatter.string(from: Date())
        return goalLogs.contains(where: { $0.dateString == todayString })
    }
}
