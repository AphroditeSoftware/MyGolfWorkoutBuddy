//
//  ContentView.swift
//  MyGolfWorkoutBuddy Watch App
//
//  Created by Janene Pappas on 7/6/26.
//
//  Root watch UI: start a round, then show live time and swing/calorie/heart-rate
//  tiles with an End Round button.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var workoutManager = WorkoutManager()

    var body: some View {
        VStack(spacing: 8) {
            if workoutManager.isSessionActive {
                activeRoundView
            } else {
                startView
            }

            if let message = workoutManager.statusMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    private var startView: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.golf")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Golf Workout Buddy")
                .font(.headline)
                .multilineTextAlignment(.center)
            Button("Start Round") {
                Task {
                    await workoutManager.requestAuthorizationAndStart()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var activeRoundView: some View {
        VStack(spacing: 6) {
            Text(formattedElapsedTime)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .monospacedDigit()

            HStack {
                statTile(systemImage: "figure.golf", value: "\(workoutManager.swingCount)", label: "Swings")
                statTile(systemImage: "flame.fill", value: activeEnergyText, label: "Cal", imageColor: .calorieFlame)
                statTile(systemImage: "heart.fill", value: heartRateText, label: "BPM", imageColor: .red)
            }
            .padding(.top, 2)

            Button("End Round") {
                workoutManager.endWorkout()
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .padding(.top, 4)
        }
    }

    private func statTile(systemImage: String, value: String, label: LocalizedStringKey, imageColor: Color? = nil) -> some View {
        VStack(spacing: 2) {
            Image(systemName: systemImage)
                .font(.caption2)
                .foregroundStyle(imageColor ?? .primary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var formattedElapsedTime: String {
        let total = Int(workoutManager.elapsedTime)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var activeEnergyText: String {
        String(format: "%.0f", workoutManager.activeEnergy)
    }

    private var heartRateText: String {
        workoutManager.heartRate > 0 ? String(format: "%.0f", workoutManager.heartRate) : "--"
    }
}

#Preview {
    ContentView()
}
