//
//  sleepApp.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/16/26.
//

import FirebaseCore
import os
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
    @State private var mediaService = MediaPlaybackService()
    @State private var podcastService = PodcastService()
    @State private var soundClassifier = SoundClassificationService()
    @State private var intelligenceService = IntelligenceService()

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
                .environment(mediaService)
                .environment(podcastService)
                .environment(soundClassifier)
                .environment(intelligenceService)
                .onAppear {
                    AppLogger.appEvent("App launched — configuring services")
                    trackingService.configure(settings: settings, watchService: watchService)
                    trackingService.intelligenceService = intelligenceService
                    // Give AuthenticationService a handle to settings so that
                    // Firebase sign-in can restore the user's name/age/gender
                    // from Firestore when Apple doesn't hand back fullName.
                    authService.settings = settings
                    // Wire the environmental classifier into AudioService so
                    // fan/AC/dog/speech don't get counted as snores.
                    trackingService.audioService.attachClassifier(soundClassifier)
                    trackingService.audioService.environmentalFilteringEnabled = settings.environmentalNoiseFilteringEnabled
                    // Tell AudioService who's playing so it can suppress
                    // snoring while the user's own audio is coming out of
                    // the speaker.
                    trackingService.audioService.attachMediaPlayback(mediaService)
                    // Give MediaPlaybackService a handle to SoundService for
                    // the sleep-sound / meditation / story routing.
                    mediaService.soundService = soundService
                    Task {
                        await cloudService.checkCloudStatus()
                    }
                }
                .onChange(of: settings.environmentalNoiseFilteringEnabled) { _, newValue in
                    trackingService.audioService.environmentalFilteringEnabled = newValue
                }
                .onChange(of: trackingService.phase) { _, newPhase in
                    AppLogger.tracking.info("Phase changed → \(String(describing: newPhase))")
                    switch newPhase {
                    case .tracking, .calibrating:
                        watchService.sendTrackingState(isTracking: true, startTime: trackingService.startTime)
                    case .idle, .done:
                        watchService.sendTrackingState(isTracking: false, startTime: nil)
                    case .completing:
                        break
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .watchMorningSummary)) { notification in
                    guard let info = notification.userInfo,
                          let score = info["score"] as? Int,
                          let duration = info["duration"] as? Double,
                          let quality = info["quality"] as? String else { return }

                    // Decode stages and movement if available
                    var stages: [SleepStageEntry] = []
                    var movement: [MovementDataPoint] = []
                    if let stagesJSON = info["stagesJSON"] as? String,
                       let data = stagesJSON.data(using: .utf8) {
                        stages = (try? JSONDecoder().decode([SleepStageEntry].self, from: data)) ?? []
                    }
                    if let movJSON = info["movementJSON"] as? String,
                       let data = movJSON.data(using: .utf8) {
                        movement = (try? JSONDecoder().decode([MovementDataPoint].self, from: data)) ?? []
                    }

                    watchService.sendMorningSummary(
                        score: score, duration: duration, quality: quality,
                        stages: stages, movementPoints: movement,
                        hrMin: info["hrMin"] as? Double ?? 0,
                        hrMax: info["hrMax"] as? Double ?? 0,
                        hrAvg: info["hrAvg"] as? Double ?? 0,
                        snoringCount: info["snoringCount"] as? Int ?? 0
                    )
                }
                .onReceive(NotificationCenter.default.publisher(for: .watchSnoringCountUpdate)) { notification in
                    if let count = notification.userInfo?["count"] as? Int {
                        watchService.sendSnoringCount(count)
                    }
                }
                .onChange(of: watchService.liveHeartRate) { _, newHR in
                    if let hr = newHR {
                        trackingService.updateWatchHR(hr)
                    }
                }
        }
        .modelContainer(sleepModelContainer)
    }
}
