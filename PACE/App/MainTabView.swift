//
//  MainTabView.swift
//  PACE
//
//  Root application shell hosting the primary navigation tabs:
//  - Goals
//  - Journey
//  - Insights
//  - Settings
//
//  Adheres strictly to PACE UI rules:
//  - Zero corner radius across all elements (no rounded pills or floating bars)
//  - #A7FF19 active accent
//  - Dark neutral backgrounds with sharp 1px borders
//

import SwiftUI

enum PACETab: String, CaseIterable, Identifiable {
    case goals = "Goals"
    case journey = "Journey"
    case insights = "Insights"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .goals:
            return "target"
        case .journey:
            return "figure.walk"
        case .insights:
            return "chart.bar.xaxis"
        case .settings:
            return "gearshape"
        }
    }

    var selectedIconName: String {
        switch self {
        case .goals:
            return "target"
        case .journey:
            return "figure.walk"
        case .insights:
            return "chart.bar.xaxis"
        case .settings:
            return "gearshape.fill"
        }
    }
}

private enum MainTabWidgetSheet: Identifiable {
    case soloGoal(PACEGoal)
    case soloLog(PACEGoal)
    case sharedGoal(SharedGoal)
    case sharedLog(SharedGoal)

    var id: String {
        switch self {
        case .soloGoal(let goal): return "solo-goal-\(goal.id)"
        case .soloLog(let goal): return "solo-log-\(goal.id)"
        case .sharedGoal(let goal): return "shared-goal-\(goal.id)"
        case .sharedLog(let goal): return "shared-log-\(goal.id)"
        }
    }
}

struct MainTabView: View {
    @ObservedObject private var authService = AuthService.shared
    @EnvironmentObject private var widgetNavigationCoordinator: PACEWidgetNavigationCoordinator
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab: PACETab = .goals
    @State private var deepLinkSheet: MainTabWidgetSheet?
    @State private var deepLinkAlertMessage: String?
    @State private var resolvingRequestId: UUID?
    
