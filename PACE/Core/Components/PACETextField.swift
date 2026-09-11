//
//  PACETextField.swift
//  PACE
//
//  Reusable sharp rectangular text field primitive adhering to PACE UI rules:
//  - Corner radius 0 (strictly rectangular)
//  - Sharp 1px neutral/accent border
//  - System sans-serif typography
//

import SwiftUI

struct PACETextField: View {
    let placeholder: String
    @Binding var text: String
    var label: String? = nil
    var isSecure: Bool = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label = label {
                Text(label.uppercased())
                    .font(PACETypography.caption())
                    .foregroundColor(PACEColor.textSecondary)
                    .tracking(1.0)
            }
            
            HStack(spacing: 8) {
                if isSecure {
                    SecureField(
                        "",
                        text: $text,
                        prompt: Text(placeholder).foregroundColor(PACEColor.textSecondary)
                    )
                    .focused($isFocused)
                    .font(PACETypography.body())
                    .foregroundColor(PACEColor.textPrimary)
                } else {
                    TextField(
                        "",
                        text: $text,
                        prompt: Text(placeholder).foregroundColor(PACEColor.textSecondary)
                    )
                    .focused($isFocused)
                    .font(PACETypography.body())
                    .foregroundColor(PACEColor.textPrimary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(PACEColor.surface)
            .overlay(
                Rectangle()
                    .stroke(isFocused ? PACEColor.accent : PACEColor.border, lineWidth: 1)
            )
        }
    }
}
