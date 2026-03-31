//
//  ContentView.swift
//  sleepWatch

import SwiftUI

struct ContentView: View {

    @EnvironmentObject var sessionManager: WatchSessionManager
    @EnvironmentObject var heartRateService: HeartRateService

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
            case .tracking(let startTime):
                TrackingView(startTime: startTime)
                    .onAppear {
                        heartRateService.onHeartRateSample = { bpm in
                            sessionManager.sendHeartRate(bpm)
                        }
                        Task {
                            await heartRateService.requestAuthorization()
                            heartRateService.startMonitoring()
                        }
                    }
                    .onDisappear {
                        heartRateService.stopMonitoring()
                        heartRateService.onHeartRateSample = nil
                    }
            case .summary(let score, let duration, let quality):
                SummaryView(score: score, duration: duration, quality: quality)
            }
        }
    }
}
