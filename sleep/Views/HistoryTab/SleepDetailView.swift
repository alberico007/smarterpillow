//
//  SleepDetailView.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/17/26.
//

import SwiftUI

struct SleepDetailView: View {

    let session: SleepSession

    @Environment(SleepSettings.self) private var settings

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // Stats
                GlassCard {
                    VStack(spacing: 12) {
                        StatRow(
                            icon: "clock",
                            label: "Duration",
                            value: FormatHelpers.duration(session.durationSeconds)
                        )
                        Divider()
                        StatRow(
                            icon: "star.fill",
                            label: "Quality",
                            value: session.quality.label
                        )
                        Divider()
                        if settings.showSleepScore {
                            StatRow(
                                icon: "gauge.with.dots.needle.33percent",
                                label: "Sleep Score",
                                value: "\(session.sleepScore)/100"
                            )
                            Divider()
                        }
                        StatRow(
                            icon: "move.3d",
                            label: "Avg Movement",
                            value: String(format: "%.3f", session.averageMovement)
                        )
                        Divider()
                        StatRow(
                            icon: "zzz",
                            label: "Snoring Events",
                            value: "\(session.snoringCount)"
                        )
                    }
                }

                // Sleep Stages Chart
                if !session.sleepStages.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Sleep Stages")
                                .font(.headline)
                            SleepStagesChart(stages: session.sleepStages)
                                .frame(height: 200)
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Stage Breakdown")
                                .font(.headline)
                            SleepStageBreakdownChart(stages: session.sleepStages)
                                .frame(height: 200)
                        }
                    }
                }

                // Movement Timeline
                if !session.movementPoints.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Movement Timeline")
                                .font(.headline)
                            MovementTimelineChart(dataPoints: session.movementPoints)
                                .frame(height: 200)
                        }
                    }
                }

                // Snoring Events
                if !session.snoringEvents.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Snoring Events")
                                .font(.headline)
                            ForEach(session.snoringEvents) { event in
                                HStack {
                                    Image(systemName: "zzz")
                                        .foregroundStyle(.purple)
                                    VStack(alignment: .leading) {
                                        Text(FormatHelpers.timeOfDay(event.startTime))
                                            .font(.subheadline)
                                        Text("Duration: \(FormatHelpers.duration(event.duration))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(String(format: "%.2f", event.averageAmplitude))
                                        .font(.subheadline.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                // Notes
                if !session.notes.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.headline)
                            Text(session.notes)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(FormatHelpers.shortDate(session.startTime))
        .navigationBarTitleDisplayMode(.inline)
    }
}
