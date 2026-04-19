//
//  WatchSessionManager.swift
//  sleepWatch

import Combine
import Foundation
import os
import WatchConnectivity

// MARK: - Watch Logger

/// Centralized logger for watch app (mirrors iPhone AppLogger pattern)
enum WatchLogger {
    private static let subsystem = "com.smarterpillow.sleepWatch"

    static let general = Logger(subsystem: subsystem, category: "general")
    static let session = Logger(subsystem: subsystem, category: "session")
    static let heartRate = Logger(subsystem: subsystem, category: "heartrate")
    static let motion = Logger(subsystem: subsystem, category: "motion")
    static let ui = Logger(subsystem: subsystem, category: "ui")
}

// MARK: - WatchAppState

enum WatchAppState {
    case idle
    case tracking(startTime: Date)
    case summary(data: SleepSummaryData)
}

struct SleepSummaryData {
    let score: Int
    let duration: TimeInterval
    let quality: String
    let stages: [SleepStageEntry]
    let movement: [MovementDataPoint]
    let hrMin: Double
    let hrMax: Double
    let hrAvg: Double
    let snoringCount: Int
}

// MARK: - WatchSessionManager

final class WatchSessionManager: NSObject, ObservableObject {

    @Published var appState: WatchAppState = .idle

    // Live tracking data from iPhone
    @Published var snoringCount: Int = 0

    // Last sleep summary — persisted across launches
    @Published var lastScore: Int?
    @Published var lastDuration: TimeInterval?
    @Published var lastQuality: String?
    @Published var lastStages: [SleepStageEntry] = []
    @Published var lastMovement: [MovementDataPoint] = []
    @Published var lastHRMin: Double?
    @Published var lastHRMax: Double?
    @Published var lastHRAvg: Double?
    @Published var lastSnoringCount: Int = 0

    override init() {
        super.init()
        loadPersistedSummary()
        WatchLogger.session.info("WatchSessionManager initialized")
    }

