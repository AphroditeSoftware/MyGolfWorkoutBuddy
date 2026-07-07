//
//  MyGolfWorkoutBuddyUITestsLaunchTests.swift
//  MyGolfWorkoutBuddyUITests
//
//  Created by Janene Pappas on 7/6/26.
//
//  Launch UI test for the iPhone app that captures a launch-screen screenshot.
//

import XCTest

final class MyGolfWorkoutBuddyUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
