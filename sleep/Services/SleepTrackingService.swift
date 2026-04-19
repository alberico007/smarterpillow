//
//  SleepTrackingService.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/17/26.
//

import Foundation
import os
import SwiftData
import WidgetKit

// MARK: - Tracking Phase

nonisolated enum TrackingPhase: Equatable, Sendable {
    case idle
    case calibrating
    case tracking
    case completing
    case done
}

@Observable
final class SleepTrackingService {

    // MARK: - Observable State

    var phase: TrackingPhase = .idle
    var elapsedTime: TimeInterval = 0.0
    var startTime: Date?

    // MARK: - Child Services

    let motionService = MotionService()
    let audioService = AudioService()
    let healthKitService = HealthKitService()
    let crashRecoveryService = CrashRecoveryService()
    let batteryService = BatteryService()
    let calibrationService = CalibrationService()
    let smartAlarmService = SmartAlarmService()
    let notificationService = NotificationService()
    let liveActivityService = LiveActivityService()
    let sleepFocusService = SleepFocusService()

    // MARK: - Watch HR Stats

    var watchHRMin: Double = 0
    var watchHRMax: Double = 0
    private var watchHRSum: Double = 0
    private var watchHRCount: Int = 0

    // MARK: - Watch Connectivity

    /// Reference to watch connectivity service — set via configure()
    weak var watchService: WatchConnectivityService?

    /// Optional Apple Intelligence handle — used by the smart alarm to write
    /// a human-readable rationale on-device. Set by sleepApp on startup.
    weak var intelligenceService: IntelligenceService?

    /// Whether the watch is the primary motion data source for this session
    private(set) var isUsingWatchMotion = false

    // MARK: - Private

    private var elapsedTimer: Timer?
    private var batteryCheckTimer: Timer?
    private var calibrationCheckTimer: Timer?
    private var snoringPushTimer: Timer?
    private var watchMovementObserver: Any?
    private var watchDisconnectObserver: Any?
    private var settings: SleepSettings?

    // MARK: - Configure

    func configure(settings: SleepSettings, watchService: WatchConnectivityService? = nil) {
        self.settings = settings
        self.watchService = watchService
        AppLogger.tracking.info("Configured tracking service — watch available: \(watchService != nil)")

        calibrationService.loadSavedBaseline()

        notificationService.scheduleBedtimeReminder(
            at: settings.bedtimeReminderTime,
            enabled: settings.bedtimeReminderEnabled
        )
        notificationService.scheduleWeeklyDigest(enabled: settings.weeklyDigestEnabled)

        smartAlarmService.configure(
            time: settings.smartAlarmTime,
            windowMinutes: settings.smartAlarmWindowMinutes,
            enabled: settings.smartAlarmEnabled
        )

        notificationService.scheduleWindDownReminder(
            bedtime: settings.scheduledBedtime,
            minutesBefore: settings.windDownReminderMinutes,
            enabled: settings.windDownReminderMinutes > 0
        )
    }

    // MARK: - Start Tracking

