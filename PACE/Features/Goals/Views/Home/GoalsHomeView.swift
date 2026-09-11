//
//  GoalsHomeView.swift
//  PACE
//
//  Goals Home screen showing primary (nearest) goal, secondary goals, and creation triggers.
//

import SwiftUI

struct GoalsHomeView: View {
    @ObservedObject var goalService = GoalService.shared
    
    @State private var showCreateGoalSheet = false
    @State private var selectedGoalForDetail: PACEGoal? = nil
    @State private var navigateToDetail = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if goalService.goals.isEmpty {
                        emptyStateView
                    } else {
                        // Summary & Goals List
                        goalsContent
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .background(PACEColor.background.ignoresSafeArea())
            .navigationTitle("GOALS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(PACEColor.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showCreateGoalSheet = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(PACEColor.accent)
                            .frame(width: 28, height: 28)
                            .background(PACEColor.surfaceElevated)
                            .overlay(
                                Rectangle()
                                    .stroke(PACEColor.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .task {
                await goalService.fetchActiveGoals()
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
                        }
                    }
                )
            }
            .navigationDestination(isPresented: $navigateToDetail) {
                if let goal = selectedGoalForDetail {
                    GoalDetailView(goal: goal)
                }
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("NO ACTIVE TARGETS")
                    .font(PACETypography.sectionHeader())
                    .foregroundColor(PACEColor.textPrimary)
                
                Text("Lock in a date. Show up consistently. Keep the proof.")
                    .font(PACETypography.body())
                    .foregroundColor(PACEColor.textSecondary)
            }
            
            PACEDivider()
            
            PACEButton(
                title: "CREATE YOUR FIRST GOAL",
                icon: "plus.square",
                variant: .primary
            ) {
                showCreateGoalSheet = true
            }
        }
        .padding(20)
        .paceCard()
        .padding(.top, 20)
    }
    
    // MARK: - Goals Content
    private var goalsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Nearest / Primary Goal
            if let primaryGoal = goalService.goals.first {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("PRIMARY TARGET")
                            .font(PACETypography.caption())
                            .foregroundColor(PACEColor.accent)
                            .tracking(1.0)
                        
                        Spacer()
                        
                        if primaryGoal.isScheduledForToday {
                            Text("SCHEDULED TODAY")
                                .font(PACETypography.metricSmall())
                                .foregroundColor(PACEColor.background)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(PACEColor.accent)
                        } else {
                            Text("REST DAY")
                                .font(PACETypography.metricSmall())
                                .foregroundColor(PACEColor.textSecondary)
                        }
                    }
                    
                    Text(primaryGoal.title.uppercased())
                        .font(PACETypography.titleLarge())
                        .foregroundColor(PACEColor.textPrimary)
                    
                    PACEDivider()
                    
                    HStack(spacing: 12) {
                        PACEMetricView(
                            label: "Days Remaining",
                            value: String(format: "%02d", primaryGoal.daysRemaining),
                            unit: "DAYS",
                            isAccentValue: true
                        )
                        
                        PACEMetricView(
                            label: "Target Date",
                            value: primaryGoal.formattedTargetDate,
                            unit: nil
                        )
                    }
                    
                    PACEButton(
                        title: "VIEW GOAL DETAILS",
                        icon: "arrow.right.square",
                        variant: .secondary
                    ) {
                        selectedGoalForDetail = primaryGoal
                        navigateToDetail = true
                    }
                }
                .padding(18)
                .paceCard(borderColor: PACEColor.accent)
            }
            
            // Secondary Goals
            if goalService.goals.count > 1 {
                VStack(alignment: .leading, spacing: 12) {
                    Text("SECONDARY TARGETS")
                        .font(PACETypography.sectionHeader())
                        .foregroundColor(PACEColor.textPrimary)
                    
                    ForEach(goalService.goals.dropFirst()) { goal in
                        Button(action: {
                            selectedGoalForDetail = goal
                            navigateToDetail = true
                        }) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(goal.title.uppercased())
                                        .font(PACETypography.body())
                                        .bold()
                                        .foregroundColor(PACEColor.textPrimary)
                                    Spacer()
                                    Text("\(goal.daysRemaining)D LEFT")
                                        .font(PACETypography.metricSmall())
                                        .foregroundColor(PACEColor.accent)
                                }
                                
                                HStack {
                                    Text("TARGET: \(goal.formattedTargetDate.uppercased())")
                                        .font(PACETypography.caption())
                                        .foregroundColor(PACEColor.textSecondary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(PACEColor.textSecondary)
                                }
                            }
                            .padding(14)
                            .paceCard()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Add New Goal CTA
            PACEButton(
                title: "NEW TARGET OBJECTIVE",
                icon: "plus",
                variant: .outline
            ) {
                showCreateGoalSheet = true
            }
            .padding(.top, 4)
        }
    }
}
