//
//  ProductPrinciplesView.swift
//  PACE
//
//  Screen 4: Product Principles matching Figma prototype:
//  - 3 vertically separated numbered blocks (01, 02, 03)
//  - Headings: SET THE DATE, SHOW UP, KEEP THE PROOF
//  - Thin horizontal separators
//  - Primary bottom CTA: CONTINUE →
//

import SwiftUI

struct ProductPrinciplesView: View {
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
            
            Spacer(minLength: 20)
            
            // Principles Blocks
            VStack(alignment: .leading, spacing: 0) {
                // Principle 01
                principleBlock(
                    number: "01",
                    title: "SET THE DATE",
                    description: "Create something meaningful with a real deadline."
                )
                
                separator
                
                // Principle 02
                principleBlock(
                    number: "02",
                    title: "SHOW UP",
                    description: "Record the work you put in each day."
                )
                
                separator
                
                // Principle 03
                principleBlock(
                    number: "03",
                    title: "KEEP THE PROOF",
                    description: "Build a visual journey using notes, time, and photographs."
                )
            }
            .padding(.horizontal, 24)
            
            Spacer(minLength: 30)
            
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
    
    private func principleBlock(number: String, title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(number)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(PACETheme.accent)
                .tracking(2.0)
            
            Text(title)
                .font(PACETextStyle.displayMedium)
                .foregroundColor(PACETheme.primaryText)
            
            Text(description)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(PACETheme.secondaryText)
                .lineSpacing(3)
        }
        .padding(.vertical, 24)
    }
    
    private var separator: some View {
        Rectangle()
            .fill(PACETheme.border)
            .frame(height: 1)
    }
}
