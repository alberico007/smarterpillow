//
//  WatchConnectivityService.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/17/26.
//

import Foundation
import os
import WatchConnectivity

// MARK: - WatchConnectivityService

/// Manages communication between the iPhone app and the Apple Watch companion app.
/// On the iPhone side this service activates the WCSession and exposes Watch state.
/// The Watch companion app mirrors tracking state and displays summary data.
@Observable
final class WatchConnectivityService: NSObject {

    // MARK: - Observable State

    /// Whether a paired Apple Watch is reachable right now
    var isWatchReachable = false

    /// Whether a Watch companion app is installed
    var isWatchAppInstalled = false

    /// Last heart rate received live from Watch during sleep (bpm)
    var liveHeartRate: Double?

    /// Timestamp of the last heart rate sample received from Watch
    var liveHeartRateTimestamp: Date?

    // MARK: - Init

    override init() {
        super.init()
        activate()
    }

    // MARK: - Activation

    private func activate() {
        guard WCSession.isSupported() else {
            AppLogger.general.info("⌚ WatchConnectivity not supported on this device")
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        AppLogger.general.info("⌚ WCSession activation requested")
    }

    // MARK: - Send to Watch

    /// Sends the current tracking state to the Watch so it can mirror the session
    func sendTrackingState(isTracking: Bool, startTime: Date?) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else {
            AppLogger.general.warning("⌚ Cannot send tracking state — session not activated")
            return
        }
        guard WCSession.default.isWatchAppInstalled else {
            AppLogger.general.debug("⌚ Watch app not installed — skipping tracking state send")
            return
        }

        var context: [String: Any] = ["isTracking": isTracking]
        if let start = startTime {
            context["startTime"] = start.timeIntervalSince1970
        }

        do {
            try WCSession.default.updateApplicationContext(context)
            AppLogger.general.info("⌚ Sent tracking state to watch — isTracking: \(isTracking)")
        } catch {
            AppLogger.error("WatchConnectivity: failed to update context", error: error)
        }
    }

    /// Pushes a morning summary to the Watch with full sleep data
    func sendMorningSummary(score: Int, duration: TimeInterval, quality: String,
                            stages: [SleepStageEntry] = [], movementPoints: [MovementDataPoint] = [],
                            hrMin: Double = 0, hrMax: Double = 0, hrAvg: Double = 0,
                            snoringCount: Int = 0) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else {
            AppLogger.general.warning("⌚ Cannot send morning summary — session not activated")
            return
        }

        var message: [String: Any] = [
            "type": "morningSummary",
            "score": score,
            "duration": duration,
            "quality": quality,
            "snoringCount": snoringCount,
            "hrMin": hrMin,
            "hrMax": hrMax,
            "hrAvg": hrAvg
        ]

        // Encode stages and movement as JSON strings
        if let stagesData = try? JSONEncoder().encode(stages),
           let stagesString = String(data: stagesData, encoding: .utf8) {
            message["stagesJSON"] = stagesString
        }

        // Downsample movement to every 5th point to keep payload small
        let downsampled = movementPoints.enumerated().compactMap { i, p in i % 5 == 0 ? p : nil }
        if let movData = try? JSONEncoder().encode(downsampled),
           let movString = String(data: movData, encoding: .utf8) {
            message["movementJSON"] = movString
        }

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                AppLogger.error("Failed to send morning summary to watch via message", error: error)
            }
            AppLogger.general.info("⌚ Sent morning summary to watch via message — score: \(score)")
        } else {
            do {
                try WCSession.default.updateApplicationContext(message)
                AppLogger.general.info("⌚ Sent morning summary to watch via context — score: \(score)")
            } catch {
                AppLogger.error("Failed to send morning summary to watch via context", error: error)
            }
        }
    }

    /// Sends current snoring event count to Watch during tracking
    func sendSnoringCount(_ count: Int) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["snoringCount": count], replyHandler: nil) { error in
            AppLogger.error("Failed to send snoring count to watch", error: error)
        }
        AppLogger.general.debug("⌚ Sent snoring count to watch: \(count)")
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
            self.isWatchAppInstalled = session.isWatchAppInstalled
            if let error = error {
                AppLogger.error("⌚ Watch activation failed", error: error)
            } else {
                AppLogger.general.info("⌚ Watch activation completed — reachable: \(session.isReachable), app installed: \(session.isWatchAppInstalled), state: \(activationState.rawValue)")
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            let wasReachable = self.isWatchReachable
            self.isWatchReachable = session.isReachable
            AppLogger.general.info("⌚ Watch reachability changed: \(wasReachable) → \(session.isReachable)")

            // Notify tracking service of connectivity change for sensor switching
            NotificationCenter.default.post(
                name: .watchReachabilityChanged,
                object: nil,
                userInfo: ["reachable": session.isReachable]
            )
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        AppLogger.general.info("⌚ Watch session became inactive")
    }
    func sessionDidDeactivate(_ session: WCSession) {
        AppLogger.general.info("⌚ Watch session deactivated — reactivating")
        WCSession.default.activate()
    }

    /// Receives messages from the Watch (heart rate, commands, movement data)
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        AppLogger.general.debug("⌚ Received message from watch: \(message.keys.joined(separator: ", "))")
        Task { @MainActor in
            handleIncomingWatchData(message)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        AppLogger.general.debug("⌚ Received application context from watch: \(applicationContext.keys.joined(separator: ", "))")
        Task { @MainActor in
            handleIncomingWatchData(applicationContext)
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        AppLogger.general.debug("⌚ Received user info from watch: \(userInfo.keys.joined(separator: ", "))")
        Task { @MainActor in
            handleIncomingWatchData(userInfo)
        }
    }

    private func handleIncomingWatchData(_ data: [String: Any]) {
        // Heart rate with timestamp
        if let hr = data["heartRate"] as? Double {
            self.liveHeartRate = hr
            if let ts = data["heartRateTimestamp"] as? TimeInterval {
                self.liveHeartRateTimestamp = Date(timeIntervalSince1970: ts)
            } else {
                self.liveHeartRateTimestamp = Date()
            }
            AppLogger.general.debug("⌚ Heart rate from watch: \(Int(hr)) BPM")
        }

        // Commands from watch (start/stop tracking)
        if let command = data["command"] as? String {
            AppLogger.general.info("⌚ Received command from watch: \(command)")
            switch command {
            case "startTracking":
                NotificationCenter.default.post(name: .startTrackingIntent, object: nil)
            case "stopTracking":
                NotificationCenter.default.post(name: .stopTrackingIntent, object: nil)
            default:
                AppLogger.general.warning("⌚ Unknown watch command: \(command)")
            }
        }

        // Movement data from watch accelerometer
        if let movJSON = data["movementJSON"] as? String,
           let movData = movJSON.data(using: .utf8),
           let points = try? JSONDecoder().decode([MovementDataPoint].self, from: movData) {
            AppLogger.general.info("⌚ Received \(points.count) movement data points from watch")
            NotificationCenter.default.post(name: .watchMovementData, object: nil,
                                            userInfo: ["points": points])
        }
    }
}
