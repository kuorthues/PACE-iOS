//
//  PACETextField.swift
//  PACE
//
//  Reusable sharp rectangular text field primitive adhering to PACE Figma design rules:
//  - Corner radius 0 (strictly rectangular)
//  - Black background with 1px dark-gray border (accent border on focus)
//  - Monospaced tracked label above
//  - Monospaced input font
//

import SwiftUI

struct PACETextField: View {
    let placeholder: String
    @Binding var text: String
    var label: String? = nil
    var isSecure: Bool = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label = label {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(PACETheme.secondaryText)
                    .tracking(1.5)
            }
            
            HStack(spacing: 8) {
                if isSecure {
                    SecureField(
                        "",
                        text: $text,
                        prompt: Text(placeholder.uppercased())
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(PACETheme.mutedText)
                    )
                    .focused($isFocused)
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundColor(PACETheme.primaryText)
                } else {
                    TextField(
                        "",
                        text: $text,
                        prompt: Text(placeholder.uppercased())
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(PACETheme.mutedText)
                    )
                    .focused($isFocused)
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundColor(PACETheme.primaryText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.black)
            .overlay(
                Rectangle()
                    .stroke(isFocused ? PACETheme.accent : PACETheme.border, lineWidth: 1)
            )
        }
    }
}
