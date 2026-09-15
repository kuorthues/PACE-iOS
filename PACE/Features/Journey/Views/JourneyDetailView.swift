//
//  JourneyDetailView.swift
//  PACE
//
//  Full dedicated Journey Timeline screen for a PACE Goal:
//  - Complete chronological timeline spanning every day from start to target date
//  - Interactive horizontally scrollable day nodes with connected square evidence thumbnails
//  - Real-time Day Detail card revealing activities, duration, note, and evidence
//  - Distinct states for: completed, completedWithEvidence, missed, rest, today, future, target
//  - Interactive sheet triggers for logging progress and full-res evidence viewing
//  - Zero Swift Charts dependency
//

import SwiftUI

struct JourneyDetailView: View {
    let goal: PACEGoal
    
    @ObservedObject private var logService = DailyLogService.shared
    @ObservedObject private var evidenceService = EvidenceService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDay: JourneyDay? = nil
    @State private var dateForLogSheet: Date? = nil
    @State private var evidenceForViewer: EvidenceItem? = nil
    @State private var showLegend: Bool = false
    
    private var goalLogs: [DailyLog] {
        logService.logsByGoal[goal.id] ?? []
    }
    
    private var goalEvidence: [EvidenceItem] {
        evidenceService.evidenceByGoal[goal.id] ?? []
    }
    
    private var days: [JourneyDay] {
        JourneyTimelineBuilder.buildTimeline(
            goal: goal,
            logs: goalLogs,
            evidenceItems: goalEvidence
        )
    }
    
    private var summary: JourneySummaryMetrics {
        JourneyTimelineBuilder.computeSummary(days: days)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Goal Header Banner
                headerBanner
                
                PACEDivider()
                
                // Key Progress Metrics Row
                metricsStrip
                
                PACEDivider()
                
                // Visual Node State Legend
                legendSection
                
                // Horizontal Connected Journey Line Section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("CHRONOLOGICAL TIMELINE")
                            .font(PACETypography.sectionHeader())
                            .foregroundColor(PACEColor.textPrimary)
                        
                        Spacer()
                        
                        Text("SCROLL HORIZONTALLY")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(PACEColor.textSecondary)
                    }
                    
