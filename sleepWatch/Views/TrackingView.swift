//
//  TrackingView.swift
//  sleepWatch

import SwiftUI

struct TrackingView: View {

    let startTime: Date

    @EnvironmentObject var heartRateService: HeartRateService
    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer?

    private var elapsedFormatted: String {
        let h = Int(elapsed) / 3600
        let m = (Int(elapsed) % 3600) / 60
        return String(format: "%d:%02d", h, m)
    }

    var body: some View {
        VStack(spacing: 10) {

            Label("Tracking", systemImage: "record.circle.fill")
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.15), in: Capsule())

            Text(elapsedFormatted)
                .font(.system(size: 42, weight: .thin, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()

            Text("hrs : min")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)

            Divider()
                .background(Color.white.opacity(0.15))
                .padding(.horizontal, 20)

            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .font(.caption)

                if let bpm = heartRateService.currentBPM {
                    Text("\(Int(bpm.rounded())) BPM")
                        .font(.system(.callout, design: .rounded, weight: .medium))
                        .foregroundStyle(.white)
                } else {
                    Text("— BPM")
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            elapsed = Date().timeIntervalSince(startTime)
            // Fire every 30s — battery optimization for overnight use; display is hr:min only
            timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                elapsed = Date().timeIntervalSince(startTime)
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}
