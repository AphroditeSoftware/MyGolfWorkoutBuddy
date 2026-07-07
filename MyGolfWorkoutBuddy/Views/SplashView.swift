//
//  SplashView.swift
//  MyGolfWorkoutBuddy
//
//  Created by Janene Pappas on 7/7/26.
//
//  Branded launch splash and the RootView that shows it briefly on startup
//  before fading into ContentView.
//

import SwiftUI

/// The app's root view: shows the splash over the content on launch, then
/// fades it away to reveal the rounds list.
struct RootView: View {
    @State private var isSplashDone = false

    var body: some View {
        ZStack {
            ContentView()

            if !isSplashDone {
                SplashView()
                    .transition(.opacity)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeInOut(duration: 0.4)) {
                isSplashDone = true
            }
        }
    }
}

/// A simple branded splash screen: the golf icon and app name, gently animated in.
struct SplashView: View {
    @State private var animateIn = false

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "figure.golf")
                    .font(.system(size: 88, weight: .semibold))
                    .foregroundStyle(.tint)
                    .scaleEffect(animateIn ? 1.0 : 0.7)

                Text("Golf Workout Buddy")
                    .font(.title2.bold())

                Text("Add your time playing to your workouts")
                    .font(.title3.bold())
                
                Text("Get credit for your walking and swings")
                    .font(.subheadline)
            }
            .multilineTextAlignment(.center)
            .opacity(animateIn ? 1 : 0)
        }
        .task {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animateIn = true
            }
        }
    }
}

#Preview("Splash") {
    SplashView()
}
