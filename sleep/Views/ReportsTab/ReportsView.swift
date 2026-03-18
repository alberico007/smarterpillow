//
//  ReportsView.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/17/26.
//

import Charts
import SwiftData
import SwiftUI

// MARK: - ReportsPeriod

enum ReportsPeriod: String, CaseIterable, Identifiable {
    case week = "7 Days"
    case month = "30 Days"
    case threeMonths = "90 Days"
    case year = "1 Year"

    var id: String { rawValue }
    var days: Int {
        switch self {
        case .week: 7
        case .month: 30
        case .threeMonths: 90
        case .year: 365
        }
    }
}

// MARK: - ReportsTab

enum ReportsTab: String, CaseIterable, Identifiable {
    case trends = "Trends"
    case factors = "Factors"
    case recordings = "Recordings"
    case history = "History"

    var id: String { rawValue }
}

// MARK: - ReportsView

struct ReportsView: View {

    @Query(sort: \SleepSession.startTime, order: .reverse)
    private var allSessions: [SleepSession]

    @Query(sort: \SleepFactor.date, order: .reverse)
    private var allFactors: [SleepFactor]

    @Environment(SleepSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTab: ReportsTab = .trends
    @State private var selectedPeriod: ReportsPeriod = .week
    @State private var selectedEventFilter: AudioEventType? = nil
    @State private var storeKitService = StoreKitService()
    @State private var showingPDFExport = false
    @State private var showingCSVExport = false

    private var filteredSessions: [SleepSession] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedPeriod.days, to: .now) ?? .now
        return allSessions.filter { $0.startTime >= cutoff }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                Picker("Section", selection: $selectedTab) {
                    ForEach(ReportsTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                // Period selector (for trends/factors)
                if selectedTab == .trends || selectedTab == .factors {
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(ReportsPeriod.allCases) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 6)
                }

                // Content
                if (selectedTab == .trends || selectedTab == .factors) &&
                    (selectedPeriod == .threeMonths || selectedPeriod == .year) &&
                    !storeKitService.isPremium {
                    PremiumLockOverlay(feature: "90-day and 1-year trends require Premium. Upgrade to see long-term patterns.")
                        .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            switch selectedTab {
                            case .trends:
                                trendsContent
                            case .factors:
                                factorContent
                            case .recordings:
                                recordingsContent
                            case .history:
                                historyContent
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Reports")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingPDFExport = true
                        } label: {
                            Label("Export PDF", systemImage: "doc.richtext")
                        }
                        Button {
                            showingCSVExport = true
                        } label: {
                            Label("Export CSV", systemImage: "tablecells")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showingPDFExport) {
                PDFExportView(sessions: allSessions)
            }
            .sheet(isPresented: $showingCSVExport) {
                CSVExportView(sessions: allSessions)
            }
        }
    }

    // MARK: - Trends

    @ViewBuilder
    private var trendsContent: some View {
        if filteredSessions.isEmpty {
            ContentUnavailableView("No Data", systemImage: "chart.line.uptrend.xyaxis", description: Text("Track sleep to see trends."))
        } else {
            // Average score
            if settings.showSleepScore {
                let avgScore = filteredSessions.map(\.sleepScore).reduce(0, +) / filteredSessions.count
                GlassCard {
                    VStack(spacing: 8) {
                        Text("Average Sleep Score")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(avgScore)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(avgScore >= 80 ? .green : avgScore >= 60 ? .yellow : .orange)
                        Text("out of 100")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Summary stats
            let avgDuration = filteredSessions.map(\.durationSeconds).reduce(0, +) / Double(filteredSessions.count)
            let avgQuality = filteredSessions.map { Double($0.qualityRating) }.reduce(0, +) / Double(filteredSessions.count)
            let avgEfficiency = filteredSessions.map(\.sleepEfficiency).reduce(0, +) / Double(filteredSessions.count)

            GlassCard {
                VStack(spacing: 12) {
                    StatRow(icon: "clock", label: "Avg Duration", value: FormatHelpers.duration(avgDuration))
                    Divider()
                    StatRow(icon: "star.fill", label: "Avg Quality", value: String(format: "%.1f/5", avgQuality))
                    Divider()
                    StatRow(icon: "percent", label: "Avg Efficiency", value: FormatHelpers.percentage(avgEfficiency))
                    Divider()
                    StatRow(icon: "bed.double.fill", label: "Nights Tracked", value: "\(filteredSessions.count)")
                }
            }

            // Score trend
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sleep Score Trend")
                        .font(.headline)
                    Chart(filteredSessions.reversed()) { session in
                        LineMark(
                            x: .value("Date", session.startTime, unit: .day),
                            y: .value("Score", session.sleepScore)
                        )
                        .foregroundStyle(.cyan)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Date", session.startTime, unit: .day),
                            y: .value("Score", session.sleepScore)
                        )
                        .foregroundStyle(.cyan)
                        .symbolSize(30)
                    }
                    .chartYScale(domain: 0...100)
                    .frame(height: 180)
                }
            }

            // Duration trend
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Duration Trend")
                        .font(.headline)
                    DurationTrendChart(sessions: filteredSessions.reversed())
                        .frame(height: 180)
                }
            }

