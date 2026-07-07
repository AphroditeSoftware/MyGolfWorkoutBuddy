//
//  MyGolfWorkoutBuddyApp.swift
//  MyGolfWorkoutBuddy
//
//  Created by Janene Pappas on 7/6/26.
//
//  iPhone app entry point; shows RootView (splash then ContentView) in the
//  main window group.
//

import SwiftUI
import UIKit

@main
struct MyGolfWorkoutBuddyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Drives the app's allowed interface orientations. The app is portrait
/// everywhere except the full-screen chart, which is forced to landscape while
/// on screen (overriding the device's Rotation Lock).
final class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        AppDelegate.orientationLock
    }
}
