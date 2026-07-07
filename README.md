# MyGolfWorkoutBuddy

Golf as a workout — an Apple Watch app that logs a round of golf to HealthKit as a single continuous workout, automatically distinguishing walking and swinging (which count) from riding in a golf cart (which doesn't). A companion iPhone app lists your saved rounds and shows the detail behind each one.

## How it works

The Watch app starts one `HKWorkoutSession` (activity type `.golf`, location `.outdoor`) for the whole round and leans on CoreMotion to decide what to do with it, with no manual input from the golfer beyond starting and ending the round:

- **`CMMotionActivityManager`** classifies the wearer's current activity. When it confidently detects `.automotive` motion (riding in the cart) for a few consecutive samples, the workout session is auto-**paused** — so that time and any energy burned during it are excluded from the saved workout. When automotive motion stops, the session auto-**resumes**.
- **`CMMotionManager`** device motion (50 Hz) watches for the signature of a golf swing: a **brief burst that pairs high rotation rate with high linear acceleration**. Rather than firing on a single sample crossing one threshold, it opens a candidate "burst" on a rotation spike, tracks the peak rotation and peak acceleration until the rotation settles, and counts a swing only if that burst was short-lived *and* cleared the acceleration gate. This rejects everyday gestures (reaching for a water bottle, waggling the club) that spin the wrist but generate little acceleration. Each detected swing is logged as an `HKWorkoutEvent` marker (with a refractory period so one swing isn't double-counted) and bumped into a live swing counter.

Both walking and swinging happen while the session is running, so both count toward the saved workout's duration and active energy; only cart time is paused out.

The iPhone app doesn't talk to the Watch app directly — it reads whatever golf workouts have landed in HealthKit and presents them as a list, with a detail screen per round (summary stats plus Swift Charts heart-rate and walking-speed graphs). It opens on a brief branded splash screen that fades into the list while HealthKit loads. Because cart time is paused out of the workout, the speed chart breaks the line across those gaps and shades them, using the workout's pause/resume events. Tapping either chart opens it full screen in landscape (forced, so it works even with the device's Rotation Lock on), where it can be pinch-zoomed and panned; the back chevron rotates back to portrait and returns. The rest of the app stays portrait.

## Project structure

```
MyGolfWorkoutBuddy/                       # iPhone companion app
├── Models/
│   └── GolfRound.swift                   # UI-friendly wrapper around an HKWorkout (date, duration,
│                                          # calories, distance, swing count/timestamps, cart intervals);
│                                          # has #if DEBUG sample data for previews
├── Services/
│   └── HealthKitManager.swift            # Read-only HealthKit access: authorization, fetch golf
│                                          # workouts, per-round average heart rate, heart rate samples,
│                                          # and derived walking-speed samples
├── ViewModels/
│   └── GolfRoundsStore.swift             # @Observable store: loads rounds, exposes load state,
│                                          # caches HKWorkout objects for detail lookups; HeartRateSample/SpeedSample models
├── Views/
│   ├── ContentView.swift                 # NavigationStack + list of rounds (loading/empty/denied/error states)
│   ├── GolfRoundRow.swift                # Row: date, duration, swing count, distance, calories
│   ├── GolfRoundDetailView.swift         # Full stats + per-swing timestamps + average heart rate +
│   │                                      # Swift Charts heart rate and walking-speed graphs (the speed
│   │                                      # chart breaks the line and shades cart-paused stretches); tap a
│   │                                      # graph for a full-screen landscape ChartZoomView (pinch-zoom and pan)
│   └── SplashView.swift                  # Launch splash + RootView that shows it briefly, then fades to ContentView
├── MyGolfWorkoutBuddyApp.swift           # @main App; hosts RootView; AppDelegate governs orientation
│                                          # (portrait app, forced landscape for the full-screen chart)
└── MyGolfWorkoutBuddy.entitlements       # HealthKit (read)

Colors.swift                              # Shared color constants (e.g. Color.calorieFlame) common to both apps

MyGolfWorkoutBuddy Watch App/             # watchOS app that records rounds
├── Services/
│   ├── HealthKitManager.swift            # Authorization for saving workouts + reading live stats
│   └── MotionClassifier.swift            # CoreMotion: cart vs. walking detection, swing burst detection
│                                          # (rotation + acceleration + duration gated)
├── ViewModels/
│   └── WorkoutManager.swift              # Owns the HKWorkoutSession/HKLiveWorkoutBuilder; pause/resume
│                                          # for cart, swing event logging, published live stats
├── Views/
│   └── ContentView.swift                 # Start/End Round button, live state label, swing/cal/BPM tiles
├── MyGolfWorkoutBuddyApp.swift
└── MyGolfWorkoutBuddy Watch App.entitlements  # HealthKit (read/write) + background delivery

MyGolfWorkoutBuddyTests/                  # Swift Testing unit tests for GolfRound stat formatting
MyGolfWorkoutBuddy Watch AppTests/        # Swift Testing unit tests for MotionClassifier swing detection
MyGolfWorkoutBuddyUITests/,
MyGolfWorkoutBuddy Watch AppUITests/      # remaining stock Xcode UI test targets (unwritten)
```

## Requirements

- Xcode with iOS/watchOS SDKs supporting deployment target 26.5 (as currently set in project build settings)
- A physical Apple Watch paired to a physical iPhone — HealthKit workout sessions, CoreMotion activity classification, and motion sensors are not meaningfully testable in the Simulator
- An Apple Developer team set for code signing (currently `DEVELOPMENT_TEAM = JPVB928KRJ`, `CODE_SIGN_STYLE = Automatic`)

## Permissions

Both targets carry the HealthKit entitlement and request authorization at runtime:

| | Watch App | iPhone App |
|---|---|---|
| HealthKit | read + write (`com.apple.developer.healthkit`, plus `.background-delivery`) | read only |
| Data shared | Workouts | — |
| Data read | Heart rate, active energy, distance walking/running | Workouts, heart rate, active energy, distance walking/running |
| Motion & Fitness | Required (`NSMotionUsageDescription`) — powers cart/swing detection | Not needed |

The first "Start Round" tap on the Watch and first launch of the iPhone app will prompt for these permissions.

## Running it

1. Open `MyGolfWorkoutBuddy.xcodeproj` in Xcode.
2. Select your team under each target's Signing & Capabilities tab if Automatic signing doesn't already resolve one.
3. Build and run the Watch App scheme on a paired Watch+iPhone.
4. Tap **Start Round**, walk around/swing to see swing count and live state update, and confirm the state switches to "In Cart — Paused" when riding a cart. Tap **End Round** to save.
5. Build and run the iPhone app scheme; the round should appear in the list once HealthKit finishes syncing it, with a detail view for full stats.

## Running the tests

The unit tests are pure logic and *do* run in the Simulator (unlike the live HealthKit/CoreMotion features, which need a device). They must run on an **iOS 26.5 simulator — e.g. iPhone 17** — because that matches the deployment target; older simulators and the paired physical devices are ineligible and the run will report "no result".

- iPhone: `MyGolfWorkoutBuddy` scheme → `MyGolfWorkoutBuddyTests` — `GolfRound` stat formatting.
- Watch: `MyGolfWorkoutBuddy Watch App` scheme → `MyGolfWorkoutBuddy Watch AppTests` — `MotionClassifier` swing detection.

From the command line, for example:

```
xcodebuild test -project MyGolfWorkoutBuddy.xcodeproj -scheme MyGolfWorkoutBuddy \
  -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MyGolfWorkoutBuddyTests
```

## Tuning notes

`MotionClassifier` uses a few hand-picked constants that will likely need adjusting against real swing/cart data:

- `swingRotationEnterThreshold` (8 rad/s) — rotation rate that opens a candidate swing burst.
- `swingRotationExitThreshold` (3 rad/s) — rotation rate the burst must fall back below to close (hysteresis).
- `swingAccelerationThreshold` (2.2 g) — peak linear acceleration the burst must also reach; the main gate that rejects low-force gestures.
- `maxSwingBurstDuration` (0.6s) — a burst that stays elevated longer than this is treated as sustained motion, not a strike.
- `swingRefractoryInterval` (1.5s) — minimum gap between two counted swings.
- `automotiveConfirmationCount` / `nonAutomotiveConfirmationCount` — consecutive activity samples required before trusting a cart-ride transition in either direction, to avoid flapping on noisy single samples.

The burst logic is factored into a CoreMotion-free `processSwingSample(rotationMagnitude:accelerationMagnitude:at:)` method so it can be exercised deterministically by the unit tests in `MyGolfWorkoutBuddy Watch AppTests` — feed synthetic magnitudes/timestamps, assert on the swings a recording delegate receives.

## Known gaps

- Unit tests cover `MotionClassifier` swing detection (`MyGolfWorkoutBuddy Watch AppTests`) and `GolfRound` stat formatting (`MyGolfWorkoutBuddyTests`); the two UI test targets are still unmodified Xcode template stubs.
- Swing detection is a hand-tuned heuristic (gated on rotation, acceleration, and burst duration), not a trained classifier; the thresholds are conservative starting points, so mis-fires and missed swings are possible and worth field-testing against real rounds.
- The iPhone app has no way to trigger a HealthKit sync manually beyond pull-to-refresh; if a round doesn't appear, refresh or check Health app permissions first.
