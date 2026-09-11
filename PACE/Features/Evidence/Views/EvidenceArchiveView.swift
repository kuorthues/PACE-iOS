//
//  EvidenceArchiveView.swift
//  PACE
//
//  Evidence Archive screen displaying verified photo proof in a square thumbnail grid:
//  - 3-column square thumbnail grid
//  - All thumbnails adhere strictly to zero corner radius
//  - Tap opens full image viewer
//  - Survives app reload
//

import SwiftUI

struct EvidenceArchiveView: View {
    let goal: PACEGoal
    
    @ObservedObject var evidenceService = EvidenceService.shared
    @ObservedObject var logService = DailyLogService.shared
    
    @State private var selectedEvidenceForViewer: EvidenceItem? = nil
    @State private var isRefreshing = false
    
    private var evidenceItems: [EvidenceItem] {
        evidenceService.evidenceByGoal[goal.id] ?? []
    }
    
    private let gridColumns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Status
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("TARGET: \(goal.title.uppercased())")
                            .font(PACETypography.metricSmall())
                            .foregroundColor(PACEColor.accent)
                        Spacer()
                        Text("\(evidenceItems.count) SNAPSHOTS")
                            .font(PACETypography.metricSmall())
                            .foregroundColor(PACEColor.textSecondary)
                    }
                    
                    Text("EVIDENCE VAULT")
                        .font(PACETypography.titleLarge())
                        .foregroundColor(PACEColor.textPrimary)
                    
                    Text("Verified square photographic proof of completed sessions.")
                        .font(PACETypography.body())
                        .foregroundColor(PACEColor.textSecondary)
                }
                .padding(.top, 8)
                
                PACEDivider()
                
                if evidenceItems.isEmpty {
                    // Zero-radius Empty State Card
                    VStack(spacing: 16) {
                        ZStack {
                            Rectangle()
                                .fill(PACEColor.surfaceElevated)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Rectangle()
                                        .stroke(PACEColor.border, lineWidth: 1)
                                )
                            
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 32))
                                .foregroundColor(PACEColor.textSecondary)
                        }
                        
                        VStack(spacing: 6) {
                            Text("NO EVIDENCE RECORDED YET")
                                .font(PACETypography.sectionHeader())
                                .foregroundColor(PACEColor.textPrimary)
                            
                            Text("When logging daily work, attach photo proof to populate your verified vault.")
                                .font(PACETypography.body())
                                .foregroundColor(PACEColor.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(32)
                    .paceCard()
                } else {
                    // Square Thumbnail Grid (Zero Corner Radius)
                    LazyVGrid(columns: gridColumns, spacing: 2) {
                        ForEach(evidenceItems) { item in
                            Button(action: {
                                selectedEvidenceForViewer = item
                            }) {
                                SquareEvidenceThumbnailCell(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(PACEColor.border) // 2px grid separation color
                }
                
                Spacer(minLength: 30)
            }
            .padding(20)
        }
        .background(PACEColor.background.ignoresSafeArea())
        .navigationTitle("EVIDENCE")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(PACEColor.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            _ = await evidenceService.fetchEvidence(for: goal.id)
            _ = await logService.fetchLogs(for: goal.id)
        }
        .sheet(item: $selectedEvidenceForViewer) { item in
            let matchingLog = logService.logsByGoal[goal.id]?.first(where: { $0.id == item.logId || $0.dateString == item.logId })
            EvidenceDetailViewer(
                evidence: item,
                goal: goal,
                log: matchingLog,
                onDeleted: {
                    Task {
                        _ = await evidenceService.fetchEvidence(for: goal.id)
                    }
                }
            )
        }
    }
}

// MARK: - Square Evidence Thumbnail Cell (Strict Zero Radius)

private struct SquareEvidenceThumbnailCell: View {
    let item: EvidenceItem
    
    @ObservedObject var evidenceService = EvidenceService.shared
    @State private var thumbnailImage: UIImage? = nil
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(PACEColor.surfaceElevated)
                .aspectRatio(1.0, contentMode: .fit)
            
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .aspectRatio(1.0, contentMode: .fit)
                    .clipped()
            } else {
                ProgressView()
                    .tint(PACEColor.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Caption or Date overlay bar at bottom
            HStack {
                Text(item.caption ?? item.logId)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(PACEColor.background)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .background(PACEColor.accent.opacity(0.95))
        }
        .aspectRatio(1.0, contentMode: .fit)
        .task {
            thumbnailImage = await evidenceService.loadImage(for: item)
        }
    }
}
