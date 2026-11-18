import SwiftUI

struct PACEProfileAvatar: View {
    let profile: PublicProfile
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            Rectangle()
                .fill(PACETheme.surfaceElevated)
                .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
            Text(profile.initials)
                .font(.system(size: size * 0.34, weight: .black, design: .monospaced))
                .foregroundColor(PACETheme.accent)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Profile initials \(profile.initials)")
    }
}
