//
//  MotionClassifier.swift
//  MyGolfWorkoutBuddy Watch App
//
//  Created by Janene Pappas on 7/6/26.
//
//  CoreMotion classifier: detects cart rides and counts golf swings, reporting
//  state changes and swings to a delegate.
//

import Foundation
import CoreMotion

/// The activity the golfer currently appears to be doing.
enum MotionState: String {
    case unknown = "Unknown"
    case walking = "Walking"
    case swinging = "Swinging"
    case stationary = "Stationary"
    case inCart = "In Cart"
}

protocol MotionClassifierDelegate: AnyObject {
    /// Called whenever the classifier's best guess of the current activity changes.
    func motionClassifier(_ classifier: MotionClassifier, didUpdateState state: MotionState)
    /// Called once per detected golf swing.
    func motionClassifier(_ classifier: MotionClassifier, didDetectSwingAt date: Date)
}

/// Combines two CoreMotion signals:
///  1. `CMMotionActivityManager` — Apple's own walking/automotive/stationary classifier,
///     used to detect "riding in a golf cart" (automotive) vs. on foot.
///  2. `CMMotionManager` device motion — raw rotation rate, used to detect the sharp,
///     brief rotational spike of an actual golf swing.
final class MotionClassifier {
    weak var delegate: MotionClassifierDelegate?

