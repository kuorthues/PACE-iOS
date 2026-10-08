//
//  WelcomeOnboardingView.swift
//  PACE
//
//  Screen 3: Post-registration Welcome screen matching Figma prototype:
//  - Large editorial negative space
//  - Middle/lower content: ACCOUNT CREATED / WELCOME TO PACE. / Start with something that matters.
//  - Primary bottom CTA: CONTINUE →
//

import SwiftUI

struct WelcomeOnboardingView: View {
    let onContinue: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Branding
            Text("P A C E")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundColor(PACETheme.accent)
                .tracking(3.0)
                .padding(.top, 16)
                .padding(.horizontal, 24)
            
            Spacer(minLength: 60)
            
            // Editorial Middle/Lower Block
            VStack(alignment: .leading, spacing: 16) {
                Text("ACCOUNT CREATED")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(PACETheme.accent)
                    .tracking(2.0)
                
                Text("WELCOME\nTO PACE.")
                    .font(PACETextStyle.displayLarge)
                    .foregroundColor(PACETheme.primaryText)
                    .lineSpacing(-4)
                
                Text("Start with something that matters.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(PACETheme.secondaryText)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            
            Spacer(minLength: 60)
            
            // Primary Bottom CTA
            VStack {
                PACEButton(
                    title: "CONTINUE →",
                    variant: .primary
                ) {
                    onContinue()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PACETheme.background.ignoresSafeArea())
    }
}
