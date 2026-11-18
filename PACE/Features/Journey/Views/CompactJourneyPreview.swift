import SwiftUI

struct CompactJourneyPreview: View {
    let goal: PACEGoal
    let days: [JourneyDay]
    var onOpenFullJourney: () -> Void

    private var completedCount: Int {
        days.filter { $0.state == .completed || $0.state == .completedWithEvidence }.count
    }

    private var currentDay: JourneyDay? {
        if let today = days.first(where: \.isToday) {
            return today
        }
        if Calendar.current.startOfDay(for: Date()) > Calendar.current.startOfDay(for: goal.targetDate) {
            return days.last
        }
        return days.last(where: { $0.log != nil }) ?? days.first
    }

    private var progressFraction: CGFloat {
        guard let currentDay, days.count > 1 else { return days.isEmpty ? 0 : 1 }
        return min(1, max(0, CGFloat(currentDay.dayIndex - 1) / CGFloat(days.count - 1)))
    }

    private var currentDayLabel: String {
        guard let currentDay else { return "CURRENT" }
        if currentDay.isToday { return "TODAY" }
        if currentDay.isTarget { return "TARGET PASSED" }
        return currentDay.log == nil ? "CURRENT" : "LAST ENTRY"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text("CURRENT JOURNEY")
                    .font(PACETextStyle.pixelLabel)
                    .foregroundColor(PACETheme.secondaryText)
                    .tracking(1.2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 4)

                Button(action: onOpenFullJourney) {
                    HStack(spacing: 6) {
                        Text("VIEW JOURNEY")
                            .font(PACETextStyle.pixelMetadata)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(PACETheme.accent)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View complete Journey for \(goal.title)")
            }

            if let first = days.first, let currentDay {
                GeometryReader { geometry in
                    let left = CGFloat(12)
                    let right = max(left + 24, geometry.size.width - 12)
                    let lineWidth = right - left
                    let progressX = left + lineWidth * progressFraction
                    let markerX = min(max(progressX, left), right)

                    ZStack {
                        Rectangle()
                            .fill(PACETheme.border)
                            .frame(width: lineWidth, height: 2)
                            .position(x: (left + right) / 2, y: 13)

                        Rectangle()
                            .fill(PACETheme.accent)
                            .frame(width: lineWidth * progressFraction, height: 2)
                            .position(x: left + lineWidth * progressFraction / 2, y: 13)

                        JourneyTimelineNodeView(state: first.state, nodeBaseSize: 8)
                            .position(x: left, y: 13)

                        JourneyTimelineNodeView(state: currentDay.state, nodeBaseSize: 8)
                            .position(x: markerX, y: 13)

                        JourneyTimelineNodeView(state: .target, nodeBaseSize: 8)
                            .position(x: right, y: 13)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 26)
                .accessibilityHidden(true)

                HStack(alignment: .top, spacing: 6) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("START")
                        Text(first.formattedShortDate.uppercased())
                            .foregroundColor(PACETheme.primaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .center, spacing: 3) {
                        Text(currentDayLabel)
                        Text("DAY \(currentDay.dayIndex) OF \(currentDay.totalDays)")
                            .foregroundColor(PACETheme.primaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityLabel("\(currentDayLabel), day \(currentDay.dayIndex) of \(currentDay.totalDays)")

                    VStack(alignment: .trailing, spacing: 3) {
                        Text("TARGET")
                        Text(goal.formattedTargetDate.uppercased())
                            .foregroundColor(PACETheme.primaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(PACETextStyle.pixelMetadata)
                .foregroundColor(PACETheme.secondaryText)
                .tracking(0.3)
                .accessibilityElement(children: .combine)

                Text("\(completedCount) OF \(days.count) DAYS COMPLETED")
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACETheme.accent)
                    .tracking(0.6)
                    .accessibilityLabel("\(completedCount) of \(days.count) days completed")
            } else {
                Text("SET A DEADLINE TO BEGIN YOUR JOURNEY.")
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACETheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
