//
//  PACECheckbox.swift
//  PACE
//
//  Reusable sharp square checkbox primitive adhering to PACE Figma styling:
//  - Corner radius 0 (strictly square)
//  - Selected: square #A7FF19 background, black checkmark
//  - Unselected: dark outlined square, transparent center
//

import SwiftUI

struct PACECheckbox: View {
    let isSelected: Bool
    var size: CGFloat = 20
    var onToggle: (() -> Void)? = nil
    
    var body: some View {
        Button(action: {
            onToggle?()
        }) {
            ZStack {
                Rectangle()
                    .fill(isSelected ? PACETheme.accent : Color.black)
                    .frame(width: size, height: size)
                    .overlay(
                        Rectangle()
                            .stroke(isSelected ? PACETheme.accent : PACETheme.border, lineWidth: 1.5)
                    )
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.55, weight: .black))
                        .foregroundColor(.black)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
