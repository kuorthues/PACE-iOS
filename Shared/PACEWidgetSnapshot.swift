import Foundation

enum PACEWidgetGoalKind: String, Codable, Equatable {
    case solo
    case shared
}

struct PACEWidgetSnapshot: Codable, Equatable, Identifiable {
    let goalId: String
    let title: String
    let kind: PACEWidgetGoalKind
    let createdAt: Date
    let createdAtString: String
    let targetDate: Date
    let historyStartDateString: String
    let targetDateString: String
    let scheduledWeekdays: [Int]
    let loggedDateStrings: [String]

    var id: String { "\(kind.rawValue):\(goalId)" }
}

enum PACEWidgetCatalogStatus: String, Codable {
    case ready
    case needsSync
    case signedOut
}

struct PACEWidgetSnapshotCatalog: Codable, Equatable {
    static let currentSchemaVersion = 2

    let schemaVersion: Int
    let accountId: String?
    let status: PACEWidgetCatalogStatus
    let goals: [PACEWidgetSnapshot]

    init(
        accountId: String?,
        status: PACEWidgetCatalogStatus,
        goals: [PACEWidgetSnapshot],
        schemaVersion: Int = currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.accountId = accountId
        self.status = status
        self.goals = goals
    }

    static var signedOut: PACEWidgetSnapshotCatalog {
        PACEWidgetSnapshotCatalog(accountId: nil, status: .signedOut, goals: [])
    }

