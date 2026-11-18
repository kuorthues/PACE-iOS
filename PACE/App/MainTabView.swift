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

struct MainTabView: View {
    @State private var selectedTab: PACETab = .goals
    @State private var deepLinkedGoal: PACEGoal? = nil
    @State private var deepLinkedLogGoal: PACEGoal? = nil
    
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
        .sheet(item: $deepLinkedGoal) { goal in
            NavigationStack {
                GoalDetailView(goal: goal)
            }
        }
        .sheet(item: $deepLinkedLogGoal) { goal in
            LogProgressView(goal: goal) {
                Task {
                    await GoalService.shared.fetchActiveGoals()
                    PACEWidgetSyncService.shared.syncPrimaryGoal(
                        goals: GoalService.shared.goals,
                        logsByGoal: DailyLogService.shared.logsByGoal
                    )
                }
            }
        }
        .onOpenURL { url in
            handleDeepLink(url: url)
        }
    }
    
    private func handleDeepLink(url: URL) {
        guard url.scheme == "pace" else { return }
        
        let host = url.host ?? url.path
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let goalId = queryItems.first(where: { $0.name == "id" || $0.name == "goalId" })?.value
        
        selectedTab = .goals
        
        let isLogDeepLink = host == "log" || url.path == "/log"
        let isGoalDeepLink = host == "goal" || url.path == "/goal"
        guard let goalId, isLogDeepLink || isGoalDeepLink else { return }

        func present(_ goal: PACEGoal) {
            if isLogDeepLink {
                deepLinkedLogGoal = goal
            } else {
                deepLinkedGoal = goal
            }
        }

        if let found = GoalService.shared.goals.first(where: { $0.id == goalId }) {
            present(found)
        } else {
            Task {
                await GoalService.shared.fetchActiveGoals()
                if let found = GoalService.shared.goals.first(where: { $0.id == goalId }) {
                    present(found)
                }
            }
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
