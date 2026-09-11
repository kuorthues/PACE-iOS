//
//  PACETheme.swift
//  PACE
//
//  Centralized design foundation for PACE:
//  - #A7FF19 is the only accent color
//  - Black/white/near-black/gray neutrals
//  - Zero-radius rectangular geometry across all controls and surfaces
//  - System sans-serif for UI text and system monospaced for metrics
//  - No gradients, no rounded pills/cards/buttons
//

import SwiftUI

// MARK: - PACE Colors
enum PACEColor {
    /// Sole accent color: #A7FF19
    static let accent = Color(red: 167 / 255.0, green: 255 / 255.0, blue: 25 / 255.0)
    
    // Neutrals
    static let background = Color.black
    static let surface = Color(red: 18 / 255.0, green: 18 / 255.0, blue: 18 / 255.0)
    static let surfaceElevated = Color(red: 28 / 255.0, green: 28 / 255.0, blue: 30 / 255.0)
    static let border = Color(red: 44 / 255.0, green: 44 / 255.0, blue: 46 / 255.0)
    static let borderSubtle = Color(red: 28 / 255.0, green: 28 / 255.0, blue: 28 / 255.0)
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 142 / 255.0, green: 142 / 255.0, blue: 147 / 255.0)
    static let textOnAccent = Color.black
}

// MARK: - PACE Typography
enum PACETypography {
    /// System sans-serif for headings
    static func titleLarge() -> Font {
        .system(size: 26, weight: .bold, design: .default)
    }
    
    /// System sans-serif for section headings
    static func sectionHeader() -> Font {
        .system(size: 16, weight: .semibold, design: .default)
    }
    
    /// System sans-serif for standard body text
    static func body() -> Font {
        .system(size: 14, weight: .regular, design: .default)
    }
    
    /// System sans-serif for labels and captions
    static func caption() -> Font {
        .system(size: 11, weight: .medium, design: .default)
    }
    
    /// System monospaced for primary metric numbers
    static func metricLarge() -> Font {
        .system(size: 32, weight: .bold, design: .monospaced)
    }
    
    /// System monospaced for medium metric values
    static func metricMedium() -> Font {
        .system(size: 20, weight: .semibold, design: .monospaced)
    }
    
    /// System monospaced for small metric indicators / timestamps
    static func metricSmall() -> Font {
        .system(size: 12, weight: .medium, design: .monospaced)
    }
}

// MARK: - Rectangular Surface Modifiers
struct PACERectangularCard: ViewModifier {
    var borderColor: Color = PACEColor.border
    var backgroundColor: Color = PACEColor.surface
    var lineWidth: CGFloat = 1
    
    func body(content: Content) -> some View {
        content
            .background(
                Rectangle()
                    .fill(backgroundColor)
            )
            .overlay(
                Rectangle()
                    .stroke(borderColor, lineWidth: lineWidth)
            )
    }
}

extension View {
    /// Applies a sharp rectangular card container with 0 corner radius and 1px border
    func paceCard(
        borderColor: Color = PACEColor.border,
        backgroundColor: Color = PACEColor.surface,
        lineWidth: CGFloat = 1
    ) -> some View {
        self.modifier(
            PACERectangularCard(
                borderColor: borderColor,
                backgroundColor: backgroundColor,
                lineWidth: lineWidth
            )
        )
    }
}
