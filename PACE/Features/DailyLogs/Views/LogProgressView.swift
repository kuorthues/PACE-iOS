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
    let sharedGoalId: String?
    
    @ObservedObject var logService = DailyLogService.shared
    @ObservedObject var evidenceService = EvidenceService.shared
    @ObservedObject var sharedGoalService = SharedGoalService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDate: Date = Date()
    @State private var selectedActivities: Set<String> = []
    @State private var durationMinutes: Int = 45
    @State private var customDurationInput: String = "45"
    @State private var note: String = ""
    @State private var isExistingEntry: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var errorMessage: String? = nil
    @State private var currentLogId: String?
    @State private var loadedSharedLog: DailyLog?
    
    // Evidence State
    @State private var selectedEvidenceImage: UIImage? = nil
    @State private var evidenceCaption: String = ""
    @State private var existingEvidenceItems: [EvidenceItem] = []
    @State private var evidenceToRemoveIds: Set<String> = []
    @State private var isSaving: Bool = false
    
    private let presetDurations = [15, 30, 45, 60, 90, 120]
    
    init(
        goal: PACEGoal,
        initialDate: Date = Date(),
        sharedGoalId: String? = nil,
        onSaved: (() -> Void)? = nil
    ) {
        self.goal = goal
        self.sharedGoalId = sharedGoalId
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
                        .onChange(of: selectedDate) {
                            if let sharedGoalId {
                                loadedSharedLog = nil
                                Task {
                                    do {
                                        loadedSharedLog = try await sharedGoalService.fetchLog(for: sharedGoalId, date: selectedDate)
                                    } catch {
                                        errorMessage = error.localizedDescription
                                    }
                                    checkExistingLog()
                                }
                            } else {
                                checkExistingLog()
                            }
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
                        existingEvidenceItems: existingEvidenceItems.filter {
                            !evidenceToRemoveIds.contains($0.id)
                        },
                        onRemoveExistingEvidence: { item in
                            evidenceToRemoveIds.insert(item.id)
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
            .task {
                for evidenceGoalId in evidenceGoalIds {
                    _ = await evidenceService.fetchEvidence(for: evidenceGoalId)
                }
                if let sharedGoalId {
                    do {
                        loadedSharedLog = try await sharedGoalService.fetchLog(for: sharedGoalId, date: selectedDate)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
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
                    let logId = currentLogId ?? dString
                    Task {
                        do {
                            if let sharedGoalId {
                                try await sharedGoalService.deleteLog(goalId: sharedGoalId, logId: logId)
                            } else {
                                try await logService.deleteLog(id: dString, goalId: goal.id)
                            }
                            onSaved?()
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
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
        evidenceToRemoveIds = []
        selectedEvidenceImage = nil

        let existing: DailyLog?
        if let sharedGoalId {
            let uid = AuthService.shared.currentUser?.id
            existing = loadedSharedLog ?? (sharedGoalService.logsByGoal[sharedGoalId] ?? [])
                .filter { $0.authorId == uid && $0.dateString == dString }
                .sorted { $0.id < $1.id }
                .first
        } else {
            existing = logService.fetchLog(for: goal.id, date: selectedDate)
        }

        currentLogId = existing?.id
        if let existing {
            isExistingEntry = true
            selectedActivities = Set(existing.selectedActivities)
            durationMinutes = existing.durationMinutes
            customDurationInput = "\(existing.durationMinutes)"
            note = existing.note ?? ""
            existingEvidenceItems = loadEvidenceItems(
                logId: existing.sourceLogId ?? existing.id,
                dateString: dString
            )
        } else {
            isExistingEntry = false
            existingEvidenceItems = loadEvidenceItems(logId: dString, dateString: dString)
        }
        evidenceCaption = ""
    }

    private var evidenceGoalIds: [String] {
        var ids = [goal.id]
        if let sharedGoalId,
           let sourceGoalId = sharedGoalService.goals.first(where: { $0.id == sharedGoalId })?.sourceGoalId,
           !ids.contains(sourceGoalId) {
            ids.append(sourceGoalId)
        }
        return ids
    }

    private func loadEvidenceItems(logId: String, dateString: String) -> [EvidenceItem] {
        var items: [EvidenceItem] = []
        for evidenceGoalId in evidenceGoalIds {
            items.append(contentsOf: evidenceService.fetchEvidenceItems(forGoal: evidenceGoalId, logId: logId))
            if logId != dateString {
                items.append(contentsOf: evidenceService.fetchEvidenceItems(forGoal: evidenceGoalId, logId: dateString))
            }
        }
        var seenIds = Set<String>()
        return items
            .filter { seenIds.insert($0.id).inserted }
            .sorted {
                if $0.createdAt == $1.createdAt { return $0.id < $1.id }
                return $0.createdAt < $1.createdAt
            }
    }
    
    
    private func submitLog() {
        errorMessage = nil
        if sharedGoalId == nil && sharedGoalService.sourceGoalIdsInProgress.contains(goal.id) {
            errorMessage = "This goal is paused while its shared copy is being prepared."
            return
        }
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
                let savedLog = try await persistLog(
                    date: selectedDate,
                    selectedActivities: Array(selectedActivities),
                    durationMinutes: durationMinutes,
                    note: note.isEmpty ? nil : note
                )

                for item in existingEvidenceItems where evidenceToRemoveIds.contains(item.id) {
                    try? await evidenceService.deleteEvidence(item)
                }

                if let imageToUpload = selectedEvidenceImage {
                    do {
                        let evidenceItem = try await evidenceService.saveEvidence(
                            goalId: evidenceGoalId(for: savedLog),
                            logId: savedLog.sourceLogId ?? savedLog.id,
                            image: imageToUpload,
                            caption: evidenceCaption.isEmpty ? nil : evidenceCaption
                        )
                        _ = try await persistLog(
                            date: selectedDate,
                            selectedActivities: Array(selectedActivities),
                            durationMinutes: durationMinutes,
                            note: note.isEmpty ? nil : note,
                            evidenceId: evidenceItem.id
                        )
                    } catch {
                        errorMessage = "Log saved, but photo evidence could not be attached: \(error.localizedDescription)"
                        onSaved?()
                        return
                    }
                } else if let referencedEvidenceId = savedLog.evidenceId,
                          evidenceToRemoveIds.contains(referencedEvidenceId) {
                    let retainedEvidence = existingEvidenceItems.first {
                        !evidenceToRemoveIds.contains($0.id)
                    }
                    _ = try await persistLog(
                        date: selectedDate,
                        selectedActivities: Array(selectedActivities),
                        durationMinutes: durationMinutes,
                        note: note.isEmpty ? nil : note,
                        evidenceId: retainedEvidence?.id,
                        clearEvidenceReference: retainedEvidence == nil
                    )
                }

                onSaved?()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func persistLog(
        date: Date,
        selectedActivities: [String],
        durationMinutes: Int,
        note: String?,
        evidenceId: String? = nil,
        clearEvidenceReference: Bool = false
    ) async throws -> DailyLog {
        if let sharedGoalId {
            return try await sharedGoalService.saveLog(
                goalId: sharedGoalId,
                date: date,
                selectedActivities: selectedActivities,
                durationMinutes: durationMinutes,
                note: note,
                evidenceId: evidenceId,
                clearEvidenceReference: clearEvidenceReference
            )
        }
        return try await logService.saveLog(
            goalId: goal.id,
            date: date,
            selectedActivities: selectedActivities,
            durationMinutes: durationMinutes,
            note: note,
            evidenceId: evidenceId,
            clearEvidenceReference: clearEvidenceReference
        )
    }

    private func evidenceGoalId(for log: DailyLog) -> String {
        guard log.sourceLogId != nil,
              let sharedGoalId,
              let sourceGoalId = sharedGoalService.goals.first(where: { $0.id == sharedGoalId })?.sourceGoalId else {
            return goal.id
        }
        return sourceGoalId
    }
}