                    JourneyTimelineView(
                        days: days,
                        selectedDay: $selectedDay,
                        isCompact: false
                    )
                    .frame(height: 140)
                    .background(PACEColor.surfaceElevated)
                    .overlay(
                        Rectangle().stroke(PACEColor.border, lineWidth: 1)
                    )
                }
                
                // Selected Day Detail Panel
                if let selected = selectedDay {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SELECTED DAY ARCHIVE")
                            .font(PACETypography.sectionHeader())
                            .foregroundColor(PACEColor.textPrimary)
                        
                        JourneyDayDetailCard(
                            day: selected,
                            goal: goal,
                            onLogAction: { date in
                                dateForLogSheet = date
                            },
                            onViewEvidence: { evidence in
                                evidenceForViewer = evidence
                            }
                        )
                    }
                }
                
                Spacer(minLength: 30)
            }
            .padding(20)
        }
        .background(PACEColor.background.ignoresSafeArea())
        .navigationTitle("JOURNEY")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(PACEColor.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            _ = await logService.fetchLogs(for: goal.id)
            _ = await evidenceService.fetchEvidence(for: goal.id)
            if selectedDay == nil {
                selectedDay = days.first(where: { $0.isToday }) ?? days.first
            }
        }
        .sheet(item: $dateForLogSheet) { date in
            LogProgressView(goal: goal, initialDate: date) {
                Task {
                    _ = await logService.fetchLogs(for: goal.id)
                    _ = await evidenceService.fetchEvidence(for: goal.id)
                    // Refresh selected day
                    if let sel = selectedDay {
                        let updatedDays = JourneyTimelineBuilder.buildTimeline(
                            goal: goal,
                            logs: logService.logsByGoal[goal.id] ?? [],
                            evidenceItems: evidenceService.evidenceByGoal[goal.id] ?? []
                        )
                        selectedDay = updatedDays.first(where: { $0.id == sel.id })
                    }
                }
            }
        }
        .sheet(item: $evidenceForViewer) { item in
            EvidenceDetailViewer(
                evidence: item,
                goal: goal,
                onDeleted: {
                    Task {
                        _ = await evidenceService.fetchEvidence(for: goal.id)
                        _ = await logService.fetchLogs(for: goal.id)
                    }
                }
            )
        }
    }
    
    // MARK: - Header Banner
    
    private var headerBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TARGET OBJECTIVE")
                .font(PACETypography.caption())
                .foregroundColor(PACEColor.textSecondary)
            
            Text(goal.title.uppercased())
                .font(PACETypography.titleLarge())
                .foregroundColor(PACEColor.textPrimary)
            
            HStack(spacing: 8) {
                Text("FREQUENCY: \(goal.scheduleDescription)")
                    .font(PACETypography.caption())
                    .foregroundColor(PACEColor.textSecondary)
                
                Text("•")
                    .foregroundColor(PACEColor.border)
                
                Text("DEADLINE: \(goal.formattedTargetDate)")
                    .font(PACETypography.caption())
                    .foregroundColor(PACEColor.accent)
            }
            .padding(.top, 2)
        }
        .padding(.top, 4)
    }
    
    // MARK: - Metrics Strip
    
    private var metricsStrip: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                PACEMetricView(
                    label: "Days Completed",
                    value: String(format: "%02d", summary.completedCount),
                    unit: "DAYS",
                    isAccentValue: summary.completedCount > 0
                )
                
                PACEMetricView(
                    label: "Photo Proofs",
                    value: String(format: "%02d", summary.evidenceCount),
                    unit: "ATTACHED"
                )
            }
            
            HStack(spacing: 12) {
                PACEMetricView(
                    label: "Consistency",
                    value: String(format: "%.0f", summary.consistencyPercentage),
                    unit: "%"
                )
                
                PACEMetricView(
                    label: "Horizon Remaining",
                    value: String(format: "%02d", summary.daysRemaining),
                    unit: "DAYS"
                )
            }
        }
    }
    
    // MARK: - Node Legend Section
    
    private var legendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showLegend.toggle()
                }
            }) {
                HStack {
                    Text("TIMELINE NODE KEY")
                        .font(PACETypography.sectionHeader())
                        .foregroundColor(PACEColor.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: showLegend ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(PACEColor.accent)
                }
            }
            .buttonStyle(.plain)
            
            if showLegend {
                VStack(alignment: .leading, spacing: 8) {
                    legendRow(
                        node: JourneyTimelineNodeView(state: .completed, nodeBaseSize: 12),
                        name: "COMPLETED",
                        description: "Filled #A7FF19 node logged on scheduled day"
                    )
                    
                    legendRow(
                        node: HStack(spacing: 2) {
                            JourneyTimelineNodeView(state: .completedWithEvidence, nodeBaseSize: 12)
                            Image(systemName: "camera.fill")
                                .font(.system(size: 8))
                                .foregroundColor(PACEColor.accent)
                        },
                        name: "PROOF ATTACHED",
                        description: "Completed node with connected square photo evidence"
                    )
                    
                    legendRow(
                        node: JourneyTimelineNodeView(state: .today, nodeBaseSize: 12),
                        name: "TODAY",
                        description: "Emphasized #A7FF19 outline for current calendar date"
                    )
                    
                    legendRow(
                        node: JourneyTimelineNodeView(state: .missed, nodeBaseSize: 12),
                        name: "MISSED",
                        description: "Gray outlined node for skipped scheduled commitment"
                    )
                    
                    legendRow(
                        node: JourneyTimelineNodeView(state: .rest, nodeBaseSize: 12),
                        name: "PLANNED REST",
                        description: "Neutral marker preserving active streak"
                    )
                    
                    legendRow(
                        node: JourneyTimelineNodeView(state: .future, nodeBaseSize: 12),
                        name: "SCHEDULED FUTURE",
                        description: "Faint marker awaiting commitment"
                    )
                    
                    legendRow(
                        node: JourneyTimelineNodeView(state: .target, nodeBaseSize: 12),
                        name: "TARGET DEADLINE",
                        description: "Distinct square terminal milestone node"
                    )
                }
                .padding(12)
                .background(PACEColor.surface)
                .overlay(
                    Rectangle().stroke(PACEColor.border, lineWidth: 1)
                )
            }
        }
    }
    
    private func legendRow(node: some View, name: String, description: String) -> some View {
        HStack(spacing: 10) {
            node
                .frame(width: 24, height: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(PACEColor.textPrimary)
                
                Text(description)
                    .font(PACETypography.caption())
                    .foregroundColor(PACEColor.textSecondary)
            }
        }
    }
}

// Support Date as Identifiable for sheet(item:)
extension Date: @retroactive Identifiable {
    public var id: TimeInterval { self.timeIntervalSince1970 }
}
