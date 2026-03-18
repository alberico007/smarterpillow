//
//  HomeView.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/17/26.
//

import SwiftData
import SwiftUI

struct HomeView: View {

    @Binding var selectedTab: AppTab

    @Environment(SleepTrackingService.self) private var trackingService
    @Environment(SleepSettings.self) private var settings
    @Environment(WeatherService.self) private var weatherService

    @Query(sort: \SleepSession.startTime, order: .reverse)
    private var sessions: [SleepSession]

    @Query(sort: \SleepFactor.date, order: .reverse)
    private var factors: [SleepFactor]

    @State private var intelligenceService = IntelligenceService()
    @State private var aiTip: String? = nil

    private var lastSession: SleepSession? { sessions.first }

    private var weekSessions: [SleepSession] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return sessions.filter { $0.startTime >= cutoff }
    }

    private var streak: Int {
        let calendar = Calendar.current
        var count = 0
        var checkDate = calendar.startOfDay(for: Date())
        for session in sessions {
            let sessionDay = calendar.startOfDay(for: session.startTime)
            if sessionDay == checkDate || sessionDay == calendar.date(byAdding: .day, value: -1, to: checkDate)! {
                count += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: sessionDay) ?? checkDate
            } else {
                break
            }
        }
        return count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let session = lastSession {
                        // Sleep Score Ring
                        SleepScoreRingCard(session: session, goalHours: settings.sleepGoalHours)

                        // Last Night Summary
                        LastNightSummaryCard(session: session)

                        // Weekly Snapshot
                        WeeklySnapshotCard(sessions: weekSessions, streak: streak, goalHours: settings.sleepGoalHours)
                    } else {
                        // Empty state
                        VStack(spacing: 16) {
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 80))
                                .foregroundStyle(.cyan)
                                .symbolEffect(.breathe)

                            Text("No Sleep Data Yet")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Start your first sleep tracking session to see your dashboard.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding(.top, 60)
                    }

                    // AI Coaching Tip
                    if let tip = aiTip {
                        AICoachCard(tip: tip, isAIPowered: intelligenceService.isAvailable)
                    }

                    // Quick Actions
                    QuickActionsCard(selectedTab: $selectedTab)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .task {
                aiTip = await intelligenceService.generateCoachingTip(
                    sessions: Array(sessions.prefix(14)),
                    factors: Array(factors.prefix(30))
                )
            }
            .navigationTitle("Home")
        }
    }
}

// MARK: - SleepScoreRingCard

private struct SleepScoreRingCard: View {

    let session: SleepSession
    let goalHours: Double

