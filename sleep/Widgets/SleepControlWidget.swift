//
//  SleepControlWidget.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/17/26.
//

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Control Widget Intent

struct ControlToggleSleepIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Sleep Tracking"
    static var description: IntentDescription = "Start or stop sleep tracking from Control Center."
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        let isTracking = UserDefaults.standard.bool(forKey: "isCurrentlyTracking")
        await MainActor.run {
            if isTracking {
                NotificationCenter.default.post(name: Notification.Name("com.slumberscope.stopTrackingIntent"), object: nil)
                UserDefaults.standard.set(false, forKey: "isCurrentlyTracking")
            } else {
                NotificationCenter.default.post(name: Notification.Name("com.slumberscope.startTrackingIntent"), object: nil)
                UserDefaults.standard.set(true, forKey: "isCurrentlyTracking")
            }
        }
        return .result()
    }
}

// MARK: - Sleep Control Widget

struct SleepControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.smarterpillow.sleep.control"
        ) {
            ControlWidgetButton(action: ControlToggleSleepIntent()) {
                Label("Sleep", systemImage: "moon.zzz.fill")
            }
        }
        .displayName("Sleep Tracking")
        .description("Start or stop sleep tracking.")
    }
}

// MARK: - Quick Start Widget

struct QuickStartSleepIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Start Sleep"
    static var description: IntentDescription = "Quickly start a sleep tracking session."
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: Notification.Name("com.slumberscope.startTrackingIntent"), object: nil)
            UserDefaults.standard.set(true, forKey: "isCurrentlyTracking")
        }
        return .result()
    }
}

struct SleepQuickStartWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.smarterpillow.sleep.quickstart"
        ) {
            ControlWidgetButton(action: QuickStartSleepIntent()) {
                Label("Sleep", systemImage: "moon.zzz.fill")
            }
        }
        .displayName("Quick Start Sleep")
        .description("One-tap start sleep tracking.")
    }
}
