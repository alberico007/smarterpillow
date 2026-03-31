//
//  HeartRateService.swift
//  sleepWatch

import Foundation
import HealthKit

final class HeartRateService: NSObject, ObservableObject {

    @Published var currentBPM: Double?

    /// Called with each new BPM sample — wired up by ContentView to relay HR to iPhone
    var onHeartRateSample: ((Double) -> Void)?

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try? await healthStore.requestAuthorization(
            toShare: [HKObjectType.workoutType()],
            read: [HKQuantityType(.heartRate)]
        )
    }

    // MARK: - Session Lifecycle

    /// Starts an HKWorkoutSession to keep the Watch process alive in background during sleep.
    /// Without an active workout session watchOS suspends the app within seconds of wrist lowering.
    func startMonitoring() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .other   // .sleep is not a valid HKWorkoutActivityType
        config.locationType = .indoor
        guard let session = try? HKWorkoutSession(healthStore: healthStore,
                                                  configuration: config) else { return }
        let liveBuilder = session.associatedWorkoutBuilder()
        liveBuilder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore,
                                                          workoutConfiguration: config)
        session.delegate = self
        liveBuilder.delegate = self
        workoutSession = session
        builder = liveBuilder
        session.startActivity(with: Date())
        liveBuilder.beginCollection(withStart: Date()) { _, _ in }
    }

    func stopMonitoring() {
        workoutSession?.end()
        builder?.endCollection(withEnd: Date()) { [weak self] _, _ in
            self?.builder?.finishWorkout { _, _ in }
        }
        workoutSession = nil
        builder = nil
    }
}

// MARK: - HKWorkoutSessionDelegate

extension HeartRateService: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {}

    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didFailWithError error: Error) {}
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension HeartRateService: HKLiveWorkoutBuilderDelegate {

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>) {
        guard collectedTypes.contains(HKQuantityType(.heartRate)),
              let stats = workoutBuilder.statistics(for: HKQuantityType(.heartRate)),
              let recent = stats.mostRecentQuantity() else { return }
        let bpm = recent.doubleValue(for: HKUnit(from: "count/min"))
        DispatchQueue.main.async {
            self.currentBPM = bpm
            self.onHeartRateSample?(bpm)
        }
    }
}
