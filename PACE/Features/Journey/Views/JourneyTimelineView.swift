//
//  JourneyTimelineView.swift
//  PACE
//
//  Custom SwiftUI horizontal timeline component.
//  Strictly adheres to PACE requirements:
//  - Zero Swift Charts dependency
//  - Horizontally scrollable line with connected day nodes
//  - Completed node: filled #A7FF19
//  - Completed with evidence: same node plus connected square evidence thumbnail
//  - Missed: gray outlined node
//  - Rest: neutral marker
//  - Future: faint marker
//  - Today: emphasized #A7FF19 outline
//  - Target: square terminal node
//  - Evidence thumbnails attach to the correct day and remain square
//  - Focused day-by-day exploration; compact dashboard uses a separate presentation
//

import SwiftUI

struct JourneyTimelineView: View {
    let days: [JourneyDay]
    @Binding var selectedDay: JourneyDay?
    
    private let columnWidth: CGFloat = 68
    private let thumbnailSize: CGFloat = 36
    private let thumbnailAreaHeight: CGFloat = 46
    private let nodeSize: CGFloat = 16
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(days.indices, id: \.self) { index in
                        let day = days[index]
                        DayColumnView(
                            day: day,
                            index: index,
                            totalCount: days.count,
                            columnWidth: columnWidth,
                            thumbnailSize: thumbnailSize,
                            thumbnailAreaHeight: thumbnailAreaHeight,
                            nodeSize: nodeSize,
                            isSelected: selectedDay?.id == day.id
                        )
                        .id(day.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedDay = day
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .onAppear {
                scrollToActiveDay(proxy: proxy)
            }
            .onChange(of: selectedDay) { _, newSelection in
                if let target = newSelection {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(target.id, anchor: .center)
                    }
                }
            }
        }
    }
    
    private func scrollToActiveDay(proxy: ScrollViewProxy) {
        if let selected = selectedDay {
            proxy.scrollTo(selected.id, anchor: .center)
        } else if let todayDay = days.first(where: { $0.isToday }) {
            proxy.scrollTo(todayDay.id, anchor: .center)
        } else if let lastCompleted = days.last(where: { $0.state == .completed || $0.state == .completedWithEvidence }) {
            proxy.scrollTo(lastCompleted.id, anchor: .center)
        } else if let first = days.first {
            proxy.scrollTo(first.id, anchor: .leading)
        }
    }
}

// MARK: - Day Column Subview

private struct DayColumnView: View {
    let day: JourneyDay
    let index: Int
    let totalCount: Int
    let columnWidth: CGFloat
    let thumbnailSize: CGFloat
    let thumbnailAreaHeight: CGFloat
    let nodeSize: CGFloat
    let isSelected: Bool
    
    private var isFirst: Bool { index == 0 }
    private var isLast: Bool { index == totalCount - 1 }
    
    var body: some View {
        VStack(spacing: 6) {
            headerLabel
                .fixedSize(horizontal: false, vertical: true)
            
            ZStack(alignment: .bottom) {
                if day.state == .completedWithEvidence {
                    SquareEvidenceMiniThumbnail(
                        evidenceItems: day.evidenceItems,
                        size: thumbnailSize,
                        stemHeight: 8
                    )
                } else {
                    Color.clear
                        .frame(height: thumbnailAreaHeight)
                }
            }
            .frame(width: columnWidth, height: thumbnailAreaHeight)
            
            ZStack {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(isFirst ? Color.clear : PACEColor.border)
                        .frame(height: 2)
                    Rectangle()
                        .fill(isLast ? Color.clear : PACEColor.border)
                        .frame(height: 2)
                }
                
                JourneyTimelineNodeView(
                    state: day.state,
                    isSelected: isSelected,
                    nodeBaseSize: nodeSize
                )
            }
            .frame(width: columnWidth, height: nodeSize + 14)
            
            VStack(spacing: 2) {
                Text(day.weekdayShort)
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(day.isToday ? PACEColor.accent : PACEColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(day.formattedShortDate)
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(day.isToday ? PACEColor.textPrimary : PACEColor.textSecondary.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Rectangle()
                .fill(isSelected ? PACEColor.accent : Color.clear)
                .frame(width: 20, height: 2)
        }
        .frame(width: columnWidth)
    }
    
    @ViewBuilder
    private var headerLabel: some View {
        if day.isTarget {
            Text("TARGET")
                .font(PACETextStyle.pixelMetadata)
                .foregroundColor(PACEColor.accent)
        } else if day.isToday {
            Text("TODAY")
                .font(PACETextStyle.pixelMetadata)
                .foregroundColor(PACEColor.accent)
        } else {
            Text(day.formattedDayIndex)
                .font(PACETextStyle.pixelMetadata)
                .foregroundColor(PACEColor.textSecondary)
        }
    }
}

struct JourneyOverviewList: View {
    let days: [JourneyDay]
    @Binding var selectedDay: JourneyDay?
    var onViewEvidence: ((EvidenceItem) -> Void)? = nil

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(days.indices, id: \.self) { index in
                let day = days[index]
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        JourneyTimelineNodeView(
                            state: day.state,
                            isSelected: selectedDay?.id == day.id,
                            nodeBaseSize: 16
                        )
                        Rectangle()
                            .fill(index == days.count - 1 ? .clear : PACEColor.border)
                            .frame(width: 2, height: 34)
                    }
                    .frame(width: 28)
                    
                    Button {
                        selectedDay = day
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(day.formattedDayProgress)
                                    .font(PACETypography.metricSmall())
                                    .foregroundColor(day.state == .completed || day.state == .completedWithEvidence ? PACEColor.accent : PACEColor.textPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Spacer(minLength: 4)
                                Text(day.state.title.uppercased())
                                    .font(PACETextStyle.pixelMetadata)
                                    .foregroundColor(PACEColor.textSecondary)
                                    .multilineTextAlignment(.trailing)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Text(day.formattedFullDate)
                                .font(PACETypography.body())
                                .foregroundColor(PACEColor.textPrimary)
                            if !day.logs.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(day.logs) { log in
                                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                                            Text(log.selectedActivities.joined(separator: " • "))
                                                .font(PACETypography.caption())
                                                .foregroundColor(PACEColor.textSecondary)
                                                .lineLimit(1)
                                            Spacer(minLength: 4)
                                            Text(log.formattedDuration)
                                                .font(PACETextStyle.pixelMetadata)
                                                .foregroundColor(PACEColor.accent)
                                                .lineLimit(1)
                                        }
                                    }
                                    if day.logs.count > 1 {
                                        Text("\(day.logs.count) SESSIONS GROUPED FOR THIS DATE")
                                            .font(PACETextStyle.pixelMetadata)
                                            .foregroundColor(PACEColor.mutedText)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(day.formattedFullDate), \(day.state.title), day \(day.dayIndex)")
                    
                    if !day.evidenceItems.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(day.evidenceItems) { evidence in
                                    Button {
                                        onViewEvidence?(evidence)
                                    } label: {
                                        JourneyEvidencePhoto(evidence: evidence, size: 58)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("View photo evidence from \(day.formattedFullDate)")
                                }
                            }
                        }
                        .frame(width: 64)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("\(day.evidenceItems.count) photo evidence items")
                    }
                }
                .frame(minHeight: 78)
                .padding(12)
                .background(selectedDay?.id == day.id ? PACEColor.surfaceElevated : PACEColor.surface)
                .overlay(Rectangle().stroke(selectedDay?.id == day.id ? PACEColor.accent : PACEColor.border, lineWidth: 1))
                .padding(.bottom, 8)
            }
        }
    }
}
