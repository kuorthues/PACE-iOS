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
    var showsScreenHeader: Bool = true
    
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
    
    private var historyDays: [JourneyDay] {
        var entries = days.filter { $0.log != nil && !$0.isTarget }
        if let target = days.first(where: { $0.isTarget }) {
            if target.log != nil {
                entries.append(target)
                entries.append(
                    JourneyDay(
                        id: "\(target.id)-deadline",
                        date: target.date,
                        dateString: target.dateString,
                        dayIndex: target.dayIndex,
                        totalDays: target.totalDays,
                        state: .target,
                        isScheduled: target.isScheduled,
                        isToday: target.isToday,
                        isTarget: true,
                        log: nil,
                        logs: [],
                        evidenceItems: []
                    )
                )
            } else {
                entries.append(target)
            }
        }
        return entries
    }

    private var hasLoggedSessions: Bool {
        goalLogs.contains { $0.goalId == goal.id }
    }

    private var summary: JourneySummaryMetrics {
        JourneyTimelineBuilder.computeSummary(days: days)
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if showsScreenHeader {
                        Text("JOURNEY")
                            .font(PACETextStyle.displayLarge)
                            .foregroundColor(PACETheme.primaryText)
                    }

                    headerBanner
                    PACEDivider()
                    metricsStrip
                    PACEDivider()
                    legendSection

                    VStack(alignment: .leading, spacing: 12) {
                        Text("HISTORY THROUGH TODAY")
                            .font(PACETextStyle.pixelLabel)
                            .foregroundColor(PACETheme.secondaryText)
                            .tracking(1.5)
                        
                        if !hasLoggedSessions {
                            historyEmptyState
                        }

                        JourneyOverviewList(
                            days: historyDays,
                            selectedDay: $selectedDay,
                            onViewEvidence: { evidence in evidenceForViewer = evidence }
                        )
                    }

                    if let selected = selectedDay {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("SELECTED DAY ARCHIVE")
                                .font(PACETextStyle.pixelLabel)
                                .foregroundColor(PACETheme.secondaryText)
                                .tracking(1.5)

                            JourneyDayDetailCard(
                                day: selected,
                                goal: goal,
                                onLogAction: { dateForLogSheet = $0 },
                                onViewEvidence: { evidenceForViewer = $0 }
                            )
                        }
                        .id("selected-day-detail")
                    }

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .onChange(of: selectedDay?.id) { _, dayId in
                guard dayId != nil else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo("selected-day-detail", anchor: .top)
                }
            }
        }
        .background(PACETheme.background.ignoresSafeArea())
        .toolbar(showsScreenHeader ? .visible : .hidden, for: .navigationBar)
        .task {
            _ = await logService.fetchLogs(for: goal.id)
            _ = await evidenceService.fetchEvidence(for: goal.id)
            if selectedDay == nil {
                selectedDay = historyDays.first(where: { $0.isToday }) ?? historyDays.last
            }
        }
        .sheet(item: $dateForLogSheet) { date in
            LogProgressView(goal: goal, initialDate: date) {
                Task {
                    _ = await logService.fetchLogs(for: goal.id)
                    _ = await evidenceService.fetchEvidence(for: goal.id)
                    if let selected = selectedDay {
                        let updatedDays = JourneyTimelineBuilder.buildTimeline(
                            goal: goal,
                            logs: logService.logsByGoal[goal.id] ?? [],
                            evidenceItems: evidenceService.evidenceByGoal[goal.id] ?? []
                        )
                        selectedDay = updatedDays.first(where: { $0.id == selected.id })
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

    private var historyEmptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(PACETheme.accent)
            Text("NO LOGGED SESSIONS YET. YOUR TARGET DEADLINE IS SHOWN BELOW.")
                .font(PACETextStyle.pixelMetadata)
                .foregroundColor(PACETheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PACETheme.surface)
        .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
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
            
            VStack(alignment: .leading, spacing: 4) {
                Text("START: \(days.first?.formattedMediumDate ?? goal.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACEColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("TARGET: \(goal.formattedTargetDate)")
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACEColor.accent)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("JOURNEY: \(summary.totalDays) DAYS · \(goal.scheduleDescription)")
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACEColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
        }
        .padding(.top, 4)
    }
    
    // MARK: - Metrics Strip
    
    private var metricsStrip: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            alignment: .leading,
            spacing: 18
        ) {
            journeyMetric(
                icon: "checkmark.square",
                label: "DAYS COMPLETED",
                value: String(format: "%02d", summary.completedCount),
                unit: "DAYS",
                isAccent: summary.completedCount > 0
            )
            journeyMetric(
                icon: "camera",
                label: "PHOTO PROOFS",
                value: String(format: "%02d", summary.evidenceCount),
                unit: "ATTACHED",
                isAccent: summary.evidenceCount > 0
            )
            journeyMetric(
                icon: "chart.bar",
                label: "CONSISTENCY",
                value: String(format: "%.0f", summary.consistencyPercentage),
                unit: "%",
                isAccent: true
            )
            journeyMetric(
                icon: "calendar",
                label: "DAYS REMAINING",
                value: String(format: "%02d", goal.daysRemaining),
                unit: "DAYS",
                isAccent: true
            )
        }
    }

    private func journeyMetric(
        icon: String,
        label: String,
        value: String,
        unit: String,
        isAccent: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isAccent ? PACETheme.accent : PACETheme.secondaryText)
                    .accessibilityHidden(true)
                Text(label)
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACETheme.secondaryText)
                    .tracking(1.0)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value)
                    .font(PACETextStyle.metricMedium)
                    .foregroundColor(isAccent ? PACETheme.accent : PACETheme.primaryText)
                    .monospacedDigit()
                Text(unit)
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACETheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value) \(unit)")
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
