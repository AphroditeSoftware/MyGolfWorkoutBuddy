//
//  MotionClassifier.swift
//  MyGolfWorkoutBuddy Watch App
//
//  Classifies what the wearer is doing right now using CoreMotion so the
//  workout can auto pause during a cart ride and count golf swings, without
//  any manual input from the golfer.
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
    /// Peak rotation rate (rad/s) a real golf swing reliably clears; a slow practice
    /// waggle or normal arm movement stays well under this.
    private let swingRotationThreshold = 6.0
    /// Minimum time between two counted swings, so one swing isn't double-counted.
    private let swingRefractoryInterval: TimeInterval = 1.5
    private var lastSwingDate: Date?
    /// How long the UI shows "Swinging" before falling back to "Walking".
    private let swingDisplayDuration: TimeInterval = 1.2

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
        // Never mistake cart vibration/road bumps for a swing.
        guard currentState != .inCart else { return }

        let rotation = motion.rotationRate
        let magnitude = (rotation.x * rotation.x + rotation.y * rotation.y + rotation.z * rotation.z).squareRoot()
        guard magnitude > swingRotationThreshold else { return }

        let now = Date()
        if let last = lastSwingDate, now.timeIntervalSince(last) < swingRefractoryInterval {
            return
        }
        lastSwingDate = now

        delegate?.motionClassifier(self, didDetectSwingAt: now)
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

    // MARK: - State updates

    private func updateState(_ newState: MotionState) {
        guard newState != currentState else { return }
        currentState = newState
        delegate?.motionClassifier(self, didUpdateState: newState)
    }
}
