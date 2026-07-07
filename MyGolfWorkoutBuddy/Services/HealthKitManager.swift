//
//  HealthKitManager.swift
//  MyGolfWorkoutBuddy
//
//  Created by Janene Pappas on 7/6/26.
//
//  Read-only HealthKit access for the iPhone app: fetches golf workouts and
//  each round's heart-rate and walking-speed samples.
//

import Foundation
import HealthKit

enum HealthKitAuthorizationError: LocalizedError {
    case notAvailable

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Health data is not available on this device."
        }
    }
}

final class HealthKitManager {
    static let shared = HealthKitManager()

    let healthStore = HKHealthStore()

    private init() {}

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        guard isHealthDataAvailable else {
            throw HealthKitAuthorizationError.notAvailable
        }

        var typesToRead: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            typesToRead.insert(heartRateType)
        }
        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            typesToRead.insert(energyType)
        }
        if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            typesToRead.insert(distanceType)
        }

        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
    }

    /// All golf workouts, most recent first.
    func fetchGolfWorkouts() async throws -> [HKWorkout] {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForWorkouts(with: .golf)
            let sortByStartDate = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortByStartDate]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }

            healthStore.execute(query)
        }
    }

    /// Average heart rate across a specific round, for the detail screen.
    func averageHeartRate(for workout: HKWorkout) async throws -> Double? {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForObjects(from: workout)
            let query = HKStatisticsQuery(
                quantityType: heartRateType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let unit = HKUnit.count().unitDivided(by: .minute())
                continuation.resume(returning: statistics?.averageQuantity()?.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }

    /// Time-ordered heart rate samples across a specific round, for charting.
    func heartRateSamples(for workout: HKWorkout) async throws -> [HeartRateSample] {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return []
        }

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForObjects(from: workout)
            let sortByStartDate = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortByStartDate]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let unit = HKUnit.count().unitDivided(by: .minute())
                let results = (samples as? [HKQuantitySample])?.map {
                    HeartRateSample(date: $0.startDate, bpm: $0.quantity.doubleValue(for: unit))
                } ?? []
                continuation.resume(returning: results)
            }
            healthStore.execute(query)
        }
    }

    /// Walking speed over a round (mph), derived from the workout's distance
    /// samples. Each distance sample is a cumulative value over its own time
    /// span, so speed is distance divided by that span.
    func walkingSpeedSamples(for workout: HKWorkout) async throws -> [SpeedSample] {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            return []
        }

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForObjects(from: workout)
            let sortByStartDate = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: distanceType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortByStartDate]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let mphPerMetersPerSecond = 2.2369362920544
                let results: [SpeedSample] = (samples as? [HKQuantitySample])?.compactMap { sample in
                    let seconds = sample.endDate.timeIntervalSince(sample.startDate)
                    guard seconds > 0 else { return nil }
                    let meters = sample.quantity.doubleValue(for: .meter())
                    let mph = (meters / seconds) * mphPerMetersPerSecond
                    // Plot at the middle of the sample's span.
                    let midpoint = sample.startDate.addingTimeInterval(seconds / 2)
                    return SpeedSample(date: midpoint, milesPerHour: mph)
                } ?? []
                continuation.resume(returning: results)
            }
            healthStore.execute(query)
        }
    }
}
