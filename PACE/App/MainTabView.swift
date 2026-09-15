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
        
        if host == "goal" || url.path == "/goal" {
            if let goalId = goalId,
               let found = GoalService.shared.goals.first(where: { $0.id == goalId }) {
                deepLinkedGoal = found
            }
        } else if host == "log" || url.path == "/log" {
            if let goalId = goalId,
               let found = GoalService.shared.goals.first(where: { $0.id == goalId }) {
                deepLinkedLogGoal = found
            }
        }
    }
    
    private var customTabBar: some View {
        VStack(spacing: 0) {
            // Sharp 1px top border
            Rectangle()
                .fill(PACEColor.border)
                .frame(height: 1)
            
            HStack(spacing: 0) {
                ForEach(PACETab.allCases) { tab in
                    Button(action: {
                        selectedTab = tab
                    }) {
                        VStack(spacing: 5) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 18, weight: selectedTab == tab ? .bold : .regular))
                            
                            Text(tab.rawValue.uppercased())
                                .font(.system(size: 10, weight: selectedTab == tab ? .bold : .medium))
                                .tracking(0.8)
                        }
                        .foregroundColor(selectedTab == tab ? PACEColor.accent : PACEColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(PACEColor.background)
                        .overlay(alignment: .top) {
                            if selectedTab == tab {
                                Rectangle()
                                    .fill(PACEColor.accent)
                                    .frame(height: 2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(PACEColor.background)
        }
        .background(PACEColor.background.ignoresSafeArea(edges: .bottom))
    }
}
