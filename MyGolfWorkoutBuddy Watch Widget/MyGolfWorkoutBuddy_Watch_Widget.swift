//
//  MyGolfWorkoutBuddy_Watch_Widget.swift
//  MyGolfWorkoutBuddy Watch Widget
//
//  Created by Janene Pappas on 7/8/26.
//
//  A quick-launch complication: shows the golf icon and opens the app (to start
//  a round) when tapped. Static content, so no data sharing is required.
//

import WidgetKit
import SwiftUI

struct GolfLauncherEntry: TimelineEntry {
    let date: Date
}

/// The launcher is static, so it vends a single entry that never needs refreshing.
struct GolfLauncherProvider: TimelineProvider {
    func placeholder(in context: Context) -> GolfLauncherEntry {
        GolfLauncherEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (GolfLauncherEntry) -> Void) {
        completion(GolfLauncherEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GolfLauncherEntry>) -> Void) {
        completion(Timeline(entries: [GolfLauncherEntry(date: Date())], policy: .never))
    }
}

struct GolfLauncherView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            HStack(spacing: 6) {
                Image(systemName: "figure.golf")
                    .font(.title2)
                VStack(alignment: .leading) {
                    Text("Golf Workout")
                    Text("Tap to start")
                        .foregroundStyle(.secondary)
                }
            }
        case .accessoryInline:
            Label("Start Round", systemImage: "figure.golf")
        default:
            // Circular / corner: just the icon on the standard accessory background.
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "figure.golf")
                    .font(.title3)
            }
        }
    }
}

struct MyGolfWorkoutBuddy_Watch_Widget: Widget {
    let kind: String = "MyGolfWorkoutBuddy_Watch_Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GolfLauncherProvider()) { _ in
            GolfLauncherView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Start Round")
        .description("Open Golf Workout Buddy to start a round.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline,
            .accessoryRectangular
        ])
    }
}

#Preview(as: .accessoryCircular) {
    MyGolfWorkoutBuddy_Watch_Widget()
} timeline: {
    GolfLauncherEntry(date: .now)
}
