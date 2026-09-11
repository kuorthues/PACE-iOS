//
//  EditGoalView.swift
//  PACE
//
//  Screen allowing users to edit an existing goal's title, target date, activities, and schedule.
//

import SwiftUI

struct EditGoalView: View {
    @ObservedObject var goalService = GoalService.shared
    @Environment(\.dismiss) private var dismiss
    
    let goal: PACEGoal
    var onUpdated: ((PACEGoal) -> Void)? = nil
    
    @State private var title: String
    @State private var targetDate: Date
    @State private var selectedActivities: Set<String>
    @State private var customActivityInput: String = ""
    @State private var availableActivities: [String]
    @State private var selectedWeekdays: Set<Int>
    @State private var errorMessage: String? = nil
    
    private let weekdayNames: [(name: String, id: Int)] = [
        ("MON", 2), ("TUE", 3), ("WED", 4), ("THU", 5), ("FRI", 6), ("SAT", 7), ("SUN", 1)
    ]
    
    init(goal: PACEGoal, onUpdated: ((PACEGoal) -> Void)? = nil) {
        self.goal = goal
        self.onUpdated = onUpdated
        _title = State(initialValue: goal.title)
        _targetDate = State(initialValue: goal.targetDate)
        _selectedActivities = State(initialValue: Set(goal.activityTypes))
        
        var defaults = ["Study", "Review", "Practice", "Mock Exam"]
        for act in goal.activityTypes where !defaults.contains(act) {
            defaults.append(act)
        }
        _availableActivities = State(initialValue: defaults)
        _selectedWeekdays = State(initialValue: Set(goal.scheduledWeekdays))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
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
                    
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("GOAL TITLE")
                            .font(PACETypography.caption())
                            .foregroundColor(PACEColor.textSecondary)
                        
                        PACETextField(
                            placeholder: "Goal Title",
                            text: $title
                        )
                    }
                    
                    PACEDivider()
                    
                    // Target Date
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TARGET DATE")
                            .font(PACETypography.caption())
                            .foregroundColor(PACEColor.textSecondary)
                        
                        DatePicker(
                            "Target Date",
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
                    
                    PACEDivider()
                    
                    // Activities
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ACTIVITY TYPES")
                            .font(PACETypography.caption())
                            .foregroundColor(PACEColor.textSecondary)
                        
                        ForEach(availableActivities, id: \.self) { activity in
                            let isSelected = selectedActivities.contains(activity)
                            Button(action: {
                                if isSelected {
                                    if selectedActivities.count > 1 {
                                        selectedActivities.remove(activity)
                                    }
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
                    
                    // Schedule Weekdays
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SCHEDULED WEEKDAYS")
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
                    
                    PACEDivider()
                    
                    // Save Button
                    PACEButton(
                        title: goalService.isLoading ? "SAVING..." : "SAVE CHANGES",
                        icon: "checkmark",
                        variant: .primary,
                        isEnabled: !goalService.isLoading
                    ) {
                        submitUpdate()
                    }
                }
                .padding(20)
            }
            .background(PACEColor.background.ignoresSafeArea())
            .navigationTitle("EDIT GOAL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
    
    private func submitUpdate() {
        errorMessage = nil
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Goal title cannot be empty."
            return
        }
        
        guard Calendar.current.startOfDay(for: targetDate) > Calendar.current.startOfDay(for: Date()) else {
            errorMessage = "Target date must be in the future."
            return
        }
        
        guard !selectedActivities.isEmpty else {
            errorMessage = "At least one activity type must be selected."
            return
        }
        
        var updatedGoal = goal
        updatedGoal.title = trimmedTitle
        updatedGoal.targetDate = targetDate
        updatedGoal.activityTypes = Array(selectedActivities)
        updatedGoal.scheduledWeekdays = Array(selectedWeekdays)
        
        Task {
            do {
                try await goalService.updateGoal(updatedGoal)
                onUpdated?(updatedGoal)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