    private let activityManager = CMMotionActivityManager()
    private let motionManager = CMMotionManager()
    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        q.name = "com.aphroditesoftwareinc.MyGolfWorkoutBuddy.motion"
        return q
    }()

    private(set) var currentState: MotionState = .unknown

    // MARK: - Swing detection tuning
    /// A golf swing shows up as a brief, violent burst that pairs high rotation
    /// with high linear acceleration. Everyday gestures (reaching for a water
    /// bottle, waggling the club, adjusting a glove) trip one of these signals
    /// but rarely all of them at once, so we require them together before
    /// counting a swing. All thresholds are conservative starting points and are
    /// expected to be tuned against real on-course data.
    ///
    /// Rotation rate (rad/s) that opens a candidate swing "burst".
    private let swingRotationEnterThreshold = 8.0
    /// Rotation rate (rad/s) the burst must fall back below to close it. The gap
    /// between enter/exit is hysteresis so a single swing isn't split in two.
    private let swingRotationExitThreshold = 3.0
    /// Peak linear acceleration (g) the burst must also reach. Lifting a light
    /// object rotates the wrist but generates little acceleration, so this gate
    /// rejects it.
    private let swingAccelerationThreshold = 2.2
    /// A real swing's high-energy phase is brief; a burst that stays elevated
    /// longer than this is some other motion (carrying the bag, scrubbing a
    /// club) and is discarded.
    private let maxSwingBurstDuration: TimeInterval = 0.6
    /// Minimum time between two counted swings, so one swing isn't double-counted.
    private let swingRefractoryInterval: TimeInterval = 1.5
    private var lastSwingDate: Date?
    /// How long the UI shows "Swinging" before falling back to "Walking".
    private let swingDisplayDuration: TimeInterval = 1.2

    // Tracks an in-progress candidate swing burst.
    private var swingBurstStart: Date?
    private var peakBurstRotation = 0.0
    private var peakBurstAcceleration = 0.0

    // MARK: - Cart detection tuning
    /// Consecutive automotive samples required before we trust it's a cart, not a bump.
    private let automotiveConfirmationCount = 3
    private var consecutiveAutomotiveSamples = 0
    /// Consecutive non-automotive samples required before resuming out of a cart pause.
    private let nonAutomotiveConfirmationCount = 2
    private var consecutiveNonAutomotiveSamples = 0

    func start() {
        currentState = .unknown
        consecutiveAutomotiveSamples = 0
        consecutiveNonAutomotiveSamples = 0
        lastSwingDate = nil
        resetSwingBurst()
        startActivityUpdatesIfAvailable()
        startDeviceMotionUpdatesIfAvailable()
    }

    func stop() {
        activityManager.stopActivityUpdates()
        motionManager.stopDeviceMotionUpdates()
    }

    // MARK: - Activity updates (walking vs. automotive/cart)

    private func startActivityUpdatesIfAvailable() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        activityManager.startActivityUpdates(to: queue) { [weak self] activity in
            guard let self, let activity else { return }
            self.handle(activity: activity)
        }
    }

    private func handle(activity: CMMotionActivity) {
        guard activity.confidence != .low else { return }

        if activity.automotive {
            consecutiveAutomotiveSamples += 1
            consecutiveNonAutomotiveSamples = 0
            if consecutiveAutomotiveSamples >= automotiveConfirmationCount {
                updateState(.inCart)
            }
        } else {
            consecutiveNonAutomotiveSamples += 1
            consecutiveAutomotiveSamples = 0
            if consecutiveNonAutomotiveSamples >= nonAutomotiveConfirmationCount {
                if activity.stationary && !activity.walking {
                    updateState(.stationary)
                } else {
                    updateState(.walking)
                }
            }
        }
    }

    // MARK: - Device motion (swing spike detection)

    private func startDeviceMotionUpdatesIfAvailable() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 50.0
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.evaluateSwing(using: motion)
        }
    }

    private func evaluateSwing(using motion: CMDeviceMotion) {
        let rotation = motion.rotationRate
        let rotationMagnitude = (rotation.x * rotation.x + rotation.y * rotation.y + rotation.z * rotation.z).squareRoot()
        let accel = motion.userAcceleration
        let accelerationMagnitude = (accel.x * accel.x + accel.y * accel.y + accel.z * accel.z).squareRoot()

        processSwingSample(rotationMagnitude: rotationMagnitude, accelerationMagnitude: accelerationMagnitude, at: Date())
    }

    /// Core swing-burst logic, kept free of CoreMotion so it can be unit tested
    /// by feeding raw magnitudes and timestamps directly.
    func processSwingSample(rotationMagnitude: Double, accelerationMagnitude: Double, at now: Date) {
        // Never mistake cart vibration/road bumps for a swing.
        guard currentState != .inCart else { return }

        guard let burstStart = swingBurstStart else {
            // Not tracking a burst yet: a sharp rotational spike opens one.
            if rotationMagnitude >= swingRotationEnterThreshold {
                swingBurstStart = now
                peakBurstRotation = rotationMagnitude
                peakBurstAcceleration = accelerationMagnitude
            }
            return
        }

        // A burst is underway: keep the running peaks of both signals.
        peakBurstRotation = max(peakBurstRotation, rotationMagnitude)
        peakBurstAcceleration = max(peakBurstAcceleration, accelerationMagnitude)

        let burstDuration = now.timeIntervalSince(burstStart)

        if rotationMagnitude < swingRotationExitThreshold {
            // Burst finished — count it only if it was a brief spike that paired
            // high rotation with high linear acceleration. A water-bottle lift
            // reaches neither the acceleration threshold nor stays this brief.
            let wasBrief = burstDuration <= maxSwingBurstDuration
            let hadEnoughAcceleration = peakBurstAcceleration >= swingAccelerationThreshold
            if wasBrief && hadEnoughAcceleration {
                registerSwing(at: now)
            }
            resetSwingBurst()
        } else if burstDuration > maxSwingBurstDuration {
            // Rotation stayed elevated too long to be a swing (a sustained arm
            // movement rather than a sharp strike); abandon this burst.
            resetSwingBurst()
        }
    }

    private func registerSwing(at date: Date) {
        // Enforce the refractory window so one swing isn't double-counted.
        if let last = lastSwingDate, date.timeIntervalSince(last) < swingRefractoryInterval {
            return
        }
        lastSwingDate = date

        delegate?.motionClassifier(self, didDetectSwingAt: date)
        updateState(.swinging)

        // Revert the displayed state after a beat, without blocking the motion
        // delivery queue (which stays busy receiving ~50 samples/sec).
        DispatchQueue.main.asyncAfter(deadline: .now() + swingDisplayDuration) { [weak self] in
            guard let self else { return }
            self.queue.addOperation {
                if self.currentState == .swinging {
                    self.updateState(.walking)
                }
            }
        }
    }

    private func resetSwingBurst() {
        swingBurstStart = nil
        peakBurstRotation = 0
        peakBurstAcceleration = 0
    }

    // MARK: - State updates

    private func updateState(_ newState: MotionState) {
        guard newState != currentState else { return }
        currentState = newState
        delegate?.motionClassifier(self, didUpdateState: newState)
    }
}

#if DEBUG
extension MotionClassifier {
    /// Testing seam: force the current activity state (e.g. `.inCart`) so swing
    /// suppression can be exercised without a live `CMMotionActivity`.
    func setStateForTesting(_ state: MotionState) {
        currentState = state
    }
}
#endif
