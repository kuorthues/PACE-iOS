//
//  PACEMetricView.swift
//  PACE
//
//  Reusable metric display primitive adhering to PACE Figma UI rules:
//  - System monospaced typography for numbers/values
//  - System monospaced tracked caption for labels
//  - Direct layout rendering or optional card container
//

import SwiftUI

struct PACEMetricView: View {
    let label: String
    let value: String
    var unit: String? = nil
    var trend: String? = nil
    var isAccentValue: Bool = false
    var showCardBackground: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(PACETheme.secondaryText)
                .tracking(1.5)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundColor(isAccentValue ? PACETheme.accent : PACETheme.primaryText)
                
                if let unit = unit {
                    Text(unit.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(PACETheme.secondaryText)
                }
            }
            
            if let trend = trend {
                Text(trend.uppercased())
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(PACETheme.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(showCardBackground ? 14 : 0)
        .if(showCardBackground) { view in
            view.paceCard()
        }
    }
}

extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
