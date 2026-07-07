//
//  GolfRoundsStore.swift
//  MyGolfWorkoutBuddy
//
//  Created by Janene Pappas on 7/6/26.
//
//  Observable store that loads golf rounds and vends each round's heart-rate
//  and walking-speed samples; defines the chart sample models.
//

import Foundation
import HealthKit

/// A single heart rate reading within a round, used to plot the detail chart.
struct HeartRateSample: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let bpm: Double
}

/// A single walking-speed reading within a round, used to plot the speed chart.
struct SpeedSample: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let milesPerHour: Double
}

@MainActor
@Observable
final class GolfRoundsStore {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case authorizationDenied
        case error(String)
    }

    private(set) var rounds: [GolfRound] = []
    private(set) var loadState: LoadState = .idle

    private let healthKitManager = HealthKitManager.shared
    /// Kept in the same order as `rounds` so the detail view can ask for
    /// per-round stats (like average heart rate) without re-querying HealthKit
    /// for the whole list.
    private var workoutsByID: [UUID: HKWorkout] = [:]

    func loadRounds() async {
        loadState = .loading
        do {
            try await healthKitManager.requestAuthorization()
            let workouts = try await healthKitManager.fetchGolfWorkouts()
            workoutsByID = Dictionary(uniqueKeysWithValues: workouts.map { ($0.uuid, $0) })
            rounds = workouts.map(GolfRound.init(workout:))
            loadState = .loaded
        } catch is HealthKitAuthorizationError {
            loadState = .authorizationDenied
        } catch {
            loadState = .error(error.localizedDescription)
        }
    }

    /// Fetched lazily per-round since it needs its own HealthKit statistics query.
    func averageHeartRate(for round: GolfRound) async -> Double? {
        guard let workout = workoutsByID[round.id] else { return nil }
        return try? await healthKitManager.averageHeartRate(for: workout)
    }

    /// Time-ordered heart rate samples for a round, used to draw the detail chart.
    func heartRateSamples(for round: GolfRound) async -> [HeartRateSample] {
        if let workout = workoutsByID[round.id] {
            return (try? await healthKitManager.heartRateSamples(for: workout)) ?? []
        }
        #if DEBUG
        return seededHeartRateSamples[round.id] ?? []
        #else
        return []
        #endif
    }

    /// Time-ordered walking-speed samples for a round, used to draw the speed chart.
    func speedSamples(for round: GolfRound) async -> [SpeedSample] {
        if let workout = workoutsByID[round.id] {
            return (try? await healthKitManager.walkingSpeedSamples(for: workout)) ?? []
        }
        #if DEBUG
        return seededSpeedSamples[round.id] ?? []
        #else
        return []
        #endif
    }

    #if DEBUG
    /// Heart rate samples injected for SwiftUI previews, keyed by round id.
    private var seededHeartRateSamples: [UUID: [HeartRateSample]] = [:]
    /// Walking-speed samples injected for SwiftUI previews, keyed by round id.
    private var seededSpeedSamples: [UUID: [SpeedSample]] = [:]

    /// A store pre-populated with dummy rounds in the `.loaded` state, for SwiftUI previews.
    static func preview(
        rounds: [GolfRound] = GolfRound.sampleRounds,
        heartRateSamples: [UUID: [HeartRateSample]] = [:],
        speedSamples: [UUID: [SpeedSample]] = [:]
    ) -> GolfRoundsStore {
        let store = GolfRoundsStore()
        store.rounds = rounds
        store.seededHeartRateSamples = heartRateSamples
        store.seededSpeedSamples = speedSamples
        store.loadState = .loaded
        return store
    }
    #endif
}
