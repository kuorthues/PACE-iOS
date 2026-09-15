//
//  JourneyPreviewSection.swift
//  PACE
//
//  Compact Journey preview component embedded directly on GoalDetailView.
//  - Displays a compact horizontal timeline strip of the goal's chronological days
//  - Shows day nodes, evidence thumbnails, and day selection
//  - Links directly to the full Journey timeline screen
//  - Zero Swift Charts dependency
//

import SwiftUI

struct JourneyPreviewSection: View {
    let goal: PACEGoal
    let logs: [DailyLog]
    var onOpenFullJourney: (() -> Void)? = nil
    
    @ObservedObject private var evidenceService = EvidenceService.shared
    @State private var selectedDay: JourneyDay? = nil
    
    private var days: [JourneyDay] {
        let evidenceList = evidenceService.evidenceByGoal[goal.id] ?? []
        return JourneyTimelineBuilder.buildTimeline(
            goal: goal,
            logs: logs,
            evidenceItems: evidenceList
        )
    }
    
    private var summary: JourneySummaryMetrics {
        JourneyTimelineBuilder.computeSummary(days: days)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Row: Section Title + Full Journey Button
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("JOURNEY TIMELINE")
                        .font(PACETypography.sectionHeader())
                        .foregroundColor(PACEColor.textPrimary)
                    
                    Text("\(summary.completedCount) OF \(summary.totalDays) DAYS COMPLETED • \(summary.evidenceCount) PROOFS")
                        .font(PACETypography.caption())
                        .foregroundColor(PACEColor.textSecondary)
                }
                
                Spacer()
                
                Button(action: {
                    onOpenFullJourney?()
                }) {
                    HStack(spacing: 4) {
                        Text("FULL TIMELINE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(PACEColor.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(
                        Rectangle().stroke(PACEColor.accent, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            
            // Compact Timeline Line
            if !days.isEmpty {
                VStack(spacing: 8) {
                    JourneyTimelineView(
                        days: days,
                        selectedDay: $selectedDay,
                        isCompact: true
                    )
                    .frame(height: 105)
                    .background(PACEColor.surfaceElevated)
                    .overlay(
                        Rectangle().stroke(PACEColor.border, lineWidth: 1)
                    )
                    
                    // Compact Day Status Summary
                    if let selected = selectedDay {
                        HStack(spacing: 8) {
                            Text(selected.formattedDayProgress.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(PACEColor.accent)
                            
                            Text("•")
                                .foregroundColor(PACEColor.textSecondary)
                            
                            Text(selected.formattedMediumDate)
                                .font(PACETypography.caption())
                                .foregroundColor(PACEColor.textPrimary)
                            
                            Spacer()
                            
                            Text(selected.state.title)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(selected.state == .completed || selected.state == .completedWithEvidence ? PACEColor.background : PACEColor.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(selected.state == .completed || selected.state == .completedWithEvidence ? PACEColor.accent : PACEColor.surface)
                                .overlay(
                                    Rectangle().stroke(PACEColor.accent, lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(PACEColor.surface)
                        .overlay(
                            Rectangle().stroke(PACEColor.border, lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding(16)
        .paceCard()
        .onAppear {
            if selectedDay == nil {
                selectedDay = days.first(where: { $0.isToday }) ?? days.last
            }
        }
    }
}
