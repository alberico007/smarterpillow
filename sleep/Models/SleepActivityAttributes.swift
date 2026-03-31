//
//  SleepActivityAttributes.swift
//  sleep
//
//

import ActivityKit
import Foundation

// MARK: - SleepTrackingAttributes

struct SleepTrackingAttributes: ActivityAttributes {
    let sessionStartTime: Date

    struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var snoringCount: Int
        var currentPhase: String // "tracking", "calibrating"
    }
}
