//
//  PACEPrimaryGoalWidget.swift
//  PACEWidget
//
//  Primary Goal Widget implementation conforming to WidgetKit.
//  Configured for systemSmall and systemMedium.
//

import WidgetKit
import SwiftUI

struct PACEWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: PACEWidgetSnapshot?
}

struct PACEWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PACEWidgetEntry {
        PACEWidgetEntry(date: Date(), snapshot: PACEWidgetSnapshot.mock)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (PACEWidgetEntry) -> Void) {
        let snapshot = PACEWidgetSnapshotManager.readSnapshot() ?? (context.isPreview ? PACEWidgetSnapshot.mock : nil)
        let entry = PACEWidgetEntry(date: Date(), snapshot: snapshot)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<PACEWidgetEntry>) -> Void) {
        let snapshot = PACEWidgetSnapshotManager.readSnapshot()
        let entry = PACEWidgetEntry(date: Date(), snapshot: snapshot)
        
        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct PACEPrimaryGoalWidget: Widget {
    let kind: String = "PACEPrimaryGoalWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PACEWidgetProvider()) { entry in
            PACEWidgetEntryView(entry: entry)
                .containerBackground(Color.black, for: .widget)
        }
        .configurationDisplayName("PACE Goal")
        .description("Track your primary objective, streak, and daily proof status.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
