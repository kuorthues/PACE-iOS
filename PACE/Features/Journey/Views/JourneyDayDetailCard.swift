//
//  JourneyDayDetailCard.swift
//  PACE
//
//  Interactive detail panel revealing date, activities, duration, note,
//  and verified evidence for a selected Journey timeline node.
//  Includes dedicated states for:
//  - Completed / Completed with Evidence
//  - Missed day state
//  - Rest day state
//  - Today pending state
//  - Future & Target state
//

import SwiftUI

struct JourneyDayDetailCard: View {
    let day: JourneyDay
    let goal: PACEGoal
    var onLogAction: ((Date) -> Void)? = nil
    var onViewEvidence: ((EvidenceItem) -> Void)? = nil
    
    @ObservedObject private var evidenceService = EvidenceService.shared
    @State private var evidenceImage: UIImage? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header Bar: Day progress + Date + Status Badge
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(day.formattedDayProgress.uppercased())
                        .font(PACETypography.metricSmall())
                        .foregroundColor(PACEColor.accent)
                    
                    Text(day.formattedMediumDate)
                        .font(PACETypography.sectionHeader())
                        .foregroundColor(PACEColor.textPrimary)
                }
                
                Spacer()
                
                statusBadge
            }
            
            PACEDivider()
            
            // Dynamic State-Specific Content
            switch day.state {
            case .completed, .completedWithEvidence:
                completedContent
                
            case .missed:
                missedContent
                
            case .rest:
                restContent
                
            case .today:
                todayPendingContent
                
            case .future:
                futureContent
                
            case .target:
                targetContent
            }
        }
        .padding(16)
        .paceCard()
        .task(id: day.id) {
            evidenceImage = nil
            if let ev = day.evidence {
                evidenceImage = await evidenceService.loadImage(for: ev)
            }
        }
    }
    
    // MARK: - Status Badge
    
    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 4) {
            if day.state == .completedWithEvidence {
                Image(systemName: "camera.fill")
                    .font(.system(size: 9, weight: .bold))
            }
            Text(day.state.title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(badgeForegroundColor)
        .background(badgeBackgroundColor)
        .overlay(
            Rectangle()
                .stroke(badgeBorderColor, lineWidth: 1)
        )
    }
    
    private var badgeForegroundColor: Color {
        switch day.state {
        case .completed, .completedWithEvidence:
            return PACEColor.background
        case .today, .target:
            return PACEColor.accent
        case .missed:
            return PACEColor.textPrimary
        case .rest, .future:
            return PACEColor.textSecondary
        }
    }
    
    private var badgeBackgroundColor: Color {
        switch day.state {
        case .completed, .completedWithEvidence:
            return PACEColor.accent
        case .today, .target:
            return PACEColor.surfaceElevated
        case .missed:
            return PACEColor.surfaceElevated
        case .rest, .future:
            return PACEColor.surface
        }
    }
    
    private var badgeBorderColor: Color {
        switch day.state {
        case .completed, .completedWithEvidence, .today, .target:
            return PACEColor.accent
        case .missed:
            return PACEColor.textSecondary
        case .rest, .future:
            return PACEColor.border
        }
    }
    
    // MARK: - Completed State Content
    
    @ViewBuilder
    private var completedContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Metrics Row: Duration + Entry Time
            if let log = day.log {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("INVESTED DURATION")
                            .font(PACETypography.caption())
                            .foregroundColor(PACEColor.textSecondary)
                        
                        Text(log.formattedDuration.uppercased())
                            .font(PACETypography.metricMedium())
                            .foregroundColor(PACEColor.accent)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("RECORDED FOR")
                            .font(PACETypography.caption())
                            .foregroundColor(PACEColor.textSecondary)
                        
                        Text(log.formattedDisplayDate)
                            .font(PACETypography.metricSmall())
                            .foregroundColor(PACEColor.textPrimary)
                    }
                }
                
                // Activities Checklist
                VStack(alignment: .leading, spacing: 6) {
                    Text("ACTIVITIES PERFORMED")
                        .font(PACETypography.caption())
                        .foregroundColor(PACEColor.textSecondary)
                    
                    Text(log.selectedActivities.joined(separator: " • ").uppercased())
                        .font(PACETypography.body())
                        .foregroundColor(PACEColor.textPrimary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PACEColor.surfaceElevated)
                        .overlay(
                            Rectangle().stroke(PACEColor.border, lineWidth: 1)
                        )
                }
                
                // Note
                if let note = log.note, !note.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NOTES & REFLECTION")
                            .font(PACETypography.caption())
                            .foregroundColor(PACEColor.textSecondary)
                        
                        Text(note)
                            .font(PACETypography.body())
                            .foregroundColor(PACEColor.textPrimary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(PACEColor.surfaceElevated)
                            .overlay(
                                Rectangle().stroke(PACEColor.border, lineWidth: 1)
                            )
                    }
                }
                
                // Evidence Section
                if let evidence = day.evidence {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("VERIFIED EVIDENCE")
                                .font(PACETypography.caption())
                                .foregroundColor(PACEColor.accent)
                            Spacer()
                            if let caption = evidence.caption {
                                Text(caption)
                                    .font(PACETypography.caption())
                                    .foregroundColor(PACEColor.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Button(action: {
                            onViewEvidence?(evidence)
                        }) {
                            HStack(spacing: 12) {
                                // Square thumbnail
                                ZStack {
                                    Rectangle()
                                        .fill(PACEColor.surfaceElevated)
                                        .frame(width: 72, height: 72)
                                        .overlay(
                                            Rectangle().stroke(PACEColor.accent, lineWidth: 1)
                                        )
                                    
                                    if let img = evidenceImage {
                                        Image(uiImage: img)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 72, height: 72)
                                            .clipped()
                                    } else {
                                        ProgressView()
                                            .tint(PACEColor.accent)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("PHOTO PROOF ATTACHED")
                                        .font(PACETypography.sectionHeader())
                                        .foregroundColor(PACEColor.textPrimary)
                                    
                                    Text(evidence.formattedCreatedAt)
                                        .font(PACETypography.caption())
                                        .foregroundColor(PACEColor.textSecondary)
                                    
                                    Text("TAP TO INSPECT HIGH-RES PROOF")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(PACEColor.accent)
                                        .padding(.top, 2)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(PACEColor.accent)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .padding(10)
                            .background(PACEColor.surfaceElevated)
                            .overlay(
                                Rectangle().stroke(PACEColor.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Edit log button
                PACEButton(
                    title: "EDIT SESSION RECORD",
                    icon: "pencil.square",
                    variant: .secondary
                ) {
                    onLogAction?(day.date)
                }
            }
        }
    }
    
    // MARK: - Missed Day Content
    
    @ViewBuilder
    private var missedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Rectangle()
                    .stroke(PACEColor.textSecondary, lineWidth: 1.5)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(PACEColor.textSecondary)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("MISSED COMMITMENT")
                        .font(PACETypography.sectionHeader())
                        .foregroundColor(PACEColor.textPrimary)
                    
                    Text("No session or proof recorded for this scheduled day.")
                        .font(PACETypography.caption())
                        .foregroundColor(PACEColor.textSecondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("SCHEDULED ACTIVITIES")
                    .font(PACETypography.caption())
                    .foregroundColor(PACEColor.textSecondary)
                
                Text(goal.activityTypes.joined(separator: " • ").uppercased())
                    .font(PACETypography.body())
                    .foregroundColor(PACEColor.textSecondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PACEColor.surfaceElevated)
                    .overlay(
                        Rectangle().stroke(PACEColor.border, lineWidth: 1)
                    )
            }
            
            Text("Consistency reflects your discipline. You can log retroactive proof if you trained offline.")
                .font(PACETypography.caption())
                .foregroundColor(PACEColor.textSecondary)
            
            PACEButton(
                title: "LOG RETROACTIVE PROOF",
                icon: "plus.square",
                variant: .secondary
            ) {
                onLogAction?(day.date)
            }
        }
    }
    
    // MARK: - Rest Day Content
    
    @ViewBuilder
    private var restContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(PACEColor.border)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "bed.double.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(PACEColor.textSecondary)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("PLANNED RECOVERY DAY")
                        .font(PACETypography.sectionHeader())
                        .foregroundColor(PACEColor.textPrimary)
                    
                    Text("No activities scheduled in your weekly frequency (\(goal.scheduleDescription)).")
                        .font(PACETypography.caption())
                        .foregroundColor(PACEColor.textSecondary)
                }
            }
            
            Text("Planned recovery days preserve your physical readiness and DO NOT break your continuous streak.")
                .font(PACETypography.caption())
                .foregroundColor(PACEColor.textSecondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PACEColor.surfaceElevated)
                .overlay(
                    Rectangle().stroke(PACEColor.border, lineWidth: 1)
                )
            
            PACEButton(
                title: "LOG BONUS SESSION",
                icon: "plus.square",
                variant: .outline
            ) {
                onLogAction?(day.date)
            }
        }
    }
    
    // MARK: - Today Pending Content
    
    @ViewBuilder
    private var todayPendingContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Rectangle()
                    .stroke(PACEColor.accent, lineWidth: 2)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "clock.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(PACEColor.accent)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("TODAY'S TARGET PENDING")
                        .font(PACETypography.sectionHeader())
                        .foregroundColor(PACEColor.textPrimary)
                    
                    Text("Scheduled session awaiting photographic evidence.")
                        .font(PACETypography.caption())
                        .foregroundColor(PACEColor.accent)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("ACTIVITIES SCHEDULED FOR TODAY")
                    .font(PACETypography.caption())
                    .foregroundColor(PACEColor.textSecondary)
                
                Text(goal.activityTypes.joined(separator: " • ").uppercased())
                    .font(PACETypography.body())
                    .foregroundColor(PACEColor.textPrimary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PACEColor.surfaceElevated)
                    .overlay(
                        Rectangle().stroke(PACEColor.border, lineWidth: 1)
                    )
            }
            
            PACEButton(
                title: "LOCK IN DAILY PROOF",
                icon: "camera.fill",
                variant: .primary
            ) {
                onLogAction?(day.date)
            }
        }
    }
    
    // MARK: - Future Content
    
    @ViewBuilder
    private var futureContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Rectangle()
                    .stroke(PACEColor.border, lineWidth: 1)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "calendar")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(PACEColor.textSecondary)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("SCHEDULED MILESTONE")
                        .font(PACETypography.sectionHeader())
                        .foregroundColor(PACEColor.textPrimary)
                    
                    Text("Upcoming commitment date.")
                        .font(PACETypography.caption())
                        .foregroundColor(PACEColor.textSecondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("PLANNED ACTIVITIES")
                    .font(PACETypography.caption())
                    .foregroundColor(PACEColor.textSecondary)
                
                Text(goal.activityTypes.joined(separator: " • ").uppercased())
                    .font(PACETypography.body())
                    .foregroundColor(PACEColor.textSecondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PACEColor.surfaceElevated)
                    .overlay(
                        Rectangle().stroke(PACEColor.border, lineWidth: 1)
                    )
            }
        }
    }
    
    // MARK: - Target Content
    
    @ViewBuilder
    private var targetContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Rectangle()
                        .stroke(PACEColor.accent, lineWidth: 2)
                        .background(Rectangle().fill(PACEColor.surfaceElevated))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "target")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(PACEColor.accent)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("TERMINAL TARGET DEADLINE")
                        .font(PACETypography.sectionHeader())
                        .foregroundColor(PACEColor.accent)
                    
                    Text("Final milestone completion date for '\(goal.title)'.")
                        .font(PACETypography.caption())
                        .foregroundColor(PACEColor.textSecondary)
                }
            }
            
            HStack(spacing: 12) {
                PACEMetricView(
                    label: "Days Until Target",
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
            
            VStack(alignment: .leading, spacing: 6) {
                Text("CORE OBJECTIVE ACTIVITIES")
                    .font(PACETypography.caption())
                    .foregroundColor(PACEColor.textSecondary)
                
                Text(goal.activityTypes.joined(separator: " • ").uppercased())
                    .font(PACETypography.body())
                    .foregroundColor(PACEColor.textPrimary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PACEColor.surfaceElevated)
                    .overlay(
                        Rectangle().stroke(PACEColor.border, lineWidth: 1)
                    )
            }
        }
    }
}
