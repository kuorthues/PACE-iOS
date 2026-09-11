//
//  PACEDivider.swift
//  PACE
//
//  Reusable sharp rectangular 1px divider primitive adhering to PACE UI rules:
//  - Strictly 1px rectangular stroke
//  - Neutral or accent color
//

import SwiftUI

struct PACEDivider: View {
    var color: Color = PACEColor.border
    var isVertical: Bool = false
    
    var body: some View {
        if isVertical {
            Rectangle()
                .fill(color)
                .frame(width: 1)
        } else {
            Rectangle()
                .fill(color)
                .frame(height: 1)
        }
    }
}
