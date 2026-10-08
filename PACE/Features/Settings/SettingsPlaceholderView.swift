//
//  SettingsPlaceholderView.swift
//  PACE
//
//  Settings screen showing system configuration and authenticated user logout.
//  Matching PACE design language: sharp rectangular layout, monospaced labels,
//  #A7FF19 accent details, no rounded cards.
//

import SwiftUI

struct SettingsPlaceholderView: View {
    @ObservedObject var authService = AuthService.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Editorial Header
                    Text("SETTINGS")
                        .font(PACETextStyle.displayLarge)
                        .foregroundColor(PACETheme.primaryText)
                        .padding(.top, 16)
                    
                    // SYSTEM CONFIGURATION SECTION
                    VStack(alignment: .leading, spacing: 14) {
                        Text("SYSTEM CONFIGURATION")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(PACETheme.secondaryText)
                            .tracking(2.0)
                        
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("BUNDLE ID")
                                    .font(PACETextStyle.label)
                                    .foregroundColor(PACETheme.secondaryText)
                                Spacer()
                                Text("mseud.edu.ph.PACE")
                                    .font(PACETextStyle.metricSmall)
                                    .foregroundColor(PACETheme.accent)
                            }
                            
                            Rectangle()
                                .fill(PACETheme.border)
                                .frame(height: 1)
                            
                            HStack {
                                Text("ACCENT TOKEN")
                                    .font(PACETextStyle.label)
                                    .foregroundColor(PACETheme.secondaryText)
                                Spacer()
                                HStack(spacing: 8) {
                                    Rectangle()
                                        .fill(PACETheme.accent)
                                        .frame(width: 12, height: 12)
                                    Text("#A7FF19")
                                        .font(PACETextStyle.metricSmall)
                                        .foregroundColor(PACETheme.primaryText)
                                }
                            }
                            
                            Rectangle()
                                .fill(PACETheme.border)
                                .frame(height: 1)
                            
                            HStack {
                                Text("GEOMETRY")
                                    .font(PACETextStyle.label)
                                    .foregroundColor(PACETheme.secondaryText)
                                Spacer()
                                Text("CORNER RADIUS 0")
                                    .font(PACETextStyle.metricSmall)
                                    .foregroundColor(PACETheme.secondaryText)
                            }
                        }
                        .padding(16)
                        .paceCard()
                    }
                    
                    // ACCOUNT & AUTHENTICATION SECTION
                    VStack(alignment: .leading, spacing: 14) {
                        Text("ACCOUNT & AUTHENTICATION")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(PACETheme.secondaryText)
                            .tracking(2.0)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            if let user = authService.currentUser {
                                HStack {
                                    Text("USER")
                                        .font(PACETextStyle.label)
                                        .foregroundColor(PACETheme.secondaryText)
                                    Spacer()
                                    Text(user.displayName ?? "PACE User")
                                        .font(PACETextStyle.metricSmall)
                                        .foregroundColor(PACETheme.primaryText)
                                }
                                
                                Rectangle()
                                    .fill(PACETheme.border)
                                    .frame(height: 1)
                                
                                HStack {
                                    Text("EMAIL")
                                        .font(PACETextStyle.label)
                                        .foregroundColor(PACETheme.secondaryText)
                                    Spacer()
                                    Text(user.email)
                                        .font(PACETextStyle.metricSmall)
                                        .foregroundColor(PACETheme.secondaryText)
                                }
                                
                                Rectangle()
                                    .fill(PACETheme.border)
                                    .frame(height: 1)
                            } else {
                                Text("Authenticated Session Active.")
                                    .font(PACETextStyle.label)
                                    .foregroundColor(PACETheme.secondaryText)
                                
                                Rectangle()
                                    .fill(PACETheme.border)
                                    .frame(height: 1)
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
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
            .background(PACETheme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
