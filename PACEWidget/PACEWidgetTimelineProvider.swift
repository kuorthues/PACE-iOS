import Foundation
import WidgetKit

struct PACEWidgetEntry: TimelineEntry {
    let date: Date
    let state: PACEWidgetEntryState
    let snapshot: PACEWidgetSnapshot?
}

enum PACEWidgetEntryState: Equatable {
    case preview
    case ready
    case noActiveGoal
    case signedOut
    case needsSync
    case goalUnavailable
    case appGroupUnavailable
}

struct PACEWidgetTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = PACEWidgetEntry
    typealias Intent = PACEWidgetConfigurationIntent

    func placeholder(in context: Context) -> PACEWidgetEntry {
        PACEWidgetEntry(date: Date(), state: .preview, snapshot: Self.previewSnapshot)
    }

    func snapshot(for configuration: Intent, in context: Context) async -> PACEWidgetEntry {
        if context.isPreview {
            return PACEWidgetEntry(date: Date(), state: .preview, snapshot: Self.previewSnapshot)
        }
        return makeEntry(for: configuration, at: Date())
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        let now = Date()
        if context.isPreview {
            return Timeline(
                entries: [PACEWidgetEntry(date: now, state: .preview, snapshot: Self.previewSnapshot)],
                policy: .never
            )
        }

        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: now)
        var entryDates = [now]
        for dayOffset in 1...7 {
            guard let nextDay = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            entryDates.append(nextDay)
        }

        let entries = entryDates.map { makeEntry(for: configuration, at: $0) }
        let nextMidnight = entryDates.dropFirst().first ?? now.addingTimeInterval(24 * 60 * 60)
        let refreshDate = calendar.date(byAdding: .minute, value: 15, to: nextMidnight) ?? nextMidnight
        return Timeline(entries: entries, policy: .after(refreshDate))
    }

    private func makeEntry(for configuration: Intent, at date: Date) -> PACEWidgetEntry {
        switch PACEWidgetSnapshotStore.readCatalog() {
        case .unavailable:
            return PACEWidgetEntry(date: date, state: .appGroupUnavailable, snapshot: nil)
        case .missing, .incompatible:
            return PACEWidgetEntry(date: date, state: .needsSync, snapshot: nil)
        case .available(let catalog):
            switch catalog.status {
            case .signedOut:
                return PACEWidgetEntry(date: date, state: .signedOut, snapshot: nil)
            case .needsSync:
                return PACEWidgetEntry(date: date, state: .needsSync, snapshot: nil)
            case .ready:
                guard let accountId = catalog.accountId else {
                    return PACEWidgetEntry(date: date, state: .needsSync, snapshot: nil)
                }

                if let selectedGoal = configuration.goal {
                    guard selectedGoal.accountId == accountId,
                          let kind = PACEWidgetGoalKind(rawValue: selectedGoal.goalKind),
                          let selectedSnapshot = catalog.goals.first(where: {
                              $0.goalId == selectedGoal.goalId && $0.kind == kind
                          }) else {
                        return PACEWidgetEntry(date: date, state: .goalUnavailable, snapshot: nil)
                    }
                    return PACEWidgetEntry(date: date, state: .ready, snapshot: selectedSnapshot)
                }

                let defaultGoal = catalog.defaultGoal(asOf: date)
                guard let defaultGoal else {
                    return PACEWidgetEntry(date: date, state: .noActiveGoal, snapshot: nil)
                }
                return PACEWidgetEntry(date: date, state: .ready, snapshot: defaultGoal)
            }
        }
    }

    private static let previewSnapshot: PACEWidgetSnapshot = {
        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        let createdAt = calendar.date(byAdding: .day, value: -12, to: now) ?? now
        let targetDate = calendar.date(byAdding: .day, value: 15, to: now) ?? now
        let createdAtString = PACEWidgetSnapshot.dayKey(for: createdAt, calendar: calendar)
        return PACEWidgetSnapshot(
            goalId: "preview-goal",
            title: "IOS MASTERY",
            kind: .solo,
            createdAt: createdAt,
            createdAtString: createdAtString,
            targetDate: targetDate,
            historyStartDateString: createdAtString,
            targetDateString: PACEWidgetSnapshot.dayKey(for: targetDate, calendar: calendar),
            scheduledWeekdays: [1, 2, 3, 4, 5, 6, 7],
            loggedDateStrings: []
        )
    }()
}
