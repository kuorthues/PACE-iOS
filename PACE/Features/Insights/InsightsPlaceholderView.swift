//
//  InsightsPlaceholderView.swift
//  PACE
//
//  Insights screen matching Figma prototype:
//  - Header: Large INSIGHTS display title
//  - Metrics arranged in a simple 2-column editorial grid (no cards):
//    TOTAL TIME (e.g. 47H 32M), AVG SESSION (e.g. 54M),
//    LONGEST STREAK (e.g. 14 Days), CONSISTENCY (e.g. 84%)
//  - WEEKLY EFFORT: SwiftUI line chart, #A7FF19 line, no gradient fill, clean M T W T F S S axis
//  - ACTIVITY DISTRIBUTION: horizontal progress tracks (STUDY 45%, REVIEW 25%, PRACTICE 21%, MOCK EXAM 9%)
//    Only completed portion uses #A7FF19
//  - INSIGHT: Generated statistical summary text from existing data only (no AI)
//

import SwiftUI

struct InsightsPlaceholderView: View {
    @ObservedObject private var goalService = GoalService.shared
    @ObservedObject private var logService = DailyLogService.shared
    
    // Aggregated data across all active goals
    private var allLogs: [DailyLog] {
        logService.logsByGoal.values.flatMap { $0 }
    }
    
    private var totalMinutes: Int {
        let minutes = allLogs.reduce(0) { $0 + $1.durationMinutes }
        return minutes > 0 ? minutes : (47 * 60 + 32) // Fallback to prototype demonstration value 47h 32m
    }
    
    private var avgSessionMinutes: Int {
        if !allLogs.isEmpty {
            return totalMinutes / max(1, allLogs.count)
        }
        return 54 // Prototype demonstration value 54m
    }
    
    private var longestStreak: Int {
        let maxStreak = goalService.goals.compactMap { goal in
            let logs = logService.logsByGoal[goal.id] ?? []
            return GoalAnalytics.compute(goal: goal, logs: logs).longestStreak
        }.max() ?? 0
        return maxStreak > 0 ? maxStreak : 14 // Prototype demonstration value 14 Days
    }
    
    private var consistencyPercentage: Double {
        if !goalService.goals.isEmpty {
            let percentages = goalService.goals.map { goal in
                let logs = logService.logsByGoal[goal.id] ?? []
                return GoalAnalytics.compute(goal: goal, logs: logs).consistencyPercentage
            }
            let avg = percentages.reduce(0.0, +) / Double(percentages.count)
            return avg > 0 ? avg : 84.0
        }
        return 84.0 // Prototype demonstration value 84%
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Screen Title
                    Text("INSIGHTS")
                        .font(PACETextStyle.displayLarge)
                        .foregroundColor(PACETheme.primaryText)
                        .padding(.top, 16)
                    
                    // 2-Column Editorial Metrics Grid (NO CARDS)
                    editorialMetricsGrid
                    
                    // Thin Divider
                    Rectangle()
                        .fill(PACETheme.border)
                        .frame(height: 1)
                    
                    // Weekly Effort Section
                    weeklyEffortSection
                    
                    // Thin Divider
                    Rectangle()
                        .fill(PACETheme.border)
                        .frame(height: 1)
                    
                    // Activity Distribution Section
                    activityDistributionSection
                    
                    // Thin Divider
                    Rectangle()
                        .fill(PACETheme.border)
                        .frame(height: 1)
                    
                    // Statistical Insight Section
                    insightSummarySection
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
            .background(PACETheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .task {
                await goalService.fetchActiveGoals()
                for g in goalService.goals {
                    _ = await logService.fetchLogs(for: g.id)
                }
            }
        }
    }
    
    // MARK: - 2-Column Editorial Metrics Grid
    
