//
//  EvidencePickerSection.swift
//  PACE
//
//  Evidence selection and preview component for daily progress logging.
//  - PhotosPicker for selecting visual proof
//  - Sharp 1:1 square preview container with zero corner radius
//  - Optional caption input
//  - Remove-before-save functionality
//  - Handles existing evidence with delete/replace capability
//

import SwiftUI
import PhotosUI

struct EvidencePickerSection: View {
    @Binding var selectedImage: UIImage?
    @Binding var caption: String
    var existingEvidence: EvidenceItem?
    var onRemoveExistingEvidence: (() -> Void)? = nil
    
    @State private var photosPickerItem: PhotosPickerItem? = nil
    @State private var isLoadingImage: Bool = false
    @State private var compressionSummary: String? = nil
    @State private var existingLoadedImage: UIImage? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("VISUAL PROOF (OPTIONAL)")
                    .font(PACETypography.caption())
                    .foregroundColor(PACEColor.textSecondary)
                Spacer()
                if selectedImage != nil || existingEvidence != nil {
                    Text("EVIDENCE ATTACHED")
                        .font(PACETypography.metricSmall())
                        .foregroundColor(PACEColor.accent)
                }
            }
            
            if let image = selectedImage ?? existingLoadedImage {
                // Photo Preview with Sharp Zero-Radius Square Frame
                VStack(alignment: .leading, spacing: 10) {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .clipped()
                            .overlay(
                                Rectangle()
                                    .stroke(PACEColor.accent, lineWidth: 1)
                            )
                        
                        // Remove / Discard Button
                        Button(action: {
                            removeSelectedPhoto()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash.fill")
                                Text("REMOVE")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(PACEColor.background)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(PACEColor.accent)
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                    }
                    
                    if let summary = compressionSummary {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle")
                                .foregroundColor(PACEColor.accent)
                            Text(summary)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(PACEColor.textSecondary)
                        }
                    }
                    
                    // Optional Caption Input
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EVIDENCE CAPTION")
                            .font(PACETypography.caption())
                            .foregroundColor(PACEColor.textSecondary)
                        
                        TextField("What does this proof demonstrate?", text: $caption)
                            .font(PACETypography.body())
                            .padding(10)
                            .background(PACEColor.surface)
                            .overlay(
                                Rectangle()
                                    .stroke(PACEColor.border, lineWidth: 1)
                            )
                            .foregroundColor(PACEColor.textPrimary)
                    }
                }
                .padding(12)
                .paceCard()
            } else {
                // Empty Picker Trigger Button (Sharp Zero Corner Radius)
                PhotosPicker(
                    selection: $photosPickerItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    HStack(spacing: 12) {
                        ZStack {
                            Rectangle()
                                .fill(PACEColor.surfaceElevated)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Rectangle()
                                        .stroke(PACEColor.accent, lineWidth: 1)
                                )
                            
                            if isLoadingImage {
                                ProgressView()
                                    .tint(PACEColor.accent)
                            } else {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(PACEColor.accent)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("ATTACH PHOTO EVIDENCE")
                                .font(PACETypography.metricSmall())
                                .foregroundColor(PACEColor.textPrimary)
                            
                            Text("Select square or landscape proof from photo library")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(PACEColor.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(PACEColor.textSecondary)
                    }
                    .padding(12)
                    .paceCard(borderColor: PACEColor.border)
                }
                .buttonStyle(.plain)
            }
        }
        .onChange(of: photosPickerItem) { _, newItem in
            guard let item = newItem else { return }
            loadPickedItem(item)
        }
        .task {
            if let existing = existingEvidence, existingLoadedImage == nil {
                caption = existing.caption ?? ""
                existingLoadedImage = await EvidenceService.shared.loadImage(for: existing)
            }
        }
    }
    
    private func loadPickedItem(_ item: PhotosPickerItem) {
        isLoadingImage = true
        Task {
            defer { isLoadingImage = false }
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    if let compressed = ImageCompressor.compress(image: uiImage) {
                        let originalKb = compressed.originalByteCount / 1024
                        let compKb = compressed.compressedByteCount / 1024
                        self.compressionSummary = "Optimized for mobile: \(compKb) KB (saved \(max(0, originalKb - compKb)) KB)"
                        self.selectedImage = compressed.image
                    } else {
                        self.selectedImage = uiImage
                    }
                }
            } catch {
                print("Failed to load photo transferable: \(error)")
            }
        }
    }
    
    private func removeSelectedPhoto() {
        selectedImage = nil
        photosPickerItem = nil
        compressionSummary = nil
        if existingEvidence != nil {
            existingLoadedImage = nil
            onRemoveExistingEvidence?()
        }
    }
}
