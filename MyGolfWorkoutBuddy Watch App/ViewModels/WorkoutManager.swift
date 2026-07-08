//
//  WorkoutManager.swift
//  MyGolfWorkoutBuddy Watch App
//
//  Created by Janene Pappas on 7/6/26.
//
//  Drives the golf HKWorkoutSession: publishes live stats, auto-pauses for cart
//  rides, logs swing events, and saves the workout when the round ends.
//

import Foundation
import HealthKit
import Combine

@MainActor
final class WorkoutManager: NSObject, ObservableObject {
    @Published var motionState: MotionState = .unknown
    @Published var isSessionActive = false
    @Published var isPaused = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var activeEnergy: Double = 0
    @Published var heartRate: Double = 0
    @Published var swingCount: Int = 0
    @Published var statusMessage: String?

    private let healthStore = HealthKitManager.shared.healthStore
    private let motionClassifier = MotionClassifier()

    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private var timer: Timer?
    private var startDate: Date?
    private var accumulatedPausedDuration: TimeInterval = 0
    private var pauseStartDate: Date?

    override init() {
        super.init()
        motionClassifier.delegate = self
    }

    // MARK: - Public controls

    func requestAuthorizationAndStart() async {
        do {
            try await HealthKitManager.shared.requestAuthorization()
            startWorkout()
        } catch {
            statusMessage = String(localized: "Couldn't get Health access: \(error.localizedDescription)")
        }
    }

    func endWorkout() {
        guard let session, session.state != .ended, session.state != .notStarted else { return }
        motionClassifier.stop()
        stopTimer()
        session.end()
    }

    // MARK: - Session setup

    private func startWorkout() {
        guard HealthKitManager.shared.isHealthDataAvailable else {
            statusMessage = String(localized: "Health data is not available on this device.")
            return
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .golf
        configuration.locationType = .outdoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

            session.delegate = self
            builder.delegate = self

            self.session = session
            self.builder = builder

            let now = Date()
            startDate = now
            accumulatedPausedDuration = 0
            elapsedTime = 0
            swingCount = 0
            motionState = .unknown
            statusMessage = nil

            session.startActivity(with: now)
            builder.beginCollection(withStart: now) { [weak self] success, error in
                guard let self else { return }
                Task { @MainActor in
                    if let error {
                        self.statusMessage = String(localized: "Couldn't start workout: \(error.localizedDescription)")
                    }
                }
            }

            isSessionActive = true
            isPaused = false
            motionClassifier.start()
            startTimer()
        } catch {
            statusMessage = String(localized: "Couldn't start workout session: \(error.localizedDescription)")
        }
    }

    // MARK: - Timer / elapsed time

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.refreshElapsedTime()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func refreshElapsedTime() {
        guard let startDate, !isPaused else { return }
        elapsedTime = Date().timeIntervalSince(startDate) - accumulatedPausedDuration
    }

    // MARK: - Cart pause / resume

    private func pauseForCart() {
        guard let session, session.state == .running else { return }
        pauseStartDate = Date()
        session.pause()
    }

    private func resumeFromCart() {
        guard let session, session.state == .paused else { return }
        session.resume()
    }

    // MARK: - Swing logging

    private func recordSwingEvent(at date: Date) {
        guard let builder else { return }
        swingCount += 1
        let event = HKWorkoutEvent(
            type: .marker,
            dateInterval: DateInterval(start: date, end: date),
            metadata: ["GolfSwingIndex": swingCount]
        )
        builder.addWorkoutEvents([event]) { _, error in
            if let error {
                print("Failed to record swing event: \(error)")
            }
        }
    }

    // MARK: - Finishing

    private func finishWorkout() {
        guard let builder else { return }
        builder.endCollection(withEnd: Date()) { [weak self] _, error in
            guard let self else { return }
            if let error {
                Task { @MainActor in
                    self.statusMessage = String(localized: "Couldn't finish collection: \(error.localizedDescription)")
                }
            }
            builder.finishWorkout { _, error in
                Task { @MainActor in
                    if let error {
                        self.statusMessage = String(localized: "Couldn't save workout: \(error.localizedDescription)")
                    }
                    self.session = nil
                    self.builder = nil
                }
            }
        }
    }
}

// MARK: - MotionClassifierDelegate

extension WorkoutManager: MotionClassifierDelegate {
    nonisolated func motionClassifier(_ classifier: MotionClassifier, didUpdateState state: MotionState) {
        Task { @MainActor in
            self.motionState = state
            switch state {
            case .inCart:
                self.pauseForCart()
            case .walking, .swinging, .stationary:
                if self.isPaused {
                    self.resumeFromCart()
                }
            case .unknown:
                break
            }
        }
    }

    nonisolated func motionClassifier(_ classifier: MotionClassifier, didDetectSwingAt date: Date) {
        Task { @MainActor in
            self.recordSwingEvent(at: date)
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            switch toState {
            case .paused:
                self.isPaused = true
            case .running:
                if self.isPaused, let pauseStart = self.pauseStartDate {
                    self.accumulatedPausedDuration += Date().timeIntervalSince(pauseStart)
                    self.pauseStartDate = nil
                }
                self.isPaused = false
            case .ended:
                self.isSessionActive = false
                self.isPaused = false
                self.finishWorkout()
            default:
                break
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.statusMessage = String(localized: "Workout session error: \(error.localizedDescription)")
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in
            for type in collectedTypes {
                guard let quantityType = type as? HKQuantityType else { continue }
                let statistics = workoutBuilder.statistics(for: quantityType)
                self.apply(statistics: statistics, for: quantityType)
            }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    private func apply(statistics: HKStatistics?, for type: HKQuantityType) {
        guard let statistics else { return }
        switch type.identifier {
        case HKQuantityTypeIdentifier.heartRate.rawValue:
            let unit = HKUnit.count().unitDivided(by: .minute())
            if let value = statistics.mostRecentQuantity()?.doubleValue(for: unit) {
                heartRate = value
            }
        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
            if let value = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                activeEnergy = value
            }
        default:
            break
        }
    }
}
