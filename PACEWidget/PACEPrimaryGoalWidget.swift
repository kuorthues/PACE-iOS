import SwiftUI
import WidgetKit

struct PACEPrimaryGoalWidget: Widget {
    let kind: String = "PACEPrimaryGoalWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: PACEWidgetConfigurationIntent.self,
            provider: PACEWidgetTimelineProvider()
        ) { entry in
            PACEWidgetEntryView(entry: entry)
                .containerBackground(Color.black, for: .widget)
        }
        .configurationDisplayName("PACE Goal")
        .description("Track a selected PACE goal, deadline, streak, and daily status.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
