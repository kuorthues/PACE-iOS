//
//  InsightsPlaceholderView.swift
//  PACE
//
//  Data-backed insights for logged sessions and activity tags.

import SwiftUI

private enum InsightsReportingPeriod: Int, CaseIterable, Identifiable {
    case sevenDays = 7
    case thirtyDays = 30

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .sevenDays: return "LAST 7 DAYS"
        case .thirtyDays: return "LAST 30 DAYS"
        }
    }
}

struct InsightsPlaceholderView: View {
    @ObservedObject private var goalService = GoalService.shared
    @ObservedObject private var logService = DailyLogService.shared
    
    @State private var selectedGoalId: String? = nil
    @State private var reportingPeriod: InsightsReportingPeriod = .sevenDays

    private var selectedGoalTitle: String {
        guard let selectedGoalId else { return "ALL GOALS" }
        return goalService.goals.first(where: { $0.id == selectedGoalId })?.title.uppercased() ?? "ALL GOALS"
    }

    private var scopedLogs: [DailyLog] {
        if let selectedGoalId {
            return logService.logsByGoal[selectedGoalId] ?? []
        }
        return logService.logsByGoal.values.flatMap { $0 }
    }

    private var periodDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<reportingPeriod.rawValue).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }
    }

    private var dailyMinutes: [Int] {
        let calendar = Calendar.current
        let minutesByDay = scopedLogs.reduce(into: [Date: Int]()) { result, log in
            result[calendar.startOfDay(for: log.date), default: 0] += log.durationMinutes
        }
        return periodDates.map { minutesByDay[$0] ?? 0 }
    }
    
    private var totalMinutes: Int {
        scopedLogs.reduce(0) { $0 + $1.durationMinutes }
    }

    private var averageSessionMinutes: Int {
        guard !scopedLogs.isEmpty else { return 0 }
        return totalMinutes / scopedLogs.count
    }

    private var longestStreak: Int {
        let goals = selectedGoalId.flatMap { id in
            goalService.goals.first(where: { $0.id == id }).map { [$0] }
        } ?? goalService.goals
        return goals.map {
            GoalAnalytics.compute(goal: $0, logs: logService.logsByGoal[$0.id] ?? []).longestStreak
        }.max() ?? 0
    }

    private var consistencyPercentage: Double? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let goals = selectedGoalId.flatMap { id in
            goalService.goals.first(where: { $0.id == id }).map { [$0] }
        } ?? goalService.goals

        var scheduledDays = 0
        var completedDays = 0
        for goal in goals {
            let logs = Set((logService.logsByGoal[goal.id] ?? []).map(\.dateString))
            for date in periodDates where date <= today {
                guard goal.scheduledWeekdays.contains(calendar.component(.weekday, from: date)) else { continue }
                scheduledDays += 1
                if logs.contains(DailyLog.dateFormatter.string(from: date)) {
                    completedDays += 1
                }
            }
        }

        guard scheduledDays > 0 else { return nil }
        return (Double(completedDays) / Double(scheduledDays) * 100).rounded()
    }

    private var activityDistribution: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for activity in scopedLogs.flatMap(\.selectedActivities) {
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
                VStack(alignment: .leading, spacing: 24) {
                    Text("INSIGHTS")
                        .font(PACETextStyle.displayLarge)
                        .foregroundColor(PACETheme.primaryText)
                        .padding(.top, 16)
                    
                    filterSection
                    editorialMetricsGrid
                    Rectangle().fill(PACETheme.border).frame(height: 1)
                    dailyEffortSection
                    Rectangle().fill(PACETheme.border).frame(height: 1)
                    activityDistributionSection
                    Rectangle().fill(PACETheme.border).frame(height: 1)
                    insightSummarySection
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
            .background(PACETheme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await goalService.fetchActiveGoals()
                for goal in goalService.goals {
                    _ = await logService.fetchLogs(for: goal.id)
                }
                if let selectedGoalId,
                   !goalService.goals.contains(where: { $0.id == selectedGoalId }) {
                    self.selectedGoalId = nil
                }
            }
        }
    }
    
    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("REPORTING FILTERS")
                .font(PACETextStyle.pixelLabel)
                .foregroundColor(PACETheme.secondaryText)
                .tracking(1.5)

            HStack(spacing: 8) {
                Menu {
                    Button("ALL GOALS") {
                        selectedGoalId = nil
                    }
                    ForEach(goalService.goals) { goal in
                        Button(goal.title.uppercased()) {
                            selectedGoalId = goal.id
                        }
                    }
                } label: {
                    filterButton(title: selectedGoalTitle, icon: "target")
                }

                Menu {
                    ForEach(InsightsReportingPeriod.allCases) { period in
                        Button(period.label) {
                            reportingPeriod = period
                        }
                    }
                } label: {
                    filterButton(title: reportingPeriod.label, icon: "calendar")
                }
            }
        }
    }

    private func filterButton(title: String, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(title)
                .font(PACETextStyle.pixelMetadata)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundColor(PACETheme.primaryText)
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PACETheme.surface)
        .overlay(Rectangle().stroke(PACETheme.border, lineWidth: 1))
    }
    
    private var editorialMetricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 22) {
            metric(label: "TOTAL TIME", value: totalMinutes == 0 ? "—" : formatDuration(totalMinutes))
            metric(label: "AVG SESSION", value: scopedLogs.isEmpty ? "—" : formatDuration(averageSessionMinutes))
            metric(label: "SESSIONS", value: "\(scopedLogs.count)")
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
    
    private var dailyEffortSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("DAILY EFFORT")
                    .font(PACETextStyle.pixelLabel)
                    .foregroundColor(PACETheme.secondaryText)
                    .tracking(1.5)
                Spacer()
                Text("\(reportingPeriod.rawValue) DAYS")
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACETheme.accent)
            }

            if dailyMinutes.allSatisfy({ $0 == 0 }) {
                Text("No logged time in this reporting period.")
                    .font(PACETextStyle.body)
                    .foregroundColor(PACETheme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            } else {
                let maxMinutes = max(dailyMinutes.max() ?? 0, 1)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(periodDates.indices, id: \.self) { index in
                            let minutes = dailyMinutes[index]
                            VStack(spacing: 5) {
                                Text(minutes == 0 ? "—" : formatDuration(minutes))
                                    .font(PACETextStyle.pixelMetadata)
                                    .foregroundColor(minutes == 0 ? PACETheme.mutedText : PACETheme.secondaryText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.65)
                                GeometryReader { proxy in
                                    VStack {
                                        Spacer()
                                        Rectangle()
                                            .fill(minutes == 0 ? PACETheme.border : PACETheme.accent)
                                            .frame(height: max(2, proxy.size.height * CGFloat(minutes) / CGFloat(maxMinutes)))
                                    }
                                }
                                .frame(height: 82)
                                Text(periodDates[index].formatted(.dateTime.weekday(.narrow)))
                                    .font(PACETextStyle.pixelMetadata)
                                    .foregroundColor(Calendar.current.isDateInToday(periodDates[index]) ? PACETheme.accent : PACETheme.mutedText)
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(periodDates[index].formatted(date: .complete, time: .omitted)), \(minutes) minutes")
                        }
                    }
                    Rectangle().fill(PACETheme.border).frame(height: 1)
                    Text("Bars show logged session time. Labels use minutes below one hour and hours above one hour.")
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(PACETheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .contain)
            }
        }
    }
    
    private var activityDistributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACTIVITY DISTRIBUTION")
                .font(PACETextStyle.pixelLabel)
                .foregroundColor(PACETheme.secondaryText)
                .tracking(1.5)
            Text("Share of activity tags across \(scopedLogs.count) logged \(scopedLogs.count == 1 ? "session" : "sessions"); this is not time by activity.")
                .font(.subheadline)
                .foregroundColor(PACETheme.secondaryText)

            if activityDistribution.isEmpty {
                Text("No activity tags logged in this selection.")
                    .font(PACETextStyle.body)
                    .foregroundColor(PACETheme.secondaryText)
            } else {
                let totalTags = activityDistribution.reduce(0) { $0 + $1.count }
                VStack(spacing: 14) {
                    ForEach(activityDistribution, id: \.name) { item in
                        let share = Double(item.count) / Double(totalTags)
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(item.name)
                                    .font(.system(.body, design: .monospaced).weight(.semibold))
                                    .foregroundColor(PACETheme.primaryText)
                                Spacer(minLength: 8)
                                Text("\(Int((share * 100).rounded()))% · \(item.count)")
                                    .font(PACETextStyle.pixelMetadata)
                                    .foregroundColor(PACETheme.accent)
                            }
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Rectangle().fill(PACETheme.surface)
                                    Rectangle().fill(PACETheme.accent).frame(width: proxy.size.width * share)
                                }
                            }
                            .frame(height: 6)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(item.name), \(item.count) of \(totalTags) activity tags, \(Int((share * 100).rounded())) percent")
                    }
                }
            }
        }
    }
    
    private var insightSummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HOW CONSISTENCY WORKS")
                .font(PACETextStyle.pixelLabel)
                .foregroundColor(PACETheme.secondaryText)
                .tracking(1.5)

            Text("Consistency counts logged sessions on scheduled days in the selected period. Planned rest days do not lower the percentage; unscheduled sessions are still included in session and time totals.")
                .font(PACETextStyle.body)
                .foregroundColor(PACETheme.primaryText)
                .lineSpacing(4)

            Text(scopedLogs.isEmpty
                 ? "Log a session to see factual progress summaries."
                 : "\(scopedLogs.count) \(scopedLogs.count == 1 ? "session" : "sessions") logged · \(formatDuration(totalMinutes)) total · longest streak \(longestStreak) \(longestStreak == 1 ? "day" : "days").")
                .font(PACETextStyle.pixelMetadata)
                .foregroundColor(PACETheme.accent)
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            return remainder == 0 ? "\(hours)H" : "\(hours)H \(remainder)M"
        }
        return "\(minutes)M"
    }
}
