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

enum TrackingPhase: Equatable {
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

    // MARK: - Private

    private var elapsedTimer: Timer?
    private var batteryCheckTimer: Timer?
    private var settings: SleepSettings?

    // MARK: - Configure

    func configure(settings: SleepSettings) {
        self.settings = settings
        AppLogger.tracking.info("Configured tracking service with settings")

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

        guard let settings = settings else { return }

        if settings.trackMotion {
            motionService.startTracking(sensitivity: settings.sensitivityLevel)
        }
        if settings.trackAudio {
            audioService.configure(sensitivity: settings.snoringSensitivity, minDuration: settings.minimumSnoreDuration)
            audioService.startTracking()
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

        if settings.calibrationEnabled && calibrationService.baseline == 0 {
            phase = .calibrating
            calibrationService.startCalibration(motionService: motionService, audioService: audioService)

            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                Task { @MainActor [weak self] in
                    guard let self = self else {
                        timer.invalidate()
                        return
                    }
                    if case .completed = self.calibrationService.phase {
                        timer.invalidate()
                        self.phase = .tracking
                    } else if case .skipped = self.calibrationService.phase {
                        timer.invalidate()
                        self.phase = .tracking
                    }
                }
            }
        } else {
            phase = .tracking
        }

        smartAlarmService.startMonitoring(
            motionService: motionService,
            notificationService: notificationService
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

        UserDefaults.standard.set(true, forKey: "isCurrentlyTracking")
        WidgetCenter.shared.reloadAllTimelines()
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

    func saveSession(quality: SleepQuality, notes: String, modelContext: ModelContext, cloudService: CloudSyncService) async {
        guard let start = startTime else { return }
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
