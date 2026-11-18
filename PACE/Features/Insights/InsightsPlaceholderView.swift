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
    @State private var selectedBarDate: Date? = nil
    @State private var showConsistencyExplanation = false

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

    private var dailySessionCounts: [Int] {
        let calendar = Calendar.current
        let sessionsByDay = scopedLogs.reduce(into: [Date: Int]()) { result, log in
            result[calendar.startOfDay(for: log.date), default: 0] += 1
        }
        return periodDates.map { sessionsByDay[$0] ?? 0 }
    }
    
    private var totalMinutes: Int {
        scopedLogs.reduce(0) { $0 + $1.durationMinutes }
    }

    private var averageSessionMinutes: Int {
        guard !scopedLogs.isEmpty else { return 0 }
        return totalMinutes / scopedLogs.count
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
                VStack(alignment: .leading, spacing: 20) {
                    Text("INSIGHTS")
                        .font(PACETextStyle.displayLarge)
                        .foregroundColor(PACETheme.primaryText)
                        .padding(.top, 4)
                    
                    filterSection
                    editorialMetricsGrid
                    Rectangle().fill(PACETheme.border).frame(height: 1)
                    dailyEffortSection

                    if !activityDistribution.isEmpty {
                        Rectangle().fill(PACETheme.border).frame(height: 1)
                        activityDistributionSection
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .safeAreaPadding(.top, 8)
            .safeAreaPadding(.bottom, 16)
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
            .onChange(of: selectedGoalId) { _, _ in
                selectedBarDate = nil
            }
            .onChange(of: reportingPeriod) { _, _ in
                selectedBarDate = nil
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
            consistencyMetric
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

    private var consistencyMetric: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text("CONSISTENCY")
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACETheme.secondaryText)
                    .tracking(1)
                Button {
                    showConsistencyExplanation.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(PACETheme.accent)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Explain consistency")
            }
            Text(consistencyPercentage.map { String(format: "%.0f%%", $0) } ?? "—")
                .font(.system(.title3, design: .monospaced).weight(.black))
                .foregroundColor(PACETheme.accent)
                .monospacedDigit()

            if showConsistencyExplanation {
                Text("Logged sessions divided by scheduled days in this period.")
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACETheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
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
                    .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            } else {
                let maxMinutes = max(dailyMinutes.max() ?? 0, 1)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(periodDates.indices, id: \.self) { index in
                            let date = periodDates[index]
                            let minutes = dailyMinutes[index]
                            let isSelected = selectedBarDate.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false
                            Button {
                                selectedBarDate = date
                            } label: {
                                VStack(spacing: 5) {
                                    ZStack(alignment: .bottom) {
                                        Rectangle()
                                            .fill(PACETheme.surface)
                                        Rectangle()
                                            .fill(minutes == 0 ? PACETheme.border : PACETheme.accent)
                                            .frame(height: max(2, 88 * CGFloat(minutes) / CGFloat(maxMinutes)))
                                    }
                                    .frame(width: reportingPeriod == .sevenDays ? 32 : 22, height: 88)
                                    .overlay(Rectangle().stroke(isSelected ? PACETheme.accent : PACETheme.border, lineWidth: isSelected ? 2 : 1))

                                    if shouldShowDateLabel(index) {
                                        Text(date.formatted(.dateTime.weekday(.narrow)))
                                            .font(PACETextStyle.pixelMetadata)
                                            .foregroundColor(Calendar.current.isDateInToday(date) ? PACETheme.accent : PACETheme.mutedText)
                                    } else {
                                        Color.clear.frame(height: 12)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(date.formatted(date: .complete, time: .omitted)), \(minutes) minutes, \(dailySessionCounts[index]) sessions")
                        }
                    }
                    .frame(minWidth: reportingPeriod == .sevenDays ? 300 : CGFloat(periodDates.count * 28), minHeight: 112, alignment: .bottom)
                    .padding(.horizontal, 2)
                }

                if let selectedBarDate,
                   let index = periodDates.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: selectedBarDate) }) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(PACETheme.accent)
                        Text("\(selectedBarDate.formatted(date: .abbreviated, time: .omitted)) · \(formatDuration(dailyMinutes[index])) · \(dailySessionCounts[index]) \(dailySessionCounts[index] == 1 ? "session" : "sessions")")
                            .font(PACETextStyle.pixelMetadata)
                            .foregroundColor(PACETheme.primaryText)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
    
    private func shouldShowDateLabel(_ index: Int) -> Bool {
        reportingPeriod == .sevenDays || index == 0 || index == periodDates.count - 1 || index.isMultiple(of: 5)
    }

    private var activityDistributionSection: some View {
        let totalTags = activityDistribution.reduce(0) { $0 + $1.count }

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(activityDistribution.count == 1 ? "TOP ACTIVITY" : "ACTIVITY TAGS")
                    .font(PACETextStyle.pixelLabel)
                    .foregroundColor(PACETheme.secondaryText)
                    .tracking(1.5)
                Spacer()
                Text("\(activityDistribution[0].name) · \(activityDistribution[0].count)")
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACETheme.accent)
                    .lineLimit(1)
            }

            if activityDistribution.count > 1 {
                ForEach(activityDistribution.dropFirst(), id: \.name) { item in
                    let share = Int((Double(item.count) / Double(totalTags) * 100).rounded())
                    HStack {
                        Text(item.name)
                            .font(PACETextStyle.pixelMetadata)
                            .foregroundColor(PACETheme.primaryText)
                        Spacer()
                        Text("\(share)% · \(item.count)")
                            .font(PACETextStyle.pixelMetadata)
                            .foregroundColor(PACETheme.secondaryText)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(item.name), \(item.count) of \(totalTags) activity tags, \(share) percent")
                }
            }
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
