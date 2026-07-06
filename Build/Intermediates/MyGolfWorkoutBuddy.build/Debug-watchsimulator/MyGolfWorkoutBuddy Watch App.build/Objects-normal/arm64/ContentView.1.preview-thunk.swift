import func SwiftUI.__designTimeFloat
import func SwiftUI.__designTimeString
import func SwiftUI.__designTimeInteger
import func SwiftUI.__designTimeBoolean

#sourceLocation(file: "/Users/janenepappas/iOS/MyGolfWorkoutBuddy/MyGolfWorkoutBuddy Watch App/Views/ContentView.swift", line: 1)
//
//  ContentView.swift
//  MyGolfWorkoutBuddy Watch App
//

import SwiftUI

struct ContentView: View {
    @StateObject private var workoutManager = WorkoutManager()

    var body: some View {
        VStack(spacing: __designTimeInteger("#9349_0", fallback: 8)) {
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
        VStack(spacing: __designTimeInteger("#9349_1", fallback: 12)) {
            Image(systemName: __designTimeString("#9349_2", fallback: "figure.golf"))
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text(__designTimeString("#9349_3", fallback: "My Golf Workout Buddy"))
                .font(.headline)
                .multilineTextAlignment(.center)
            Button(__designTimeString("#9349_4", fallback: "Start Round")) {
                Task {
                    await workoutManager.requestAuthorizationAndStart()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var activeRoundView: some View {
        VStack(spacing: __designTimeInteger("#9349_5", fallback: 6)) {
            Text(formattedElapsedTime)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .monospacedDigit()

            stateLabel

            HStack {
                statTile(systemImage: __designTimeString("#9349_6", fallback: "figure.golf"), value: "\(workoutManager.swingCount)", label: __designTimeString("#9349_7", fallback: "Swings"))
                statTile(systemImage: __designTimeString("#9349_8", fallback: "flame.fill"), value: activeEnergyText, label: __designTimeString("#9349_9", fallback: "Cal"))
                statTile(systemImage: __designTimeString("#9349_10", fallback: "heart.fill"), value: heartRateText, label: __designTimeString("#9349_11", fallback: "BPM"))
            }
            .padding(.top, __designTimeInteger("#9349_12", fallback: 2))

            Button(__designTimeString("#9349_13", fallback: "End Round")) {
                workoutManager.endWorkout()
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .padding(.top, __designTimeInteger("#9349_14", fallback: 4))
        }
    }

    private var stateLabel: some View {
        let (text, color): (String, Color) = {
            switch workoutManager.motionState {
            case .walking:
                return (__designTimeString("#9349_15", fallback: "Walking"), .green)
            case .swinging:
                return (__designTimeString("#9349_16", fallback: "Swinging"), .yellow)
            case .stationary:
                return (__designTimeString("#9349_17", fallback: "Stationary"), .gray)
            case .inCart:
                return (__designTimeString("#9349_18", fallback: "In Cart \u{2014} Paused"), .orange)
            case .unknown:
                return (__designTimeString("#9349_19", fallback: "Getting Ready…"), .gray)
            }
        }()

        return Text(text)
            .font(.caption)
            .foregroundStyle(color)
    }

    private func statTile(systemImage: String, value: String, label: String) -> some View {
        VStack(spacing: __designTimeInteger("#9349_20", fallback: 2)) {
            Image(systemName: systemImage)
                .font(.caption2)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
            Text(label)
                .font(.system(size: __designTimeInteger("#9349_21", fallback: 9)))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var formattedElapsedTime: String {
        let total = Int(workoutManager.elapsedTime)
        let hours = total / __designTimeInteger("#9349_22", fallback: 3600)
        let minutes = (total % __designTimeInteger("#9349_23", fallback: 3600)) / __designTimeInteger("#9349_24", fallback: 60)
        let seconds = total % __designTimeInteger("#9349_25", fallback: 60)
        if hours > __designTimeInteger("#9349_26", fallback: 0) {
            return String(format: __designTimeString("#9349_27", fallback: "%d:%02d:%02d"), hours, minutes, seconds)
        }
        return String(format: __designTimeString("#9349_28", fallback: "%02d:%02d"), minutes, seconds)
    }

    private var activeEnergyText: String {
        String(format: __designTimeString("#9349_29", fallback: "%.0f"), workoutManager.activeEnergy)
    }

    private var heartRateText: String {
        workoutManager.heartRate > __designTimeInteger("#9349_30", fallback: 0) ? String(format: __designTimeString("#9349_31", fallback: "%.0f"), workoutManager.heartRate) : __designTimeString("#9349_32", fallback: "--")
    }
}

#Preview {
    ContentView()
}
