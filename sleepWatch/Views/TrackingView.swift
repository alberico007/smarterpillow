//
//  TrackingView.swift
//  sleepWatch

import os
import SwiftUI

struct TrackingView: View {

    let startTime: Date

    @EnvironmentObject var heartRateService: HeartRateService
    @EnvironmentObject var sessionManager: WatchSessionManager
    @EnvironmentObject var watchMotionService: WatchMotionService
    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer?
    @State private var recentHR: [(Date, Double)] = []
    @State private var showingStopConfirmation = false

    private var elapsedFormatted: String {
        let h = Int(elapsed) / 3600
        let m = (Int(elapsed) % 3600) / 60
        return String(format: "%d:%02d", h, m)
    }

    private var movementColor: Color {
        let intensity = watchMotionService.currentIntensity
        if intensity > 0.15 { return .orange }
        if intensity > 0.05 { return .yellow }
        return .green
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {

                // Tracking badge
                Label("Tracking", systemImage: "record.circle.fill")
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15), in: Capsule())

                // Elapsed time
                Text(elapsedFormatted)
                    .font(.system(size: 36, weight: .thin, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Text("hrs : min")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)

                Divider().background(Color.white.opacity(0.15)).padding(.horizontal, 12)

                // Heart rate with mini chart
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.red)
                                .font(.caption2)
                            if let bpm = heartRateService.currentBPM {
                                Text("\(Int(bpm.rounded()))")
                                    .font(.system(.callout, design: .rounded, weight: .semibold))
                                    .foregroundStyle(.white)
                            } else {
                                Text("—")
                                    .font(.system(.callout, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            Text("BPM")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if recentHR.count >= 2 {
                        WatchHeartRateChart(samples: recentHR)
                            .frame(width: 60, height: 28)
                    }
                }
                .padding(.horizontal, 8)

                // Movement gauge
                VStack(spacing: 3) {
                    HStack {
                        Image(systemName: "figure.walk")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Movement")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(movementColor)
                                .frame(width: max(4, geo.size.width * min(watchMotionService.currentIntensity / 0.3, 1.0)), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.horizontal, 8)

                // Snoring count
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if sessionManager.snoringCount > 0 {
                        Text("\(sessionManager.snoringCount) snoring event\(sessionManager.snoringCount == 1 ? "" : "s")")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.orange)
                    } else {
                        Text("No snoring")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 8)

                Divider().background(Color.white.opacity(0.15)).padding(.horizontal, 12)

                // Stop button with confirmation
                Button {
                    showingStopConfirmation = true
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red.opacity(0.8))
                .confirmationDialog("Stop Tracking?", isPresented: $showingStopConfirmation, titleVisibility: .visible) {
                    Button("Stop Tracking", role: .destructive) {
                        WatchLogger.ui.info("User confirmed stop tracking")
                        sessionManager.sendCommand("stopTracking")
                    }
                    Button("Continue Sleeping", role: .cancel) {
                        WatchLogger.ui.info("User cancelled stop tracking")
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .onAppear {
            elapsed = Date().timeIntervalSince(startTime)
            // Update elapsed time every 30 seconds (sufficient for sleep tracking display)
            timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                DispatchQueue.main.async {
                    elapsed = Date().timeIntervalSince(startTime)
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
        .onChange(of: heartRateService.currentBPM) { _, newBPM in
            guard let bpm = newBPM else { return }
            recentHR.append((Date(), bpm))
            if recentHR.count > 15 {
                recentHR.removeFirst(recentHR.count - 15)
            }
        }
    }
}
