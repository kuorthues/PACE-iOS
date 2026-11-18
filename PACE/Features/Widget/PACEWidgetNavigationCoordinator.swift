import Foundation
import SwiftUI

enum PACEWidgetNavigationDestination: Equatable {
    case goals
    case goal(id: String, kind: PACEWidgetGoalKind)
    case log(id: String, kind: PACEWidgetGoalKind)
    case invalid
}

struct PACEWidgetNavigationRequest: Equatable, Identifiable {
    let id: UUID
    let destination: PACEWidgetNavigationDestination

    init(destination: PACEWidgetNavigationDestination) {
        self.id = UUID()
        self.destination = destination
    }
}

@MainActor
final class PACEWidgetNavigationCoordinator: ObservableObject {
    static let shared = PACEWidgetNavigationCoordinator()

    @Published private(set) var pendingRequest: PACEWidgetNavigationRequest?

    private init() {}

    func receive(_ url: URL) {
        guard url.scheme?.lowercased() == "pace" else { return }

        let host = (url.host ?? url.path)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            pendingRequest = PACEWidgetNavigationRequest(destination: .invalid)
            return
        }

        if host == "goals" {
            pendingRequest = PACEWidgetNavigationRequest(destination: .goals)
            return
        }
        guard host == "goal" || host == "log" else { return }

        let queryItems = components.queryItems ?? []
        let goalId = queryItems.first(where: {
            $0.name == "id" || $0.name == "goalId"
        })?.value
        guard let goalId, Self.isValidGoalId(goalId) else {
            pendingRequest = PACEWidgetNavigationRequest(destination: .invalid)
            return
        }

        let rawKind = queryItems.first(where: { $0.name == "kind" })?.value ?? "solo"
        guard let kind = PACEWidgetGoalKind(rawValue: rawKind) else {
            pendingRequest = PACEWidgetNavigationRequest(destination: .invalid)
            return
        }

        let destination: PACEWidgetNavigationDestination = host == "log"
            ? .log(id: goalId, kind: kind)
            : .goal(id: goalId, kind: kind)
        pendingRequest = PACEWidgetNavigationRequest(destination: destination)
    }

    func consume(requestId: UUID) {
        guard pendingRequest?.id == requestId else { return }
        pendingRequest = nil
    }

    private static func isValidGoalId(_ value: String) -> Bool {
        !value.isEmpty
            && value.count <= 512
            && !value.contains("/")
            && value.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) }
    }
}
