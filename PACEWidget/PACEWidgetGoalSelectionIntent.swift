import AppIntents
import Foundation

struct PACEWidgetGoalEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "PACE Goal"
    static var defaultQuery = PACEWidgetGoalQuery()

    var id: String

    @Property(title: "Goal")
    var name: String

    @Property(title: "Details")
    var details: String

    var accountId: String

    var goalId: String

    var goalKind: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(details)")
    }

    init(snapshot: PACEWidgetSnapshot, accountId: String) {
        self.id = Self.identifier(accountId: accountId, kind: snapshot.kind, goalId: snapshot.goalId)
        self.accountId = accountId
        self.goalId = snapshot.goalId
        self.goalKind = snapshot.kind.rawValue
        self.name = snapshot.title
        self.details = Self.details(for: snapshot)
    }

    init(unavailableIdentifier: String) {
        let parts = Self.parseIdentifier(unavailableIdentifier)
        self.id = unavailableIdentifier
        self.accountId = parts?.accountId ?? ""
        self.goalId = parts?.goalId ?? ""
        self.goalKind = parts?.kind.rawValue ?? ""
        self.name = "Unavailable goal"
        self.details = "Open PACE to sync or choose another goal"
    }

    static func identifier(accountId: String, kind: PACEWidgetGoalKind, goalId: String) -> String {
        "\(accountId)|\(kind.rawValue)|\(goalId)"
    }

    static func parseIdentifier(_ identifier: String) -> (accountId: String, kind: PACEWidgetGoalKind, goalId: String)? {
        guard let accountSeparator = identifier.firstIndex(of: "|") else { return nil }
        let accountId = String(identifier[..<accountSeparator])
        let kindStart = identifier.index(after: accountSeparator)
        guard let kindSeparator = identifier[kindStart...].firstIndex(of: "|") else { return nil }
        let rawKind = String(identifier[kindStart..<kindSeparator])
        let goalStart = identifier.index(after: kindSeparator)
        let goalId = String(identifier[goalStart...])
        guard !accountId.isEmpty,
              let kind = PACEWidgetGoalKind(rawValue: rawKind),
              !goalId.isEmpty else { return nil }
        return (accountId, kind, goalId)
    }

    private static func details(for snapshot: PACEWidgetSnapshot) -> String {
        let target = "TARGET \(snapshot.formattedTargetDate)"
        return snapshot.kind == .shared ? "SHARED · \(target)" : target
    }
}

struct PACEWidgetGoalQuery: EntityQuery {
    func entities(for identifiers: [PACEWidgetGoalEntity.ID]) async throws -> [PACEWidgetGoalEntity] {
        let catalog = readyCatalog()
        return identifiers.map { identifier in
            guard let catalog,
                  let accountId = catalog.accountId,
                  let snapshot = catalog.goals.first(where: {
                      PACEWidgetGoalEntity.identifier(accountId: accountId, kind: $0.kind, goalId: $0.goalId) == identifier
                  }) else {
                return PACEWidgetGoalEntity(unavailableIdentifier: identifier)
            }
            return PACEWidgetGoalEntity(snapshot: snapshot, accountId: accountId)
        }
    }

    func suggestedEntities() async throws -> [PACEWidgetGoalEntity] {
        guard let catalog = readyCatalog(), let accountId = catalog.accountId else { return [] }
        return catalog.orderedGoals()
            .map { PACEWidgetGoalEntity(snapshot: $0, accountId: accountId) }
    }

    private func readyCatalog() -> PACEWidgetSnapshotCatalog? {
        guard case .available(let catalog) = PACEWidgetSnapshotStore.readCatalog(),
              catalog.status == .ready else { return nil }
        return catalog
    }
}

struct PACEWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose a PACE Goal"
    static var description = IntentDescription("Choose which PACE goal this widget tracks.")

    @Parameter(title: "Goal")
    var goal: PACEWidgetGoalEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Track a PACE goal")
    }
}