    func startTracking() {
        guard phase == .idle else { return }
        AppLogger.tracking.info("🟢 Starting sleep tracking session")

        let now = Date()
        startTime = now
        elapsedTime = 0

        guard let settings = settings else {
            AppLogger.tracking.error("Cannot start tracking — settings not configured")
            return
        }

        // Determine motion data source: watch (preferred) or iPhone (fallback)
        let watchReachable = watchService?.isWatchReachable ?? false
        isUsingWatchMotion = watchReachable && settings.trackMotion

        if settings.trackMotion {
            if isUsingWatchMotion {
                AppLogger.tracking.info("⌚ Watch connected — using watch for motion tracking (iPhone accelerometer off)")
            } else {
                AppLogger.tracking.info("📱 No watch — using iPhone accelerometer for motion tracking")
                motionService.startTracking(sensitivity: settings.sensitivityLevel)
            }
        }

        // Audio/snoring detection always runs on iPhone (watch has no mic for this)
        if settings.trackAudio {
            audioService.configure(sensitivity: settings.snoringSensitivity, minDuration: settings.minimumSnoreDuration)
            audioService.startTracking()
            AppLogger.tracking.info("🎙️ Audio/snoring detection started on iPhone")
        }

        liveActivityService.startLiveActivity(startTime: now)

        if settings.enableSleepFocus {
            sleepFocusService.enableSleepFocus()
        }

        batteryService.startMonitoring()
        batteryCheckTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkBatteryWarnings()
            }
        }

        // Skip recalibration if the GetReadyForBed baseline already
        // completed (phase == .completed) or the user opted out (.skipped).
        // We previously checked `baseline == 0` which falsely re-triggered
        // calibration on devices/simulators that legitimately measured 0.
        let alreadyCalibrated: Bool = {
            if case .completed = calibrationService.phase { return true }
            if case .skipped = calibrationService.phase { return true }
            return false
        }()

        if settings.calibrationEnabled && !alreadyCalibrated {
            phase = .calibrating
            calibrationService.startCalibration(motionService: motionService, audioService: audioService)

            calibrationCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if case .completed = self.calibrationService.phase {
                        self.calibrationCheckTimer?.invalidate()
                        self.calibrationCheckTimer = nil
                        self.phase = .tracking
                    } else if case .skipped = self.calibrationService.phase {
                        self.calibrationCheckTimer?.invalidate()
                        self.calibrationCheckTimer = nil
                        self.phase = .tracking
                    }
                }
            }
        } else {
            AppLogger.tracking.info("🛌 Calibration already completed in pre-tracking flow — skipping re-calibration")
            phase = .tracking
        }

        smartAlarmService.startMonitoring(
            motionService: motionService,
            notificationService: notificationService,
            healthKitService: healthKitService,
            intelligenceService: intelligenceService
        )

        crashRecoveryService.startPeriodicSave { [weak self] in
            guard let self = self, let start = self.startTime else { return nil }
            return RecoveryState(
                startTime: start,
                elapsedTime: self.elapsedTime,
                movementPoints: self.motionService.dataPoints,
                snoringEvents: self.audioService.snoringEvents,
                savedAt: Date()
            )
        }

        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let start = self.startTime else { return }
                self.elapsedTime = Date().timeIntervalSince(start)
                self.liveActivityService.updateActivity(
                    elapsed: self.elapsedTime,
                    snoringCount: self.audioService.snoringEvents.count,
                    phase: "tracking"
                )
            }
        }

        // Reset watch HR stats
        watchHRMin = 0
        watchHRMax = 0
        watchHRSum = 0
        watchHRCount = 0

        // Push snoring count to watch every 60 seconds
        snoringPushTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                NotificationCenter.default.post(
                    name: .watchSnoringCountUpdate,
                    object: nil,
                    userInfo: ["count": self.audioService.snoringEvents.count]
                )
            }
        }

        // Observe movement data from watch accelerometer
        watchMovementObserver = NotificationCenter.default.addObserver(
            forName: .watchMovementData,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let points = notification.userInfo?["points"] as? [MovementDataPoint] else { return }
            AppLogger.tracking.info("⌚ Received \(points.count) movement points from watch")
            self.motionService.dataPoints.append(contentsOf: points)
        }

        // Handle watch disconnect/reconnect during active tracking
        watchDisconnectObserver = NotificationCenter.default.addObserver(
            forName: .watchReachabilityChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self, self.phase == .tracking || self.phase == .calibrating else { return }
            let reachable = notification.userInfo?["reachable"] as? Bool ?? false
            self.handleWatchReachabilityChange(reachable: reachable)
        }

        UserDefaults.standard.set(true, forKey: "isCurrentlyTracking")
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Watch Reachability Change During Tracking

    /// Called when watch connects or disconnects during an active session.
    /// Switches motion data source dynamically to avoid data gaps.
    func handleWatchReachabilityChange(reachable: Bool) {
        guard let settings = settings, settings.trackMotion else { return }

        if reachable && !isUsingWatchMotion {
            // Watch reconnected — switch to watch motion, stop iPhone accelerometer
            AppLogger.tracking.info("⌚ Watch reconnected during tracking — switching motion to watch")
            motionService.stopTracking()
            isUsingWatchMotion = true
        } else if !reachable && isUsingWatchMotion {
            // Watch disconnected — fall back to iPhone accelerometer
            AppLogger.tracking.info("📱 Watch disconnected during tracking — falling back to iPhone accelerometer")
            motionService.startTracking(sensitivity: settings.sensitivityLevel)
            isUsingWatchMotion = false
        }
    }

    /// Update watch heart rate stats from live data
    func updateWatchHR(_ bpm: Double) {
        guard bpm > 0 else { return }
        if watchHRCount == 0 {
            watchHRMin = bpm
            watchHRMax = bpm
        } else {
            watchHRMin = min(watchHRMin, bpm)
            watchHRMax = max(watchHRMax, bpm)
        }
        watchHRSum += bpm
        watchHRCount += 1
    }

    var watchHRAvg: Double {
        watchHRCount > 0 ? watchHRSum / Double(watchHRCount) : 0
    }

    // MARK: - Stop Tracking

    func stopTracking() {
        AppLogger.tracking.info("🔴 Stopping sleep tracking session")
        motionService.stopTracking()
        audioService.stopTracking()
        batteryService.stopMonitoring()
        smartAlarmService.stopMonitoring()
        crashRecoveryService.stopPeriodicSave()

        elapsedTimer?.invalidate()
        elapsedTimer = nil
        batteryCheckTimer?.invalidate()
        batteryCheckTimer = nil
        snoringPushTimer?.invalidate()
        snoringPushTimer = nil

        if let observer = watchMovementObserver {
            NotificationCenter.default.removeObserver(observer)
            watchMovementObserver = nil
        }
        if let observer = watchDisconnectObserver {
            NotificationCenter.default.removeObserver(observer)
            watchDisconnectObserver = nil
        }
        isUsingWatchMotion = false

        liveActivityService.endActivity()
        sleepFocusService.disableSleepFocus()

        phase = .completing

        UserDefaults.standard.set(false, forKey: "isCurrentlyTracking")
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Recover Session

    func recoverSession() {
        AppLogger.tracking.info("♻️ Recovering crashed session")
        crashRecoveryService.checkForPendingRecovery()
        guard let state = crashRecoveryService.recoveredState else { return }

        startTime = state.startTime
        elapsedTime = state.elapsedTime
        motionService.dataPoints = state.movementPoints
        audioService.snoringEvents = state.snoringEvents

        phase = .completing
    }

    // MARK: - Discard Recovery

    func discardRecovery() {
        crashRecoveryService.clearRecovery()
    }

    // MARK: - Save Session

    @discardableResult
    func saveSession(quality: SleepQuality, notes: String, modelContext: ModelContext, cloudService: CloudSyncService) async -> SleepSession? {
        guard let start = startTime else { return nil }
        let end = Date()

        let movementPoints = motionService.dataPoints
        let snoringEvents = audioService.snoringEvents
        let stages = deriveSleepStages(from: movementPoints, start: start, end: end)

        let onsetLatency: Double
        if let firstSleepStage = stages.first(where: { $0.stage != .awake }) {
            onsetLatency = firstSleepStage.startTime.timeIntervalSince(start)
        } else {
            onsetLatency = 0
        }

        let session = SleepSession(
            startTime: start,
            endTime: end,
            quality: quality,
            notes: notes,
            movementPoints: movementPoints,
            snoringEvents: snoringEvents,
            sleepStages: stages,
            onsetLatencySeconds: onsetLatency
        )

        modelContext.insert(session)

        do {
            try modelContext.save()
            AppLogger.tracking.info("💾 Saving sleep session — score: \(session.sleepScore)")
        } catch {
            AppLogger.error("Failed to save sleep session", error: error)
        }

        // Pull Apple Watch biometrics AND stage classifications for this
        // window if the user wore one. Runs off-main so it doesn't block
        // the save/UI. Re-saves the session in place when values arrive.
        // This is what turns us from "iPhone estimator" into "works with
        // your Apple Watch" in the competitive sense.
        Task { @MainActor [healthKitService = self.healthKitService] in
            async let biometricsTask = healthKitService.fetchAllBiometrics(from: start, to: end)
            async let restingHRTask = healthKitService.fetchRestingHeartRate()
            async let watchStagesTask = healthKitService.fetchAppleWatchStages(from: start, to: end)

            let biometrics = await biometricsTask
            let restingHR = await restingHRTask
            let watchStages = await watchStagesTask

            session.averageHeartRateBPM = biometrics.heartRate?.average
            session.minimumHeartRateBPM = biometrics.heartRate?.minimum
            session.hrvAverageMS = biometrics.hrvAverage
            session.respiratoryRateBPM = biometrics.respiratoryRate
            session.bloodOxygenPercent = biometrics.bloodOxygen
            session.wristTemperatureCelsius = biometrics.wristTemperature
            session.restingHeartRateBPM = restingHR

            // Prefer Apple Watch stages over our iPhone estimation when
            // available — Watch has direct HR + motion, much more reliable
            // than our audio+motion proxy.
            if !watchStages.isEmpty {
                session.sleepStages = watchStages
                AppLogger.healthKit.info("⌚ Using \(watchStages.count) Apple Watch sleep-stage samples as ground truth")
            }

            try? modelContext.save()
            AppLogger.healthKit.info("⌚ Biometrics merged — avgHR:\(biometrics.heartRate?.average ?? -1), HRV:\(biometrics.hrvAverage ?? -1)ms")
        }

        if let settings = settings, settings.syncHealthKit {
            do {
                try await healthKitService.saveSleepSession(session)
                session.syncedToHealthKit = true
                try modelContext.save()
            } catch {
                AppLogger.error("HealthKit sync failed", error: error)
            }
        }

        if let settings = settings, settings.morningSummaryEnabled {
            notificationService.sendMorningSummary(
                duration: session.durationSeconds,
                quality: session.quality.label,
                score: session.sleepScore
            )
        }

        // Notify watch of sleep summary with full data
        var summaryInfo: [String: Any] = [
            "score": session.sleepScore,
            "duration": session.durationSeconds,
            "quality": session.quality.label,
            "snoringCount": snoringEvents.count,
            "hrMin": watchHRMin,
            "hrMax": watchHRMax,
            "hrAvg": watchHRAvg
        ]
        if let stagesData = try? JSONEncoder().encode(stages),
           let stagesString = String(data: stagesData, encoding: .utf8) {
            summaryInfo["stagesJSON"] = stagesString
        }
        if let movData = try? JSONEncoder().encode(movementPoints),
           let movString = String(data: movData, encoding: .utf8) {
            summaryInfo["movementJSON"] = movString
        }
        NotificationCenter.default.post(
            name: .watchMorningSummary,
            object: nil,
            userInfo: summaryInfo
        )

        crashRecoveryService.clearRecovery()

        // Sync to Firestore
        Task {
            await cloudService.syncSessions([session])
        }

        phase = .done
        AppLogger.tracking.debug("Phase changed to: \(String(describing: self.phase))")

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streakCount = 1
        let lastTrackDate = UserDefaults.standard.object(forKey: "lastTrackDate") as? Date
        if let lastDate = lastTrackDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if daysBetween <= 1 {
                let currentStreak = UserDefaults.standard.integer(forKey: "currentStreak")
                streakCount = currentStreak + 1
            }
        }
        UserDefaults.standard.set(today, forKey: "lastTrackDate")
        UserDefaults.standard.set(streakCount, forKey: "currentStreak")

        if streakCount > 1 && streakCount % 7 == 0 {
            notificationService.sendStreakCelebration(streakCount: streakCount)
        }

        let goalHours = session.durationSeconds / 3600.0
        if let settings = settings, goalHours >= settings.sleepGoalHours {
            notificationService.sendGoalAchievement(hours: goalHours, goalHours: settings.sleepGoalHours)
        }

        UserDefaults.standard.set(session.sleepScore, forKey: "lastSleepScore")
        let hours = Int(session.durationSeconds) / 3600
        let minutes = (Int(session.durationSeconds) % 3600) / 60
        UserDefaults.standard.set("\(hours)h \(minutes)m", forKey: "lastSleepDuration")
        UserDefaults.standard.set(session.sleepScore, forKey: "weeklyAvgScore")
        WidgetCenter.shared.reloadAllTimelines()

        return session
    }

    // MARK: - Reset

    func reset() {
        phase = .idle
        elapsedTime = 0
        startTime = nil
        motionService.dataPoints = []
        audioService.snoringEvents = []
        UserDefaults.standard.set(false, forKey: "isCurrentlyTracking")
    }

    // MARK: - Derive Sleep Stages

    func deriveSleepStages(from movementData: [MovementDataPoint], start: Date, end: Date) -> [SleepStageEntry] {
        guard !movementData.isEmpty else { return [] }

        var stages: [SleepStageEntry] = []
        let windowDuration: TimeInterval = 1800

        var windowStart = start
        while windowStart < end {
            let windowEnd = min(windowStart.addingTimeInterval(windowDuration), end)

            let windowPoints = movementData.filter { $0.timestamp >= windowStart && $0.timestamp < windowEnd }
            let avgIntensity: Double
            if windowPoints.isEmpty {
                avgIntensity = 0.0
            } else {
                avgIntensity = windowPoints.map(\.intensity).reduce(0, +) / Double(windowPoints.count)
            }

            let calibratedIntensity = calibrationService.applyCalibration(to: avgIntensity)

            let stage: SleepStageType
            if calibratedIntensity > 0.15 {
                stage = .awake
            } else if calibratedIntensity > 0.08 {
                stage = .light
            } else if calibratedIntensity > 0.03 {
                stage = .rem
            } else {
                stage = .deep
            }

            stages.append(SleepStageEntry(
                startTime: windowStart,
                endTime: windowEnd,
                stage: stage
            ))

            windowStart = windowEnd
        }

        return stages
    }

    // MARK: - Battery Warnings

    func checkBatteryWarnings() {
        switch batteryService.warningLevel {
        case .critical:
            notificationService.sendBatteryWarning(level: batteryService.batteryLevel)
        case .low:
            notificationService.sendBatteryWarning(level: batteryService.batteryLevel)
        case .normal:
            break
        }
    }
}
