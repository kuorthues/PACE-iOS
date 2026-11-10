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
    
    private var days: [JourneyDay] {
        let evidenceList = evidenceService.evidenceByGoal[goal.id] ?? []
        return JourneyTimelineBuilder.buildTimeline(
            goal: goal,
            logs: logs,
            evidenceItems: evidenceList
        )
    }
    
    
    var body: some View {
        CompactJourneyPreview(goal: goal, days: days) {
            onOpenFullJourney?()
        }
        .padding(16)
        .paceCard()
    }
}
