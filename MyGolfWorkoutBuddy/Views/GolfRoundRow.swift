//
//  GolfRoundRow.swift
//  MyGolfWorkoutBuddy
//
//  Created by Janene Pappas on 7/6/26.
//


import SwiftUI

struct GolfRoundRow: View {
    let round: GolfRound

    /// Fixed width for each stat so columns line up between rows.
    private let statWidth: CGFloat = 72

    /// The duration stat needs more room (e.g. "4h 00m") to avoid wrapping.
    private let timeStatWidth: CGFloat = 96

    /// The swing count is just a short number, so it needs less room.
    private let swingStatWidth: CGFloat = 52

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(round.formattedDate)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Label(round.formattedDuration, systemImage: "clock")
                    .frame(width: timeStatWidth, alignment: .leading)
                Label("\(round.swingCount)", systemImage: "figure.golf")
                    .frame(width: swingStatWidth, alignment: .leading)
                if let distance = round.formattedDistance {
                    Label(distance, systemImage: "figure.walk")
                        .frame(width: statWidth, alignment: .leading)
                }
                if let calories = round.formattedCalories {
                    Label {
                        Text(calories)
                    } icon: {
                        Image(systemName: "flame")
                            .foregroundStyle(Color.calorieFlame)
                    }
                    .frame(width: statWidth, alignment: .leading)
                }
            }
            .labelStyle(CompactLabelStyle())
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

/// A label style that tightens the spacing between the icon and its title,
/// tinting the icon with the accent color while leaving the title secondary.
/// Icons with their own explicit color (like the flame) keep that color.
private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 2) {
            configuration.icon
                .foregroundStyle(Color.accentColor)
            configuration.title
                .foregroundStyle(.secondary)
        }
    }
}
