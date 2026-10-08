//
//  PACETheme.swift
//  PACE
//
//  Centralized design foundation and design tokens for PACE:
//  - Sole accent: #A7FF19
//  - Near pure black / black canvas
//  - Zero-radius rectangular geometry across all controls and surfaces
//  - Condensed bold display typography for headlines & hero titles
//  - Monospaced tracked typography for labels, steps, metrics, and technical data
//  - No gradients, no rounded cards/buttons/pills
//

import SwiftUI

// MARK: - PACE Design Tokens
enum PACETheme {
    /// Sole accent color: #A7FF19
    static let accent = Color(red: 167 / 255.0, green: 255 / 255.0, blue: 25 / 255.0)
    
    // Neutrals
    static let background = Color.black
    static let surface = Color(red: 14 / 255.0, green: 14 / 255.0, blue: 14 / 255.0)
    static let surfaceElevated = Color(red: 24 / 255.0, green: 24 / 255.0, blue: 26 / 255.0)
    static let border = Color(red: 38 / 255.0, green: 38 / 255.0, blue: 40 / 255.0)
    static let borderSubtle = Color(red: 24 / 255.0, green: 24 / 255.0, blue: 24 / 255.0)
    static let primaryText = Color.white
    static let secondaryText = Color(red: 142 / 255.0, green: 142 / 255.0, blue: 147 / 255.0)
    static let mutedText = Color(red: 99 / 255.0, green: 99 / 255.0, blue: 102 / 255.0)
    static let textOnAccent = Color.black
}

// Backwards compatibility alias
typealias PACEColor = PACETheme

// Extension on PACEColor for aliases
extension PACETheme {
    static var textPrimary: Color { primaryText }
    static var textSecondary: Color { secondaryText }
}

// MARK: - PACE Typography & Text Styles
enum PACETextStyle {
    /// Large condensed display hero font (e.g. SHOW UP FOR WHAT MATTERS)
    static var displayHero: Font {
        .system(size: 52, weight: .black, design: .default).width(.condensed)
    }
    
    /// Large condensed display font for primary screen headings
    static var displayLarge: Font {
        .system(size: 34, weight: .black, design: .default).width(.condensed)
    }
    
    /// Medium condensed display font for section headings and cards
    static var displayMedium: Font {
        .system(size: 24, weight: .bold, design: .default).width(.condensed)
    }
    
    /// Small condensed display font for subheaders
    static var displaySmall: Font {
        .system(size: 18, weight: .bold, design: .default).width(.condensed)
    }
    
    /// Technical monospaced uppercase label with tracking
    static var label: Font {
        .system(size: 11, weight: .bold, design: .monospaced)
    }
    
    /// Sub-label / helper
    static var labelSmall: Font {
        .system(size: 9, weight: .medium, design: .monospaced)
    }
    
    /// Huge monospaced metric number (e.g. 43 DAYS REMAINING)
    static var metricHero: Font {
        .system(size: 72, weight: .black, design: .monospaced)
    }
    
    /// Primary monospaced metric number
    static var metricLarge: Font {
        .system(size: 32, weight: .bold, design: .monospaced)
    }
    
    /// Medium monospaced metric value
    static var metricMedium: Font {
        .system(size: 20, weight: .semibold, design: .monospaced)
    }
    
    /// Small monospaced metric value
    static var metricSmall: Font {
        .system(size: 12, weight: .medium, design: .monospaced)
    }
    
    /// Standard body text
    static var body: Font {
        .system(size: 14, weight: .regular, design: .default)
    }
    
    /// Subdued body text
    static var bodyMuted: Font {
        .system(size: 14, weight: .regular, design: .default)
    }
}

// Backwards compatibility alias
enum PACETypography {
    static func titleLarge() -> Font { PACETextStyle.displayLarge }
    static func sectionHeader() -> Font { PACETextStyle.displaySmall }
    static func body() -> Font { PACETextStyle.body }
    static func caption() -> Font { PACETextStyle.label }
    static func metricLarge() -> Font { PACETextStyle.metricLarge }
    static func metricMedium() -> Font { PACETextStyle.metricMedium }
    static func metricSmall() -> Font { PACETextStyle.metricSmall }
}

// MARK: - Rectangular Surface Modifiers
struct PACERectangularCard: ViewModifier {
    var borderColor: Color = PACETheme.border
    var backgroundColor: Color = PACETheme.surface
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
        borderColor: Color = PACETheme.border,
        backgroundColor: Color = PACETheme.surface,
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
