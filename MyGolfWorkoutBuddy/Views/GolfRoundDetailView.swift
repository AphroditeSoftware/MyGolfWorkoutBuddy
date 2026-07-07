//
//  GolfRoundDetailView.swift
//  MyGolfWorkoutBuddy
//

import SwiftUI
import Charts

struct GolfRoundDetailView: View {
    let round: GolfRound
    let store: GolfRoundsStore

    @State private var averageHeartRate: Double?
    @State private var heartRateSamples: [HeartRateSample] = []
    @State private var isLoadingHeartRate = true

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
            averageHeartRate = await average
            heartRateSamples = await samples
            isLoadingHeartRate = false
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
        ]
    )

    // Synthetic heart rate curve so the chart has something to draw.
    let bpms: [Double] = [92, 104, 118, 131, 126, 140, 135, 122, 110, 98]
    let samples = bpms.enumerated().map { index, bpm in
        HeartRateSample(date: start.addingTimeInterval(Double(index) * 360), bpm: bpm)
    }

    return NavigationStack {
        GolfRoundDetailView(
            round: round,
            store: .preview(rounds: [round], heartRateSamples: [round.id: samples])
        )
    }
}
