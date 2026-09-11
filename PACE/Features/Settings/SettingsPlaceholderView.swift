//
//  SettingsPlaceholderView.swift
//  PACE
//
//  Settings screen showing system configuration and authenticated user logout.
//  No OAuth providers, profiles, or account settings beyond logout.
//

import SwiftUI

struct SettingsPlaceholderView: View {
    @ObservedObject var authService = AuthService.shared
    
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
                        if let user = authService.currentUser {
                            HStack {
                                Text("USER")
                                    .font(PACETypography.caption())
                                    .foregroundColor(PACEColor.textSecondary)
                                Spacer()
                                Text(user.displayName ?? "PACE User")
                                    .font(PACETypography.metricSmall())
                                    .foregroundColor(PACEColor.textPrimary)
                            }
                            
                            PACEDivider()
                            
                            HStack {
                                Text("EMAIL")
                                    .font(PACETypography.caption())
                                    .foregroundColor(PACEColor.textSecondary)
                                Spacer()
                                Text(user.email)
                                    .font(PACETypography.metricSmall())
                                    .foregroundColor(PACEColor.textSecondary)
                            }
                            
                            PACEDivider()
                        } else {
                            Text("Authenticated Session Active.")
                                .font(PACETypography.caption())
                                .foregroundColor(PACEColor.textSecondary)
                            
                            PACEDivider()
                        }
                        
                        PACEButton(
                            title: "LOGOUT",
                            icon: "rectangle.portrait.and.arrow.right",
                            variant: .outline
                        ) {
                            authService.signOut()
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
