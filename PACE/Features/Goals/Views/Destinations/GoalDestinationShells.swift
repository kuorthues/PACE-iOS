//
//  GoalDestinationShells.swift
//  PACE
//
//  Navigation destination shells for modules not yet implemented:
//  - Log Progress
//  - Journey
//  - Activities
//  - Evidence
//

import SwiftUI

struct LogProgressDestinationView: View {
    let goal: PACEGoal
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("LOG PROGRESS")
                    .font(PACETypography.titleLarge())
                    .foregroundColor(PACEColor.textPrimary)
                
                Text("Daily logging module will be implemented in the subsequent module.")
                    .font(PACETypography.body())
                    .foregroundColor(PACEColor.textSecondary)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("TARGET: \(goal.title.uppercased())")
                        .font(PACETypography.sectionHeader())
                        .foregroundColor(PACEColor.accent)
                    
                    PACEDivider()
                    
                    Text("Scheduled activities: \(goal.activityTypes.joined(separator: ", "))")
                        .font(PACETypography.body())
                        .foregroundColor(PACEColor.textSecondary)
                }
                .padding(16)
                .paceCard()
            }
            .padding(20)
        }
        .background(PACEColor.background.ignoresSafeArea())
        .navigationTitle("LOG PROGRESS")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct JourneyDestinationView: View {
    let goal: PACEGoal
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("JOURNEY TRAIL")
                    .font(PACETypography.titleLarge())
                    .foregroundColor(PACEColor.textPrimary)
                
                Text("Chronological journey records for \(goal.title) will appear here.")
                    .font(PACETypography.body())
                    .foregroundColor(PACEColor.textSecondary)
            }
            .padding(20)
        }
        .background(PACEColor.background.ignoresSafeArea())
        .navigationTitle("JOURNEY")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ActivitiesDestinationView: View {
    let goal: PACEGoal
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("ACTIVITIES")
                    .font(PACETypography.titleLarge())
                    .foregroundColor(PACEColor.textPrimary)
                
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(goal.activityTypes, id: \.self) { activity in
                        HStack {
                            Rectangle()
                                .fill(PACEColor.accent)
                                .frame(width: 8, height: 8)
                            Text(activity.uppercased())
                                .font(PACETypography.body())
                                .foregroundColor(PACEColor.textPrimary)
                            Spacer()
                        }
                        .padding(12)
                        .paceCard()
                    }
                }
            }
            .padding(20)
        }
        .background(PACEColor.background.ignoresSafeArea())
        .navigationTitle("ACTIVITIES")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct EvidenceDestinationView: View {
    let goal: PACEGoal
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("EVIDENCE VAULT")
                    .font(PACETypography.titleLarge())
                    .foregroundColor(PACEColor.textPrimary)
                
                Text("Verified square evidence snapshots for \(goal.title).")
                    .font(PACETypography.body())
                    .foregroundColor(PACEColor.textSecondary)
                
                Rectangle()
                    .fill(PACEColor.surfaceElevated)
                    .aspectRatio(1.0, contentMode: .fit)
                    .overlay(
                        Rectangle()
                            .stroke(PACEColor.border, lineWidth: 1)
                    )
                    .overlay(
                        Text("SQUARE EVIDENCE FRAME")
                            .font(PACETypography.caption())
                            .foregroundColor(PACEColor.textSecondary)
                    )
            }
            .padding(20)
        }
        .background(PACEColor.background.ignoresSafeArea())
        .navigationTitle("EVIDENCE")
        .navigationBarTitleDisplayMode(.inline)
    }
}
