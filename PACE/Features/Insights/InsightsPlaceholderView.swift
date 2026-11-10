//
//  InsightsPlaceholderView.swift
//  PACE
//
//  Data-backed insights for logged sessions and activity tags.
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
        allLogs.reduce(0) { $0 + $1.durationMinutes }
    }

    private var avgSessionMinutes: Int {
        guard !allLogs.isEmpty else { return 0 }
        return totalMinutes / allLogs.count
    }

    private var longestStreak: Int {
        goalService.goals.compactMap { goal in
            let logs = logService.logsByGoal[goal.id] ?? []
            return GoalAnalytics.compute(goal: goal, logs: logs).longestStreak
        }.max() ?? 0
    }

    private var consistencyPercentage: Double? {
        guard !allLogs.isEmpty, !goalService.goals.isEmpty else { return nil }
        let percentages = goalService.goals.map { goal in
            let logs = logService.logsByGoal[goal.id] ?? []
            return GoalAnalytics.compute(goal: goal, logs: logs).consistencyPercentage
        }
        return percentages.reduce(0.0, +) / Double(percentages.count)
    }

    private var recentDays: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
    }

    private var dailyMinutes: [Int] {
        let calendar = Calendar.current
        let minutesByDay = allLogs.reduce(into: [Date: Int]()) { result, log in
            let day = calendar.startOfDay(for: log.date)
            result[day, default: 0] += log.durationMinutes
        }
        return recentDays.map { minutesByDay[$0] ?? 0 }
    }

    private var activityDistribution: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for activity in allLogs.flatMap(\.selectedActivities) {
            let name = activity.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                counts[name, default: 0] += 1
            }
        }
        return counts.map { (name: $0.key, count: $0.value) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
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
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 24) {
            metric(label: "TOTAL TIME", value: "\(totalMinutes / 60)H \(totalMinutes % 60)M")
            metric(label: "AVG SESSION", value: allLogs.isEmpty ? "—" : "\(avgSessionMinutes)M")
            metric(label: "LONGEST STREAK", value: "\(longestStreak) DAYS")
            metric(label: "CONSISTENCY", value: consistencyPercentage.map { String(format: "%.0f%%", $0) } ?? "—")
        }
    }

    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(PACETextStyle.pixelMetadata)
                .foregroundColor(PACETheme.secondaryText)
                .tracking(1)
            Text(value)
                .font(.system(.title3, design: .monospaced).weight(.black))
                .monospacedDigit()
                .foregroundColor(PACETheme.primaryText)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
                .accessibilityLabel("\(label), \(value)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Weekly Effort Line Chart (SwiftUI Path, #A7FF19, No Gradient)
    
    private var weeklyEffortSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("WEEKLY EFFORT")
                .font(PACETextStyle.pixelLabel)
                .foregroundColor(PACETheme.secondaryText)
                .tracking(1.5)

            if dailyMinutes.allSatisfy({ $0 == 0 }) {
                Text("No logged time in the last seven days.")
                    .font(.body)
                    .foregroundColor(PACETheme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
            } else {
                VStack(spacing: 10) {
                    GeometryReader { geo in
                        let values = dailyMinutes
                        let maxValue = CGFloat(max(values.max() ?? 0, 1))
                        let width = geo.size.width
                        let height = geo.size.height
                        let stepX = width / CGFloat(max(1, values.count - 1))

                        ZStack {
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: height - 1))
                                path.addLine(to: CGPoint(x: width, y: height - 1))
                            }
                            .stroke(PACETheme.border, lineWidth: 1)

                            Path { path in
                                for (index, value) in values.enumerated() {
                                    let x = CGFloat(index) * stepX
                                    let y = height - (CGFloat(value) / maxValue * (height - 12)) - 6
                                    if index == 0 {
                                        path.move(to: CGPoint(x: x, y: y))
                                    } else {
                                        path.addLine(to: CGPoint(x: x, y: y))
                                    }
                                }
                            }
                            .stroke(PACETheme.accent, lineWidth: 2)

                            ForEach(values.indices, id: \.self) { index in
                                let x = CGFloat(index) * stepX
                                let y = height - (CGFloat(values[index]) / maxValue * (height - 12)) - 6
                                Rectangle()
                                    .fill(PACETheme.accent)
                                    .frame(width: 7, height: 7)
                                    .position(x: x, y: y)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .frame(height: 112)
                    .accessibilityHidden(true)

                    HStack(alignment: .top, spacing: 0) {
                        ForEach(recentDays.indices, id: \.self) { index in
                            let date = recentDays[index]
                            VStack(spacing: 3) {
                                Text(date.formatted(.dateTime.weekday(.abbreviated)))
                                Text(date.formatted(.dateTime.day()))
                            }
                            .font(PACETextStyle.pixelMetadata)
                            .foregroundColor(PACETheme.secondaryText)
                            .frame(maxWidth: .infinity)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(date.formatted(date: .complete, time: .omitted)), \(dailyMinutes[index]) minutes")
                        }
                    }
                }
                .accessibilityElement(children: .contain)
            }
        }
    }
    
    // MARK: - Activity Distribution (Horizontal Progress Lines)
    
    private var activityDistributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACTIVITY DISTRIBUTION")
                .font(PACETextStyle.pixelLabel)
                .foregroundColor(PACETheme.secondaryText)
                .tracking(1.5)

            Text("Share of logged activity tags, not duration per activity.")
                .font(.subheadline)
                .foregroundColor(PACETheme.secondaryText)

            if activityDistribution.isEmpty {
                Text("No activity tags logged yet.")
                    .font(.body)
                    .foregroundColor(PACETheme.secondaryText)
                    .padding(.top, 4)
            } else {
                let totalTags = activityDistribution.reduce(0) { $0 + $1.count }
                VStack(spacing: 16) {
                    ForEach(activityDistribution, id: \.name) { item in
                        let share = Double(item.count) / Double(totalTags)
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(item.name)
                                    .font(.system(.body, design: .monospaced).weight(.semibold))
                                    .foregroundColor(PACETheme.primaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 8)
                                Text("\(Int((share * 100).rounded()))% · \(item.count) \(item.count == 1 ? "tag" : "tags")")
                                    .font(PACETextStyle.pixelMetadata)
                                    .foregroundColor(PACETheme.accent)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Rectangle().fill(PACETheme.surface)
                                    Rectangle()
                                        .fill(PACETheme.accent)
                                        .frame(width: proxy.size.width * share)
                                }
                            }
                            .frame(height: 6)
                            .accessibilityHidden(true)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(item.name), \(item.count) of \(totalTags) logged activity tags, \(Int((share * 100).rounded())) percent")
                    }
                }
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Statistical Insight Section
    
    private var insightSummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INSIGHT")
                .font(PACETextStyle.pixelLabel)
                .foregroundColor(PACETheme.secondaryText)
                .tracking(1.5)

            Text(allLogs.isEmpty
                 ? "Log a session to see your activity insights."
                 : "You've logged \(totalMinutes) minutes across \(allLogs.count) \(allLogs.count == 1 ? "session" : "sessions").")
                .font(.body)
                .foregroundColor(PACETheme.primaryText)
                .lineSpacing(4)
        }
    }
}
