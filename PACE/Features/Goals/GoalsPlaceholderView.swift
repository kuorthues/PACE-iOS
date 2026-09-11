//
//  GoalsPlaceholderView.swift
//  PACE
//
//  Goals feature placeholder screen (Module 1 Foundation).
//  No business logic or Firebase integration in this module.
//

import SwiftUI

struct GoalsPlaceholderView: View {
    @State private var sampleInput: String = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Metric Summary
                    HStack(spacing: 12) {
                        PACEMetricView(
                            label: "Active Targets",
                            value: "04",
                            trend: "+2 this cycle",
                            isAccentValue: true
                        )
                        PACEMetricView(
                            label: "Pace Velocity",
                            value: "92",
                            unit: "%"
                        )
                    }
                    
                    PACEDivider()
                    
                    // Section header
                    Text("CURRENT GOALS")
                        .font(PACETypography.sectionHeader())
                        .foregroundColor(PACEColor.textPrimary)
                    
                    // Demo card showcasing sharp rectangular design & primitives
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Sprint Target: Complete Foundation Setup")
                            .font(PACETypography.body())
                            .foregroundColor(PACEColor.textPrimary)
                        
                        Text("Module 1 Foundation Placeholder. Core goal tracking and CRUD will be implemented in subsequent modules.")
                            .font(PACETypography.caption())
                            .foregroundColor(PACEColor.textSecondary)
                        
                        PACEDivider()
                        
                        PACETextField(
                            placeholder: "Enter goal title...",
                            text: $sampleInput,
                            label: "Quick Entry"
                        )
                        
                        PACEButton(
                            title: "RECORD TARGET",
                            icon: "plus.square",
                            variant: .primary
                        ) {
                            // Placeholder action - no business logic
                        }
                    }
                    .padding(16)
                    .paceCard()
                    
                    Spacer()
                }
                .padding(16)
            }
            .background(PACEColor.background.ignoresSafeArea())
            .navigationTitle("GOALS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(PACEColor.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
