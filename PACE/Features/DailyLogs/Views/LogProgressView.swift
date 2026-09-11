//
//  LogProgressView.swift
//  PACE
//
//  Daily progress entry screen:
//  - Activity selection from configured goal activities
//  - Duration selection & custom input
//  - Optional notes
//  - Late entry support (past dates allowed, future blocked)
//  - Duplicate-day prevention (converts into update)
//  - No photo evidence in this module
//

import SwiftUI

struct LogProgressView: View {
    let goal: PACEGoal
    var onSaved: (() -> Void)? = nil
    
    @ObservedObject var logService = DailyLogService.shared
    @ObservedObject var evidenceService = EvidenceService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDate: Date = Date()
    @State private var selectedActivities: Set<String> = []
    @State private var durationMinutes: Int = 45
    @State private var customDurationInput: String = "45"
    @State private var note: String = ""
    @State private var isExistingEntry: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var errorMessage: String? = nil
    
    // Evidence State
    @State private var selectedEvidenceImage: UIImage? = nil
    @State private var evidenceCaption: String = ""
    @State private var existingEvidence: EvidenceItem? = nil
    @State private var shouldRemoveEvidence: Bool = false
    @State private var isSaving: Bool = false
    
    private let presetDurations = [15, 30, 45, 60, 90, 120]
    
    init(goal: PACEGoal, initialDate: Date = Date(), onSaved: (() -> Void)? = nil) {
        self.goal = goal
        self.onSaved = onSaved
        _selectedDate = State(initialValue: initialDate)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Status
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TARGET: \(goal.title.uppercased())")
                            .font(PACETypography.metricSmall())
                            .foregroundColor(PACEColor.accent)
                        
                        Text(isExistingEntry ? "UPDATE PROGRESS" : "LOG TODAY'S WORK")
                            .font(PACETypography.titleLarge())
                            .foregroundColor(PACEColor.textPrimary)
                    }
                    .padding(.top, 8)
                    
                    PACEDivider()
                    
                    // Notice if existing entry for selected date
                    if isExistingEntry {
                        HStack(spacing: 8) {
                            Image(systemName: "pencil.square.fill")
                                .foregroundColor(PACEColor.accent)
                            Text("Entry already exists for this date. Saving will update your record.")
                                .font(PACETypography.caption())
                                .foregroundColor(PACEColor.textPrimary)
                        }
                        .padding(12)
                        .paceCard(borderColor: PACEColor.accent)
                    }
                    
                    // Error Message
                    if let error = errorMessage {
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
                    
                    // Date Selection (Defaults to Today, supports Late Entry)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("ENTRY DATE")
                                .font(PACETypography.caption())
                                .foregroundColor(PACEColor.textSecondary)
                            Spacer()
                            if Calendar.current.isDateInToday(selectedDate) {
                                Text("TODAY")
                                    .font(PACETypography.metricSmall())
                                    .foregroundColor(PACEColor.accent)
                            } else {
                                Text("LATE ENTRY")
                                    .font(PACETypography.metricSmall())
                                    .foregroundColor(PACEColor.textSecondary)
                            }
                        }
                        
