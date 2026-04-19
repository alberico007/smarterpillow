//
//  IdleView.swift
//  sleepWatch

import os
import SwiftUI

struct IdleView: View {

    @EnvironmentObject var sessionManager: WatchSessionManager
    @State private var pulseAnimation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {

                // App icon
                ZStack {
                    Circle()
                        .fill(Color.indigo.opacity(0.15))
                        .frame(width: 50, height: 50)
                        .scaleEffect(pulseAnimation ? 1.15 : 1.0)
                        .animation(
                            .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                            value: pulseAnimation
                        )
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                // Last night's summary
                if let score = sessionManager.lastScore,
                   let duration = sessionManager.lastDuration,
                   let quality = sessionManager.lastQuality {
                    lastNightCard(score: score, duration: duration, quality: quality)
                } else {
                    Text("No sleep data yet")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                // Start Tracking button
                Button {
                    WatchLogger.ui.info("User tapped Start Tracking")
                    sessionManager.sendCommand("startTracking")
                } label: {
                    Label("Start Tracking", systemImage: "bed.double.fill")
                        .font(.system(.callout, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
            }
            .padding(.horizontal, 4)
        }
        .onAppear { pulseAnimation = true }
    }

    // MARK: - Last Night Card

    private func lastNightCard(score: Int, duration: TimeInterval, quality: String) -> some View {
        VStack(spacing: 8) {
            Text("Last Night")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                // Score ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 4)
                        .frame(width: 36, height: 36)
                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 100)
                        .stroke(scoreColor(score), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 36, height: 36)
                        .rotationEffect(.degrees(-90))
                    Text("\(score)")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(formatDuration(duration))
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(quality)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80:  return .cyan
        case 40..<60:  return .yellow
        default:       return .orange
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        return "\(h)h \(m)m"
    }
}
