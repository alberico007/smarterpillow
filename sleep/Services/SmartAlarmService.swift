//
//  SmartAlarmService.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/17/26.
//

import AudioToolbox
import Foundation
import os

// MARK: - AlarmSound

enum AlarmSound: String, CaseIterable, Identifiable {
    case gentle = "Gentle Chime"
    case sunrise = "Sunrise"
    case birds = "Morning Birds"
    case waves = "Ocean Waves"
    case bells = "Soft Bells"
    case harp = "Harp"
    case piano = "Piano"
    case forest = "Forest"
    case rain = "Light Rain"
    case systemDefault = "Default"

    var id: String { rawValue }

    var systemSoundID: UInt32 {
        // Map to system sound IDs or custom audio files
        switch self {
        case .gentle: 1013
        case .sunrise: 1016
        case .birds: 1025
        case .waves: 1023
        case .bells: 1012
        case .harp: 1014
        case .piano: 1015
        case .forest: 1020
        case .rain: 1021
        case .systemDefault: 1005
        }
    }

    var icon: String {
        switch self {
        case .gentle: "bell.fill"
        case .sunrise: "sunrise.fill"
        case .birds: "bird.fill"
        case .waves: "water.waves"
        case .bells: "bell.and.waves.left.and.right.fill"
        case .harp: "harp"
        case .piano: "pianokeys"
        case .forest: "tree.fill"
        case .rain: "cloud.rain.fill"
        case .systemDefault: "alarm.fill"
        }
    }
}

@Observable
final class SmartAlarmService {

    // MARK: - Observable State

    var isMonitoring = false
    var alarmTriggered = false
    var snoozedUntil: Date?
    var isGradualWakeActive = false
    var gradualWakeProgress: Double = 0 // 0.0 to 1.0
    var selectedSound: AlarmSound = .gentle

    // MARK: - Private

    private var alarmTime: Date?
    private var windowMinutes: Int = 30
    private var alarmEnabled = false

    private var monitoringTimer: Timer?
    private var alarmRepeatTimer: Timer?
    private var gradualWakeTimer: Timer?

    // MARK: - Configuration

    func configure(time: Date, windowMinutes: Int, enabled: Bool) {
        self.alarmTime = time
        self.windowMinutes = windowMinutes
        self.alarmEnabled = enabled
    }

    // MARK: - Monitoring

    func startMonitoring(motionService: MotionService, notificationService: NotificationService) {
        guard alarmEnabled, alarmTime != nil else { return }
        isMonitoring = true
        alarmTriggered = false
        snoozedUntil = nil

        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                guard !self.alarmTriggered else { return }

                // Check snooze
                if let snoozed = self.snoozedUntil, Date() < snoozed {
                    return
                }

                guard self.isInAlarmWindow() else { return }

                // Check if user is in light sleep (movement > threshold)
                if motionService.currentIntensity > 0.08 {
                    self.triggerAlarm()
                    notificationService.sendAlarmNotification()
                }
            }
        }
    }

    // MARK: - Trigger Alarm

    func triggerAlarm() {
        guard !alarmTriggered else { return }
        alarmTriggered = true
        AppLogger.alarm.info("⏰ Smart alarm triggered!")

        // Play alert sound and vibrate
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        AudioServicesPlayAlertSound(1005) // System alert sound

        // Repeat every 3 seconds
        alarmRepeatTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.alarmTriggered else { return }
                AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                AudioServicesPlayAlertSound(1005)
            }
        }
    }

    // MARK: - Snooze

    func snooze(minutes: Int) {
        AppLogger.alarm.info("💤 Alarm snoozed for \(minutes) minutes")
        alarmTriggered = false
        alarmRepeatTimer?.invalidate()
        alarmRepeatTimer = nil
        snoozedUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
    }

    // MARK: - Dismiss

    func dismiss() {
        alarmTriggered = false
        alarmRepeatTimer?.invalidate()
        alarmRepeatTimer = nil
        stopMonitoring()
    }

    // MARK: - Gradual Wake

    func startGradualWake(durationMinutes: Int) {
        isGradualWakeActive = true
        gradualWakeProgress = 0
        let totalSteps = durationMinutes * 60 / 5 // update every 5 seconds
        var step = 0

        gradualWakeTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self = self else { timer.invalidate(); return }
                step += 1
                self.gradualWakeProgress = min(Double(step) / Double(max(totalSteps, 1)), 1.0)

                // Increase alarm volume gradually
                if step % 12 == 0 { // Every minute, play a quiet sound
                    AudioServicesPlaySystemSound(SystemSoundID(self.selectedSound.systemSoundID))
                }

                if self.gradualWakeProgress >= 1.0 {
                    timer.invalidate()
                    self.isGradualWakeActive = false
                    // Full alarm now
                    self.triggerFullAlarm()
                }
            }
        }
    }

    private func triggerFullAlarm() {
        alarmTriggered = true
        AudioServicesPlaySystemSound(SystemSoundID(selectedSound.systemSoundID))
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    func stopGradualWake() {
        gradualWakeTimer?.invalidate()
        gradualWakeTimer = nil
        isGradualWakeActive = false
        gradualWakeProgress = 0
    }

    // MARK: - Continue Sleeping

    func continueSleeping() {
        alarmTriggered = false
        stopGradualWake()
        // Reset monitoring to detect next light sleep
        // The tracking continues
    }

    // MARK: - Stop Monitoring

    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        alarmRepeatTimer?.invalidate()
        alarmRepeatTimer = nil
        isMonitoring = false
    }

    // MARK: - Private

    private func isInAlarmWindow() -> Bool {
        guard let alarmTime = alarmTime else { return false }

        let calendar = Calendar.current
        let now = Date()

        // Extract hour/minute from alarm time and apply to today
        let alarmComponents = calendar.dateComponents([.hour, .minute], from: alarmTime)
        guard let todayAlarm = calendar.date(bySettingHour: alarmComponents.hour ?? 7,
                                              minute: alarmComponents.minute ?? 0,
                                              second: 0,
                                              of: now) else { return false }

        let windowStart = todayAlarm.addingTimeInterval(TimeInterval(-windowMinutes * 60))
        return now >= windowStart && now <= todayAlarm
    }
}
