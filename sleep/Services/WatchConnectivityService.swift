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

    // MARK: - Init

    override init() {
        super.init()
        activate()
    }

    // MARK: - Activation

    private func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Send to Watch

    /// Sends the current tracking state to the Watch so it can mirror the session
    func sendTrackingState(isTracking: Bool, startTime: Date?) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isReachable else { return }

        var context: [String: Any] = ["isTracking": isTracking]
        if let start = startTime {
            context["startTime"] = start.timeIntervalSince1970
        }

        do {
            try WCSession.default.updateApplicationContext(context)
        } catch {
            AppLogger.general.error("WatchConnectivity: failed to update context – \(error.localizedDescription)")
        }
    }

    /// Pushes a morning summary to the Watch face complication / notification
    func sendMorningSummary(score: Int, duration: TimeInterval, quality: String) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else { return }

        let message: [String: Any] = [
            "type": "morningSummary",
            "score": score,
            "duration": duration,
            "quality": quality
        ]

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            // Queue for next time Watch is reachable
            try? WCSession.default.updateApplicationContext(message)
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
            self.isWatchAppInstalled = session.isWatchAppInstalled
            AppLogger.general.info("⌚ Watch activation completed — reachable: \(session.isReachable), app installed: \(session.isWatchAppInstalled)")
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
            AppLogger.general.info("⌚ Watch reachability changed: \(session.isReachable)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate after Watch switching
        WCSession.default.activate()
    }

    /// Receives messages from the Watch (e.g. live heart rate during sleep)
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            if let hr = message["heartRate"] as? Double {
                self.liveHeartRate = hr
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            if let hr = applicationContext["heartRate"] as? Double {
                self.liveHeartRate = hr
            }
        }
    }
}