    func orderedGoals(asOf date: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> [PACEWidgetSnapshot] {
        let today = PACEWidgetSnapshot.dayKey(for: date, calendar: calendar)
        let sorted = goals.sorted {
            if $0.targetDateString == $1.targetDateString { return $0.id < $1.id }
            return $0.targetDateString < $1.targetDateString
        }
        let upcoming = sorted.filter { $0.targetDateString >= today }
        let overdue = sorted.filter { $0.targetDateString < today }.reversed()
        return upcoming + Array(overdue)
    }

    func defaultGoal(asOf date: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> PACEWidgetSnapshot? {
        orderedGoals(asOf: date, calendar: calendar).first
    }
}

enum PACEWidgetCatalogReadResult {
    case available(PACEWidgetSnapshotCatalog)
    case missing
    case unavailable
    case incompatible
}

enum PACEWidgetCatalogWriteResult {
    case changed
    case unchanged
    case unavailable
    case encodingFailed
}

enum PACEWidgetSnapshotStore {
    static let appGroupSuite = "group.mseud.edu.ph.PACE"
    static let catalogKey = "pace_widget_snapshot_catalog_v2"
    static let legacyCatalogKey = "pace_widget_snapshot_catalog_v1"
    static let legacySnapshotKey = "pace_primary_goal_widget_snapshot"

    static func readCatalog() -> PACEWidgetCatalogReadResult {
        guard let defaults = UserDefaults(suiteName: appGroupSuite) else {
            return .unavailable
        }
        guard let data = defaults.data(forKey: catalogKey) else {
            return .missing
        }
        guard let catalog = try? JSONDecoder().decode(PACEWidgetSnapshotCatalog.self, from: data),
              catalog.schemaVersion == PACEWidgetSnapshotCatalog.currentSchemaVersion,
              catalog.goals.allSatisfy({
                  PACEWidgetSnapshot.isValidDayKey($0.createdAtString)
                      && PACEWidgetSnapshot.isValidDayKey($0.historyStartDateString)
                      && PACEWidgetSnapshot.isValidDayKey($0.targetDateString)
                      && $0.loggedDateStrings.allSatisfy({ PACEWidgetSnapshot.isValidDayKey($0) })
              }) else {
            return .incompatible
        }
        return .available(catalog)
    }

    @discardableResult
    static func write(_ catalog: PACEWidgetSnapshotCatalog) -> PACEWidgetCatalogWriteResult {
        guard let defaults = UserDefaults(suiteName: appGroupSuite) else {
            return .unavailable
        }
        defaults.removeObject(forKey: legacyCatalogKey)
        defaults.removeObject(forKey: legacySnapshotKey)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(catalog) else {
            return .encodingFailed
        }
        defaults.removeObject(forKey: legacySnapshotKey)
        guard defaults.data(forKey: catalogKey) != data else {
            return .unchanged
        }
        defaults.set(data, forKey: catalogKey)
        return .changed
    }

}

struct PACEWidgetMetrics: Equatable {
    let daysRemaining: Int
    let daysOverdue: Int
    let currentStreak: Int
    let isLoggedToday: Bool
    let isScheduledToday: Bool

    var isOverdue: Bool { daysOverdue > 0 }
    var isRestDay: Bool { !isLoggedToday && !isScheduledToday }
    var isProofPending: Bool { !isLoggedToday && isScheduledToday }
}

extension PACEWidgetSnapshot {
    func metrics(for date: Date, calendar: Calendar = .autoupdatingCurrent) -> PACEWidgetMetrics {
        let today = calendar.startOfDay(for: date)
        let targetDay = Self.date(fromDayKey: targetDateString, calendar: calendar)
            ?? calendar.startOfDay(for: date)
        let difference = calendar.dateComponents([.day], from: today, to: targetDay).day ?? 0
        let loggedDates = Set(loggedDateStrings)
        let formatter = Self.dayKeyFormatter(calendar: calendar)
        let dayKey: (Date) -> String = { formatter.string(from: $0) }
        let todayKey = dayKey(today)
        let weekday = calendar.component(.weekday, from: today)
        let isLoggedToday = loggedDates.contains(todayKey)
        let isScheduledToday = scheduledWeekdays.contains(weekday)
        let streak = PACEWidgetCurrentStreakCalculator.currentStreak(
            loggedDateStrings: loggedDates,
            scheduledWeekdays: scheduledWeekdays,
            historyStartDate: Self.date(fromDayKey: historyStartDateString, calendar: calendar)
                ?? calendar.startOfDay(for: date),
            asOf: date,
            calendar: calendar,
            dayKey: dayKey
        )

        return PACEWidgetMetrics(
            daysRemaining: max(0, difference),
            daysOverdue: max(0, -difference),
            currentStreak: streak,
            isLoggedToday: isLoggedToday,
            isScheduledToday: isScheduledToday
        )
    }

    var formattedTargetDate: String {
        let formatter = DateFormatter()
        formatter.calendar = .autoupdatingCurrent
        formatter.timeZone = Calendar.autoupdatingCurrent.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let date = Self.date(fromDayKey: targetDateString, calendar: .autoupdatingCurrent) ?? Date()
        return formatter.string(from: date).uppercased()
    }

    static func dayKey(for date: Date, calendar: Calendar) -> String {
        dayKeyFormatter(calendar: calendar).string(from: date)
    }

    static func isValidDayKey(_ value: String, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        guard let date = date(fromDayKey: value, calendar: calendar) else { return false }
        return dayKey(for: date, calendar: calendar) == value
    }

    private static func date(fromDayKey value: String, calendar: Calendar) -> Date? {
        dayKeyFormatter(calendar: calendar).date(from: value)
    }

    private static func dayKeyFormatter(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}

enum PACEWidgetCurrentStreakCalculator {
    static func currentStreak(
        loggedDateStrings: Set<String>,
        scheduledWeekdays: [Int],
        historyStartDate: Date,
        asOf: Date,
        calendar: Calendar,
        dayKey: (Date) -> String
    ) -> Int {
        let today = calendar.startOfDay(for: asOf)
        let earliestDate = calendar.startOfDay(for: historyStartDate)
        var streak = 0
        var checkDate = today

        if loggedDateStrings.contains(dayKey(today)) {
            streak += 1
        }

        guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
            return streak
        }
        checkDate = previousDay

        while checkDate >= earliestDate {
            let isLogged = loggedDateStrings.contains(dayKey(checkDate))
            let isScheduled = scheduledWeekdays.contains(calendar.component(.weekday, from: checkDate))

            if isLogged {
                streak += 1
            } else if isScheduled {
                break
            }

            guard let previous = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                break
            }
            checkDate = previous
        }

        return streak
    }
}
