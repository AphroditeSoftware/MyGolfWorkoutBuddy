//
//  HealthKitManager.swift
//  MyGolfWorkoutBuddy Watch App
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

/// Thin wrapper around the one HKHealthStore the app needs, handling the
/// authorization request for saving golf workouts and reading the live stats
/// (heart rate, active energy, distance) shown while a round is in progress.
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

        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType()
        ]

        let typesToRead: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]

        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }
}
