//
//  GetStartedView.swift
//  PACE
//
//  Screen 1: Landing screen matching Figma prototype:
//  - Top-left P A C E neon tracked branding
//  - Massive white condensed hero: SHOW UP / FOR WHAT / MATTERS.
//  - Subdued subtitle: Set the date. Show up consistently. / Keep the proof.
//  - Primary neon CTA: GET STARTED →
//  - Secondary outlined CTA: I ALREADY HAVE AN ACCOUNT →
//

import SwiftUI

struct GetStartedView: View {
    @ObservedObject var authService = AuthService.shared
    @State private var navigateToRegister = false
    @State private var navigateToLogin = false
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Top Brand Mark
                Text("P A C E")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(PACETheme.accent)
                    .tracking(3.0)
                    .padding(.top, 16)
                    .padding(.horizontal, 24)
                
                Spacer(minLength: 40)
                
                // Hero Block
                VStack(alignment: .leading, spacing: 24) {
                    Text("SHOW UP\nFOR WHAT\nMATTERS.")
                        .font(PACETextStyle.displayHero)
                        .foregroundColor(PACETheme.primaryText)
                        .lineSpacing(-6)
                        .minimumScaleFactor(0.85)
                    
                    Text("Set the date. Show up consistently.\nKeep the proof.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(PACETheme.secondaryText)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 24)
                
                Spacer(minLength: 40)
                
                // Action Buttons
                VStack(spacing: 12) {
                    PACEButton(
                        title: "GET STARTED →",
                        variant: .primary
                    ) {
                        navigateToRegister = true
                    }
                    
                    PACEButton(
                        title: "I ALREADY HAVE AN ACCOUNT →",
                        variant: .secondary
                    ) {
                        navigateToLogin = true
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                
                // Bottom Brand Tagline
                Text("P A C E   —   S E T   T H E   D A T E .   S H O W   U P .   K E E P   T H E   P R O O F .")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(white: 0.25))
                    .tracking(1.0)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PACETheme.background.ignoresSafeArea())
            .navigationDestination(isPresented: $navigateToRegister) {
                CreateAccountView()
            }
            .navigationDestination(isPresented: $navigateToLogin) {
                LoginView()
            }
        }
    }
}
