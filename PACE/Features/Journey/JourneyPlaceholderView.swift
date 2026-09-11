//
//  JourneyPlaceholderView.swift
//  PACE
//
//  Journey feature placeholder screen (Module 1 Foundation).
//  No business logic or Firebase integration in this module.
//

import SwiftUI

struct JourneyPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Metrics
                    HStack(spacing: 12) {
                        PACEMetricView(
                            label: "Daily Streak",
                            value: "14",
                            unit: "DAYS",
                            isAccentValue: true
                        )
                        PACEMetricView(
                            label: "Total Logs",
                            value: "38",
                            unit: "ENTRIES"
                        )
                    }
                    
                    PACEDivider()
                    
                    Text("DAILY EVIDENCE TRAIL")
                        .font(PACETypography.sectionHeader())
                        .foregroundColor(PACEColor.textPrimary)
                    
                    // Square evidence placeholder
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Evidence Preview")
                            .font(PACETypography.caption())
                            .foregroundColor(PACEColor.textSecondary)
                        
                        // Strict square evidence frame (corner radius 0)
                        Rectangle()
                            .fill(PACEColor.surfaceElevated)
                            .aspectRatio(1.0, contentMode: .fit)
                            .overlay(
                                Rectangle()
                                    .stroke(PACEColor.border, lineWidth: 1)
                            )
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "camera.viewfinder")
                                        .font(.system(size: 32))
                                        .foregroundColor(PACEColor.accent)
                                    Text("SQUARE EVIDENCE PLACEHOLDER")
                                        .font(PACETypography.caption())
                                        .foregroundColor(PACEColor.textSecondary)
                                }
                            )
                        
                        Text("Journey logs and photo evidence capture will be wired in future modules.")
                            .font(PACETypography.caption())
                            .foregroundColor(PACEColor.textSecondary)
                        
                        PACEButton(
                            title: "NEW LOG ENTRY",
                            icon: "square.and.pencil",
                            variant: .secondary
                        ) {
                            // Placeholder action
                        }
                    }
                    .padding(16)
                    .paceCard()
                    
                    Spacer()
                }
                .padding(16)
            }
            .background(PACEColor.background.ignoresSafeArea())
            .navigationTitle("JOURNEY")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(PACEColor.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
