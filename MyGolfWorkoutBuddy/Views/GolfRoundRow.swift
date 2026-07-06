//
//  GolfRoundRow.swift
//  MyGolfWorkoutBuddy
//
//  Created by Janene Pappas on 7/6/26.
//


import SwiftUI

struct GolfRoundRow: View {
    let round: GolfRound

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(round.formattedDate)
                .font(.headline)

            HStack(spacing: 12) {
                Label(round.formattedDuration, systemImage: "clock")
                Label("\(round.swingCount)", systemImage: "figure.golf")
                if let calories = round.formattedCalories {
                    Label(calories, systemImage: "flame")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
