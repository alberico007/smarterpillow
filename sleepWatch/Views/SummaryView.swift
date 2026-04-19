//
//  SummaryView.swift
//  sleepWatch

import os
import SwiftUI

struct SummaryView: View {

    @EnvironmentObject var sessionManager: WatchSessionManager

    let summaryData: SleepSummaryData

    private var durationFormatted: String {
        let h = Int(summaryData.duration) / 3600
        let m = (Int(summaryData.duration) % 3600) / 60
        return "\(h)h \(m)m"
    }

    private var scoreColor: Color {
        switch summaryData.score {
        case 80...100: return .green
        case 60..<80:  return .cyan
        case 40..<60:  return .yellow
        default:       return .orange
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {

                // Header
                Image(systemName: "sun.horizon.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Text("Sleep Summary")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)

                // Score ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 6)
                        .frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: CGFloat(summaryData.score) / 100)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                    Text("\(summaryData.score)")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                }

                // Duration + Quality
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text(durationFormatted)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Duration")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    VStack(spacing: 2) {
                        Text(summaryData.quality)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Quality")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                // Sleep Stages Chart
                if !summaryData.stages.isEmpty {
                    VStack(spacing: 4) {
                        Text("Sleep Stages")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                        WatchStagesChart(stages: summaryData.stages)
                    }
                    .padding(.horizontal, 4)
                }

                // Heart Rate + Snoring stats
                HStack(spacing: 12) {
                    if summaryData.hrAvg > 0 {
                        VStack(spacing: 2) {
                            HStack(spacing: 2) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.red)
                                Text("\(Int(summaryData.hrAvg))")
                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            Text("\(Int(summaryData.hrMin))-\(Int(summaryData.hrMax))")
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            Image(systemName: "waveform")
                                .font(.system(size: 8))
                                .foregroundStyle(.orange)
                            Text(summaryData.snoringCount > 0 ? "\(summaryData.snoringCount)" : "0")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        Text("Snoring")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                // Movement Chart
                if !summaryData.movement.isEmpty {
                    VStack(spacing: 4) {
                        Text("Movement")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                        WatchMovementChart(points: summaryData.movement)
                    }
                    .padding(.horizontal, 4)
                }

                // Done button
                Button {
                    WatchLogger.ui.info("User dismissed summary")
                    sessionManager.dismissSummary()
                } label: {
                    Text("Done")
                        .font(.system(.callout, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .padding(.top, 4)
            }
            .padding(.vertical, 6)
        }
    }
}
