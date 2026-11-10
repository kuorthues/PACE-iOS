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
                    Text("SETTINGS")
                        .font(PACETextStyle.displayLarge)
                        .foregroundColor(PACETheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 16)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("SYSTEM CONFIGURATION")
                            .font(.system(.subheadline, design: .monospaced).weight(.bold))
                            .foregroundColor(PACETheme.secondaryText)
                            .tracking(1.5)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("BUNDLE ID")
                                    .font(PACETextStyle.pixelLabel)
                                    .foregroundColor(PACETheme.secondaryText)
                                Text("mseud.edu.ph.PACE")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(PACETheme.accent)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Rectangle()
                                .fill(PACETheme.border)
                                .frame(height: 1)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("ACCENT TOKEN")
                                    .font(PACETextStyle.pixelLabel)
                                    .foregroundColor(PACETheme.secondaryText)
                                HStack(spacing: 8) {
                                    Rectangle()
                                        .fill(PACETheme.accent)
                                        .frame(width: 14, height: 14)
                                        .accessibilityHidden(true)
                                    Text("#A7FF19")
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(PACETheme.primaryText)
                                }
                            }

                            Rectangle()
                                .fill(PACETheme.border)
                                .frame(height: 1)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("GEOMETRY")
                                    .font(PACETextStyle.pixelLabel)
                                    .foregroundColor(PACETheme.secondaryText)
                                Text("CORNER RADIUS 0")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(PACETheme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .paceCard()
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("ACCOUNT & AUTHENTICATION")
                            .font(.system(.subheadline, design: .monospaced).weight(.bold))
                            .foregroundColor(PACETheme.secondaryText)
                            .tracking(1.5)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 16) {
                            if let user = authService.currentUser {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("USER")
                                        .font(PACETextStyle.pixelLabel)
                                        .foregroundColor(PACETheme.secondaryText)
                                    Text(user.displayName ?? "PACE User")
                                        .font(.body)
                                        .foregroundColor(PACETheme.primaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Rectangle()
                                    .fill(PACETheme.border)
                                    .frame(height: 1)
                                    .accessibilityHidden(true)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("EMAIL")
                                        .font(PACETextStyle.pixelLabel)
                                        .foregroundColor(PACETheme.secondaryText)
                                    Text(user.email)
                                        .font(.body)
                                        .foregroundColor(PACETheme.secondaryText)
                                        .textSelection(.enabled)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Rectangle()
                                    .fill(PACETheme.border)
                                    .frame(height: 1)
                                    .accessibilityHidden(true)
                            } else {
                                Text("Authenticated Session Active.")
                                    .font(.body)
                                    .foregroundColor(PACETheme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)

                                Rectangle()
                                    .fill(PACETheme.border)
                                    .frame(height: 1)
                                    .accessibilityHidden(true)
                            }

                            PACEButton(
                                title: "LOGOUT",
                                icon: "rectangle.portrait.and.arrow.right",
                                variant: .outline
                            ) {
                                authService.signOut()
                            }
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .accessibilityHint("Signs out of your PACE account")
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .paceCard()
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(PACETheme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
