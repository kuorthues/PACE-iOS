//
//  EvidencePickerSection.swift
//  PACE
//
// Evidence selection and preview component for daily progress logging.
// - Adds one compressed photo per save while retaining all existing proofs
// - Displays each existing proof and supports removing it before save
//

import SwiftUI
import PhotosUI

struct EvidencePickerSection: View {
    @Binding var selectedImage: UIImage?
    @Binding var caption: String
    var existingEvidenceItems: [EvidenceItem]
    var onRemoveExistingEvidence: ((EvidenceItem) -> Void)? = nil
    
    @State private var photosPickerItem: PhotosPickerItem? = nil
    @State private var isLoadingImage = false
    @State private var compressionSummary: String? = nil
    @State private var loadedEvidenceImages: [String: UIImage] = [:]
    @State private var missingEvidenceIds: Set<String> = []
    
    private let evidenceColumns = [GridItem(.adaptive(minimum: 112), spacing: 8)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("VISUAL PROOF (OPTIONAL)")
                    .font(PACETypography.caption())
                    .foregroundColor(PACEColor.textSecondary)
                
                Spacer()
                
                let photoCount = existingEvidenceItems.count + (selectedImage == nil ? 0 : 1)
                if photoCount > 0 {
                    Text("\(photoCount) \(photoCount == 1 ? "PHOTO" : "PHOTOS") ATTACHED")
                        .font(PACETypography.metricSmall())
                        .foregroundColor(PACEColor.accent)
                        .accessibilityLabel("\(photoCount) photo evidence items attached")
                }
            }
            
            if !existingEvidenceItems.isEmpty {
                LazyVGrid(columns: evidenceColumns, alignment: .leading, spacing: 12) {
                    ForEach(existingEvidenceItems) { item in
                        existingPhoto(item)
                    }
                }
            }
            
            if let selectedImage {
                VStack(alignment: .leading, spacing: 10) {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .clipped()
                            .overlay(Rectangle().stroke(PACEColor.accent, lineWidth: 1))
                        
                        Button(action: removeSelectedPhoto) {
                            Label("REMOVE", systemImage: "trash.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(PACEColor.background)
                                .padding(.horizontal, 10)
                                .frame(minHeight: 44)
                                .background(PACEColor.accent)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove selected photo")
                    }
                    
                    if let compressionSummary {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle")
                                .foregroundColor(PACEColor.accent)
                            Text(compressionSummary)
                                .font(PACETypography.caption())
                                .foregroundColor(PACEColor.textSecondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EVIDENCE CAPTION")
                            .font(PACETypography.caption())
                            .foregroundColor(PACEColor.textSecondary)
                        
                        TextField("What does this proof demonstrate?", text: $caption)
                            .font(PACETypography.body())
                            .padding(10)
                            .background(PACEColor.surface)
                            .overlay(Rectangle().stroke(PACEColor.border, lineWidth: 1))
                            .foregroundColor(PACEColor.textPrimary)
                    }
                }
                .padding(12)
                .paceCard()
            } else {
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
                                .overlay(Rectangle().stroke(PACEColor.accent, lineWidth: 1))
                            
                            if isLoadingImage {
                                ProgressView().tint(PACEColor.accent)
                            } else {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(PACEColor.accent)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(existingEvidenceItems.isEmpty ? "ATTACH PHOTO EVIDENCE" : "ADD ANOTHER PHOTO")
                                .font(PACETypography.metricSmall())
                                .foregroundColor(PACEColor.textPrimary)
                            
                            Text("Choose a photo from your library; existing proofs remain attached.")
                                .font(PACETypography.caption())
                                .foregroundColor(PACEColor.textSecondary)
                        }
                        
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(PACEColor.textSecondary)
                    }
                    .padding(12)
                    .frame(minHeight: 68)
                    .paceCard(borderColor: PACEColor.border)
                }
                .buttonStyle(.plain)
                .disabled(isLoadingImage)
                .accessibilityLabel(existingEvidenceItems.isEmpty ? "Attach photo evidence" : "Add another photo")
            }
        }
        .onChange(of: photosPickerItem) { _, newItem in
            guard let newItem else { return }
            loadPickedItem(newItem)
        }
        .task(id: existingEvidenceItems.map(\.id).joined(separator: "|")) {
            for item in existingEvidenceItems
            where loadedEvidenceImages[item.id] == nil && !missingEvidenceIds.contains(item.id) {
                if let image = await EvidenceService.shared.loadImage(for: item) {
                    loadedEvidenceImages[item.id] = image
                } else {
                    missingEvidenceIds.insert(item.id)
                }
            }
        }
    }
    
    @ViewBuilder
    private func existingPhoto(_ item: EvidenceItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .topTrailing) {
                    Group {
                        if let image = loadedEvidenceImages[item.id] {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else if missingEvidenceIds.contains(item.id) {
                            Rectangle()
                                .fill(PACEColor.surfaceElevated)
                                .overlay {
                                    VStack(spacing: 4) {
                                        Image(systemName: "photo")
                                        Text("PHOTO UNAVAILABLE")
                                            .multilineTextAlignment(.center)
                                    }
                                    .font(PACETypography.caption())
                                    .foregroundColor(PACEColor.textSecondary)
                                    .padding(6)
                                }
                        } else {
                            Rectangle()
                                .fill(PACEColor.surfaceElevated)
                                .overlay(ProgressView().tint(PACEColor.accent))
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    
                    if let onRemoveExistingEvidence {
                        Button {
                            onRemoveExistingEvidence(item)
                        } label: {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(PACEColor.background)
                                .frame(width: 44, height: 44)
                                .background(PACEColor.accent)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove photo evidence")
                    }
                }
                .overlay(Rectangle().stroke(PACEColor.border, lineWidth: 1))
            }
            .aspectRatio(1, contentMode: .fit)
            
            if let caption = item.caption, !caption.isEmpty {
                Text(caption)
                    .font(PACETypography.caption())
                    .foregroundColor(PACEColor.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
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
                        let compressedKb = compressed.compressedByteCount / 1024
                        compressionSummary = "Optimized: \(compressedKb) KB (saved \(max(0, originalKb - compressedKb)) KB)"
                        selectedImage = compressed.image
                    } else {
                        selectedImage = uiImage
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
        caption = ""
    }
}
