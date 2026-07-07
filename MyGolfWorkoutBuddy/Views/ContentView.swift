//
//  ContentView.swift
//  MyGolfWorkoutBuddy
//
//  Created by Janene Pappas on 7/6/26.
//
//  Root list of recorded golf rounds, with loading, empty, error, and
//  authorization states, navigating to a detail view per round.
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
                .navigationTitle("My Golf Rounds")
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
            ProgressView("Loading rounds…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .authorizationDenied:
            ContentUnavailableView(
                "Health Access Needed",
                systemImage: "heart.text.square",
                description: Text("Allow MyGolfWorkoutBuddy to read your workouts in the Health app to see your rounds here.")
            )

        case .error(let message):
            ContentUnavailableView(
                "Couldn't Load Rounds",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )

        case .loaded where store.rounds.isEmpty:
            ContentUnavailableView(
                "No Rounds Yet",
                systemImage: "figure.golf",
                description: Text("Rounds you record on your Apple Watch will show up here.")
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
