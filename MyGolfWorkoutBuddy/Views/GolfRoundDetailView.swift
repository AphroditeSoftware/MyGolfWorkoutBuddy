//
//  GolfRoundDetailView.swift
//  MyGolfWorkoutBuddy
//
//  Created by Janene Pappas on 7/6/26.
//
//  Detail screen for one round: summary stats, heart-rate and walking-speed
//  charts (with cart time shaded), and the list of detected swings.
//

import SwiftUI
import Charts

struct GolfRoundDetailView: View {
    let round: GolfRound
    let store: GolfRoundsStore

    @State private var averageHeartRate: Double?
    @State private var heartRateSamples: [HeartRateSample] = []
    @State private var isLoadingHeartRate = true

    @State private var speedSamples: [SpeedSample] = []
    @State private var isLoadingSpeed = true

    var body: some View {
        List {
            Section {
                statRow(systemImage: "calendar", title: "Date", value: round.formattedDate)
                statRow(systemImage: "clock", title: "Duration", value: round.formattedDuration)
                if let calories = round.formattedCalories {
                    statRow(systemImage: "flame", title: "Calories Burned", value: calories, imageColor: .calorieFlame)
                }
                if let distance = round.formattedDistance {
                    statRow(systemImage: "figure.walk", title: "Distance", value: distance)
                }
            }
            
            Section("Heart Rate") {
                if isLoadingHeartRate {
                    HStack {
                        ProgressView()
                        Text("Loading…")
                            .foregroundStyle(.secondary)
                    }
                } else if averageHeartRate == nil && heartRateSamples.isEmpty {
                    Text("No heart rate data for this round.")
                        .foregroundStyle(.secondary)
                } else {
                    if let averageHeartRate {
                        statRow(systemImage: "heart.fill", title: "Average", value: String(format: "%.0f BPM", averageHeartRate), imageColor: .red)
                    }
                    if !heartRateSamples.isEmpty {
                        heartRateChart
                    }
                }
            }

            Section("Speed") {
                if isLoadingSpeed {
                    HStack {
                        ProgressView()
                        Text("Loading…")
                            .foregroundStyle(.secondary)
                    }
                } else if speedSamples.isEmpty {
                    Text("No speed data for this round.")
                        .foregroundStyle(.secondary)
                } else {
                    speedChart
                }
            }

            Section("Golf Swings") {
                statRow(systemImage: "figure.golf", title: "Swings Detected", value: "\(round.swingCount)")

                if !round.swingTimestamps.isEmpty {
                    ForEach(Array(round.swingTimestamps.enumerated()), id: \.offset) { index, timestamp in
                        HStack {
                            Text("Swing \(index + 1)")
                            Spacer()
                            Text(relativeOffset(for: timestamp))
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                }
            }


        }
        .navigationTitle("Round Detail")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            async let average = store.averageHeartRate(for: round)
            async let samples = store.heartRateSamples(for: round)
            async let speed = store.speedSamples(for: round)
            averageHeartRate = await average
            heartRateSamples = await samples
            isLoadingHeartRate = false
            speedSamples = await speed
            isLoadingSpeed = false
        }
    }

    private var heartRateChart: some View {
        Chart(heartRateSamples) { sample in
            LineMark(
                x: .value("Time", sample.date),
                y: .value("BPM", sample.bpm)
            )
            .foregroundStyle(Color.calorieFlame)
            .interpolationMethod(.catmullRom)
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .frame(height: 160)
        .padding(.vertical, 4)
    }

    /// A speed sample tagged with which contiguous run (between cart pauses) it
    /// belongs to, so the chart can draw each run as its own unconnected line.
    private struct SegmentedSpeedSample: Identifiable {
        let sample: SpeedSample
        let segment: Int
        var id: UUID { sample.id }
    }

    /// Speed samples split into segments by the round's cart intervals: any point
    /// inside a cart pause is dropped, and each point's segment is the number of
    /// cart intervals that have already ended before it.
    private var segmentedSpeedSamples: [SegmentedSpeedSample] {
        let intervals = round.cartIntervals.sorted { $0.start < $1.start }
        return speedSamples.compactMap { sample in
            if intervals.contains(where: { $0.contains(sample.date) }) {
                return nil
            }
            let segment = intervals.filter { $0.end <= sample.date }.count
            return SegmentedSpeedSample(sample: sample, segment: segment)
        }
    }

    private var speedChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            Chart {
                // Shade the stretches the round was paused for a cart ride so the
                // line bridging that gap isn't mistaken for actual movement.
                ForEach(round.cartIntervals, id: \.self) { interval in
                    RectangleMark(
                        xStart: .value("Cart start", interval.start),
                        xEnd: .value("Cart end", interval.end)
                    )
                    .foregroundStyle(.gray.opacity(0.18))
                }

                // Split the line into a separate series on each side of a cart
                // gap so it isn't drawn straight across the paused stretch.
                ForEach(segmentedSpeedSamples) { item in
                    LineMark(
                        x: .value("Time", item.sample.date),
                        y: .value("mph", item.sample.milesPerHour),
                        series: .value("Segment", item.segment)
                    )
                    .foregroundStyle(.green)
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartYScale(domain: .automatic(includesZero: true))
            .frame(height: 160)

            if !round.cartIntervals.isEmpty {
                Label("Shaded time was spent in a cart (paused).", systemImage: "car.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func statRow(systemImage: String, title: String, value: String, imageColor: Color? = nil) -> some View {
        HStack {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(imageColor ?? Color.accentColor)
            }
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func relativeOffset(for timestamp: Date) -> String {
        let seconds = Int(timestamp.timeIntervalSince(round.startDate))
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d into round", minutes, remainingSeconds)
    }
}

#if DEBUG
#Preview {
    let start = Date.now
    let round = GolfRound(
        id: UUID(),
        startDate: start,
        endDate: start.addingTimeInterval(3600),
        duration: 3600,
        totalEnergyBurned: 450,
        totalDistance: 4800,
        swingCount: 3,
        swingTimestamps: [
            start.addingTimeInterval(120),
            start.addingTimeInterval(400),
            start.addingTimeInterval(900)
        ],
        cartIntervals: [
            DateInterval(start: start.addingTimeInterval(1320), end: start.addingTimeInterval(1560)),
            DateInterval(start: start.addingTimeInterval(2760), end: start.addingTimeInterval(2940))
        ]
    )

    // Synthetic heart rate curve so the chart has something to draw.
    let bpms: [Double] = [92, 104, 118, 131, 126, 140, 135, 122, 110, 98]
    let samples = bpms.enumerated().map { index, bpm in
        HeartRateSample(date: start.addingTimeInterval(Double(index) * 360), bpm: bpm)
    }

    // Synthetic walking-speed curve (mph) so the speed chart has something to draw.
    let speeds: [Double] = [0.0, 2.6, 3.1, 2.9, 0.2, 2.8, 3.0, 2.7, 0.1, 2.5]
    let speedSamples = speeds.enumerated().map { index, mph in
        SpeedSample(date: start.addingTimeInterval(Double(index) * 360), milesPerHour: mph)
    }

    return NavigationStack {
        GolfRoundDetailView(
            round: round,
            store: .preview(
                rounds: [round],
                heartRateSamples: [round.id: samples],
                speedSamples: [round.id: speedSamples]
            )
        )
    }
}
#endif
