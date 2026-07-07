//
//  GolfRoundDetailView.swift
//  MyGolfWorkoutBuddy
//

import SwiftUI

struct GolfRoundDetailView: View {
    let round: GolfRound
    let store: GolfRoundsStore

    @State private var averageHeartRate: Double?
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

            Section("Heart Rate") {
                if isLoadingHeartRate {
                    HStack {
                        ProgressView()
                        Text("Loading…")
                            .foregroundStyle(.secondary)
                    }
                } else if let averageHeartRate {
                    statRow(systemImage: "heart.fill", title: "Average", value: String(format: "%.0f BPM", averageHeartRate), imageColor: .red)
                } else {
                    Text("No heart rate data for this round.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Round Detail")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            averageHeartRate = await store.averageHeartRate(for: round)
            isLoadingHeartRate = false
        }
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
    NavigationStack {
        GolfRoundDetailView(
            round: GolfRound(
                id: UUID(),
                startDate: .now,
                endDate: .now.addingTimeInterval(3600),
                duration: 3600,
                totalEnergyBurned: 450,
                totalDistance: 4800,
                swingCount: 3,
                swingTimestamps: [
                    Date().addingTimeInterval(120),
                    Date().addingTimeInterval(400),
                    Date().addingTimeInterval(900)
                ]
            ),
            store: GolfRoundsStore()
        )
    }
}
