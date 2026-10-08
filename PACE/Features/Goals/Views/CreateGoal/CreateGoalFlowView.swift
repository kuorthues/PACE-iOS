//
//  CreateGoalFlowView.swift
//  PACE
//
//  Four-step goal creation flow matching Figma prototype:
//  - Top row: ← BACK | NEW GOAL 0X / 04 | CANCEL
//  - Step 1: WHAT ARE YOU WORKING TOWARD? / NAME YOUR GOAL
//  - Step 2: WHEN DOES IT MATTER? / Huge #A7FF19 date / XX DAYS FROM TODAY
//  - Step 3: WHAT COUNTS AS SHOWING UP? / YOUR ACTIVITIES / Square checkboxes + dividers
//  - Step 4: HOW OFTEN WILL YOU SHOW UP? / YOUR SCHEDULE / Square selectors
//  - GOAL CREATED: P A C E / GOAL CREATED / Huge #A7FF19 days / START TODAY. / CTAs
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
    @State private var targetDate: Date = Calendar.current.date(byAdding: .day, value: 43, to: Date()) ?? Date()
    
    // Step 3: Activity Types
    @State private var availableActivities: [String] = ["Study", "Review", "Practice", "Mock Exam"]
    @State private var selectedActivities: Set<String> = ["Study"]
    @State private var customActivityInput: String = ""
    
    // Step 4: Schedule
    enum ScheduleType: String, CaseIterable {
        case everyDay = "EVERY DAY"
        case weekdays = "WEEKDAYS"
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
        VStack(spacing: 0) {
            if currentStep <= 4 {
                // Fixed Figma Top Navigation Bar
                stepTopBar
                
                // Thin Divider
                Rectangle()
                    .fill(PACETheme.border)
                    .frame(height: 1)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Error message banner
                    if let error = errorMessage {
                        HStack(spacing: 8) {
                            Rectangle()
                                .fill(PACETheme.accent)
                                .frame(width: 3)
                            Text(error)
                                .font(PACETypography.body())
                                .foregroundColor(PACETheme.primaryText)
                        }
                        .padding(12)
                        .background(PACETheme.surface)
                        .overlay(
                            Rectangle().stroke(PACETheme.border, lineWidth: 1)
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
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
                }
            }
        }
        .background(PACETheme.background.ignoresSafeArea())
    }
    
    // MARK: - Top Navigation Bar (Figma Parity)
    
    private var stepTopBar: some View {
        HStack {
            Button(action: {
                if currentStep > 1 {
                    errorMessage = nil
                    currentStep -= 1
                } else {
                    dismiss()
                }
            }) {
                Text("← BACK")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(PACETheme.secondaryText)
                    .tracking(1.0)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text(String(format: "NEW GOAL %02d / 04", currentStep))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(PACETheme.accent)
                .tracking(2.0)
            
            Spacer()
            
            Button(action: {
                dismiss()
            }) {
                Text("CANCEL")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(PACETheme.secondaryText)
                    .tracking(1.0)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    // MARK: - Step 1: Title
    
    private var step1TitleView: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("WHAT ARE YOU WORKING TOWARD?")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(PACETheme.secondaryText)
                    .tracking(1.5)
                
                Text("NAME YOUR\nGOAL")
                    .font(PACETextStyle.displayLarge)
                    .foregroundColor(PACETheme.primaryText)
                    .lineSpacing(-4)
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
            
            VStack(alignment: .leading, spacing: 8) {
                PACETextField(
                    placeholder: "E.G. PASS AZ-900 CERTIFICATION",
                    text: $title,
                    label: "GOAL TITLE"
                )
                
                Text("Be specific. The more real it feels, the more it matters.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(PACETheme.secondaryText)
                    .padding(.top, 4)
            }
            .padding(.top, 32)
            .padding(.horizontal, 24)
            
            Spacer(minLength: 120)
            
            VStack {
                PACEButton(
                    title: "CONTINUE →",
                    variant: .primary,
                    isEnabled: !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    errorMessage = nil
                    currentStep = 2
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Step 2: Target Date
    
    private var step2DateView: some View {
        let days = calculatedDaysRemaining
        let formattedDate = formattedTargetDate
        
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("WHEN DOES IT MATTER?")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(PACETheme.secondaryText)
                    .tracking(1.5)
                
                // Huge selected date using #A7FF19
                Text(formattedDate)
                    .font(.system(size: 36, weight: .black, design: .monospaced))
                    .foregroundColor(PACETheme.accent)
                    .tracking(1.0)
                    .padding(.top, 4)
                
                Text("\(days) DAYS FROM TODAY")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(PACETheme.secondaryText)
                    .tracking(1.5)
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
            
            // Native accessible date picker styled cleanly
            VStack(alignment: .leading, spacing: 8) {
                DatePicker(
                    "",
                    selection: $targetDate,
                    in: Calendar.current.date(byAdding: .day, value: 1, to: Date())!...,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .colorScheme(.dark)
                .tint(PACETheme.accent)
                .padding(12)
                .background(PACETheme.surface)
                .overlay(
                    Rectangle().stroke(PACETheme.border, lineWidth: 1)
                )
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
            
            Spacer(minLength: 40)
            
            VStack {
                PACEButton(
                    title: "CONTINUE →",
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
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
    
    private var formattedTargetDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd yyyy"
        return formatter.string(from: targetDate).uppercased()
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
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("WHAT COUNTS AS SHOWING UP?")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(PACETheme.secondaryText)
                    .tracking(1.5)
                
                Text("YOUR\nACTIVITIES")
                    .font(PACETextStyle.displayLarge)
                    .foregroundColor(PACETheme.primaryText)
                    .lineSpacing(-4)
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
            
            // Activity rows separated by thin dividers
            VStack(spacing: 0) {
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
                            Text(activity.uppercased())
                                .font(.system(size: 15, weight: isSelected ? .bold : .medium, design: .monospaced))
                                .foregroundColor(isSelected ? PACETheme.primaryText : PACETheme.secondaryText)
                            
                            Spacer()
                            
                            PACECheckbox(isSelected: isSelected) {
                                if isSelected {
                                    selectedActivities.remove(activity)
                                } else {
                                    selectedActivities.insert(activity)
                                }
                            }
                        }
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                    
                    Rectangle()
                        .fill(PACETheme.border)
                        .frame(height: 1)
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 24)
            
            // Custom Activity Input
            VStack(alignment: .leading, spacing: 10) {
                Text("ADD CUSTOM ACTIVITY")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(PACETheme.secondaryText)
                    .tracking(1.5)
                    .padding(.top, 20)
                
                HStack(spacing: 8) {
                    PACETextField(
                        placeholder: "E.G. CODING, FLASHCARDS",
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
                    .frame(width: 80)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer(minLength: 40)
            
            VStack {
                PACEButton(
                    title: "CONTINUE →",
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
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Step 4: Schedule
    
    private var step4ScheduleView: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("HOW OFTEN WILL YOU SHOW UP?")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(PACETheme.secondaryText)
                    .tracking(1.5)
                
                Text("YOUR\nSCHEDULE")
                    .font(PACETextStyle.displayLarge)
                    .foregroundColor(PACETheme.primaryText)
                    .lineSpacing(-4)
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
            
            // Schedule preset rows separated by thin dividers
            VStack(spacing: 0) {
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
                            Text(type.rawValue)
                                .font(.system(size: 15, weight: isSelected ? .bold : .medium, design: .monospaced))
                                .foregroundColor(isSelected ? PACETheme.primaryText : PACETheme.secondaryText)
                            
                            Spacer()
                            
                            // Square selector
                            Rectangle()
                                .fill(isSelected ? PACETheme.accent : Color.clear)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Rectangle().stroke(isSelected ? PACETheme.accent : PACETheme.border, lineWidth: 1)
                                )
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .black))
                                        .foregroundColor(PACETheme.background)
                                        .opacity(isSelected ? 1.0 : 0.0)
                                )
                        }
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                    
                    Rectangle()
                        .fill(PACETheme.border)
                        .frame(height: 1)
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 24)
            
            // Custom Weekday Checkboxes
            if scheduleType == .custom {
                VStack(alignment: .leading, spacing: 10) {
                    Text("SELECT WEEKDAYS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(PACETheme.secondaryText)
                        .tracking(1.5)
                        .padding(.top, 16)
                    
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
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(isDaySelected ? PACETheme.accent : PACETheme.surface)
                                    .foregroundColor(isDaySelected ? PACETheme.background : PACETheme.secondaryText)
                                    .overlay(
                                        Rectangle()
                                            .stroke(isDaySelected ? PACETheme.accent : PACETheme.border, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            
            Spacer(minLength: 40)
            
            VStack {
                PACEButton(
                    title: goalService.isLoading ? "CREATING..." : "CREATE GOAL →",
                    variant: .primary,
                    isEnabled: !goalService.isLoading && !selectedWeekdays.isEmpty
                ) {
                    submitGoalCreation()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Goal Created Confirmation View
    
    private var goalCreatedConfirmationView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                Text("P A C E")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(PACETheme.accent)
                    .tracking(3.0)
                    .padding(.top, 16)
                
                Text("GOAL CREATED")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(PACETheme.secondaryText)
                    .tracking(2.0)
            }
            .padding(.horizontal, 24)
            
            Spacer(minLength: 24)
            
            // Goal Content
            VStack(alignment: .leading, spacing: 16) {
                if let goal = createdGoal {
                    Text(goal.title.uppercased())
                        .font(PACETextStyle.displayMedium)
                        .foregroundColor(PACETheme.primaryText)
                    
                    // Huge #A7FF19 Days Remaining
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(goal.daysRemaining)")
                            .font(.system(size: 64, weight: .black, design: .monospaced))
                            .foregroundColor(PACETheme.accent)
                            .tracking(1.0)
                        
                        Text("DAYS.")
                            .font(PACETextStyle.displayLarge)
                            .foregroundColor(PACETheme.primaryText)
                            .lineSpacing(-4)
                    }
                    .padding(.vertical, 8)
                }
                
                Text("START TODAY.")
                    .font(PACETextStyle.displayLarge)
                    .foregroundColor(PACETheme.primaryText)
                    .lineSpacing(-4)
            }
            .padding(.horizontal, 24)
            
            Spacer(minLength: 32)
            
            // Action Buttons
            VStack(spacing: 12) {
                PACEButton(
                    title: "LOG FIRST DAY →",
                    variant: .primary
                ) {
                    if let goal = createdGoal {
                        onLogFirstDay?(goal)
                    }
                    dismiss()
                }
                
                PACEButton(
                    title: "GO TO DASHBOARD →",
                    variant: .secondary
                ) {
                    onFinish?()
                    dismiss()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
