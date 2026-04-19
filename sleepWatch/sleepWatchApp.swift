//
//  sleepWatchApp.swift
//  sleepWatch

import os
import SwiftUI

@main
struct sleepWatchApp: App {

    @StateObject private var sessionManager = WatchSessionManager()
    @StateObject private var heartRateService = HeartRateService()
    @StateObject private var watchMotionService = WatchMotionService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionManager)
                .environmentObject(heartRateService)
                .environmentObject(watchMotionService)
                .onAppear {
                    WatchLogger.general.info("Watch app launched")
                    sessionManager.activate()
                }
        }
    }
}
