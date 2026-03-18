//
//  ContentView.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/16/26.
//

import os
import SwiftUI

enum AppTab: Hashable {
    case home, track, reports, settings
}

struct ContentView: View {

    @Environment(SleepSettings.self) private var settings
    @Environment(SleepTrackingService.self) private var trackingService

    @State private var showingOnboarding = false
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: .home) {
                HomeView(selectedTab: $selectedTab)
            }

            Tab("Track", systemImage: "moon.zzz.fill", value: .track) {
                TonightView()
            }

            Tab("Reports", systemImage: "chart.line.uptrend.xyaxis", value: .reports) {
                ReportsView()
            }

            Tab("Settings", systemImage: "gearshape", value: .settings) {
                SettingsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .onAppear {
            AppLogger.ui.info("ContentView appeared — onboarding completed: \(settings.hasCompletedOnboarding)")
            if !settings.hasCompletedOnboarding {
                showingOnboarding = true
            }
        }
        .onChange(of: settings.hasCompletedOnboarding) { _, completed in
            if !completed {
                selectedTab = .home
                showingOnboarding = true
            }
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView {
                settings.hasCompletedOnboarding = true
                showingOnboarding = false
            }
        }
    }
}
