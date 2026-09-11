//
//  EvidenceDetailViewer.swift
//  PACE
//
//  Full image viewer for verified photo evidence:
//  - Sharp black backdrop
//  - Full-resolution mobile image display
//  - Structured metadata card (goal, date, duration, activities, caption)
//  - Delete confirmation and removal
//  - Strict zero-radius styling
//

import SwiftUI

struct EvidenceDetailViewer: View {
    let evidence: EvidenceItem
    var goal: PACEGoal? = nil
    var log: DailyLog? = nil
    var onDeleted: (() -> Void)? = nil
    
    @ObservedObject var evidenceService = EvidenceService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var loadedImage: UIImage? = nil
    @State private var isLoading = true
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteErrorMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Main Image Frame (Full display with sharp 1px border)
                    ZStack {
                        Rectangle()
                            .fill(PACEColor.surfaceElevated)
                            .aspectRatio(1.0, contentMode: .fit)
                            .overlay(
                                Rectangle()
                                    .stroke(PACEColor.border, lineWidth: 1)
                            )
                        
                        if let image = loadedImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else if isLoading {
                            ProgressView()
                                .tint(PACEColor.accent)
                                .scaleEffect(1.5)
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "photo")
                                    .font(.system(size: 32))
                                    .foregroundColor(PACEColor.textSecondary)
                                Text("IMAGE UNAVAILABLE")
                                    .font(PACETypography.caption())
                                    .foregroundColor(PACEColor.textSecondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    if let error = deleteErrorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.square.fill")
                                .foregroundColor(PACEColor.accent)
                            Text(error)
                                .font(PACETypography.body())
                                .foregroundColor(PACEColor.textPrimary)
                        }
                        .padding(12)
                        .paceCard(borderColor: PACEColor.accent)
                    }
                    
                    // Metadata Panel
                    VStack(alignment: .leading, spacing: 14) {
                        Text("EVIDENCE DETAILS")
                            .font(PACETypography.sectionHeader())
                            .foregroundColor(PACEColor.textPrimary)
                        
                        // Caption if present
                        if let caption = evidence.caption, !caption.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CAPTION")
                                    .font(PACETypography.caption())
                                    .foregroundColor(PACEColor.accent)
                                Text(caption)
                                    .font(PACETypography.body())
                                    .foregroundColor(PACEColor.textPrimary)
                            }
                            PACEDivider()
                        }
                        
                        // Target Goal
                        HStack {
                            Text("TARGET")
                                .font(PACETypography.caption())
                                .foregroundColor(PACEColor.textSecondary)
                            Spacer()
                            Text(goal?.title.uppercased() ?? "GOAL")
                                .font(PACETypography.metricSmall())
                                .foregroundColor(PACEColor.accent)
                        }
                        
                        PACEDivider()
                        
                        // Session Date
                        HStack {
                            Text("SESSION DATE")
                                .font(PACETypography.caption())
                                .foregroundColor(PACEColor.textSecondary)
                            Spacer()
                            Text(log?.formattedDisplayDate.uppercased() ?? evidence.formattedCreatedAt.uppercased())
                                .font(PACETypography.metricSmall())
                                .foregroundColor(PACEColor.textPrimary)
                        }
                        
                        // Activities if known
                        if let log = log {
                            PACEDivider()
                            HStack {
                                Text("ACTIVITIES")
                                    .font(PACETypography.caption())
                                    .foregroundColor(PACEColor.textSecondary)
                                Spacer()
                                Text(log.selectedActivities.joined(separator: ", ").uppercased())
                                    .font(PACETypography.metricSmall())
                                    .foregroundColor(PACEColor.textPrimary)
                            }
                            
                            PACEDivider()
                            HStack {
                                Text("DURATION")
                                    .font(PACETypography.caption())
                                    .foregroundColor(PACEColor.textSecondary)
                                Spacer()
                                Text(log.formattedDuration)
                                    .font(PACETypography.metricSmall())
                                    .foregroundColor(PACEColor.accent)
                            }
                        }
                        
                        PACEDivider()
                        
                        // Storage Path Reference (Verification proof)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("STORAGE SCOPE")
                                .font(PACETypography.caption())
                                .foregroundColor(PACEColor.textSecondary)
                            Text(evidence.storagePath)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(PACEColor.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(16)
                    .paceCard()
                    
                    // Delete Evidence Action
                    PACEButton(
                        title: isDeleting ? "DELETING EVIDENCE..." : "DELETE EVIDENCE",
                        icon: "trash",
                        variant: .outline,
                        isEnabled: !isDeleting
                    ) {
                        showDeleteConfirmation = true
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .padding(20)
            }
            .background(PACEColor.background.ignoresSafeArea())
            .navigationTitle("PHOTO PROOF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(PACEColor.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("CLOSE") {
                        dismiss()
                    }
                    .font(PACETypography.caption())
                    .foregroundColor(PACEColor.textSecondary)
                }
            }
            .task {
                loadedImage = await evidenceService.loadImage(for: evidence)
                isLoading = false
            }
            .confirmationDialog(
                "Delete Photo Evidence?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("DELETE PERMANENTLY", role: .destructive) {
                    performDelete()
                }
                Button("CANCEL", role: .cancel) {}
            } message: {
                Text("This will permanently delete this visual proof snapshot. Associated session log will remain.")
            }
        }
    }
    
    private func performDelete() {
        isDeleting = true
        deleteErrorMessage = nil
        Task {
            do {
                try await evidenceService.deleteEvidence(evidence)
                onDeleted?()
                dismiss()
            } catch {
                isDeleting = false
                deleteErrorMessage = "Failed to delete evidence: \(error.localizedDescription)"
            }
        }
    }
}
