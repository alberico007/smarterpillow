//
//  DevLogSheet.swift
//  sleep
//
//  Hidden diagnostic view accessible from the Get Ready for Bed animation
//  (five taps on the breathing circle). Reads recent unified-log entries
//  via OSLogStore so users curious about what the app is doing can see
//  real logs, not a mocked-up console.
//

import SwiftUI
import OSLog

struct DevLogSheet: View {

    @Environment(\.dismiss) private var dismiss

    @State private var entries: [DevLogEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let subsystem = Bundle.main.bundleIdentifier ?? "sleep"

    /// Only calibration / sensor / microphone processing logs are surfaced
    /// here. The user sees what the app is actually doing during the 15s
    /// baseline, not every notification / auth / UI event.
    private let allowedCategories: Set<String> = ["audio", "motion", "tracking", "sound"]

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && entries.isEmpty {
                    ProgressView("Reading logs…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.orange)
                        Text("Couldn't read logs")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(entries) { entry in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(entry.levelColor)
                                            .frame(width: 6, height: 6)
                                        Text(entry.category)
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(entry.timestamp)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(.tertiary)
                                    }
                                    Text(entry.message)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.primary)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 14)
                                Divider()
                                    .opacity(0.3)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Diagnostic Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await loadLogs() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task { await loadLogs() }
        }
    }

    // MARK: - Load

    private func loadLogs() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let since = store.position(date: Date().addingTimeInterval(-600)) // last 10 minutes
            let allEntries = try store.getEntries(at: since)
            var result: [DevLogEntry] = []
            for entry in allEntries {
                guard let logEntry = entry as? OSLogEntryLog else { continue }
                guard logEntry.subsystem == subsystem else { continue }
                guard allowedCategories.contains(logEntry.category) else { continue }
                result.append(DevLogEntry(from: logEntry))
            }
            // Newest last in OSLogStore — reverse for UI so newest appears at top
            entries = result.reversed()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Entry

private struct DevLogEntry: Identifiable {
    let id = UUID()
    let timestamp: String
    let category: String
    let message: String
    let level: OSLogEntryLog.Level

    init(from entry: OSLogEntryLog) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        self.timestamp = formatter.string(from: entry.date)
        self.category = entry.category
        self.message = entry.composedMessage
        self.level = entry.level
    }

    var levelColor: Color {
        switch level {
        case .error, .fault: return .red
        case .notice: return .orange
        case .info: return .cyan
        case .debug: return .secondary
        default: return .secondary
        }
    }
}
