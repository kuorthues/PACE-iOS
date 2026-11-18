import SwiftUI

struct PACEBrandMark: View {
    var showsWordmark: Bool = true
    var logoSize: CGFloat = 28

    var body: some View {
        HStack(spacing: 9) {
            Image("PACELogo")
                .resizable()
                .scaledToFit()
                .frame(width: logoSize, height: logoSize)
                .accessibilityHidden(true)

            if showsWordmark {
                Text("PACE")
                    .font(.system(size: logoSize * 0.72, weight: .black, design: .default).width(.condensed))
                    .tracking(1.4)
                    .foregroundColor(PACETheme.primaryText)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("PACE")
    }
}