                        DatePicker(
                            "Select Date",
                            selection: $selectedDate,
                            in: ...Date(),
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.compact)
                        .colorScheme(.dark)
                        .tint(PACEColor.accent)
                        .padding(12)
                        .paceCard()
                        .onChange(of: selectedDate) { _ in
                            checkExistingLog()
                        }
                    }
                    
                    PACEDivider()
                    
                    // Activity Selection
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ACTIVITIES PERFORMED")
                            .font(PACETypography.caption())
                            .foregroundColor(PACEColor.textSecondary)
                        
                        ForEach(goal.activityTypes, id: \.self) { activity in
                            let isSelected = selectedActivities.contains(activity)
                            Button(action: {
                                if isSelected {
                                    selectedActivities.remove(activity)
                                } else {
                                    selectedActivities.insert(activity)
                                }
                            }) {
                                HStack {
                                    Rectangle()
                                        .fill(isSelected ? PACEColor.accent : Color.clear)
                                        .frame(width: 16, height: 16)
                                        .overlay(
                                            Rectangle()
                                                .stroke(isSelected ? PACEColor.accent : PACEColor.border, lineWidth: 1)
                                        )
                                        .overlay(
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10, weight: .black))
                                                .foregroundColor(PACEColor.background)
                                                .opacity(isSelected ? 1.0 : 0.0)
                                        )
                                    
                                    Text(activity.uppercased())
                                        .font(PACETypography.body())
                                        .foregroundColor(PACEColor.textPrimary)
                                    
                                    Spacer()
                                }
                                .padding(12)
                                .paceCard(borderColor: isSelected ? PACEColor.accent : PACEColor.border)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    PACEDivider()
                    
                    // Duration Selection
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("SESSION DURATION")
                                .font(PACETypography.caption())
                                .foregroundColor(PACEColor.textSecondary)
                            Spacer()
                            Text("\(durationMinutes) MINUTES")
                                .font(PACETypography.metricMedium())
                                .foregroundColor(PACEColor.accent)
                        }
                        
                        // Preset Buttons
                        HStack(spacing: 6) {
                            ForEach(presetDurations, id: \.self) { mins in
                                let isSelected = (durationMinutes == mins)
                                Button(action: {
                                    durationMinutes = mins
                                    customDurationInput = "\(mins)"
                                }) {
                                    Text("\(mins)M")
                                        .font(PACETypography.metricSmall())
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(isSelected ? PACEColor.accent : PACEColor.surfaceElevated)
                                        .foregroundColor(isSelected ? PACEColor.background : PACEColor.textSecondary)
                                        .overlay(
                                            Rectangle()
                                                .stroke(isSelected ? PACEColor.accent : PACEColor.border, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    PACEDivider()
                    
                    // Session Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SESSION NOTE (OPTIONAL)")
                            .font(PACETypography.caption())
                            .foregroundColor(PACEColor.textSecondary)
                        
                        TextField(
                            "What did you cover or accomplish?",
                            text: $note,
                            axis: .vertical
                        )
                        .lineLimit(3...5)
                        .padding(12)
                        .background(PACEColor.surface)
                        .overlay(
                            Rectangle()
                                .stroke(PACEColor.border, lineWidth: 1)
                        )
                        .foregroundColor(PACEColor.textPrimary)
                    }
                    
                    PACEDivider()
                    
                    // Photo Evidence Attachment
                    EvidencePickerSection(
                        selectedImage: $selectedEvidenceImage,
                        caption: $evidenceCaption,
                        existingEvidence: existingEvidence,
                        onRemoveExistingEvidence: {
                            shouldRemoveEvidence = true
                            existingEvidence = nil
                        }
                    )
                    
                    PACEDivider()
                    
                    // Actions
                    VStack(spacing: 12) {
                        PACEButton(
                            title: isSaving ? "RECORDING PROOF..." : (isExistingEntry ? "UPDATE RECORD" : "LOCK IN DAILY PROOF"),
                            icon: isSaving ? nil : "checkmark.square",
                            variant: .primary,
                            isEnabled: !selectedActivities.isEmpty && durationMinutes > 0 && !isSaving
                        ) {
                            submitLog()
                        }
                        
                        if isExistingEntry {
                            PACEButton(
                                title: "DELETE THIS ENTRY",
                                icon: "trash",
                                variant: .outline
                            ) {
                                showDeleteConfirmation = true
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
            }
            .background(PACEColor.background.ignoresSafeArea())
            .navigationTitle("LOG PROGRESS")
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
            .onAppear {
                // Initialize default activities if none selected
                if selectedActivities.isEmpty, let first = goal.activityTypes.first {
                    selectedActivities.insert(first)
                }
                checkExistingLog()
            }
            .confirmationDialog(
                "Delete Daily Log?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("DELETE", role: .destructive) {
                    let dString = DailyLog.dateFormatter.string(from: selectedDate)
                    Task {
                        try? await logService.deleteLog(id: dString, goalId: goal.id)
                        onSaved?()
                        dismiss()
                    }
                }
                Button("CANCEL", role: .cancel) {}
            } message: {
                Text("Delete log for \(DailyLog.dateFormatter.string(from: selectedDate))?")
            }
        }
    }
    
    private func checkExistingLog() {
        let dString = DailyLog.dateFormatter.string(from: Calendar.current.startOfDay(for: selectedDate))
        if let existing = logService.fetchLog(for: goal.id, date: selectedDate) {
            isExistingEntry = true
            selectedActivities = Set(existing.selectedActivities)
            durationMinutes = existing.durationMinutes
            customDurationInput = "\(existing.durationMinutes)"
            note = existing.note ?? ""
            
            existingEvidence = evidenceService.fetchEvidence(forGoal: goal.id, logId: existing.id) ?? evidenceService.fetchEvidence(forGoal: goal.id, logId: dString)
            if let ev = existingEvidence {
                evidenceCaption = ev.caption ?? ""
            }
        } else {
            isExistingEntry = false
            existingEvidence = evidenceService.fetchEvidence(forGoal: goal.id, logId: dString)
            if let ev = existingEvidence {
                evidenceCaption = ev.caption ?? ""
            }
        }
    }
    
    private func submitLog() {
        errorMessage = nil
        guard !selectedActivities.isEmpty else {
            errorMessage = "Please select at least one activity."
            return
        }
        guard durationMinutes > 0 else {
            errorMessage = "Duration must be at least 1 minute."
            return
        }
        
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                // 1. Save or update daily log entry
                let savedLog = try await logService.saveLog(
                    goalId: goal.id,
                    date: selectedDate,
                    selectedActivities: Array(selectedActivities),
                    durationMinutes: durationMinutes,
                    note: note.isEmpty ? nil : note
                )
                
                // 2. Handle removal of existing evidence if requested
                if shouldRemoveEvidence, let existing = existingEvidence {
                    try? await evidenceService.deleteEvidence(existing)
                }
                
                // 3. Handle upload of newly selected evidence
                if let imageToUpload = selectedEvidenceImage {
                    do {
                        let evidenceItem = try await evidenceService.saveEvidence(
                            goalId: goal.id,
                            logId: savedLog.id,
                            image: imageToUpload,
                            caption: evidenceCaption.isEmpty ? nil : evidenceCaption
                        )
                        _ = try await logService.saveLog(
                            goalId: goal.id,
                            date: selectedDate,
                            selectedActivities: Array(selectedActivities),
                            durationMinutes: durationMinutes,
                            note: note.isEmpty ? nil : note,
                            evidenceId: evidenceItem.id
                        )
                    } catch {
                        // Safe failure presentation without corrupting log
                        self.errorMessage = "Log saved, but photo evidence upload failed: \(error.localizedDescription)"
                        onSaved?()
                        return
                    }
                }
                
                onSaved?()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
