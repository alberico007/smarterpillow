//
//  MotionService.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/17/26.
//

import CoreMotion
import Foundation
import os

@Observable
final class MotionService {

    // MARK: - Observable State

    var isTracking = false
    var currentIntensity: Double = 0.0
    var dataPoints: [MovementDataPoint] = []

    // MARK: - Private

    private let motionManager = CMMotionManager()
    private var recentAccelerations: [Double] = []
    private var samplingTimer: Timer?

    // MARK: - Tracking

    func startTracking(sensitivity: Double) {
        guard !isTracking else { return }
        guard motionManager.isAccelerometerAvailable else {
            AppLogger.motion.error("Accelerometer not available")
            return
        }
        AppLogger.motion.info("🏃 Motion tracking started with sensitivity: \(sensitivity)")

        dataPoints = []
        recentAccelerations = []
        isTracking = true

        motionManager.accelerometerUpdateInterval = 0.1 // 10 Hz

        motionManager.startAccelerometerUpdates(to: OperationQueue()) { @Sendable [weak self] data, error in
            guard let data = data, error == nil else { return }

            let x = data.acceleration.x
            let y = data.acceleration.y
            let z = data.acceleration.z
            let magnitude = sqrt(x * x + y * y + z * z)

            // Subtract gravity (1.0g) and apply sensitivity
            let intensity = max(0, (magnitude - 1.0)) * sensitivity

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.currentIntensity = intensity
                self.recentAccelerations.append(intensity)
            }
        }

        // 30-second sampling timer to aggregate data points
        samplingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.aggregateRecentData()
            }
        }
    }

    func stopTracking() {
        guard isTracking else { return }
        AppLogger.motion.info("🏃 Motion tracking stopped")

        // Final aggregation of remaining data
        aggregateRecentData()

        motionManager.stopAccelerometerUpdates()
        samplingTimer?.invalidate()
        samplingTimer = nil
        isTracking = false
        currentIntensity = 0.0
    }

    // MARK: - Private Aggregation

    private func aggregateRecentData() {
        guard !recentAccelerations.isEmpty else { return }

        let average = recentAccelerations.reduce(0, +) / Double(recentAccelerations.count)
        let point = MovementDataPoint(
            timestamp: Date(),
            intensity: average
        )
        dataPoints.append(point)
        AppLogger.motion.debug("Movement intensity: \(average)")
        recentAccelerations = []
    }
}