            // Bedtime consistency
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Bedtime Consistency")
                        .font(.headline)
                    Chart(filteredSessions.reversed()) { session in
                        let hour = Calendar.current.component(.hour, from: session.startTime)
                        let minute = Calendar.current.component(.minute, from: session.startTime)
                        let timeValue = Double(hour) + Double(minute) / 60.0
                        PointMark(
                            x: .value("Date", session.startTime, unit: .day),
                            y: .value("Bedtime", timeValue)
                        )
                        .foregroundStyle(.indigo)
                        .symbolSize(40)
                    }
                    .frame(height: 150)
                }
            }
        }
    }

    // MARK: - Factors

    @ViewBuilder
    private var factorContent: some View {
        let correlations = FactorService.analyzeCorrelations(factors: allFactors, sessions: Array(filteredSessions))

        if correlations.isEmpty {
            ContentUnavailableView("Not Enough Data", systemImage: "chart.bar.fill", description: Text("Log factors before sleep to see correlations. Minimum 3 nights with and without each factor."))
        } else {
            ForEach(correlations) { corr in
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: corr.factorType.icon)
                                .foregroundStyle(corr.factorType.color)
                            Text(corr.factorType.label)
                                .font(.headline)
                            Spacer()
                            Image(systemName: corr.isPositive ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .foregroundStyle(corr.isPositive ? .green : .red)
                        }

                        Text(corr.insight)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 0) {
                            VStack {
                                Text("\(Int(corr.withFactor.rounded()))")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                Text("With")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("\(corr.nightsWithFactor) nights")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity)

                            Text("vs")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            VStack {
                                Text("\(Int(corr.withoutFactor.rounded()))")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                Text("Without")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("\(corr.nightsWithoutFactor) nights")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Recordings

    @ViewBuilder
    private var recordingsContent: some View {
        let sessionsWithSnoring = allSessions.filter { $0.snoringCount > 0 }
        if sessionsWithSnoring.isEmpty {
            ContentUnavailableView("No Recordings", systemImage: "waveform", description: Text("Audio events will appear here after sleep tracking."))
        } else {
            // Filter bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(label: "All", isSelected: selectedEventFilter == nil) {
                        selectedEventFilter = nil
                    }
                    ForEach(AudioEventType.allCases) { eventType in
                        FilterChip(
                            label: eventType.rawValue,
                            icon: eventType.icon,
                            color: eventType.color,
                            isSelected: selectedEventFilter == eventType
                        ) {
                            selectedEventFilter = eventType
                        }
                    }
                }
                .padding(.horizontal, 4)
            }

            // Event count summary
            let allEvents = sessionsWithSnoring.flatMap(\.snoringEvents)
            let classifiedEvents = allEvents.map { event in
                (event: event, type: AudioEventType.classify(amplitude: event.averageAmplitude, duration: event.duration))
            }
            let filteredEvents = selectedEventFilter == nil
                ? classifiedEvents
                : classifiedEvents.filter { $0.type == selectedEventFilter }

            GlassCard {
                HStack {
                    Label("\(filteredEvents.count) events", systemImage: "waveform")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    if let filter = selectedEventFilter {
                        Text(filter.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(filter.color.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }

            // Sessions with events
            ForEach(sessionsWithSnoring.prefix(20)) { session in
                let sessionEvents = session.snoringEvents.map { event in
                    (event: event, type: AudioEventType.classify(amplitude: event.averageAmplitude, duration: event.duration))
                }
                let visibleEvents = selectedEventFilter == nil
                    ? sessionEvents
                    : sessionEvents.filter { $0.type == selectedEventFilter }

                if !visibleEvents.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(session.startTime, style: .date)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(visibleEvents.count) events")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            ForEach(visibleEvents.prefix(5), id: \.event.id) { item in
                                AudioPlayerView(event: item.event, eventType: item.type)
                                if item.event.id != visibleEvents.prefix(5).last?.event.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - FilterChip

    private struct FilterChip: View {
        let label: String
        var icon: String? = nil
        var color: Color = .cyan
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 4) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.caption2)
                    }
                    Text(label)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? color.opacity(0.2) : Color.secondary.opacity(0.1))
                .foregroundStyle(isSelected ? color : .secondary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - History

    @ViewBuilder
    private var historyContent: some View {
        if allSessions.isEmpty {
            ContentUnavailableView("No Sleep Data", systemImage: "moon.zzz", description: Text("Start tracking your sleep to see history."))
        } else {
            ForEach(allSessions) { session in
                NavigationLink(destination: SleepDetailView(session: session)) {
                    GlassCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.startTime, style: .date)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(FormatHelpers.duration(session.durationSeconds))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if settings.showSleepScore {
                                Text("\(session.sleepScore)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(session.sleepScore >= 80 ? .green : session.sleepScore >= 60 ? .yellow : .orange)
                            }

                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= session.qualityRating ? "star.fill" : "star")
                                        .font(.system(size: 8))
                                        .foregroundStyle(star <= session.qualityRating ? .yellow : .secondary)
                                }
                            }

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