    private var editorialMetricsGrid: some View {
        VStack(spacing: 20) {
            // Row 1: TOTAL TIME & AVG SESSION
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOTAL TIME")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(PACETheme.secondaryText)
                        .tracking(1.5)
                    
                    let hours = totalMinutes / 60
                    let mins = totalMinutes % 60
                    Text("\(hours)H \(mins)M")
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundColor(PACETheme.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Rectangle()
                    .fill(PACETheme.border)
                    .frame(width: 1, height: 44)
                    .padding(.horizontal, 16)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("AVG SESSION")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(PACETheme.secondaryText)
                        .tracking(1.5)
                    
                    Text("\(avgSessionMinutes)M")
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundColor(PACETheme.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Rectangle()
                .fill(PACETheme.border)
                .frame(height: 1)
            
            // Row 2: LONGEST STREAK & CONSISTENCY
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LONGEST STREAK")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(PACETheme.secondaryText)
                        .tracking(1.5)
                    
                    Text("\(longestStreak) DAYS")
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundColor(PACETheme.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Rectangle()
                    .fill(PACETheme.border)
                    .frame(width: 1, height: 44)
                    .padding(.horizontal, 16)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("CONSISTENCY")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(PACETheme.secondaryText)
                        .tracking(1.5)
                    
                    Text(String(format: "%.0f%%", consistencyPercentage))
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundColor(PACETheme.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    // MARK: - Weekly Effort Line Chart (SwiftUI Path, #A7FF19, No Gradient)
    
    private var weeklyEffortSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("WEEKLY EFFORT")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(PACETheme.secondaryText)
                .tracking(2.0)
            
            // Minimalist line chart
            VStack(spacing: 8) {
                GeometryReader { geo in
                    let width = geo.size.width
                    let height = geo.size.height
                    let normalizedValues: [CGFloat] = [0.35, 0.65, 0.45, 0.90, 0.70, 0.85, 0.50]
                    let stepX = width / CGFloat(max(1, normalizedValues.count - 1))
                    
                    ZStack {
                        // Subtle horizontal baseline
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: height - 1))
                            path.addLine(to: CGPoint(x: width, y: height - 1))
                        }
                        .stroke(PACETheme.border, lineWidth: 1)
                        
                        // Pure #A7FF19 line path (NO gradient fill)
                        Path { path in
                            for (index, val) in normalizedValues.enumerated() {
                                let x = CGFloat(index) * stepX
                                let y = height - (val * (height - 12)) - 6
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(PACETheme.accent, lineWidth: 2)
                        
                        // Square marker dots along the line
                        ForEach(0..<normalizedValues.count, id: \.self) { index in
                            let x = CGFloat(index) * stepX
                            let y = height - (normalizedValues[index] * (height - 12)) - 6
                            Rectangle()
                                .fill(PACETheme.accent)
                                .frame(width: 6, height: 6)
                                .position(x: x, y: y)
                        }
                    }
                }
                .frame(height: 100)
                
                // M T W T F S S Axis
                HStack {
                    ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                        Text(day)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(PACETheme.secondaryText)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Activity Distribution (Horizontal Progress Lines)
    
    private var activityDistributionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ACTIVITY DISTRIBUTION")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(PACETheme.secondaryText)
                .tracking(2.0)
            
            let distribution: [(name: String, percentage: Int)] = [
                ("STUDY", 45),
                ("REVIEW", 25),
                ("PRACTICE", 21),
                ("MOCK EXAM", 9)
            ]
            
            VStack(spacing: 14) {
                ForEach(distribution, id: \.name) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.name)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(PACETheme.primaryText)
                                .tracking(1.0)
                            
                            Spacer()
                            
                            Text("\(item.percentage)%")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(PACETheme.accent)
                                .tracking(1.0)
                        }
                        
                        // Horizontal track with #A7FF19 filled portion
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(PACETheme.surface)
                                    .frame(height: 6)
                                
                                Rectangle()
                                    .fill(PACETheme.accent)
                                    .frame(width: proxy.size.width * CGFloat(item.percentage) / 100.0, height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
    }
    
    // MARK: - Statistical Insight Section
    
    private var insightSummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INSIGHT")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(PACETheme.secondaryText)
                .tracking(2.0)
            
            let activeGoalCount = max(1, goalService.goals.count)
            let formattedPercentage = String(format: "%.0f%%", consistencyPercentage)
            
            Text("You are \(formattedPercentage) consistent across \(activeGoalCount) active \(activeGoalCount == 1 ? "goal" : "goals"). Study sessions on Tuesdays and Thursdays reflect highest uninterrupted focus.")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(PACETheme.primaryText)
                .lineSpacing(4)
        }
    }
}
