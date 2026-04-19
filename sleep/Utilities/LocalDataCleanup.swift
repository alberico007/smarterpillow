//
//  LocalDataCleanup.swift
//  sleep
//

import Foundation
import os
import SwiftData

enum LocalDataCleanup {

    /// Wipe every SwiftData record belonging to the current user and reset
    /// personal settings. Call before switching accounts so the next signed-in
    /// user can't see the previous user's local-only data.
    static func wipeUserData(modelContext: ModelContext, settings: SleepSettings) {
        do {
            try modelContext.delete(model: SleepSession.self)
            try modelContext.delete(model: SleepFactor.self)
            try modelContext.delete(model: SoundPreset.self)
            try modelContext.save()
        } catch {
            AppLogger.auth.error("LocalDataCleanup — SwiftData wipe failed: \(error.localizedDescription)")
        }

        settings.userName = ""
        settings.userLastName = ""
        settings.userAge = 30
        settings.userGender = "Not specified"
        settings.sleepGoalHours = 8.0
        settings.hasCompletedOnboarding = false

        UserDefaults.standard.removeObject(forKey: "isCurrentlyTracking")

        AppLogger.auth.info("🧹 Local user data wiped")
    }
}
