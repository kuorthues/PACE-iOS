//
//  PACEMetricView.swift
//  PACE
//
//  Reusable metric display primitive adhering to PACE UI rules:
//  - System monospaced typography for numbers/values
//  - System sans-serif typography for labels
//  - Corner radius 0 rectangular card container
//

import SwiftUI

struct PACEMetricView: View {
    let label: String
    let value: String
    var unit: String? = nil
    var trend: String? = nil
    var isAccentValue: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(PACETypography.caption())
                .foregroundColor(PACEColor.textSecondary)
                .tracking(1.0)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(PACETypography.metricLarge())
                    .foregroundColor(isAccentValue ? PACEColor.accent : PACEColor.textPrimary)
                
                if let unit = unit {
                    Text(unit)
                        .font(PACETypography.metricSmall())
                        .foregroundColor(PACEColor.textSecondary)
                }
            }
            
            if let trend = trend {
                Text(trend)
                    .font(PACETypography.metricSmall())
                    .foregroundColor(PACEColor.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .paceCard()
    }
}
