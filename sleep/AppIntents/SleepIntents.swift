//
//  SleepIntents.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/17/26.
//

import AppIntents
import Foundation

// MARK: - Notification Names

extension Notification.Name {
    static let startTrackingIntent = Notification.Name("com.slumberscope.startTrackingIntent")
    static let stopTrackingIntent = Notification.Name("com.slumberscope.stopTrackingIntent")
    static let playRainSoundsIntent = Notification.Name("com.slumberscope.playRainSoundsIntent")
}

// MARK: - StartSleepTrackingIntent

struct StartSleepTrackingIntent: AppIntent {

    static var title: LocalizedStringResource = "Start Sleep Tracking"
    static var description: IntentDescription = "Starts a new sleep tracking session in Slumberscope."
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .startTrackingIntent, object: nil)
        }
        return .result()
    }
}

// MARK: - StopSleepTrackingIntent

struct StopSleepTrackingIntent: AppIntent {

    static var title: LocalizedStringResource = "Stop Sleep Tracking"
    static var description: IntentDescription = "Stops the current sleep tracking session."
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .stopTrackingIntent, object: nil)
        }
        return .result()
    }
}

// MARK: - GetLastSleepScoreIntent

struct GetLastSleepScoreIntent: AppIntent {

    static var title: LocalizedStringResource = "Get Last Sleep Score"
    static var description: IntentDescription = "Returns your most recent sleep score."

    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        // Access the last session score via UserDefaults cache or return 0
        let defaults = UserDefaults.standard
        let lastScore = defaults.integer(forKey: "lastSleepScore")
        return .result(value: lastScore)
    }
}

// MARK: - StartTrackingWithSoundsIntent

struct StartTrackingWithSoundsIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Tracking with Rain Sounds"
    static var description: IntentDescription = "Starts sleep tracking and plays rain sounds."
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .startTrackingIntent, object: nil)
            NotificationCenter.default.post(name: .playRainSoundsIntent, object: nil)
        }
        return .result()
    }
}

// MARK: - GetSleepSummaryIntent

struct GetSleepSummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Sleep Summary"
    static var description: IntentDescription = "Returns a summary of your recent sleep."

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let defaults = UserDefaults.standard
        let lastScore = defaults.integer(forKey: "lastSleepScore")
        let avgScore = defaults.integer(forKey: "weeklyAvgScore")
        return .result(value: "Your last sleep score was \(lastScore). Your weekly average is \(avgScore).")
    }
}

// MARK: - SleepShortcuts

struct SleepShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartSleepTrackingIntent(),
            phrases: [
                "Start sleep tracking with \(.applicationName)",
                "Track my sleep with \(.applicationName)",
                "Begin sleep tracking in \(.applicationName)",
                "Start tracking sleep with \(.applicationName)"
            ],
            shortTitle: "Start Sleep Tracking",
            systemImageName: "moon.zzz.fill"
        )

        AppShortcut(
            intent: StopSleepTrackingIntent(),
            phrases: [
                "Stop sleep tracking with \(.applicationName)",
                "Stop tracking my sleep with \(.applicationName)",
                "End sleep tracking in \(.applicationName)"
            ],
            shortTitle: "Stop Sleep Tracking",
            systemImageName: "stop.fill"
        )

        AppShortcut(
            intent: GetLastSleepScoreIntent(),
            phrases: [
                "Get my sleep score from \(.applicationName)",
                "What was my sleep score in \(.applicationName)",
                "How did I sleep last night in \(.applicationName)"
            ],
            shortTitle: "Last Sleep Score",
            systemImageName: "gauge.with.dots.needle.33percent"
        )

        AppShortcut(
            intent: StartTrackingWithSoundsIntent(),
            phrases: [
                "Start sleep tracking with rain sounds in \(.applicationName)",
                "Track my sleep with sounds in \(.applicationName)"
            ],
            shortTitle: "Track with Rain",
            systemImageName: "cloud.rain.fill"
        )

        AppShortcut(
            intent: GetSleepSummaryIntent(),
            phrases: [
                "Get my sleep summary from \(.applicationName)",
                "How have I been sleeping in \(.applicationName)"
            ],
            shortTitle: "Sleep Summary",
            systemImageName: "chart.line.uptrend.xyaxis"
        )
    }
}
