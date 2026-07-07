//
//  MyGolfWorkoutBuddyTests.swift
//  MyGolfWorkoutBuddyTests
//
//  Created by Janene Pappas on 7/6/26.
//
//  Unit tests for GolfRound's formatted-stat helpers (duration, distance,
//  calories) and its defaults.
//

import Testing
import Foundation
@testable import MyGolfWorkoutBuddy

struct GolfRoundFormattingTests {

    /// Builds a round with only the fields the formatting helpers read.
    private func makeRound(
        duration: TimeInterval = 0,
        energy: Double? = nil,
        distance: Double? = nil
    ) -> GolfRound {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        return GolfRound(
            id: UUID(),
            startDate: start,
            endDate: start.addingTimeInterval(duration),
            duration: duration,
            totalEnergyBurned: energy,
            totalDistance: distance,
            swingCount: 0,
            swingTimestamps: []
        )
    }

    // MARK: - Duration

    @Test(arguments: [
        (duration: 0.0, expected: "0m"),        // nothing yet
        (duration: 30.0, expected: "1m"),       // partial minute rounds up
        (duration: 60.0, expected: "1m"),       // exact minute
        (duration: 90.0, expected: "2m"),       // 1.5 min rounds up
        (duration: 3_600.0, expected: "1h 00m"), // exact hour, zero-padded minutes
        (duration: 6_300.0, expected: "1h 45m"), // exact
        (duration: 6_301.0, expected: "1h 46m"), // one second over rounds the minute up
        (duration: 14_400.0, expected: "4h 00m")
    ])
    func formattedDurationRoundsUpToTheMinute(testCase: (duration: TimeInterval, expected: String)) {
        #expect(makeRound(duration: testCase.duration).formattedDuration == testCase.expected)
    }

    // MARK: - Distance

    @Test func distanceConvertsMetersToMiles() {
        #expect(makeRound(distance: 1609.344).formattedDistance == "1.0 mi")
        #expect(makeRound(distance: 4_800).formattedDistance == "3.0 mi")
    }

    @Test func distanceIsNilWithoutData() {
        #expect(makeRound(distance: nil).formattedDistance == nil)
    }

    // MARK: - Calories

    @Test func caloriesRoundToAWholeNumber() {
        #expect(makeRound(energy: 612).formattedCalories == "612 Cal")
        #expect(makeRound(energy: 612.6).formattedCalories == "613 Cal")
    }

    @Test func caloriesIsNilWithoutData() {
        #expect(makeRound(energy: nil).formattedCalories == nil)
    }

    // MARK: - Defaults

    @Test func cartIntervalsDefaultToEmpty() {
        #expect(makeRound().cartIntervals.isEmpty)
    }
}
