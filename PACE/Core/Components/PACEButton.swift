//
//  PACEButton.swift
//  PACE
//
//  Reusable sharp rectangular button primitive adhering to PACE Figma design rules:
//  - Corner radius 0 (strictly rectangular)
//  - Full-width rectangular geometry
//  - Primary: #A7FF19 background, black monospaced uppercase text
//  - Secondary: transparent / black background, thin dark-gray border, white/gray text
//  - Generous vertical padding with arrow indicator where appropriate
//

import SwiftUI

enum PACEButtonVariant {
    case primary
    case secondary
    case outline
}

struct PACEButton: View {
    let title: String
    var icon: String? = nil
    var showArrow: Bool = false
    var variant: PACEButtonVariant = .primary
    var isFullWidth: Bool = true
    var isEnabled: Bool = true
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            if isEnabled {
                action()
            }
        }) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                }
                
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                
                if showArrow || (!title.contains("→") && (variant == .primary || variant == .secondary)) {
                    Text("→")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                }
            }
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .overlay(
                Rectangle()
                    .stroke(borderColor, lineWidth: 1)
            )
            .opacity(isEnabled ? 1.0 : 0.4)
        }
        .disabled(!isEnabled)
        .buttonStyle(.plain)
    }
    
    private var backgroundColor: Color {
        switch variant {
        case .primary:
            return PACETheme.accent
        case .secondary:
            return Color.black
        case .outline:
            return Color.black
        }
    }
    
    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return Color.black
        case .secondary:
            return Color.white
        case .outline:
            return PACETheme.accent
        }
    }
    
    private var borderColor: Color {
        switch variant {
        case .primary:
            return PACETheme.accent
        case .secondary:
            return PACETheme.border
        case .outline:
            return PACETheme.accent
        }
    }
}