    var body: some View {
        GlassCard {
            VStack(spacing: 12) {
                Text("Last Night's Sleep Score")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 140, height: 140)

                    // Score ring
                    Circle()
                        .trim(from: 0, to: CGFloat(session.sleepScore) / 100.0)
                        .stroke(
                            AngularGradient(
                                colors: [scoreColor.opacity(0.6), scoreColor],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 140, height: 140)

                    VStack(spacing: 2) {
                        Text("\(session.sleepScore)")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(scoreColor)
                        Text("of 100")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)

                // Goal progress
                let hours = session.durationSeconds / 3600.0
                let goalProgress = min(hours / goalHours, 1.0)
                HStack {
                    Image(systemName: "target")
                        .foregroundStyle(.secondary)
                    Text("\(String(format: "%.1f", hours))h of \(String(format: "%.0f", goalHours))h goal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(FormatHelpers.percentage(goalProgress))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(goalProgress >= 1.0 ? .green : .orange)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var scoreColor: Color {
        let score = session.sleepScore
        if score >= 80 { return .green }
        if score >= 60 { return .yellow }
        if score >= 40 { return .orange }
        return .red
    }
}

// MARK: - LastNightSummaryCard

private struct LastNightSummaryCard: View {

    let session: SleepSession

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Last Night")
                    .font(.headline)

                // Time in bed
                HStack {
                    Image(systemName: "bed.double.fill")
                        .foregroundStyle(.indigo)
                        .frame(width: 24)
                    Text("Time in Bed")
                        .font(.subheadline)
                    Spacer()
                    Text(FormatHelpers.duration(session.durationSeconds))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Divider()

                // Sleep efficiency
                HStack {
                    Image(systemName: "percent")
                        .foregroundStyle(.cyan)
                        .frame(width: 24)
                    Text("Sleep Efficiency")
                        .font(.subheadline)
                    Spacer()
                    Text(FormatHelpers.percentage(session.sleepEfficiency))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Divider()

                // Disruptions
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .frame(width: 24)
                    Text("Disruptions")
                        .font(.subheadline)
                    Spacer()
                    Text("\(session.awakeningCount)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                // Sleep stage breakdown bar
                if !session.sleepStages.isEmpty {
                    Divider()
                    SleepStageBar(stages: session.sleepStages)
                }
            }
        }
    }
}

// MARK: - SleepStageBar

private struct SleepStageBar: View {

    let stages: [SleepStageEntry]

    private var stagePercentages: [(type: SleepStageType, pct: Double)] {
        let total = stages.reduce(0.0) { $0 + $1.endTime.timeIntervalSince($1.startTime) }
        guard total > 0 else { return [] }
        return SleepStageType.allCases.compactMap { stageType in
            let dur = stages.filter { $0.stage == stageType }.reduce(0.0) { $0 + $1.endTime.timeIntervalSince($1.startTime) }
            guard dur > 0 else { return nil }
            return (type: stageType, pct: dur / total)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(stagePercentages, id: \.type) { item in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(item.type.color)
                            .frame(width: max(4, geo.size.width * item.pct - 2))
                    }
                }
            }
            .frame(height: 8)

            // Legend
            HStack(spacing: 12) {
                ForEach(stagePercentages, id: \.type) { item in
                    HStack(spacing: 4) {
                        Circle().fill(item.type.color).frame(width: 6, height: 6)
                        Text("\(item.type.label) \(FormatHelpers.percentage(item.pct))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - WeeklySnapshotCard

private struct WeeklySnapshotCard: View {

    let sessions: [SleepSession]
    let streak: Int
    let goalHours: Double

    private var averageScore: Int {
        guard !sessions.isEmpty else { return 0 }
        return sessions.map(\.sleepScore).reduce(0, +) / sessions.count
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("This Week")
                        .font(.headline)
                    Spacer()
                    if streak > 1 {
                        Label("\(streak)-night streak", systemImage: "flame.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                // 7-day bar chart
                WeeklyDurationBars(sessions: sessions, goalHours: goalHours)
                    .frame(height: 100)

                HStack {
                    VStack(alignment: .leading) {
                        Text("Avg Score")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(averageScore)")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Nights Tracked")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(sessions.count)")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                }
            }
        }
    }
}

// MARK: - WeeklyDurationBars

private struct WeeklyDurationBars: View {

    let sessions: [SleepSession]
    let goalHours: Double

    private var last7Days: [(label: String, hours: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            let dayStart = day
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: day)!
            let daySession = sessions.first {
                $0.startTime >= dayStart && $0.startTime < dayEnd
            }
            let label = FormatHelpers.weekday(day)
            return (label: label, hours: (daySession?.durationSeconds ?? 0) / 3600.0)
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(last7Days.enumerated()), id: \.offset) { _, day in
                VStack(spacing: 4) {
                    if day.hours > 0 {
                        Text(String(format: "%.0f", day.hours))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }

                    RoundedRectangle(cornerRadius: 4)
                        .fill(day.hours >= goalHours ? Color.green : day.hours > 0 ? Color.indigo : Color.gray.opacity(0.15))
                        .frame(height: day.hours > 0 ? max(8, CGFloat(day.hours / 12.0) * 70) : 4)

                    Text(day.label)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - AICoachCard

private struct AICoachCard: View {

    let tip: String
    var isAIPowered: Bool = false

    var body: some View {
        GlassCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "brain.head.profile.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .pink], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Sleep Coach")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        if isAIPowered {
                            Text("AI")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.purple.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                    Text(tip)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
        }
    }
}

// MARK: - QuickActionsCard

private struct QuickActionsCard: View {

    @Binding var selectedTab: AppTab
    @Environment(SleepTrackingService.self) private var trackingService
    @Environment(\.modelContext) private var modelContext
    @State private var showingFactorLog = false
    @State private var showingExport = false

    var body: some View {
        GlassCard {
            VStack(spacing: 12) {
                Text("Quick Actions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 16) {
                    QuickActionButton(icon: "play.fill", label: "Start\nTracking", color: .cyan) {
                        trackingService.startTracking()
                        selectedTab = .track
                    }
                    QuickActionButton(icon: "cup.and.saucer.fill", label: "Log\nFactor", color: .brown) {
                        showingFactorLog = true
                    }
                    QuickActionButton(icon: "doc.text.fill", label: "Export\nReport", color: .indigo) {
                        selectedTab = .reports
                    }
                }
            }
        }
        .sheet(isPresented: $showingFactorLog) {
            NavigationStack {
                FactorLoggingView()
            }
        }
    }
}

private struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 48, height: 48)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
