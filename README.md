# MyGolfWorkoutBuddy

Golf as a workout — an Apple Watch app that logs a round of golf to HealthKit as a single continuous workout, automatically distinguishing walking and swinging (which count) from riding in a golf cart (which doesn't). A companion iPhone app lists your saved rounds and shows the detail behind each one.

## How it works

The Watch app starts one `HKWorkoutSession` (activity type `.golf`, location `.outdoor`) for the whole round and leans on CoreMotion to decide what to do with it, with no manual input from the golfer beyond starting and ending the round:

- **`CMMotionActivityManager`** classifies the wearer's current activity. When it confidently detects `.automotive` motion (riding in the cart) for a few consecutive samples, the workout session is auto-**paused** — so that time and any energy burned during it are excluded from the saved workout. When automotive motion stops, the session auto-**resumes**.
- **`CMMotionManager`** device motion (50 Hz) watches for a sharp rotation-rate spike characteristic of a golf swing. Each detected swing is logged as an `HKWorkoutEvent` marker (with a refractory period so one swing isn't double-counted) and bumped into a live swing counter.

Both walking and swinging happen while the session is running, so both count toward the saved workout's duration and active energy; only cart time is paused out.

The iPhone app doesn't talk to the Watch app directly — it reads whatever golf workouts have landed in HealthKit and presents them as a list, with a detail screen per round.

## Project structure

```
MyGolfWorkoutBuddy/                       # iPhone companion app
├── Models/
│   └── GolfRound.swift                   # UI-friendly wrapper around an HKWorkout (date, duration,
│                                          # calories, distance, swing count/timestamps); has #if DEBUG
│                                          # sample data for previews
├── Services/
│   └── HealthKitManager.swift            # Read-only HealthKit access: authorization, fetch golf
│                                          # workouts, per-round average heart rate
├── ViewModels/
│   └── GolfRoundsStore.swift             # @Observable store: loads rounds, exposes load state,
│                                          # caches HKWorkout objects for detail lookups
├── Views/
│   ├── ContentView.swift                 # NavigationStack + list of rounds (loading/empty/denied/error states)
│   ├── GolfRoundRow.swift                # Row: date, duration, swing count, calories
│   └── GolfRoundDetailView.swift         # Full stats + per-swing timestamps + average heart rate
├── MyGolfWorkoutBuddyApp.swift
└── MyGolfWorkoutBuddy.entitlements       # HealthKit (read)

MyGolfWorkoutBuddy Watch App/             # watchOS app that records rounds
├── Services/
│   ├── HealthKitManager.swift            # Authorization for saving workouts + reading live stats
│   └── MotionClassifier.swift            # CoreMotion: cart vs. walking detection, swing spike detection
├── ViewModels/
│   └── WorkoutManager.swift              # Owns the HKWorkoutSession/HKLiveWorkoutBuilder; pause/resume
│                                          # for cart, swing event logging, published live stats
├── Views/
│   └── ContentView.swift                 # Start/End Round button, live state label, swing/cal/BPM tiles
├── MyGolfWorkoutBuddyApp.swift
└── MyGolfWorkoutBuddy Watch App.entitlements  # HealthKit (read/write) + background delivery

MyGolfWorkoutBuddyTests/, MyGolfWorkoutBuddyUITests/,
MyGolfWorkoutBuddy Watch AppTests/, MyGolfWorkoutBuddy Watch AppUITests/  # stock Xcode test targets (unwritten)
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

## Tuning notes

`MotionClassifier` uses a few hand-picked constants that will likely need adjusting against real swing/cart data:

- `swingRotationThreshold` (6 rad/s) — peak rotation rate that counts as a swing.
- `swingRefractoryInterval` (1.5s) — minimum gap between two counted swings.
- `automotiveConfirmationCount` / `nonAutomotiveConfirmationCount` — consecutive activity samples required before trusting a cart-ride transition in either direction, to avoid flapping on noisy single samples.

## Known gaps

- No unit/UI tests have been written yet — the four test targets are still the unmodified Xcode template stubs.
- Swing detection is a single-threshold heuristic (rotation-rate magnitude), not a trained classifier; mis-fires (e.g., an aggressive practice swing or a bumpy cart ride) are possible and worth field-testing.
- The iPhone app has no way to trigger a HealthKit sync manually beyond pull-to-refresh; if a round doesn't appear, refresh or check Health app permissions first.
