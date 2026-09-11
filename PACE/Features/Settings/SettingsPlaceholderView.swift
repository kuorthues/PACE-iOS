//
//  SettingsPlaceholderView.swift
//  PACE
//
//  Settings feature placeholder screen (Module 1 Foundation).
//  No business logic or Firebase Auth integration in this module.
//

import SwiftUI

struct SettingsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("SYSTEM CONFIGURATION")
                        .font(PACETypography.sectionHeader())
                        .foregroundColor(PACEColor.textPrimary)
                    
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("BUNDLE ID")
                                .font(PACETypography.caption())
                                .foregroundColor(PACEColor.textSecondary)
                            Spacer()
                            Text("mseud.edu.ph.PACE")
                                .font(PACETypography.metricSmall())
                                .foregroundColor(PACEColor.accent)
                        }
                        
                        PACEDivider()
                        
                        HStack {
                            Text("ACCENT TOKEN")
                                .font(PACETypography.caption())
                                .foregroundColor(PACEColor.textSecondary)
                            Spacer()
                            HStack(spacing: 6) {
                                Rectangle()
                                    .fill(PACEColor.accent)
                                    .frame(width: 12, height: 12)
                                Text("#A7FF19")
                                    .font(PACETypography.metricSmall())
                                    .foregroundColor(PACEColor.textPrimary)
                            }
                        }
                        
                        PACEDivider()
                        
                        HStack {
                            Text("GEOMETRY")
                                .font(PACETypography.caption())
                                .foregroundColor(PACEColor.textSecondary)
                            Spacer()
                            Text("CORNER RADIUS 0")
                                .font(PACETypography.metricSmall())
                                .foregroundColor(PACEColor.textSecondary)
                        }
                    }
                    .padding(16)
                    .paceCard()
                    
                    Text("ACCOUNT & AUTHENTICATION")
                        .font(PACETypography.sectionHeader())
                        .foregroundColor(PACEColor.textPrimary)
                    
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Authentication placeholder. Firebase Auth sign-in, account settings, and data sync will be wired in future modules.")
                            .font(PACETypography.caption())
                            .foregroundColor(PACEColor.textSecondary)
                        
                        PACEButton(
                            title: "ACCOUNT ACTIONS (PLACEHOLDER)",
                            icon: "person.crop.square",
                            variant: .outline
                        ) {
                            // Placeholder
                        }
                    }
                    .padding(16)
                    .paceCard()
                    
                    Spacer()
                }
                .padding(16)
            }
            .background(PACEColor.background.ignoresSafeArea())
            .navigationTitle("SETTINGS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(PACEColor.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
