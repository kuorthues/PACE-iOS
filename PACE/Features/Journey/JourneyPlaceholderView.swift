//
//  JourneyPlaceholderView.swift
//  PACE
//
//  Main Journey tab view hosting chronological timelines for active goals.
//  Strictly adheres to PACE UI rules:
//  - Zero corner radius
//  - #A7FF19 accent
//  - Real-time Journey Line rendering
//  - Zero Swift Charts dependency
//

import SwiftUI

struct JourneyPlaceholderView: View {
    @ObservedObject private var goalService = GoalService.shared
    @State private var selectedGoalId: String? = nil
    
    private var activeGoals: [PACEGoal] {
        goalService.goals.filter { $0.status == .active }
    }
    
    private var currentGoal: PACEGoal? {
        if let selectedId = selectedGoalId,
           let goal = activeGoals.first(where: { $0.id == selectedId }) {
            return goal
        }
        return activeGoals.first
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if let goal = currentGoal {
                    VStack(spacing: 0) {
                        // Multi-Goal Selector bar if multiple goals exist
                        if activeGoals.count > 1 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(activeGoals) { g in
                                        Button(action: {
                                            selectedGoalId = g.id
                                        }) {
                                            Text(g.title.uppercased())
                                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                .foregroundColor(g.id == goal.id ? PACEColor.background : PACEColor.textPrimary)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(g.id == goal.id ? PACEColor.accent : PACEColor.surfaceElevated)
                                                .overlay(
                                                    Rectangle().stroke(g.id == goal.id ? PACEColor.accent : PACEColor.border, lineWidth: 1)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            }
                            .background(PACEColor.surface)
                            
                            Rectangle()
                                .fill(PACEColor.border)
                                .frame(height: 1)
                        }
                        
                        JourneyDetailView(goal: goal)
                    }
                } else {
                    // Zero-radius Empty State Card
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("CHRONOLOGICAL JOURNEY")
                                .font(PACETypography.titleLarge())
                                .foregroundColor(PACEColor.textPrimary)
                            
                            PACEDivider()
                            
                            VStack(spacing: 16) {
                                ZStack {
                                    Rectangle()
                                        .fill(PACEColor.surfaceElevated)
                                        .frame(width: 80, height: 80)
                                        .overlay(
                                            Rectangle().stroke(PACEColor.border, lineWidth: 1)
                                        )
                                    
                                    Image(systemName: "figure.walk")
                                        .font(.system(size: 36))
                                        .foregroundColor(PACEColor.accent)
                                }
                                
                                VStack(spacing: 6) {
                                    Text("NO ACTIVE GOAL DETECTED")
                                        .font(PACETypography.sectionHeader())
                                        .foregroundColor(PACEColor.textPrimary)
                                    
                                    Text("Create a target goal to unlock your chronological journey timeline, daily progress nodes, and verified photographic evidence trail.")
                                        .font(PACETypography.body())
                                        .foregroundColor(PACEColor.textSecondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 16)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(32)
                            .paceCard()
                        }
                        .padding(20)
                    }
                }
            }
            .background(PACEColor.background.ignoresSafeArea())
            .navigationTitle("JOURNEY")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(PACEColor.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await goalService.fetchActiveGoals()
            }
        }
    }
}
