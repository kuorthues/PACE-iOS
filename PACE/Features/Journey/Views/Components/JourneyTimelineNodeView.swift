//
//  JourneyTimelineNodeView.swift
//  PACE
//
//  Visual node component rendering the 7 timeline day states.
//  Strictly adheres to PACE requirements:
//  - Zero corner radius (strict rectangular geometry)
//  - Completed node: filled #A7FF19
//  - Completed with evidence: same node plus connected square evidence thumbnail
//  - Missed: gray outlined node
//  - Rest: neutral marker
//  - Future: faint marker
//  - Today: emphasized #A7FF19 outline
//  - Target: square terminal node
//

import SwiftUI

struct JourneyTimelineNodeView: View {
    let state: JourneyDayState
    var isSelected: Bool = false
    var nodeBaseSize: CGFloat = 16
    
    var body: some View {
        ZStack {
            // Selection Accent Ring / Highlight
            if isSelected {
                Rectangle()
                    .stroke(PACEColor.accent, lineWidth: 1.5)
                    .frame(width: nodeBaseSize + 12, height: nodeBaseSize + 12)
            }
            
            // Node Geometry per State
            switch state {
            case .completed, .completedWithEvidence:
                // Completed node: filled #A7FF19
                Rectangle()
                    .fill(PACEColor.accent)
                    .frame(width: nodeBaseSize, height: nodeBaseSize)
                    .overlay(
                        Rectangle()
                            .stroke(PACEColor.background, lineWidth: 1)
                    )
                
            case .missed:
                // Missed: gray outlined node
                Rectangle()
                    .stroke(PACEColor.textSecondary, lineWidth: 1.5)
                    .background(Rectangle().fill(PACEColor.surfaceElevated))
                    .frame(width: nodeBaseSize, height: nodeBaseSize)
                
            case .rest:
                // Rest: neutral marker
                Rectangle()
                    .fill(PACEColor.border)
                    .frame(width: nodeBaseSize * 0.6, height: nodeBaseSize * 0.6)
                
            case .future:
                // Future: faint marker
                Rectangle()
                    .stroke(PACEColor.border, lineWidth: 1)
                    .background(Rectangle().fill(PACEColor.background))
                    .frame(width: nodeBaseSize * 0.7, height: nodeBaseSize * 0.7)
                
            case .today:
                // Today: emphasized #A7FF19 outline
                Rectangle()
                    .stroke(PACEColor.accent, lineWidth: 2)
                    .background(Rectangle().fill(PACEColor.surfaceElevated))
                    .frame(width: nodeBaseSize + 4, height: nodeBaseSize + 4)
                    .overlay(
                        Rectangle()
                            .fill(PACEColor.accent.opacity(0.35))
                            .frame(width: 4, height: 4)
                    )
                
            case .target:
                // Target: square terminal node
                ZStack {
                    Rectangle()
                        .stroke(PACEColor.accent, lineWidth: 2)
                        .background(Rectangle().fill(PACEColor.surface))
                        .frame(width: nodeBaseSize + 8, height: nodeBaseSize + 8)
                    
                    Image(systemName: "target")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(PACEColor.accent)
                }
            }
        }
        .frame(width: nodeBaseSize + 14, height: nodeBaseSize + 14)
    }
}
