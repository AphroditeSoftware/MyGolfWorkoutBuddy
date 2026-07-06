//
//  ContentView.swift
//  MyGolfWorkoutBuddy Watch App
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
            Text("My Golf Workout Buddy")
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

            stateLabel

            HStack {
                statTile(systemImage: "figure.golf", value: "\(workoutManager.swingCount)", label: "Swings")
                statTile(systemImage: "flame.fill", value: activeEnergyText, label: "Cal")
                statTile(systemImage: "heart.fill", value: heartRateText, label: "BPM")
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

    private var stateLabel: some View {
        let (text, color): (String, Color) = {
            switch workoutManager.motionState {
            case .walking:
                return ("Walking", .green)
            case .swinging:
                return ("Swinging", .yellow)
            case .stationary:
                return ("Stationary", .gray)
            case .inCart:
                return ("In Cart \u{2014} Paused", .orange)
            case .unknown:
                return ("Getting Ready…", .gray)
            }
        }()

        return Text(text)
            .font(.caption)
            .foregroundStyle(color)
    }

    private func statTile(systemImage: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: systemImage)
                .font(.caption2)
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
