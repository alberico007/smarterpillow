//
//  WatchSessionManager.swift
//  sleepWatch

import Foundation
import WatchConnectivity

enum WatchAppState {
    case idle
    case tracking(startTime: Date)
    case summary(score: Int, duration: TimeInterval, quality: String)
}

final class WatchSessionManager: NSObject, ObservableObject {

    @Published var appState: WatchAppState = .idle

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendHeartRate(_ bpm: Double) {
        guard WCSession.default.activationState == .activated else { return }
        let message: [String: Any] = ["heartRate": bpm]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            try? WCSession.default.updateApplicationContext(message)
        }
    }
}

extension WatchSessionManager: WCSessionDelegate {

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {}

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        handlePayload(applicationContext)
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any]) {
        handlePayload(message)
    }

    private func handlePayload(_ payload: [String: Any]) {
        DispatchQueue.main.async {
            // Morning summary takes priority — don't overwrite with stale tracking state
            if let type = payload["type"] as? String, type == "morningSummary",
               let score = payload["score"] as? Int,
               let duration = payload["duration"] as? TimeInterval,
               let quality = payload["quality"] as? String {
                self.appState = .summary(score: score, duration: duration, quality: quality)
                return
            }
            if let isTracking = payload["isTracking"] as? Bool {
                if isTracking, let startInterval = payload["startTime"] as? TimeInterval {
                    self.appState = .tracking(startTime: Date(timeIntervalSince1970: startInterval))
                } else if case .tracking = self.appState {
                    // Only revert to idle from tracking — don't overwrite a summary
                    self.appState = .idle
                }
            }
        }
    }
}
