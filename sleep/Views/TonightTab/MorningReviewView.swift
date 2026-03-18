//
//  MorningReviewView.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/17/26.
//

import SwiftData
import SwiftUI

struct MorningReviewView: View {

    @Environment(SleepTrackingService.self) private var trackingService
    @Environment(WeatherService.self) private var weatherService
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SleepSession.startTime, order: .reverse)
    private var recentSessions: [SleepSession]

    @State private var selectedQuality: SleepQuality = .fair
    @State private var notes: String = ""
    @State private var isSaving = false
    @State private var heartRate: HeartRateStats?
    @State private var heartRateLoaded = false
    @State private var biometrics: BiometricStats?
    @State private var selectedMood: MorningMood? = nil
    @State private var aiSummary: String? = nil
    @State private var intelligenceService = IntelligenceService()
    @State private var showingShareSheet = false

    // Previous nights for comparison (up to 7, excluding the session being saved)
    private var previousSessions: [SleepSession] {
        Array(recentSessions.prefix(7))
    }

    private var averagePreviousScore: Double? {
        guard !previousSessions.isEmpty else { return nil }
        let total = previousSessions.reduce(0) { $0 + $1.sleepScore }
        return Double(total) / Double(previousSessions.count)
    }

    private var previewSession: SleepSession? {
        guard let start = trackingService.startTime else { return nil }
        return SleepSession(
            startTime: start,
            endTime: Date(),
            quality: selectedQuality,
            movementPoints: trackingService.motionService.dataPoints,
            snoringEvents: trackingService.audioService.snoringEvents,
            sleepStages: trackingService.deriveSleepStages(
                from: trackingService.motionService.dataPoints,
                start: start,
                end: Date()
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 12)

                // Header
                VStack(spacing: 6) {
                    Image(systemName: "sunrise.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(
                            LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom)
                        )
                        .symbolEffect(.breathe)

                    Text("Good Morning!")
                        .font(.title)
                        .fontWeight(.semibold)

                    Text("How did you sleep?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // AI Morning Summary
                if let summary = aiSummary {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "brain.head.profile.fill")
                                    .foregroundStyle(.purple)
                                Text("AI Summary")
                                    .font(.headline)
                                Spacer()
                                if intelligenceService.isAvailable {
                                    Text("Apple Intelligence")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Weather Card
                WeatherCard(weatherService: weatherService)

                // Biometrics Card (Apple Watch)
                if heartRateLoaded {
                    BiometricsCard(heartRate: heartRate, biometrics: biometrics)
                }

                // Score Breakdown
                if let session = previewSession {
                    ScoreBreakdownCard(session: session)
                }

                // Sleep Stage Timeline
                if let session = previewSession, !session.sleepStages.isEmpty {
                    StageTimelineCard(stages: session.sleepStages)
                }

                // Audio Highlights
                if !trackingService.audioService.snoringEvents.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("Audio Highlights", systemImage: "waveform")
                                    .font(.headline)
                                Spacer()
                                Text("\(trackingService.audioService.snoringEvents.count) events")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            ForEach(trackingService.audioService.snoringEvents.prefix(5)) { event in
                                let eventType = AudioEventType.classify(
                                    amplitude: event.averageAmplitude,
                                    duration: event.duration
                                )
                                AudioPlayerView(event: event, eventType: eventType)
                                if event.id != trackingService.audioService.snoringEvents.prefix(5).last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }

                // Sleep Comparison Card
                if let avgScore = averagePreviousScore {
                    SleepComparisonCard(previousSessions: previousSessions, averageScore: avgScore)
                }

                // Morning Mood
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How do you feel?")
                            .font(.headline)

                        HStack(spacing: 16) {
                            ForEach(MorningMood.allCases) { mood in
                                Button {
                                    selectedMood = mood
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(mood.emoji)
                                            .font(.title)
                                        Text(mood.label)
                                            .font(.caption2)
                                            .foregroundStyle(selectedMood == mood ? .primary : .secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(selectedMood == mood ? Color.cyan.opacity(0.15) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Quality picker
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sleep Quality")
                            .font(.headline)

                        HStack(spacing: 12) {
                            ForEach(SleepQuality.allCases) { quality in
                                QualityButton(
                                    quality: quality,
                                    isSelected: selectedQuality == quality
                                ) {
                                    selectedQuality = quality
                                }
                            }
                        }
                    }
                }

                // Notes
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)

                        TextField("How did you feel? Any dreams?", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                            .textFieldStyle(.plain)
                    }
                }

                // Save button
                if isSaving {
                    ProgressView("Saving...")
                        .padding()
                } else {
                    GlassButton(title: "Save Session", icon: "checkmark.circle.fill") {
                        isSaving = true
                        Task {
                            await trackingService.saveSession(
                                quality: selectedQuality,
                                notes: notes,
                                modelContext: modelContext
                            )
                            // Update mood on saved session
                            if let mood = selectedMood, let lastSession = recentSessions.first {
                                lastSession.morningMood = mood.rawValue
                                try? modelContext.save()
                            }
                            isSaving = false
                        }
                    }
                }

                // Share button
                if trackingService.phase == .completing {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Label("Share Report", systemImage: "square.and.arrow.up")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let start = trackingService.startTime {
                let summary = buildShareText(startTime: start)
                ShareSheet(text: summary)
            }
        }
        .task {
            // Fetch weather
            await weatherService.fetchWakeUpWeather()

            // Fetch heart rate and biometrics from Apple Watch via HealthKit
            if let start = trackingService.startTime {
                heartRate = await trackingService.healthKitService.fetchHeartRate(
                    from: start,
                    to: Date()
                )
                biometrics = await trackingService.healthKitService.fetchAllBiometrics(from: start, to: Date())
            }
            heartRateLoaded = true

            // Generate AI summary
            if let start = trackingService.startTime {
                let tempSession = SleepSession(
                    startTime: start,
                    endTime: Date(),
                    quality: selectedQuality,
                    movementPoints: trackingService.motionService.dataPoints,
                    snoringEvents: trackingService.audioService.snoringEvents
                )
                aiSummary = await intelligenceService.generateMorningSummary(session: tempSession)
            }
        }
    }

    private func buildShareText(startTime: Date) -> String {
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let snoringCount = trackingService.audioService.snoringEvents.count

        var text = "Slumberscope Sleep Report\n"
        text += "Date: \(startTime.formatted(date: .abbreviated, time: .omitted))\n"
        text += "Duration: \(hours)h \(minutes)m\n"
        text += "Quality: \(selectedQuality.label)\n"
        text += "Snoring Events: \(snoringCount)\n"
        if let summary = aiSummary {
            text += "\n\(summary)\n"
        }
        text += "\nTracked with Slumberscope"
        return text
    }
}

// MARK: - ShareSheet

private struct ShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - WeatherCard

private struct WeatherCard: View {

    let weatherService: WeatherService

    var body: some View {
        GlassCard {
            if weatherService.isLoading {
                HStack {
                    ProgressView()
                    Text("Getting weather…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            } else if let weather = weatherService.weather {
                HStack(spacing: 16) {
                    // Weather icon
                    Image(systemName: weather.symbolName)
                        .font(.system(size: 42))
                        .symbolRenderingMode(.multicolor)
                        .frame(width: 56)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(weather.cityName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Text(weather.temperature)
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(weather.condition)
                            .font(.subheadline)

                        HStack(spacing: 8) {
                            Text(weather.feelsLike)
                            Text("·")
                            Text(weather.humidity)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            } else {
                HStack {
                    Image(systemName: "icloud.slash")
                        .foregroundStyle(.secondary)
                    Text("Weather unavailable")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - SleepComparisonCard

private struct SleepComparisonCard: View {

    let previousSessions: [SleepSession]
    let averageScore: Double

    // We compare the MOST recent prior session vs the 7-night average
    private var lastSession: SleepSession? { previousSessions.first }

    private var trend: ComparisonTrend {
        guard let last = lastSession else { return .same }
        let diff = Double(last.sleepScore) - averageScore
        if diff > 5 { return .better }
        if diff < -5 { return .worse }
        return .same
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Sleep Trend", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)

                HStack(spacing: 0) {
                    // Last night
                    if let last = lastSession {
                        StatBlock(
                            value: "\(last.sleepScore)",
                            label: "Last Night",
                            color: scoreColor(last.sleepScore)
                        )
                    }

                    Divider().frame(height: 40)

                    // 7-night average
                    StatBlock(
                        value: "\(Int(averageScore.rounded()))",
                        label: "\(previousSessions.count)-Night Avg",
                        color: .secondary
                    )

                    Divider().frame(height: 40)

                    // Trend
                    TrendBadge(trend: trend)
                        .frame(maxWidth: .infinity)
                }

                // Mini sparkline
                if previousSessions.count > 1 {
                    ScoreSparkline(sessions: previousSessions)
                        .frame(height: 32)
                }
            }
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...: return .green
        case 60..<80: return .yellow
        default: return .red
        }
    }
}

// MARK: - StatBlock

private struct StatBlock: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - TrendBadge

private enum ComparisonTrend { case better, worse, same }

private struct TrendBadge: View {
    let trend: ComparisonTrend

    private var icon: String {
        switch trend {
        case .better: return "arrow.up.circle.fill"
        case .worse: return "arrow.down.circle.fill"
        case .same: return "equal.circle.fill"
        }
    }
    private var color: Color {
        switch trend {
        case .better: return .green
        case .worse: return .red
        case .same: return .secondary
        }
    }
    private var label: String {
        switch trend {
        case .better: return "Better"
        case .worse: return "Worse"
        case .same: return "Similar"
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - ScoreSparkline

private struct ScoreSparkline: View {
    let sessions: [SleepSession]

    var body: some View {
        GeometryReader { geo in
            let scores = sessions.reversed().map { Double($0.sleepScore) }
            let maxScore = max(scores.max() ?? 100, 1.0)
            let minScore = min(scores.min() ?? 0, maxScore - 1)
            let range = maxScore - minScore
            let w = geo.size.width
            let h = geo.size.height
            let step = w / max(Double(scores.count - 1), 1)

            Path { path in
                for (i, score) in scores.enumerated() {
                    let x = Double(i) * step
                    let y = h - ((score - minScore) / range * h)
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(
                LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )

            // Dots
            ForEach(Array(scores.enumerated()), id: \.offset) { i, score in
                let x = Double(i) * step
                let y = h - ((score - minScore) / range * h)
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 5, height: 5)
                    .position(x: x, y: y)
            }
        }
    }
}

// MARK: - HeartRateCard

private struct HeartRateCard: View {

    let stats: HeartRateStats?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Heart Rate", systemImage: "heart.fill")
                        .font(.headline)
                        .foregroundStyle(.red)
                    Spacer()
                    if stats?.isFromWatch == true {
                        Label("Apple Watch", systemImage: "applewatch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let stats = stats {
                    HStack(spacing: 0) {
                        HeartStatBlock(value: stats.averageFormatted, label: "Average", color: .red)
                        Divider().frame(height: 40)
                        HeartStatBlock(value: stats.minimumFormatted, label: "Lowest", color: .blue)
                        Divider().frame(height: 40)
                        HeartStatBlock(value: stats.maximumFormatted, label: "Highest", color: .orange)
                    }

                    Text("\(stats.sampleCount) samples recorded during sleep")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "applewatch.slash")
                            .foregroundStyle(.secondary)
                        Text("No heart rate data — pair an Apple Watch to see this during sleep.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - HeartStatBlock

private struct HeartStatBlock: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - QualityButton

private struct QualityButton: View {

    let quality: SleepQuality
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: quality.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .yellow : .secondary)

                Text(quality.label)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.yellow.opacity(0.15) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - BiometricsCard

private struct BiometricsCard: View {
    let heartRate: HeartRateStats?
    let biometrics: BiometricStats?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Biometrics", systemImage: "heart.fill")
                        .font(.headline)
                        .foregroundStyle(.red)
                    Spacer()
                    if heartRate?.isFromWatch == true {
                        Label("Apple Watch", systemImage: "applewatch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let hr = heartRate {
                    // Heart Rate
                    HStack(spacing: 0) {
                        BiometricStatBlock(value: hr.averageFormatted, label: "Avg HR", icon: "heart.fill", color: .red)
                        Divider().frame(height: 40)
                        BiometricStatBlock(value: hr.minimumFormatted, label: "Lowest", icon: "arrow.down", color: .blue)
                        Divider().frame(height: 40)
                        BiometricStatBlock(value: hr.maximumFormatted, label: "Highest", icon: "arrow.up", color: .orange)
                    }
                }

                // Additional biometrics
                if let bio = biometrics {
                    Divider()

                    HStack(spacing: 0) {
                        if let hrv = bio.hrvAverage {
                            BiometricStatBlock(value: "\(Int(hrv)) ms", label: "HRV", icon: "waveform.path.ecg", color: .green)
                        }
                        if let rr = bio.respiratoryRate {
                            if bio.hrvAverage != nil { Divider().frame(height: 40) }
                            BiometricStatBlock(value: String(format: "%.1f", rr), label: "Resp Rate", icon: "lungs.fill", color: .cyan)
                        }
                        if let spo2 = bio.bloodOxygen {
                            if bio.respiratoryRate != nil || bio.hrvAverage != nil { Divider().frame(height: 40) }
                            BiometricStatBlock(value: "\(Int(spo2))%", label: "SpO2", icon: "drop.fill", color: .blue)
                        }
                    }

                    if let temp = bio.wristTemperature {
                        Divider()
                        HStack {
                            Image(systemName: "thermometer.medium")
                                .foregroundStyle(.orange)
                            Text("Wrist Temperature")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.1f\u{00B0}C", temp))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                } else if heartRate == nil {
                    HStack(spacing: 8) {
                        Image(systemName: "applewatch.slash")
                            .foregroundStyle(.secondary)
                        Text("No biometric data — pair an Apple Watch to see metrics during sleep.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct BiometricStatBlock: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - ScoreBreakdownCard

private struct ScoreBreakdownCard: View {
    let session: SleepSession

    private var durationScore: Int {
        let hours = session.durationSeconds / 3600.0
        if hours >= 7 && hours <= 9 { return 35 }
        else if hours >= 6 && hours < 7 { return 25 }
        else if hours > 9 && hours <= 10 { return 28 }
        else if hours >= 5 && hours < 6 { return 15 }
        else { return max(0, Int(10 - abs(hours - 8) * 2)) }
    }

    private var qualityScore: Int {
        Int(Double(session.qualityRating) / 5.0 * 30.0)
    }

    private var movementScore: Int {
        Int(max(0, 20 - session.averageMovement * 40))
    }

    private var snoringScore: Int {
        Int(15 - min(15, Double(session.snoringCount) * 3))
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Score Breakdown")
                    .font(.headline)

                ScoreRow(label: "Duration", score: durationScore, maxScore: 35, color: .cyan, icon: "clock.fill")
                ScoreRow(label: "Quality", score: qualityScore, maxScore: 30, color: .yellow, icon: "star.fill")
                ScoreRow(label: "Restfulness", score: movementScore, maxScore: 20, color: .green, icon: "figure.walk")
                ScoreRow(label: "Breathing", score: snoringScore, maxScore: 15, color: .purple, icon: "lungs.fill")

                Divider()

                HStack {
                    Text("Total Score")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(session.sleepScore)/100")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(session.sleepScore >= 80 ? .green : session.sleepScore >= 60 ? .yellow : .orange)
                }
            }
        }
    }
}

private struct ScoreRow: View {
    let label: String
    let score: Int
    let maxScore: Int
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.caption)
            Spacer()
            ProgressView(value: Double(score), total: Double(maxScore))
                .tint(color)
                .frame(width: 80)
            Text("\(score)/\(maxScore)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - StageTimelineCard

private struct StageTimelineCard: View {
    let stages: [SleepStageEntry]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Sleep Stages")
                    .font(.headline)

                if stages.isEmpty {
                    Text("No stage data available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    SleepStagesChart(stages: stages)
                        .frame(height: 120)

                    // Stage summary
                    let total = stages.reduce(0.0) { $0 + $1.endTime.timeIntervalSince($1.startTime) }
                    HStack(spacing: 12) {
                        ForEach(SleepStageType.allCases) { stageType in
                            let duration = stages.filter { $0.stage == stageType }
                                .reduce(0.0) { $0 + $1.endTime.timeIntervalSince($1.startTime) }
                            if duration > 0 {
                                let _ = duration / max(total, 1)
                                let mins = Int(duration / 60)
                                VStack(spacing: 2) {
                                    Circle().fill(stageType.color).frame(width: 8, height: 8)
                                    Text("\(mins)m")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                    Text(stageType.label)
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
