//
//  JourneyIntroductionView.swift
//  PACE
//
//  Screen 5: Journey Introduction screen matching Figma prototype:
//  - Header: PACE, THE JOURNEY LINE
//  - Simplified Journey timeline preview:
//    thin horizontal line, #A7FF19 completed nodes, gray missed node,
//    square photo evidence preview above relevant node, outlined current node,
//    target terminal state.
//  - Below: EVERY NODE / IS A DAY.
//  - Three explanatory rows:
//    1. Every completed day becomes part of the path.
//    2. Every photograph becomes evidence.
//    3. Every missed day stays visible.
//  - Primary button: CREATE MY FIRST GOAL →
//  - Reuses existing JourneyTimelineNodeView & SquareEvidenceMiniThumbnail
//

import SwiftUI

struct JourneyIntroductionView: View {
    let onContinue: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 10) {
                Text("P A C E")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(PACETheme.accent)
                    .tracking(3.0)
                
                Text("THE JOURNEY LINE")
                    .font(PACETextStyle.displayMedium)
                    .foregroundColor(PACETheme.primaryText)
            }
            .padding(.top, 16)
            .padding(.horizontal, 24)
            
            Spacer(minLength: 20)
            
            // Simplified Journey Timeline Preview
            VStack(spacing: 0) {
                timelinePreview
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            
            Spacer(minLength: 20)
            
            // Explanatory Section
            VStack(alignment: .leading, spacing: 20) {
                Text("EVERY NODE\nIS A DAY.")
                    .font(PACETextStyle.displayMedium)
                    .foregroundColor(PACETheme.primaryText)
                    .lineSpacing(-2)
                
                VStack(alignment: .leading, spacing: 14) {
                    explanatoryRow(text: "Every completed day becomes part of the path.")
                    explanatoryRow(text: "Every photograph becomes evidence.")
                    explanatoryRow(text: "Every missed day stays visible.")
                }
            }
            .padding(.horizontal, 24)
            
            Spacer(minLength: 30)
            
            // Primary Button
            VStack {
                PACEButton(
                    title: "CREATE MY FIRST GOAL →",
                    variant: .primary
                ) {
                    onContinue()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PACETheme.background.ignoresSafeArea())
    }
    
    // MARK: - Timeline Preview
    
    private var timelinePreview: some View {
        ZStack {
            // Background Container
            Rectangle()
                .fill(PACETheme.surface)
                .overlay(
                    Rectangle().stroke(PACETheme.border, lineWidth: 1)
                )
            
            // Timeline track & nodes
            VStack(spacing: 0) {
                // Top area for evidence preview
                HStack(spacing: 0) {
                    // Node 01 space
                    Spacer()
                    
                    // Node 02 evidence thumbnail
                    SquareEvidenceMiniThumbnail(evidence: nil, size: 32, stemHeight: 8)
                    
                    // Remaining nodes space
                    Spacer()
                    Spacer()
                    Spacer()
                    Spacer()
                }
                .padding(.horizontal, 16)
                
                // Track line with nodes
                ZStack {
                    // Thin horizontal connecting line
                    Rectangle()
                        .fill(PACETheme.border)
                        .frame(height: 2)
                        .padding(.horizontal, 20)
                    
                    HStack {
                        // 01: Completed
                        JourneyTimelineNodeView(state: .completed, nodeBaseSize: 14)
                        
                        Spacer()
                        
                        // 02: Completed with Evidence
                        JourneyTimelineNodeView(state: .completedWithEvidence, nodeBaseSize: 14)
                        
                        Spacer()
                        
                        // 03: Missed
                        JourneyTimelineNodeView(state: .missed, nodeBaseSize: 14)
                        
                        Spacer()
                        
                        // 04: Completed
                        JourneyTimelineNodeView(state: .completed, nodeBaseSize: 14)
                        
                        Spacer()
                        
                        // 05: Today / Current (outlined)
                        JourneyTimelineNodeView(state: .today, nodeBaseSize: 14)
                        
                        Spacer()
                        
                        // 06: Target terminal state
                        JourneyTimelineNodeView(state: .target, nodeBaseSize: 14)
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: 32)
            }
            .padding(.vertical, 16)
        }
        .frame(height: 120)
    }
    
    private func explanatoryRow(text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(PACETheme.accent)
                .frame(width: 3, height: 16)
                .padding(.top, 2)
            
            Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(PACETheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
