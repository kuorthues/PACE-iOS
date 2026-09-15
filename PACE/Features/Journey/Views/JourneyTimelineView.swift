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
//  - Supports both full interactive mode and compact preview mode
//

import SwiftUI

struct JourneyTimelineView: View {
    let days: [JourneyDay]
    @Binding var selectedDay: JourneyDay?
    var isCompact: Bool = false
    
    private var columnWidth: CGFloat {
        isCompact ? 52 : 68
    }
    
    private var thumbnailSize: CGFloat {
        isCompact ? 28 : 36
    }
    
    private var thumbnailAreaHeight: CGFloat {
        thumbnailSize + 10
    }
    
    private var nodeSize: CGFloat {
        isCompact ? 12 : 16
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                        DayColumnView(
                            day: day,
                            index: index,
                            totalCount: days.count,
                            columnWidth: columnWidth,
                            thumbnailSize: thumbnailSize,
                            thumbnailAreaHeight: thumbnailAreaHeight,
                            nodeSize: nodeSize,
                            isCompact: isCompact,
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
                .padding(.vertical, isCompact ? 10 : 16)
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
    let isCompact: Bool
    let isSelected: Bool
    
    private var isFirst: Bool { index == 0 }
    private var isLast: Bool { index == totalCount - 1 }
    
    var body: some View {
        VStack(spacing: 6) {
            // 1. Top Header Label (Day Index or Status)
            headerLabel
                .frame(height: isCompact ? 14 : 18)
            
            // 2. Connected Square Evidence Thumbnail Slot
            ZStack(alignment: .bottom) {
                if day.state == .completedWithEvidence {
                    SquareEvidenceMiniThumbnail(
                        evidence: day.evidence,
                        size: thumbnailSize,
                        stemHeight: 8
                    )
                } else {
                    Color.clear
                        .frame(height: thumbnailAreaHeight)
                }
            }
            .frame(width: columnWidth, height: thumbnailAreaHeight)
            
            // 3. Timeline Center Track & Node
            ZStack {
                // Background Track Line
                HStack(spacing: 0) {
                    // Left connecting line segment
                    Rectangle()
                        .fill(isFirst ? Color.clear : trackColor(for: index - 1))
                        .frame(height: 2)
                    
                    // Right connecting line segment
                    Rectangle()
                        .fill(isLast ? Color.clear : trackColor(for: index))
                        .frame(height: 2)
                }
                
                // Day Node
                JourneyTimelineNodeView(
                    state: day.state,
                    isSelected: isSelected,
                    nodeBaseSize: nodeSize
                )
            }
            .frame(width: columnWidth, height: nodeSize + 14)
            
            // 4. Bottom Metadata Labels (Weekday & Short Date)
            VStack(spacing: 2) {
                Text(isCompact ? day.weekdaySingleLetter : day.weekdayShort)
                    .font(.system(size: isCompact ? 9 : 10, weight: day.isToday ? .bold : .medium))
                    .foregroundColor(day.isToday ? PACEColor.accent : PACEColor.textSecondary)
                
                Text(day.formattedShortDate)
                    .font(.system(size: isCompact ? 8 : 9, weight: .regular, design: .monospaced))
                    .foregroundColor(day.isToday ? PACEColor.textPrimary : PACEColor.textSecondary.opacity(0.8))
            }
            .frame(height: isCompact ? 24 : 28)
            
            // 5. Selection Bottom Indicator
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
                .font(.system(size: isCompact ? 8 : 9, weight: .bold, design: .monospaced))
                .foregroundColor(PACEColor.accent)
        } else if day.isToday {
            Text("TODAY")
                .font(.system(size: isCompact ? 8 : 9, weight: .bold, design: .monospaced))
                .foregroundColor(PACEColor.accent)
        } else {
            Text(isCompact ? "D\(day.dayIndex)" : "DAY \(day.dayIndex)")
                .font(.system(size: isCompact ? 8 : 9, weight: .medium, design: .monospaced))
                .foregroundColor(PACEColor.textSecondary)
        }
    }
    
    private func trackColor(for segmentIndex: Int) -> Color {
        // Subtle line linking all nodes
        PACEColor.border
    }
}
