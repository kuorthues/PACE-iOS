//
//  SquareEvidenceMiniThumbnail.swift
//  PACE
//
//  Connected square evidence thumbnail for the PACE Journey Line.
//  Strictly adheres to PACE design rules:
//  - Strictly square (aspectRatio 1.0)
//  - Zero corner radius
//  - Connected to the day node via a 1px vertical stem line
//  - Asynchronously loads and caches image
//

import SwiftUI

struct SquareEvidenceMiniThumbnail: View {
    let evidence: EvidenceItem?
    var size: CGFloat = 36
    var stemHeight: CGFloat = 8
    
    @ObservedObject private var evidenceService = EvidenceService.shared
    @State private var thumbnailImage: UIImage? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Strict Square Evidence Frame (Zero Corner Radius)
            ZStack {
                Rectangle()
                    .fill(PACEColor.surfaceElevated)
                    .frame(width: size, height: size)
                    .overlay(
                        Rectangle()
                            .stroke(PACEColor.accent, lineWidth: 1)
                    )
                
                if let image = thumbnailImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipped()
                } else {
                    Image(systemName: "camera.fill")
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundColor(PACEColor.accent)
                }
            }
            .frame(width: size, height: size)
            
            // Connected vertical stem line to day node
            Rectangle()
                .fill(PACEColor.accent)
                .frame(width: 2, height: stemHeight)
        }
        .task {
            if let evidence = evidence {
                thumbnailImage = await evidenceService.loadImage(for: evidence)
            }
        }
    }
}
