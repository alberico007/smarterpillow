//
//  sleepWatchApp.swift
//  sleepWatch

import SwiftUI

@main
struct sleepWatchApp: App {

    @StateObject private var sessionManager = WatchSessionManager()
    @StateObject private var heartRateService = HeartRateService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionManager)
                .environmentObject(heartRateService)
                .onAppear { sessionManager.activate() }
        }
    }
}
