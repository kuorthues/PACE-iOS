//
//  GoalDetailView.swift
//  PACE
//
//  Goal detail screen showing:
//  - Title, Target Date, Days Remaining, Today Status
//  - Metric placeholders (Streak, Logs, Velocity)
//  - Navigation destinations: Log Progress, Journey, Activities, Evidence
//  - Edit Goal & Delete Goal with confirmation
//

import SwiftUI

struct GoalDetailView: View {
    @ObservedObject var goalService = GoalService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State var goal: PACEGoal
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var navigateToLogProgress = false
    @State private var navigateToJourney = false
    @State private var navigateToActivities = false
    @State private var navigateToEvidence = false
    
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
                
                // Countdown & Target Date Metrics
                HStack(spacing: 12) {
                    PACEMetricView(
                        label: "Days Remaining",
                        value: String(format: "%02d", goal.daysRemaining),
                        unit: "DAYS",
                        isAccentValue: true
                    )
                    
                    PACEMetricView(
                        label: "Target Date",
                        value: goal.formattedTargetDate,
                        unit: nil
                    )
                }
                
                // Metrics Placeholders (if logs do not exist yet)
                VStack(alignment: .leading, spacing: 12) {
                    Text("VELOCITY & PERFORMANCE")
                        .font(PACETypography.sectionHeader())
                        .foregroundColor(PACEColor.textPrimary)
                    
                    HStack(spacing: 12) {
                        PACEMetricView(
                            label: "Current Streak",
                            value: "00",
                            unit: "DAYS"
                        )
                        PACEMetricView(
                            label: "Evidence Logs",
                            value: "00",
                            unit: "ENTRIES"
                        )
                    }
                    
                    Text("Metrics will automatically populate once daily logs are recorded.")
                        .font(PACETypography.caption())
                        .foregroundColor(PACEColor.textSecondary)
                }
                .padding(16)
                .paceCard()
                
                // Action Destinations
                VStack(alignment: .leading, spacing: 10) {
                    Text("QUICK ACTIONS")
                        .font(PACETypography.sectionHeader())
                        .foregroundColor(PACEColor.textPrimary)
                    
                    PACEButton(
                        title: "LOG PROGRESS",
                        icon: "plus.square",
                        variant: .primary
                    ) {
                        navigateToLogProgress = true
                    }
                    
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
        .sheet(isPresented: $showEditSheet) {
            EditGoalView(goal: goal) { updated in
                self.goal = updated
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
                    dismiss()
                }
            }
            Button("CANCEL", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete '\(goal.title)'? This action cannot be undone.")
        }
        .navigationDestination(isPresented: $navigateToLogProgress) {
            LogProgressDestinationView(goal: goal)
        }
        .navigationDestination(isPresented: $navigateToJourney) {
            JourneyDestinationView(goal: goal)
        }
        .navigationDestination(isPresented: $navigateToActivities) {
            ActivitiesDestinationView(goal: goal)
        }
        .navigationDestination(isPresented: $navigateToEvidence) {
            EvidenceDestinationView(goal: goal)
        }
    }
}
