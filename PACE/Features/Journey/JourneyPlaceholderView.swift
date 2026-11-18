//
//  JourneyPlaceholderView.swift
//  PACE
//
//  Main Journey tab view hosting the chronological timeline for active goals.

import SwiftUI

struct JourneyPlaceholderView: View {
    @ObservedObject private var goalService = GoalService.shared
    @State private var selectedGoalId: String? = nil
    @State private var isGoalSelectorExpanded = false
    
    private var activeGoals: [PACEGoal] {
        goalService.goals.filter { $0.status == .active }
    }
    
    private var currentGoal: PACEGoal? {
        if let selectedGoalId,
           let selected = activeGoals.first(where: { $0.id == selectedGoalId }) {
            return selected
        }
        return activeGoals.first
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("JOURNEY")
                    .font(PACETextStyle.displayLarge)
                    .foregroundColor(PACETheme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 14)

                if let goal = currentGoal {
                    if activeGoals.count > 1 {
                        goalSelector(for: goal)
                    }

                    JourneyDetailView(goal: goal, showsScreenHeader: false)
                        .id(goal.id)
                } else {
                    emptyState
                }
            }
            .background(PACETheme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await goalService.fetchActiveGoals()
                if selectedGoalId == nil {
                    selectedGoalId = goalService.goals.first?.id
                }
            }
        }
    }

    private func goalSelector(for goal: PACEGoal) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isGoalSelectorExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ACTIVE JOURNEY")
                            .font(PACETextStyle.pixelMetadata)
                            .foregroundColor(PACETheme.secondaryText)
                            .tracking(1.1)
                        Text(goal.title.uppercased())
                            .font(PACETextStyle.displaySmall)
                            .foregroundColor(PACETheme.primaryText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: isGoalSelectorExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(PACETheme.accent)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PACETheme.surface)
                .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select active journey")
            .accessibilityValue(goal.title)

            if isGoalSelectorExpanded {
                VStack(spacing: 0) {
                    ForEach(activeGoals) { option in
                        Button {
                            selectedGoalId = option.id
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isGoalSelectorExpanded = false
                            }
                        } label: {
                            HStack {
                                Text(option.title.uppercased())
                                    .font(PACETextStyle.pixelLabel)
                                    .foregroundColor(option.id == goal.id ? PACETheme.accent : PACETheme.primaryText)
                                    .lineLimit(1)
                                Spacer()
                                if option.id == goal.id {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(PACETheme.accent)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(PACETheme.surfaceElevated)
                            .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open \(option.title) journey")
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("NO ACTIVE JOURNEY")
                    .font(PACETextStyle.displayMedium)
                    .foregroundColor(PACETheme.primaryText)

                Text("Create a target goal to unlock your chronological timeline, daily progress nodes, and verified photographic evidence trail.")
                    .font(PACETextStyle.body)
                    .foregroundColor(PACETheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Rectangle()
                    .fill(PACETheme.border)
                    .frame(height: 1)
            }
            .padding(20)
        }
    }
}
