//
//  MyGolfWorkoutBuddy_Watch_AppTests.swift
//  MyGolfWorkoutBuddy Watch AppTests
//
//  Created by Janene Pappas on 7/6/26.
//
//  Swift Testing unit tests for MotionClassifier swing detection, driven by
//  synthetic motion samples and a recording delegate.
//

import Testing
import Foundation
@testable import MyGolfWorkoutBuddy_Watch_App

/// Captures the callbacks a `MotionClassifier` makes so tests can assert on them.
private final class RecordingDelegate: MotionClassifierDelegate {
    var swingDates: [Date] = []
    var states: [MotionState] = []

    func motionClassifier(_ classifier: MotionClassifier, didUpdateState state: MotionState) {
        states.append(state)
    }

    func motionClassifier(_ classifier: MotionClassifier, didDetectSwingAt date: Date) {
        swingDates.append(date)
    }
}

struct MotionClassifierSwingDetectionTests {

    /// A fixed reference time so every test is deterministic.
    private let t0 = Date(timeIntervalSinceReferenceDate: 0)

    private func makeClassifier() -> (MotionClassifier, RecordingDelegate) {
        let classifier = MotionClassifier()
        let delegate = RecordingDelegate()
        classifier.delegate = delegate
        return (classifier, delegate)
    }

    /// Feeds a swing-shaped burst: one high-energy spike sample followed by a
    /// "settled" sample below the exit threshold that closes the burst.
    private func feedBurst(
        _ classifier: MotionClassifier,
        peakRotation: Double,
        peakAcceleration: Double,
        start: Date,
        duration: TimeInterval = 0.1
    ) {
        classifier.processSwingSample(rotationMagnitude: peakRotation, accelerationMagnitude: peakAcceleration, at: start)
        classifier.processSwingSample(rotationMagnitude: 1.0, accelerationMagnitude: 0.1, at: start.addingTimeInterval(duration))
    }

    @Test func realSwingIsCounted() {
        let (classifier, delegate) = makeClassifier()

        // Brief burst that pairs high rotation with high acceleration.
        feedBurst(classifier, peakRotation: 12.0, peakAcceleration: 3.0, start: t0)

        #expect(delegate.swingDates.count == 1)
        #expect(delegate.states.contains(.swinging))
    }

    @Test func liftingWithLowAccelerationIsNotCounted() {
        let (classifier, delegate) = makeClassifier()

        // Reaching for a water bottle can spin the wrist past the rotation gate,
        // but generates very little linear acceleration.
        feedBurst(classifier, peakRotation: 9.0, peakAcceleration: 0.8, start: t0)

        #expect(delegate.swingDates.isEmpty)
    }

    @Test func gentleMotionNeverOpensABurst() {
        let (classifier, delegate) = makeClassifier()

        // Rotation stays under the enter threshold the whole time.
        classifier.processSwingSample(rotationMagnitude: 5.0, accelerationMagnitude: 3.0, at: t0)
        classifier.processSwingSample(rotationMagnitude: 4.0, accelerationMagnitude: 3.0, at: t0.addingTimeInterval(0.1))

        #expect(delegate.swingDates.isEmpty)
    }

    @Test func sustainedRotationIsNotCounted() {
        let (classifier, delegate) = makeClassifier()

        // Rotation opens a burst but stays elevated well past the max duration,
        // so it's treated as a sustained movement rather than a strike.
        classifier.processSwingSample(rotationMagnitude: 12.0, accelerationMagnitude: 3.0, at: t0)
        classifier.processSwingSample(rotationMagnitude: 12.0, accelerationMagnitude: 3.0, at: t0.addingTimeInterval(0.7))
        classifier.processSwingSample(rotationMagnitude: 1.0, accelerationMagnitude: 0.1, at: t0.addingTimeInterval(0.8))

        #expect(delegate.swingDates.isEmpty)
    }

    @Test func swingsWithinRefractoryWindowAreCountedOnce() {
        let (classifier, delegate) = makeClassifier()

        feedBurst(classifier, peakRotation: 12.0, peakAcceleration: 3.0, start: t0)
        // Second qualifying burst closes ~0.5s after the first — inside the 1.5s window.
        feedBurst(classifier, peakRotation: 12.0, peakAcceleration: 3.0, start: t0.addingTimeInterval(0.5))

        #expect(delegate.swingDates.count == 1)
    }

    @Test func swingsBeyondRefractoryWindowAreBothCounted() {
        let (classifier, delegate) = makeClassifier()

        feedBurst(classifier, peakRotation: 12.0, peakAcceleration: 3.0, start: t0)
        // Second qualifying burst well after the 1.5s refractory window.
        feedBurst(classifier, peakRotation: 12.0, peakAcceleration: 3.0, start: t0.addingTimeInterval(2.0))

        #expect(delegate.swingDates.count == 2)
    }

    @Test func swingsAreIgnoredWhileInCart() {
        let (classifier, delegate) = makeClassifier()
        classifier.setStateForTesting(.inCart)

        // A textbook swing should still be suppressed during a cart ride.
        feedBurst(classifier, peakRotation: 12.0, peakAcceleration: 3.0, start: t0)

        #expect(delegate.swingDates.isEmpty)
    }
}
