//
//  PACEButton.swift
//  PACE
//
//  Reusable sharp rectangular button primitive adhering to PACE UI rules:
//  - Corner radius 0 (strictly rectangular)
//  - #A7FF19 accent for primary actions
//  - System sans-serif typography
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
                        .font(.system(size: 14, weight: .bold))
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .bold))
            }
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.vertical, 14)
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
            return PACEColor.accent
        case .secondary:
            return PACEColor.surfaceElevated
        case .outline:
            return Color.black
        }
    }
    
    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return PACEColor.textOnAccent
        case .secondary:
            return PACEColor.textPrimary
        case .outline:
            return PACEColor.accent
        }
    }
    
    private var borderColor: Color {
        switch variant {
        case .primary:
            return PACEColor.accent
        case .secondary:
            return PACEColor.border
        case .outline:
            return PACEColor.accent
        }
    }
}
