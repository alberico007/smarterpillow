//
//  ContentView.swift
//  sleepWatch

import os
import SwiftUI

struct ContentView: View {

    @EnvironmentObject var sessionManager: WatchSessionManager
    @EnvironmentObject var heartRateService: HeartRateService
    @EnvironmentObject var watchMotionService: WatchMotionService

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.08, green: 0.04, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            switch sessionManager.appState {
            case .idle:
                IdleView()
                    .onAppear {
                        WatchLogger.ui.info("View → Idle")
                    }
            case .tracking(let startTime):
                TrackingView(startTime: startTime)
                    .onAppear {
                        WatchLogger.ui.info("View → Tracking — starting services")

                        // Wire HR callback to send data to iPhone
                        heartRateService.onHeartRateSample = { bpm in
                            sessionManager.sendHeartRate(bpm)
                        }

                        // Wire motion callback to send batches to iPhone
                        watchMotionService.onMovementBatch = { points in
                            sessionManager.sendMovementData(points)
                        }

                        // Start services
                        Task {
                            await heartRateService.requestAuthorization()
                            heartRateService.startMonitoring()
                            WatchLogger.heartRate.info("Heart rate monitoring started")
                        }
                        watchMotionService.startTracking()
                    }
                    .onDisappear {
                        WatchLogger.ui.info("TrackingView disappearing — stopping services")
                        heartRateService.stopMonitoring()
                        heartRateService.onHeartRateSample = nil
                        watchMotionService.stopTracking()
                        watchMotionService.onMovementBatch = nil
                    }
            case .summary(let data):
                SummaryView(summaryData: data)
                    .onAppear {
                        WatchLogger.ui.info("View → Summary (score: \(data.score))")
                    }
            }
        }
    }
}
