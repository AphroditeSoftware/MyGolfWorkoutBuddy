import func SwiftUI.__designTimeFloat
import func SwiftUI.__designTimeString
import func SwiftUI.__designTimeInteger
import func SwiftUI.__designTimeBoolean

#sourceLocation(file: "/Users/janenepappas/iOS/MyGolfWorkoutBuddy/MyGolfWorkoutBuddy/Views/GolfRoundDetailView.swift", line: 1)
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
                statRow(systemImage: __designTimeString("#8839_0", fallback: "calendar"), title: __designTimeString("#8839_1", fallback: "Date"), value: round.formattedDate)
                statRow(systemImage: __designTimeString("#8839_2", fallback: "clock"), title: __designTimeString("#8839_3", fallback: "Duration"), value: round.formattedDuration)
                if let calories = round.formattedCalories {
                    statRow(systemImage: __designTimeString("#8839_4", fallback: "flame"), title: __designTimeString("#8839_5", fallback: "Active Energy"), value: calories)
                }
                if let distance = round.formattedDistance {
                    statRow(systemImage: __designTimeString("#8839_6", fallback: "figure.walk"), title: __designTimeString("#8839_7", fallback: "Distance"), value: distance)
                }
            }

            Section(__designTimeString("#8839_8", fallback: "Golf Swings")) {
                statRow(systemImage: __designTimeString("#8839_9", fallback: "figure.golf"), title: __designTimeString("#8839_10", fallback: "Swings Detected"), value: "\(round.swingCount)")

                if !round.swingTimestamps.isEmpty {
                    ForEach(Array(round.swingTimestamps.enumerated()), id: \.offset) { index, timestamp in
                        HStack {
                            Text("Swing \(index + __designTimeInteger("#8839_11", fallback: 1))")
                            Spacer()
                            Text(relativeOffset(for: timestamp))
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                }
            }

            Section(__designTimeString("#8839_12", fallback: "Heart Rate")) {
                if isLoadingHeartRate {
                    HStack {
                        ProgressView()
                        Text(__designTimeString("#8839_13", fallback: "Loading…"))
                            .foregroundStyle(.secondary)
                    }
                } else if let averageHeartRate {
                    statRow(systemImage: __designTimeString("#8839_14", fallback: "heart.fill"), title: __designTimeString("#8839_15", fallback: "Average"), value: String(format: __designTimeString("#8839_16", fallback: "%.0f BPM"), averageHeartRate))
                } else {
                    Text(__designTimeString("#8839_17", fallback: "No heart rate data for this round."))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(__designTimeString("#8839_18", fallback: "Round Detail"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            averageHeartRate = await store.averageHeartRate(for: round)
            isLoadingHeartRate = __designTimeBoolean("#8839_19", fallback: false)
        }
    }

    private func statRow(systemImage: String, title: String, value: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func relativeOffset(for timestamp: Date) -> String {
        let seconds = Int(timestamp.timeIntervalSince(round.startDate))
        let minutes = seconds / __designTimeInteger("#8839_20", fallback: 60)
        let remainingSeconds = seconds % __designTimeInteger("#8839_21", fallback: 60)
        return String(format: __designTimeString("#8839_22", fallback: "%d:%02d into round"), minutes, remainingSeconds)
    }
}

#Preview {
    NavigationStack {
        GolfRoundDetailView(
            round: GolfRound(
                id: UUID(),
                startDate: .now,
                endDate: .now.addingTimeInterval(__designTimeInteger("#8839_23", fallback: 3600)),
                duration: __designTimeInteger("#8839_24", fallback: 3600),
                totalEnergyBurned: __designTimeInteger("#8839_25", fallback: 450),
                totalDistance: __designTimeInteger("#8839_26", fallback: 4800),
                swingCount: __designTimeInteger("#8839_27", fallback: 3),
                swingTimestamps: [
                    Date().addingTimeInterval(__designTimeInteger("#8839_28", fallback: 120)),
                    Date().addingTimeInterval(__designTimeInteger("#8839_29", fallback: 400)),
                    Date().addingTimeInterval(__designTimeInteger("#8839_30", fallback: 900))
                ]
            ),
            store: GolfRoundsStore()
        )
    }
}
