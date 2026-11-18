import SwiftUI
import WidgetKit

struct PACEWidgetEntryView: View {
    let entry: PACEWidgetEntry

    @Environment(\.widgetFamily) private var family

    private let accent = Color(red: 167.0 / 255.0, green: 1.0, blue: 25.0 / 255.0)
    private let muted = Color(red: 142.0 / 255.0, green: 142.0 / 255.0, blue: 147.0 / 255.0)
    private let border = Color(red: 48.0 / 255.0, green: 48.0 / 255.0, blue: 50.0 / 255.0)

    var body: some View {
        Group {
            if let snapshot = entry.snapshot,
               entry.state == .ready || entry.state == .preview {
                if family == .systemMedium {
                    mediumView(snapshot: snapshot)
                } else {
                    smallView(snapshot: snapshot)
                }
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .foregroundStyle(.white)
        .widgetURL(destinationURL)
        .accessibilityElement(children: .combine)
    }

    private func smallView(snapshot: PACEWidgetSnapshot) -> some View {
        let metrics = snapshot.metrics(for: entry.date)

        return VStack(alignment: .leading, spacing: 7) {
            brandHeader(kind: snapshot.kind)

            Text(snapshot.title.uppercased())
                .font(.system(.headline, design: .default, weight: .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            HStack(alignment: .lastTextBaseline, spacing: 5) {
                if metrics.isOverdue {
                    Text("\(metrics.daysOverdue)")
                        .font(.system(.title3, design: .monospaced, weight: .bold))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Text("\(metrics.daysRemaining)")
                        .font(.system(.largeTitle, design: .monospaced, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }

                Text(countdownCaption(metrics))
                    .font(.system(.caption2, design: .monospaced, weight: .medium))
                    .foregroundStyle(muted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            }

            statusLine(metrics, compact: true)
        }
        .padding(2)
    }

    private func mediumView(snapshot: PACEWidgetSnapshot) -> some View {
        let metrics = snapshot.metrics(for: entry.date)

        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                brandHeader(kind: snapshot.kind)

                Text(snapshot.title.uppercased())
                    .font(.system(.title3, design: .default, weight: .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 2)

                statusLine(metrics, compact: false)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(metrics.isProofPending ? accent : Color.clear)
                    .overlay(Rectangle().stroke(metrics.isProofPending ? accent : border, lineWidth: 1))
                    .foregroundStyle(metrics.isProofPending ? .black : .white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            Rectangle()
                .fill(border)
                .frame(width: 1)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    if metrics.isOverdue {
                        Text("\(metrics.daysOverdue)")
                            .font(.system(.title, design: .monospaced, weight: .bold))
                            .foregroundStyle(accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("DAYS OVERDUE")
                            .font(.system(.caption2, design: .monospaced, weight: .medium))
                            .foregroundStyle(muted)
                    } else {
                        Text("\(metrics.daysRemaining)")
                            .font(.system(.largeTitle, design: .monospaced, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                        Text(metrics.daysRemaining == 0 ? "DUE TODAY" : "DAYS LEFT")
                            .font(.system(.caption2, design: .monospaced, weight: .medium))
                            .foregroundStyle(muted)
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(metrics.currentStreak)")
                        .font(.system(.title2, design: .monospaced, weight: .bold))
                        .foregroundStyle(metrics.currentStreak > 0 ? accent : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("DAY STREAK")
                        .font(.system(.caption2, design: .monospaced, weight: .medium))
                        .foregroundStyle(muted)
                }

                Text("TARGET \(snapshot.formattedTargetDate)")
                    .font(.system(.caption2, design: .monospaced, weight: .medium))
                    .foregroundStyle(muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(width: 112, alignment: .leading)
        }
        .padding(2)
    }

    private func brandHeader(kind: PACEWidgetGoalKind) -> some View {
        HStack(spacing: 6) {
            Text("PACE")
                .font(.system(.caption, design: .monospaced, weight: .black))
                .tracking(1.2)
                .foregroundStyle(accent)

            if kind == .shared {
                Text("TOGETHER")
                    .font(.system(.caption2, design: .monospaced, weight: .medium))
                    .foregroundStyle(muted)
            }

            Spacer(minLength: 0)
        }
        .accessibilityLabel(kind == .shared ? "PACE Together" : "PACE")
    }

    @ViewBuilder
    private func statusLine(_ metrics: PACEWidgetMetrics, compact: Bool) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(metrics.isProofPending && !compact ? .black : (metrics.isLoggedToday || metrics.isProofPending ? accent : muted))
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)

            Text(statusCaption(metrics, compact: compact))
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(metrics.isLoggedToday ? accent : (metrics.isProofPending ? (compact ? accent : .black) : muted))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            brandHeader(kind: .solo)
            Spacer(minLength: 0)
            Text(emptyTitle)
                .font(.system(.headline, design: .default, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            Text(emptyDetail)
                .font(.system(.caption2, design: .monospaced, weight: .medium))
                .foregroundStyle(muted)
                .lineLimit(family == .systemSmall ? 3 : 2)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 0)
        }
        .padding(2)
    }

    private var emptyTitle: String {
        switch entry.state {
        case .preview: return "PACE"
        case .ready: return "GOAL UNAVAILABLE"
        case .noActiveGoal: return "NO ACTIVE GOAL"
        case .signedOut: return "SIGN IN TO CONTINUE"
        case .needsSync: return "OPEN PACE TO SYNC"
        case .goalUnavailable: return "GOAL UNAVAILABLE"
        case .appGroupUnavailable: return "WIDGET DATA UNAVAILABLE"
        }
    }

    private var emptyDetail: String {
        switch entry.state {
        case .preview: return "PREVIEW"
        case .ready, .goalUnavailable: return "EDIT WIDGET TO SELECT ANOTHER GOAL"
        case .noActiveGoal: return "OPEN PACE TO CREATE A GOAL"
        case .signedOut: return "OPEN PACE TO SIGN IN"
        case .needsSync: return "OPEN PACE TO SYNC YOUR GOALS"
        case .appGroupUnavailable: return "OPEN PACE TO SYNC YOUR GOALS"
        }
    }

    private var destinationURL: URL? {
        guard let snapshot = entry.snapshot,
              entry.state == .ready else {
            return Self.url(host: "goals")
        }
        let metrics = snapshot.metrics(for: entry.date)
        let shouldOpenLog = family == .systemMedium && metrics.isProofPending
        return Self.url(
            host: shouldOpenLog ? "log" : "goal",
            goalId: snapshot.goalId,
            kind: snapshot.kind
        )
    }

    private static func url(host: String, goalId: String? = nil, kind: PACEWidgetGoalKind? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = "pace"
        components.host = host
        if let goalId {
            components.queryItems = [
                URLQueryItem(name: host == "log" ? "goalId" : "id", value: goalId),
                URLQueryItem(name: "kind", value: kind?.rawValue)
            ]
        }
        return components.url
    }

    private func countdownCaption(_ metrics: PACEWidgetMetrics) -> String {
        if metrics.isOverdue { return "DAYS OVERDUE" }
        return metrics.daysRemaining == 0 ? "DUE TODAY" : "DAYS REMAINING"
    }

    private func statusCaption(_ metrics: PACEWidgetMetrics, compact: Bool) -> String {
        if entry.state == .preview { return "PREVIEW" }
        if metrics.isLoggedToday { return compact ? "LOGGED TODAY" : "LOGGED TODAY · OPEN GOAL" }
        if metrics.isProofPending { return compact ? "PROOF PENDING" : "LOG TODAY" }
        return "REST DAY"
    }
}
