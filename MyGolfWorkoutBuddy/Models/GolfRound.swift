//
//  GolfRound.swift
//  MyGolfWorkoutBuddy
//
//  A lightweight, UI-friendly view of an HKWorkout saved by the Watch app.
//  Swing count/timestamps come from the HKWorkoutEvent markers the Watch app
//  records each time it detects a golf swing.
//

import Foundation
import HealthKit

struct GolfRound: Identifiable, Hashable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let totalEnergyBurned: Double? // kilocalories
    let totalDistance: Double? // meters
    let swingCount: Int
    let swingTimestamps: [Date]

    init(
        id: UUID,
        startDate: Date,
        endDate: Date,
        duration: TimeInterval,
        totalEnergyBurned: Double?,
        totalDistance: Double?,
        swingCount: Int,
        swingTimestamps: [Date]
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.totalEnergyBurned = totalEnergyBurned
        self.totalDistance = totalDistance
        self.swingCount = swingCount
        self.swingTimestamps = swingTimestamps
    }

    init(workout: HKWorkout) {
        id = workout.uuid
        startDate = workout.startDate
        endDate = workout.endDate
        duration = workout.duration

        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            totalEnergyBurned = workout.statistics(for: energyType)?.sumQuantity()?.doubleValue(for: .kilocalorie())
        } else {
            totalEnergyBurned = nil
        }

        if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            totalDistance = workout.statistics(for: distanceType)?.sumQuantity()?.doubleValue(for: .meter())
        } else {
            totalDistance = nil
        }

        let swingEvents = (workout.workoutEvents ?? []).filter { $0.type == .marker }
        swingTimestamps = swingEvents.map(\.dateInterval.start).sorted()
        swingCount = swingTimestamps.count
    }
}

extension GolfRound {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var formattedDate: String {
        Self.dateFormatter.string(from: startDate)
    }

    var formattedDuration: String {
        let total = Int(duration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }
        return String(format: "%dm", minutes)
    }

    var formattedCalories: String? {
        guard let totalEnergyBurned else { return nil }
        return String(format: "%.0f Cal", totalEnergyBurned)
    }

    var formattedDistance: String? {
        guard let totalDistance else { return nil }
        let miles = totalDistance / 1609.344
        return String(format: "%.1f mi", miles)
    }
}

#if DEBUG
extension GolfRound {
    /// Dummy rounds used to populate SwiftUI previews without hitting HealthKit.
    nonisolated static let sampleRounds: [GolfRound] = [
        GolfRound(
            id: UUID(),
            startDate: Date(timeIntervalSinceNow: -86_400),
            endDate: Date(timeIntervalSinceNow: -86_400 + 14_400),
            duration: 14_400,
            totalEnergyBurned: 612,
            totalDistance: 9_012,
            swingCount: 78,
            swingTimestamps: [
                Date(timeIntervalSinceNow: -86_400 + 300),
                Date(timeIntervalSinceNow: -86_400 + 1_450),
                Date(timeIntervalSinceNow: -86_400 + 3_600)
            ]
        ),
        GolfRound(
            id: UUID(),
            startDate: Date(timeIntervalSinceNow: -5 * 86_000),
            endDate: Date(timeIntervalSinceNow: -5 * 86_000 + 6_300),
            duration: 6_300,
            totalEnergyBurned: 275,
            totalDistance: 3_400,
            swingCount: 41,
            swingTimestamps: [
                Date(timeIntervalSinceNow: -5 * 86_000 + 200),
                Date(timeIntervalSinceNow: -5 * 86_000 + 2_100)
            ]
        ),
        GolfRound(
            id: UUID(),
            startDate: Date(timeIntervalSinceNow: -12 * 86_200),
            endDate: Date(timeIntervalSinceNow: -12 * 86_200 + 16_200),
            duration: 16_200,
            totalEnergyBurned: 703,
            totalDistance: 10_150,
            swingCount: 92,
            swingTimestamps: []
        )
    ]
}
#endif