    func activate() {
        guard WCSession.isSupported() else {
            WatchLogger.session.warning("WCSession not supported")
            return
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
        WatchLogger.session.info("WCSession activation requested")
    }

    func sendHeartRate(_ bpm: Double) {
        guard WCSession.default.activationState == .activated else {
            WatchLogger.heartRate.warning("Cannot send HR — session not activated")
            return
        }
        let message: [String: Any] = [
            "heartRate": bpm,
            "heartRateTimestamp": Date().timeIntervalSince1970
        ]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                WatchLogger.heartRate.error("Failed to send HR via message: \(error.localizedDescription)")
            }
        } else {
            try? WCSession.default.updateApplicationContext(message)
        }
        WatchLogger.heartRate.debug("Sent HR to iPhone: \(Int(bpm)) BPM")
    }

    func sendMovementData(_ points: [MovementDataPoint]) {
        guard WCSession.default.activationState == .activated else {
            WatchLogger.motion.warning("Cannot send movement — session not activated")
            return
        }
        guard let data = try? JSONEncoder().encode(points),
              let jsonString = String(data: data, encoding: .utf8) else {
            WatchLogger.motion.error("Failed to encode movement data")
            return
        }
        WCSession.default.transferUserInfo(["movementJSON": jsonString])
        WatchLogger.motion.info("Sent \(points.count) movement points to iPhone via transferUserInfo")
    }

    @discardableResult
    func sendCommand(_ command: String) -> Bool {
        guard WCSession.default.activationState == .activated else {
            WatchLogger.session.warning("Cannot send command '\(command)' — session not activated")
            return false
        }

        WatchLogger.session.info("Sending command to iPhone: \(command)")

        // On watchOS, sendMessage wakes the iPhone app even if not reachable
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["command": command], replyHandler: nil) { error in
                WatchLogger.session.error("Failed to send command '\(command)': \(error.localizedDescription)")
            }
        } else {
            // Fallback: transferUserInfo queues for delivery when iPhone wakes
            WCSession.default.transferUserInfo(["command": command])
            WatchLogger.session.info("iPhone not reachable — queued command '\(command)' via transferUserInfo")
        }

        // Optimistic local state update so watch UI responds immediately
        if command == "startTracking" {
            snoringCount = 0
            appState = .tracking(startTime: Date())
            WatchLogger.ui.info("Optimistic state → tracking")
        } else if command == "stopTracking" {
            appState = .idle
            WatchLogger.ui.info("Optimistic state → idle")
        }

        return true
    }

    func dismissSummary() {
        appState = .idle
        WatchLogger.ui.info("Summary dismissed → idle")
    }

    // MARK: - Persistence

    private func loadPersistedSummary() {
        let ud = UserDefaults.standard
        lastScore = ud.object(forKey: "lastScore") as? Int
        lastDuration = ud.object(forKey: "lastDuration") as? TimeInterval
        lastQuality = ud.string(forKey: "lastQuality")
        lastHRMin = ud.object(forKey: "lastHRMin") as? Double
        lastHRMax = ud.object(forKey: "lastHRMax") as? Double
        lastHRAvg = ud.object(forKey: "lastHRAvg") as? Double
        lastSnoringCount = ud.integer(forKey: "lastSnoringCount")

        if let stagesData = ud.data(forKey: "lastStagesJSON") {
            lastStages = (try? JSONDecoder().decode([SleepStageEntry].self, from: stagesData)) ?? []
        }
        if let movData = ud.data(forKey: "lastMovementJSON") {
            lastMovement = (try? JSONDecoder().decode([MovementDataPoint].self, from: movData)) ?? []
        }

        if lastScore != nil {
            WatchLogger.session.info("Loaded persisted summary — score: \(self.lastScore ?? 0)")
        } else {
            WatchLogger.session.info("No persisted summary found")
        }
    }

    private func persistSummary(_ data: SleepSummaryData) {
        let ud = UserDefaults.standard
        ud.set(data.score, forKey: "lastScore")
        ud.set(data.duration, forKey: "lastDuration")
        ud.set(data.quality, forKey: "lastQuality")
        ud.set(data.hrMin, forKey: "lastHRMin")
        ud.set(data.hrMax, forKey: "lastHRMax")
        ud.set(data.hrAvg, forKey: "lastHRAvg")
        ud.set(data.snoringCount, forKey: "lastSnoringCount")

        if let encoded = try? JSONEncoder().encode(data.stages) {
            ud.set(encoded, forKey: "lastStagesJSON")
        }
        if let encoded = try? JSONEncoder().encode(data.movement) {
            ud.set(encoded, forKey: "lastMovementJSON")
        }
        WatchLogger.session.info("Persisted sleep summary — score: \(data.score)")
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let error = error {
            WatchLogger.session.error("WCSession activation failed: \(error.localizedDescription)")
        } else {
            WatchLogger.session.info("WCSession activated — state: \(activationState.rawValue)")
        }
    }

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        WatchLogger.session.debug("Received application context: \(applicationContext.keys.joined(separator: ", "))")
        handlePayload(applicationContext)
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any]) {
        WatchLogger.session.debug("Received message: \(message.keys.joined(separator: ", "))")
        handlePayload(message)
    }

    private func handlePayload(_ payload: [String: Any]) {
        DispatchQueue.main.async {
            // Snoring count update during tracking
            if let count = payload["snoringCount"] as? Int,
               payload["type"] as? String != "morningSummary" {
                self.snoringCount = count
                WatchLogger.session.debug("Snoring count updated: \(count)")
            }

            // Morning summary takes priority
            if let type = payload["type"] as? String, type == "morningSummary",
               let score = payload["score"] as? Int,
               let duration = payload["duration"] as? TimeInterval,
               let quality = payload["quality"] as? String {

                WatchLogger.session.info("Received morning summary — score: \(score), duration: \(Int(duration/3600))h")

                // Decode stages
                var stages: [SleepStageEntry] = []
                if let stagesJSON = payload["stagesJSON"] as? String,
                   let data = stagesJSON.data(using: .utf8) {
                    stages = (try? JSONDecoder().decode([SleepStageEntry].self, from: data)) ?? []
                    WatchLogger.session.debug("Decoded \(stages.count) sleep stages")
                }

                // Decode movement
                var movement: [MovementDataPoint] = []
                if let movJSON = payload["movementJSON"] as? String,
                   let data = movJSON.data(using: .utf8) {
                    movement = (try? JSONDecoder().decode([MovementDataPoint].self, from: data)) ?? []
                    WatchLogger.session.debug("Decoded \(movement.count) movement points")
                }

                let summaryData = SleepSummaryData(
                    score: score, duration: duration, quality: quality,
                    stages: stages, movement: movement,
                    hrMin: payload["hrMin"] as? Double ?? 0,
                    hrMax: payload["hrMax"] as? Double ?? 0,
                    hrAvg: payload["hrAvg"] as? Double ?? 0,
                    snoringCount: payload["snoringCount"] as? Int ?? 0
                )

                // Update last summary
                self.lastScore = score
                self.lastDuration = duration
                self.lastQuality = quality
                self.lastStages = stages
                self.lastMovement = movement
                self.lastHRMin = summaryData.hrMin
                self.lastHRMax = summaryData.hrMax
                self.lastHRAvg = summaryData.hrAvg
                self.lastSnoringCount = summaryData.snoringCount

                self.persistSummary(summaryData)
                self.appState = .summary(data: summaryData)
                WatchLogger.ui.info("State → summary (score: \(score))")
                return
            }

            if let isTracking = payload["isTracking"] as? Bool {
                if isTracking, let startInterval = payload["startTime"] as? TimeInterval {
                    self.snoringCount = 0
                    self.appState = .tracking(startTime: Date(timeIntervalSince1970: startInterval))
                    WatchLogger.ui.info("State → tracking (from iPhone)")
                } else if case .tracking = self.appState {
                    self.appState = .idle
                    WatchLogger.ui.info("State → idle (tracking stopped by iPhone)")
                }
            }
        }
    }
}
