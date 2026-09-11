//
//  InsightsPlaceholderView.swift
//  PACE
//
//  Insights feature placeholder screen (Module 1 Foundation).
//  No business logic or analytics integration in this module.
//

import SwiftUI

struct InsightsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Metrics Grid
                    HStack(spacing: 12) {
                        PACEMetricView(
                            label: "Completion Rate",
                            value: "87.5",
                            unit: "%",
                            trend: "+4.2% vs last week",
                            isAccentValue: true
                        )
                        PACEMetricView(
                            label: "Log Frequency",
                            value: "6.8",
                            unit: "/WK"
                        )
                    }
                    
                    PACEDivider()
                    
                    Text("VELOCITY OVERVIEW")
                        .font(PACETypography.sectionHeader())
                        .foregroundColor(PACEColor.textPrimary)
                    
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("TARGET EXECUTION")
                                .font(PACETypography.caption())
                                .foregroundColor(PACEColor.textSecondary)
                            Spacer()
                            Text("STATUS: ON TRACK")
                                .font(PACETypography.metricSmall())
                                .foregroundColor(PACEColor.accent)
                        }
                        
                        // Sharp rectangular indicator bar
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(PACEColor.surfaceElevated)
                                    .frame(height: 8)
                                
                                Rectangle()
                                    .fill(PACEColor.accent)
                                    .frame(width: proxy.size.width * 0.78, height: 8)
                            }
                            .overlay(
                                Rectangle()
                                    .stroke(PACEColor.border, lineWidth: 1)
                            )
                        }
                        .frame(height: 8)
                        
                        Text("Detailed trends and velocity charts will be integrated in subsequent modules.")
                            .font(PACETypography.caption())
                            .foregroundColor(PACEColor.textSecondary)
                    }
                    .padding(16)
                    .paceCard()
                    
                    Spacer()
                }
                .padding(16)
            }
            .background(PACEColor.background.ignoresSafeArea())
            .navigationTitle("INSIGHTS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(PACEColor.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
