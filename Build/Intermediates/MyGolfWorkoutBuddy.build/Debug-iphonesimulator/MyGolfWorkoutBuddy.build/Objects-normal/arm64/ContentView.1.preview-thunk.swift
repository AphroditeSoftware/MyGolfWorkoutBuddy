import func SwiftUI.__designTimeFloat
import func SwiftUI.__designTimeString
import func SwiftUI.__designTimeInteger
import func SwiftUI.__designTimeBoolean

#sourceLocation(file: "/Users/janenepappas/iOS/MyGolfWorkoutBuddy/MyGolfWorkoutBuddy/Views/ContentView.swift", line: 1)
//
//  ContentView.swift
//  MyGolfWorkoutBuddy
//

import SwiftUI

struct ContentView: View {
    @State private var store: GolfRoundsStore

    init() {
        _store = State(initialValue: GolfRoundsStore())
    }

    init(store: GolfRoundsStore) {
        _store = State(initialValue: store)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(__designTimeString("#8389_0", fallback: "My Golf Rounds"))
                .task {
                    if store.rounds.isEmpty {
                        await store.loadRounds()
                    }
                }
                .refreshable {
                    await store.loadRounds()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.loadState {
        case .idle, .loading:
            ProgressView(__designTimeString("#8389_1", fallback: "Loading rounds…"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .authorizationDenied:
            ContentUnavailableView(
                __designTimeString("#8389_2", fallback: "Health Access Needed"),
                systemImage: __designTimeString("#8389_3", fallback: "heart.text.square"),
                description: Text(__designTimeString("#8389_4", fallback: "Allow MyGolfWorkoutBuddy to read your workouts in the Health app to see your rounds here."))
            )

        case .error(let message):
            ContentUnavailableView(
                __designTimeString("#8389_5", fallback: "Couldn't Load Rounds"),
                systemImage: __designTimeString("#8389_6", fallback: "exclamationmark.triangle"),
                description: Text(message)
            )

        case .loaded where store.rounds.isEmpty:
            ContentUnavailableView(
                __designTimeString("#8389_7", fallback: "No Rounds Yet"),
                systemImage: __designTimeString("#8389_8", fallback: "figure.golf"),
                description: Text(__designTimeString("#8389_9", fallback: "Rounds you record on your Apple Watch will show up here."))
            )

        case .loaded:
            List(store.rounds) { round in
                NavigationLink(value: round) {
                    GolfRoundRow(round: round)
                }
            }
            .listStyle(.plain)
            .navigationDestination(for: GolfRound.self) { round in
                GolfRoundDetailView(round: round, store: store)
            }
        }
    }
}



#Preview {
    ContentView(store: .preview())
}
