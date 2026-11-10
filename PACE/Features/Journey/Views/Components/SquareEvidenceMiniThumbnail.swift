import SwiftUI

struct SquareEvidenceMiniThumbnail: View {
    let evidenceItems: [EvidenceItem]
    var size: CGFloat = 36
    var stemHeight: CGFloat = 8
    
    @ObservedObject private var evidenceService = EvidenceService.shared
    @State private var thumbnailImage: UIImage?
    @State private var didLoadThumbnail = false
    
    private var firstEvidence: EvidenceItem? {
        evidenceItems.first
    }
    
    private var taskIdentifier: String? {
        firstEvidence.map { "\($0.userId)|\($0.id)" }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                Rectangle()
                    .fill(PACEColor.surfaceElevated)
                    .frame(width: size, height: size)
                    .overlay(Rectangle().stroke(PACEColor.accent, lineWidth: 1))
                
                if let thumbnailImage {
                    Image(uiImage: thumbnailImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipped()
                } else if didLoadThumbnail {
                    Image(systemName: "exclamationmark.square")
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundColor(PACEColor.textSecondary)
                } else {
                    ProgressView()
                        .tint(PACEColor.accent)
                }
                
                if evidenceItems.count > 1 {
                    Text("+\(evidenceItems.count - 1)")
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(.white)
                        .padding(2)
                        .background(PACEColor.background)
                }
            }
            .frame(width: size, height: size)
            
            Rectangle()
                .fill(PACEColor.accent)
                .frame(width: 2, height: stemHeight)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .task(id: taskIdentifier) {
            thumbnailImage = nil
            didLoadThumbnail = false
            guard let firstEvidence else {
                didLoadThumbnail = true
                return
            }
            thumbnailImage = await evidenceService.loadImage(for: firstEvidence)
            didLoadThumbnail = true
        }
    }
    
    private var accessibilityLabel: String {
        guard firstEvidence != nil else {
            return "Photo evidence metadata unavailable"
        }
        if didLoadThumbnail && thumbnailImage == nil {
            return "Photo evidence image unavailable"
        }
        return "\(evidenceItems.count) photo evidence items"
    }
}
