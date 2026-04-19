//
//  WatchSleepCharts.swift
//  sleepWatch
//
//  Compact Swift Charts optimized for Apple Watch display.

import Charts
import SwiftUI

// MARK: - WatchStagesChart

struct WatchStagesChart: View {

    let stages: [SleepStageEntry]

    private func stageValue(_ stage: SleepStageType) -> Int {
        switch stage {
        case .awake: 4
        case .rem: 3
        case .light: 2
        case .deep: 1
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Chart(stages) { entry in
                RectangleMark(
                    xStart: .value("Start", entry.startTime),
                    xEnd: .value("End", entry.endTime),
                    yStart: .value("Stage", stageValue(entry.stage) - 1),
                    yEnd: .value("Top", stageValue(entry.stage))
                )
                .foregroundStyle(entry.stage.color)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 50)

            // Color legend
            HStack(spacing: 6) {
                ForEach([SleepStageType.deep, .light, .rem, .awake]) { stage in
                    HStack(spacing: 2) {
                        Circle().fill(stage.color).frame(width: 5, height: 5)
                        Text(stage.label)
                            .font(.system(size: 8, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - WatchMovementChart

struct WatchMovementChart: View {

    let points: [MovementDataPoint]

    var body: some View {
        Chart(points) { point in
            AreaMark(
                x: .value("Time", point.timestamp),
                y: .value("Intensity", point.intensity)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [.cyan.opacity(0.6), .cyan.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 40)
    }
}

// MARK: - WatchHeartRateChart

struct WatchHeartRateChart: View {

    let samples: [(Date, Double)]

    var body: some View {
        Chart {
            ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
                LineMark(
                    x: .value("Time", sample.0),
                    y: .value("BPM", sample.1)
                )
                .foregroundStyle(.red)
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 30)
    }
}
