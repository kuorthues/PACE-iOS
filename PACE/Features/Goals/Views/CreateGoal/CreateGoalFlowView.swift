//
//  CreateGoalFlowView.swift
//  PACE
//
//  Four-step goal creation flow:
//  Step 1: Goal Title
//  Step 2: Future Target Date
//  Step 3: Activity Types (Study, Review, Practice, Mock Exam + Custom)
//  Step 4: Schedule (Every Day, Weekdays, Custom Weekdays)
//  Confirmation: Days remaining, "Log First Day" or "Go to Dashboard"
//

import SwiftUI

struct CreateGoalFlowView: View {
    @ObservedObject var goalService = GoalService.shared
    @Environment(\.dismiss) private var dismiss
    
    var onLogFirstDay: ((PACEGoal) -> Void)? = nil
    var onFinish: (() -> Void)? = nil
    
    @State private var currentStep: Int = 1
    
    // Step 1: Title
    @State private var title: String = ""
    
    // Step 2: Target Date
    @State private var targetDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    
    // Step 3: Activity Types
    @State private var availableActivities: [String] = ["Study", "Review", "Practice", "Mock Exam"]
    @State private var selectedActivities: Set<String> = ["Study"]
    @State private var customActivityInput: String = ""
    
    // Step 4: Schedule
    enum ScheduleType: String, CaseIterable {
        case everyDay = "EVERY DAY"
        case weekdays = "WEEKDAYS (MON-FRI)"
        case custom = "CUSTOM"
    }
    @State private var scheduleType: ScheduleType = .everyDay
    @State private var selectedWeekdays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
    
    // Created goal result
    @State private var createdGoal: PACEGoal? = nil
    @State private var errorMessage: String? = nil
    
    private let weekdayNames: [(name: String, id: Int)] = [
        ("MON", 2), ("TUE", 3), ("WED", 4), ("THU", 5), ("FRI", 6), ("SAT", 7), ("SUN", 1)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if currentStep <= 4 {
                        // Step Progress Header
                        HStack {
                            Text("STEP \(currentStep) OF 4")
                                .font(PACETypography.metricSmall())
                                .foregroundColor(PACEColor.accent)
                            Spacer()
                            Text(stepTitle(currentStep).uppercased())
                                .font(PACETypography.caption())
                                .foregroundColor(PACEColor.textSecondary)
                        }
                        .padding(.top, 8)
                        
                        // Sharp Step Progress Bar
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(PACEColor.surfaceElevated)
                                    .frame(height: 4)
                                Rectangle()
                                    .fill(PACEColor.accent)
                                    .frame(width: proxy.size.width * (CGFloat(currentStep) / 4.0), height: 4)
                            }
                        }
                        .frame(height: 4)
                        
