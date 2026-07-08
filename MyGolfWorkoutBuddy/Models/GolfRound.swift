//
//  GolfRound.swift
//  MyGolfWorkoutBuddy
//
//  Created by Janene Pappas on 7/6/26.
//
//  UI-friendly model wrapping an HKWorkout: derives swings and cart intervals
//  from workout events and formats its stats for display.
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
    /// Stretches the round was paused for a cart ride, derived from the
    /// workout's pause/resume events. Used to shade cart time in charts.
    let cartIntervals: [DateInterval]

    init(
        id: UUID,
        startDate: Date,
        endDate: Date,
        duration: TimeInterval,
        totalEnergyBurned: Double?,
        totalDistance: Double?,
        swingCount: Int,
        swingTimestamps: [Date],
        cartIntervals: [DateInterval] = []
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.totalEnergyBurned = totalEnergyBurned
        self.totalDistance = totalDistance
        self.swingCount = swingCount
        self.swingTimestamps = swingTimestamps
        self.cartIntervals = cartIntervals
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

        let events = (workout.workoutEvents ?? []).sorted { $0.dateInterval.start < $1.dateInterval.start }

        let swingEvents = events.filter { $0.type == .marker }
        swingTimestamps = swingEvents.map(\.dateInterval.start).sorted()
        swingCount = swingTimestamps.count

        // Pair each pause with the following resume to recover cart intervals;
        // if the round ended while paused, close the last one at the end date.
        var intervals: [DateInterval] = []
        var pauseStart: Date?
        for event in events {
            switch event.type {
            case .pause:
                pauseStart = event.dateInterval.start
            case .resume:
                if let start = pauseStart {
                    intervals.append(DateInterval(start: start, end: event.dateInterval.start))
                    pauseStart = nil
                }
            default:
                break
            }
        }
        if let start = pauseStart {
            intervals.append(DateInterval(start: start, end: workout.endDate))
        }
        cartIntervals = intervals
    }
}

extension GolfRound {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }()

    var formattedDate: String {
        Self.dateFormatter.string(from: startDate)
    }

    var formattedDuration: String {
        // Round up to the next whole minute so partial minutes aren't dropped.
        let totalMinutes = Int((duration / 60).rounded(.up))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }
        return String(format: "%dm", minutes)
    }

    var formattedCalories: String? {
        guard let totalEnergyBurned else { return nil }
        return String(format: NSLocalizedString("%.0f Cal", comment: "Calories burned during a round"), totalEnergyBurned)
    }

    var formattedDistance: String? {
        guard let totalDistance else { return nil }
        let miles = totalDistance / 1609.344
        return String(format: NSLocalizedString("%.1f mi", comment: "Distance walked in miles"), miles)
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
            startDate: Date(timeIntervalSinceNow: -5 * 86_400),
            endDate: Date(timeIntervalSinceNow: -5 * 86_400 + 6_300),
            duration: 6_300,
            totalEnergyBurned: 275,
            totalDistance: 3_400,
            swingCount: 41,
            swingTimestamps: [
                Date(timeIntervalSinceNow: -5 * 86_400 + 200),
                Date(timeIntervalSinceNow: -5 * 86_400 + 2_100)
            ]
        ),
        GolfRound(
            id: UUID(),
            startDate: Date(timeIntervalSinceNow: -12 * 86_400),
            endDate: Date(timeIntervalSinceNow: -12 * 86_400 + 16_200),
            duration: 16_200,
            totalEnergyBurned: 703,
            totalDistance: 10_150,
            swingCount: 92,
            swingTimestamps: []
        )
    ]
}
#endif