    var body: some View {
        Group {
            switch selectedTab {
            case .goals:
                GoalsHomeView()
            case .journey:
                JourneyPlaceholderView()
            case .insights:
                InsightsPlaceholderView()
            case .settings:
                SettingsPlaceholderView()
            }
        }
        .safeAreaInset(edge: .bottom) {
            customTabBar
        }
        .background(PACEColor.background.ignoresSafeArea())
        .sheet(item: $deepLinkSheet) { destination in
            NavigationStack {
                deepLinkSheetContent(destination)
            }
        }
        .task(id: authService.currentUser?.id) {
            await processPendingWidgetLink()
        }
        .onChange(of: widgetNavigationCoordinator.pendingRequest?.id) { _, _ in
            Task { await processPendingWidgetLink() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshWidgetData()
            }
        }
        .alert(
            "PACE",
            isPresented: Binding(
                get: { deepLinkAlertMessage != nil },
                set: { if !$0 { deepLinkAlertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { deepLinkAlertMessage = nil }
        } message: {
            Text(deepLinkAlertMessage ?? "This goal is no longer available.")
        }
    }

    @MainActor
    private func processPendingWidgetLink() async {
        guard let request = widgetNavigationCoordinator.pendingRequest else { return }
        selectedTab = .goals

        switch request.destination {
        case .goals:
            widgetNavigationCoordinator.consume(requestId: request.id)
            return
        case .invalid:
            deepLinkAlertMessage = "This PACE link is invalid or the goal is no longer available."
            widgetNavigationCoordinator.consume(requestId: request.id)
            return
        case .goal, .log:
            break
        }

        guard authService.isAuthenticated,
              let accountId = authService.currentUser?.id,
              resolvingRequestId != request.id else { return }

        resolvingRequestId = request.id
        defer {
            if resolvingRequestId == request.id { resolvingRequestId = nil }
        }

        let destinationSheet: MainTabWidgetSheet?
        switch request.destination {
        case .goal(let goalId, .solo):
            let goal = await resolveSoloGoal(id: goalId)
            destinationSheet = goal.map(MainTabWidgetSheet.soloGoal)
        case .log(let goalId, .solo):
            let goal = await resolveSoloGoal(id: goalId)
            destinationSheet = goal.map(MainTabWidgetSheet.soloLog)
        case .goal(let goalId, .shared):
            let goal = await resolveSharedGoal(id: goalId, accountId: accountId)
            destinationSheet = goal.map(MainTabWidgetSheet.sharedGoal)
        case .log(let goalId, .shared):
            let goal = await resolveSharedGoal(id: goalId, accountId: accountId)
            destinationSheet = goal.map(MainTabWidgetSheet.sharedLog)
        case .goals, .invalid:
            destinationSheet = nil
        }

        guard !Task.isCancelled,
              AuthService.shared.currentUser?.id == accountId else { return }
        if let destinationSheet {
            deepLinkSheet = destinationSheet
        } else {
            deepLinkAlertMessage = "This goal is no longer available to your account."
        }
        widgetNavigationCoordinator.consume(requestId: request.id)
    }

    private func resolveSoloGoal(id: String) async -> PACEGoal? {
        var goal = await GoalService.shared.fetchGoal(id: id)
        if goal == nil {
            await GoalService.shared.fetchActiveGoals()
            goal = await GoalService.shared.fetchGoal(id: id)
        }
        guard let goal,
              goal.status == .active,
              goal.userId == AuthService.shared.currentUser?.id else { return nil }
        return goal
    }

    private func resolveSharedGoal(id: String, accountId: String) async -> SharedGoal? {
        guard let goal = await SharedGoalService.shared.fetchGoal(id: id),
              goal.status == .active,
              goal.memberIds.contains(accountId) else { return nil }
        return goal
    }

    @ViewBuilder
    private func deepLinkSheetContent(_ destination: MainTabWidgetSheet) -> some View {
        switch destination {
        case .soloGoal(let goal):
            GoalDetailView(goal: goal)
        case .soloLog(let goal):
            LogProgressView(goal: goal) {
                Task {
                    _ = await DailyLogService.shared.fetchLogs(for: goal.id)
                    PACEWidgetSyncService.shared.requestSync()
                }
            }
        case .sharedGoal(let goal):
            SharedGoalDetailView(goal: goal)
        case .sharedLog(let goal):
            SharedGoalDetailView(goal: goal, openLoggingOnAppear: true)
        }
    }

    private func refreshWidgetData() {
        guard authService.isAuthenticated else {
            PACEWidgetSyncService.shared.clearForSignedOut()
            return
        }
        Task {
            await GoalService.shared.fetchActiveGoals()
            for goal in GoalService.shared.goals {
                _ = await DailyLogService.shared.fetchLogs(for: goal.id)
            }
            PACEWidgetSyncService.shared.requestSync()
        }
    }
    
    private var customTabBar: some View {
        VStack(spacing: 0) {
            // Sharp 1px top border
            Rectangle()
                .fill(PACETheme.border)
                .frame(height: 1)
            
            HStack(spacing: 0) {
                ForEach(PACETab.allCases) { tab in
                    Button(action: {
                        selectedTab = tab
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: selectedTab == tab ? tab.selectedIconName : tab.iconName)
                                .font(.system(size: 16, weight: selectedTab == tab ? .semibold : .regular))
                                .foregroundColor(selectedTab == tab ? PACETheme.accent : PACETheme.secondaryText)
                                .frame(height: 18)
                                .accessibilityHidden(true)

                            Text(tab.rawValue.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(1.3)
                                .foregroundColor(selectedTab == tab ? PACETheme.accent : PACETheme.secondaryText)
                            
                            Rectangle()
                                .fill(selectedTab == tab ? PACETheme.accent : Color.clear)
                                .frame(width: 28, height: 2)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 54)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(tab.rawValue) tab")
                    .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                }
            }
            .background(PACETheme.background)
        }
        .background(PACETheme.background.ignoresSafeArea(edges: .bottom))
    }
}