                        PACEDivider()
                    }
                    
                    // Error message
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
                    
                    // Step Content
                    Group {
                        switch currentStep {
                        case 1:
                            step1TitleView
                        case 2:
                            step2DateView
                        case 3:
                            step3ActivitiesView
                        case 4:
                            step4ScheduleView
                        default:
                            goalCreatedConfirmationView
                        }
                    }
                    
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 20)
            }
            .background(PACEColor.background.ignoresSafeArea())
            .navigationTitle(currentStep <= 4 ? "NEW GOAL" : "CONFIRMED")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(PACEColor.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if currentStep <= 4 {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("CANCEL") {
                            dismiss()
                        }
                        .font(PACETypography.caption())
                        .foregroundColor(PACEColor.textSecondary)
                    }
                }
            }
        }
    }
    
    private func stepTitle(_ step: Int) -> String {
        switch step {
        case 1: return "Goal Title"
        case 2: return "Target Date"
        case 3: return "Activity Types"
        case 4: return "Schedule"
        default: return "Confirmation"
        }
    }
    
    // MARK: - Step 1: Title
    private var step1TitleView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("WHAT ARE YOU WORKING TOWARDS?")
                .font(PACETypography.titleLarge())
                .foregroundColor(PACEColor.textPrimary)
            
            Text("Define a specific, measurable objective you will show up for.")
                .font(PACETypography.body())
                .foregroundColor(PACEColor.textSecondary)
            
            PACETextField(
                placeholder: "e.g., Board Exam 2027, iOS Portfolio, JLPT N3",
                text: $title,
                label: "Goal Title"
            )
            
            PACEButton(
                title: "CONTINUE TO TARGET DATE",
                icon: "arrow.right",
                variant: .primary,
                isEnabled: !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                errorMessage = nil
                currentStep = 2
            }
            .padding(.top, 10)
        }
    }
    
    // MARK: - Step 2: Target Date
    private var step2DateView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SET THE TARGET DATE")
                .font(PACETypography.titleLarge())
                .foregroundColor(PACEColor.textPrimary)
            
            Text("Select the deadline for this goal. Target date must be in the future.")
                .font(PACETypography.body())
                .foregroundColor(PACEColor.textSecondary)
            
            // Computed Days Remaining Metric
            let days = calculatedDaysRemaining
            PACEMetricView(
                label: "Countdown to Target",
                value: String(format: "%02d", max(0, days)),
                unit: "DAYS REMAINING",
                isAccentValue: true
            )
            
            VStack(alignment: .leading, spacing: 8) {
                Text("DEADLINE DATE")
                    .font(PACETypography.caption())
                    .foregroundColor(PACEColor.textSecondary)
                
                DatePicker(
                    "",
                    selection: $targetDate,
                    in: Calendar.current.date(byAdding: .day, value: 1, to: Date())!...,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .colorScheme(.dark)
                .tint(PACEColor.accent)
                .padding(12)
                .paceCard()
            }
            
            HStack(spacing: 12) {
                PACEButton(
                    title: "BACK",
                    variant: .secondary,
                    isFullWidth: false
                ) {
                    errorMessage = nil
                    currentStep = 1
                }
                
                PACEButton(
                    title: "SELECT ACTIVITIES",
                    icon: "arrow.right",
                    variant: .primary,
                    isEnabled: days > 0
                ) {
                    if days <= 0 {
                        errorMessage = "Target date must be in the future."
                    } else {
                        errorMessage = nil
                        currentStep = 3
                    }
                }
            }
            .padding(.top, 10)
        }
    }
    
    private var calculatedDaysRemaining: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTarget = calendar.startOfDay(for: targetDate)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfTarget)
        return max(0, components.day ?? 0)
    }
    
    // MARK: - Step 3: Activity Types
    private var step3ActivitiesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SELECT ACTIVITY TYPES")
                .font(PACETypography.titleLarge())
                .foregroundColor(PACEColor.textPrimary)
            
            Text("Choose the methods and activities you will use to log proof towards this goal.")
                .font(PACETypography.body())
                .foregroundColor(PACEColor.textSecondary)
            
            // Available Activity Checkboxes
            VStack(spacing: 10) {
                ForEach(availableActivities, id: \.self) { activity in
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
                                .frame(width: 18, height: 18)
                                .overlay(
                                    Rectangle()
                                        .stroke(isSelected ? PACEColor.accent : PACEColor.border, lineWidth: 1)
                                )
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .black))
                                        .foregroundColor(PACEColor.background)
                                        .opacity(isSelected ? 1.0 : 0.0)
                                )
                            
                            Text(activity.uppercased())
                                .font(PACETypography.body())
                                .foregroundColor(PACEColor.textPrimary)
                            
                            Spacer()
                        }
                        .padding(14)
                        .paceCard(borderColor: isSelected ? PACEColor.accent : PACEColor.border)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Custom Activity Input
            VStack(alignment: .leading, spacing: 8) {
                Text("ADD CUSTOM ACTIVITY")
                    .font(PACETypography.caption())
                    .foregroundColor(PACEColor.textSecondary)
                
                HStack(spacing: 8) {
                    PACETextField(
                        placeholder: "e.g., Coding, Flashcards",
                        text: $customActivityInput
                    )
                    
                    PACEButton(
                        title: "ADD",
                        variant: .secondary,
                        isFullWidth: false,
                        isEnabled: !customActivityInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ) {
                        let trimmed = customActivityInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty && !availableActivities.contains(trimmed) {
                            availableActivities.append(trimmed)
                            selectedActivities.insert(trimmed)
                            customActivityInput = ""
                        }
                    }
                }
            }
            
            HStack(spacing: 12) {
                PACEButton(
                    title: "BACK",
                    variant: .secondary,
                    isFullWidth: false
                ) {
                    errorMessage = nil
                    currentStep = 2
                }
                
                PACEButton(
                    title: "CONFIGURE SCHEDULE",
                    icon: "arrow.right",
                    variant: .primary,
                    isEnabled: !selectedActivities.isEmpty
                ) {
                    if selectedActivities.isEmpty {
                        errorMessage = "At least one activity type must be selected."
                    } else {
                        errorMessage = nil
                        currentStep = 4
                    }
                }
            }
            .padding(.top, 10)
        }
    }
    
    // MARK: - Step 4: Schedule
    private var step4ScheduleView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("COMMITMENT SCHEDULE")
                .font(PACETypography.titleLarge())
                .foregroundColor(PACEColor.textPrimary)
            
            Text("Define on which days you are expected to log evidence.")
                .font(PACETypography.body())
                .foregroundColor(PACEColor.textSecondary)
            
            // Preset schedule choices
            VStack(spacing: 10) {
                ForEach(ScheduleType.allCases, id: \.self) { type in
                    let isSelected = (scheduleType == type)
                    Button(action: {
                        scheduleType = type
                        switch type {
                        case .everyDay:
                            selectedWeekdays = [1, 2, 3, 4, 5, 6, 7]
                        case .weekdays:
                            selectedWeekdays = [2, 3, 4, 5, 6]
                        case .custom:
                            break
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
                            
                            Text(type.rawValue)
                                .font(PACETypography.body())
                                .foregroundColor(PACEColor.textPrimary)
                            
                            Spacer()
                        }
                        .padding(14)
                        .paceCard(borderColor: isSelected ? PACEColor.accent : PACEColor.border)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Custom Weekday Checkboxes if Custom selected
            if scheduleType == .custom {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SELECT WEEKDAYS")
                        .font(PACETypography.caption())
                        .foregroundColor(PACEColor.textSecondary)
                    
                    HStack(spacing: 6) {
                        ForEach(weekdayNames, id: \.id) { day in
                            let isDaySelected = selectedWeekdays.contains(day.id)
                            Button(action: {
                                if isDaySelected {
                                    if selectedWeekdays.count > 1 {
                                        selectedWeekdays.remove(day.id)
                                    }
                                } else {
                                    selectedWeekdays.insert(day.id)
                                }
                            }) {
                                Text(day.name)
                                    .font(PACETypography.metricSmall())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(isDaySelected ? PACEColor.accent : PACEColor.surfaceElevated)
                                    .foregroundColor(isDaySelected ? PACEColor.background : PACEColor.textSecondary)
                                    .overlay(
                                        Rectangle()
                                            .stroke(isDaySelected ? PACEColor.accent : PACEColor.border, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.top, 4)
            }
            
            HStack(spacing: 12) {
                PACEButton(
                    title: "BACK",
                    variant: .secondary,
                    isFullWidth: false
                ) {
                    errorMessage = nil
                    currentStep = 3
                }
                
                PACEButton(
                    title: goalService.isLoading ? "CREATING..." : "CREATE GOAL",
                    icon: goalService.isLoading ? nil : "checkmark.square",
                    variant: .primary,
                    isEnabled: !goalService.isLoading && !selectedWeekdays.isEmpty
                ) {
                    submitGoalCreation()
                }
            }
            .padding(.top, 10)
        }
    }
    
    // MARK: - Confirmation Screen
    private var goalCreatedConfirmationView: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(PACEColor.accent)
                    .frame(width: 8, height: 28)
                Text("GOAL CREATED")
                    .font(PACETypography.titleLarge())
                    .foregroundColor(PACEColor.textPrimary)
            }
            
            Text("Your commitment is locked in. Show up consistently and keep the proof.")
                .font(PACETypography.body())
                .foregroundColor(PACEColor.textSecondary)
            
            if let goal = createdGoal {
                VStack(alignment: .leading, spacing: 12) {
                    Text(goal.title.uppercased())
                        .font(PACETypography.sectionHeader())
                        .foregroundColor(PACEColor.textPrimary)
                    
                    PACEDivider()
                    
                    HStack(spacing: 12) {
                        PACEMetricView(
                            label: "Days Remaining",
                            value: String(format: "%02d", goal.daysRemaining),
                            unit: "DAYS",
                            isAccentValue: true
                        )
                        
                        PACEMetricView(
                            label: "Schedule",
                            value: goal.scheduleDescription,
                            unit: nil
                        )
                    }
                }
                .padding(16)
                .paceCard()
            }
            
            PACEDivider()
            
            VStack(spacing: 12) {
                PACEButton(
                    title: "LOG FIRST DAY",
                    icon: "plus.square",
                    variant: .primary
                ) {
                    if let goal = createdGoal {
                        onLogFirstDay?(goal)
                    }
                    dismiss()
                }
                
                PACEButton(
                    title: "GO TO DASHBOARD",
                    variant: .secondary
                ) {
                    onFinish?()
                    dismiss()
                }
            }
        }
    }
    
    private func submitGoalCreation() {
        errorMessage = nil
        Task {
            do {
                let created = try await goalService.createGoal(
                    title: title,
                    targetDate: targetDate,
                    activityTypes: Array(selectedActivities),
                    scheduledWeekdays: Array(selectedWeekdays)
                )
                self.createdGoal = created
                self.currentStep = 5
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
