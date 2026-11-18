import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
final class PACEWidgetSyncService {
    static let shared = PACEWidgetSyncService()
    static let widgetKind = "PACEPrimaryGoalWidget"

    private var pendingSync: Task<Void, Never>?

    private init() {}

    func markNeedsSync(for accountId: String? = AuthService.shared.currentUser?.id) {
        guard let accountId, !accountId.isEmpty else {
            clearForSignedOut()
            return
        }

        if case .available(let catalog) = PACEWidgetSnapshotStore.readCatalog(),
           catalog.accountId == accountId,
           catalog.status == .ready {
            return
        }

        persist(PACEWidgetSnapshotCatalog(accountId: accountId, status: .needsSync, goals: []))
    }

    func requestSync() {
        guard AuthService.shared.isAuthenticated,
              let accountId = AuthService.shared.currentUser?.id else {
            clearForSignedOut()
            return
        }

        pendingSync?.cancel()
        pendingSync = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 250_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.syncCurrentAccount(accountId: accountId)
        }
    }

    func clearForSignedOut() {
        pendingSync?.cancel()
        pendingSync = nil
        persist(.signedOut)
    }

    private func syncCurrentAccount(accountId: String) {
        guard AuthService.shared.isAuthenticated,
              AuthService.shared.currentUser?.id == accountId else {
            clearForSignedOut()
            return
        }

        let sharedService = SharedGoalService.shared
        if AuthService.shared.isFirebaseConfigured && !sharedService.hasLoaded {
            return
        }

        let soloGoals = GoalService.shared.goals.filter {
            $0.userId == accountId && $0.status == .active
        }

        let previousSnapshots: [String: PACEWidgetSnapshot]
        if case .available(let previousCatalog) = PACEWidgetSnapshotStore.readCatalog(),
           previousCatalog.accountId == accountId,
           previousCatalog.status == .ready {
            previousSnapshots = Dictionary(uniqueKeysWithValues: previousCatalog.goals.map { ($0.id, $0) })
        } else {
            previousSnapshots = [:]
        }

        if soloGoals.isEmpty,
           GoalService.shared.errorMessage != nil || sharedService.errorMessage != nil {
            persist(PACEWidgetSnapshotCatalog(accountId: accountId, status: .needsSync, goals: []))
            return
        }

        var snapshots = soloGoals.map { goal in
            makeSnapshot(
                id: goal.id,
                title: goal.title,
                kind: .solo,
                createdAt: goal.createdAt,
                targetDate: goal.targetDate,
                scheduledWeekdays: goal.scheduledWeekdays,
                logs: DailyLogService.shared.logsByGoal[goal.id] ?? [],
                previousSnapshot: previousSnapshots["solo:\(goal.id)"]
            )
        }

        let activeSharedGoals = sharedService.goals.filter {
            $0.status == .active && $0.memberIds.contains(accountId)
        }
        snapshots.append(contentsOf: activeSharedGoals.map { goal in
            let ownLogs = (sharedService.logsByGoal[goal.id] ?? []).filter { $0.authorId == accountId }
            let personalStartDate = goal.ownerId == accountId
                ? goal.startDate
                : (goal.memberJoinedAt ?? goal.startDate)
            return makeSnapshot(
                id: goal.id,
                title: goal.title,
                kind: .shared,
                createdAt: personalStartDate,
                targetDate: goal.targetDateForDisplay,
                targetDateString: goal.targetDateString,
                scheduledWeekdays: goal.scheduledWeekdays,
                logs: ownLogs,
                previousSnapshot: previousSnapshots["shared:\(goal.id)"]
            )
        })

        snapshots.sort {
            if $0.targetDateString == $1.targetDateString { return $0.id < $1.id }
            return $0.targetDateString < $1.targetDateString
        }

        persist(PACEWidgetSnapshotCatalog(accountId: accountId, status: .ready, goals: snapshots))
    }

    private func makeSnapshot(
        id: String,
        title: String,
        kind: PACEWidgetGoalKind,
        createdAt: Date,
        targetDate: Date,
        targetDateString: String? = nil,
        scheduledWeekdays: [Int],
        logs: [DailyLog],
        previousSnapshot: PACEWidgetSnapshot?
    ) -> PACEWidgetSnapshot {
        let calendar = Calendar.autoupdatingCurrent
        let createdAtString = previousSnapshot.flatMap { Self.matchesStoredTimestamp($0.createdAt, createdAt) ? $0.createdAtString : nil }
            ?? PACEWidgetSnapshot.dayKey(for: createdAt, calendar: calendar)
        let providedTargetDateString = targetDateString.flatMap {
            PACEWidgetSnapshot.isValidDayKey($0, calendar: calendar) ? $0 : nil
        }
        let resolvedTargetDateString = providedTargetDateString
            ?? previousSnapshot.flatMap { Self.matchesStoredTimestamp($0.targetDate, targetDate) ? $0.targetDateString : nil }
            ?? PACEWidgetSnapshot.dayKey(for: targetDate, calendar: calendar)
        let dateStrings = Array(Set(logs.map(\.dateString).filter {
            PACEWidgetSnapshot.isValidDayKey($0, calendar: calendar)
        })).sorted()
        let historyStartDateString = min(dateStrings.min() ?? createdAtString, createdAtString)
        return PACEWidgetSnapshot(
            goalId: id,
            title: title,
            kind: kind,
            createdAt: createdAt,
            createdAtString: createdAtString,
            targetDate: targetDate,
            historyStartDateString: historyStartDateString,
            targetDateString: resolvedTargetDateString,
            scheduledWeekdays: scheduledWeekdays,
            loggedDateStrings: dateStrings
        )
    }

    private func persist(_ catalog: PACEWidgetSnapshotCatalog) {
        UserDefaults.standard.removeObject(forKey: PACEWidgetSnapshotStore.legacySnapshotKey)
        guard case .changed = PACEWidgetSnapshotStore.write(catalog) else { return }
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: Self.widgetKind)
        #endif
    }

    private static func matchesStoredTimestamp(_ lhs: Date, _ rhs: Date) -> Bool {
        abs(lhs.timeIntervalSince(rhs)) < 1
    }
}
