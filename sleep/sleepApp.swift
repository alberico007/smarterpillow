//
//  sleepApp.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/16/26.
//

import FirebaseCore
import SwiftData
import SwiftUI

// MARK: - Model Container with migration handling

private let sleepModelContainer: ModelContainer = {
    let schema = Schema([SleepSession.self, SleepFactor.self, SoundPreset.self])
    let config = ModelConfiguration(schema: schema)
    do {
        return try ModelContainer(for: schema, configurations: [config])
    } catch {
        AppLogger.error("SwiftData container failed — deleting store and retrying", error: error)
        let storeURL = config.url
        try? FileManager.default.removeItem(at: storeURL)
        let walURL = storeURL.appendingPathExtension("wal")
        let shmURL = storeURL.appendingPathExtension("shm")
        try? FileManager.default.removeItem(at: walURL)
        try? FileManager.default.removeItem(at: shmURL)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer even after reset: \(error)")
        }
    }
}()

@main
struct sleepApp: App {

    @State private var settings = SleepSettings()
    @State private var trackingService = SleepTrackingService()
    @State private var weatherService = WeatherService()
    @State private var watchService = WatchConnectivityService()
    @State private var storeKitService = StoreKitService()
    @State private var authService = AuthenticationService()
    @State private var cloudService = CloudSyncService()
    @State private var soundService = SoundService()

    init() {
        FirebaseApp.configure()
        if let app = FirebaseApp.app() {
            AppLogger.appEvent("Firebase configured — project: \(app.options.projectID ?? "unknown")")
        } else {
            AppLogger.error("Firebase failed to configure", error: nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(trackingService)
                .environment(weatherService)
                .environment(watchService)
                .environment(storeKitService)
                .environment(authService)
                .environment(cloudService)
                .environment(soundService)
                .onAppear {
                    AppLogger.appEvent("App launched — configuring services")
                    trackingService.configure(settings: settings)
                    Task {
                        await cloudService.checkCloudStatus()
                    }
                }
        }
        .modelContainer(sleepModelContainer)
    }
}
