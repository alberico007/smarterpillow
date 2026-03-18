//
//  PrivacyControlsView.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/17/26.
//

import SwiftData
import SwiftUI

struct PrivacyControlsView: View {

    @Environment(\.modelContext) private var modelContext

    @Query private var sessions: [SleepSession]

    @State private var onDeviceOnly = true
    @State private var showingDeleteSleepData = false
    @State private var showingDeleteAudioRecordings = false
    @State private var showingDeleteCloudData = false

    var body: some View {
        Form {
            // MARK: Audio Storage
            Section {
                Toggle("On-Device Only", isOn: $onDeviceOnly)
                if !onDeviceOnly {
                    Text("Sleep data will be backed up to iCloud.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("All audio processing runs on-device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Audio Storage")
            }

            // MARK: AI Processing
            Section {
                Text("All AI features use on-device Foundation Models. No data is sent to external servers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("AI Processing")
            }

            // MARK: Data Export
            Section {
                Button {
                    // Export PDF
                } label: {
                    Label("Export PDF", systemImage: "doc.richtext")
                }

                Button {
                    // Export CSV
                } label: {
                    Label("Export CSV", systemImage: "tablecells")
                }

                Button {
                    // Export to Apple Health
                } label: {
                    Label("Export to Apple Health", systemImage: "heart.fill")
                }
            } header: {
                Text("Data Export")
            }

            // MARK: Data Management
            Section {
                Button(role: .destructive) {
                    showingDeleteSleepData = true
                } label: {
                    Label("Delete All Sleep Data", systemImage: "trash")
                }

                Button(role: .destructive) {
                    showingDeleteAudioRecordings = true
                } label: {
                    Label("Delete All Audio Recordings", systemImage: "waveform.slash")
                }

                Button(role: .destructive) {
                    showingDeleteCloudData = true
                } label: {
                    Label("Delete Cloud Data", systemImage: "icloud.slash")
                }
            } header: {
                Text("Data Management")
            } footer: {
                Text("\(sessions.count) sleep sessions recorded.")
            }

            // MARK: Privacy Info
            Section {
                HStack {
                    Text("Data collected")
                        .font(.subheadline)
                    Spacer()
                    Text("Sleep patterns, audio events, movement")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Data shared")
                        .font(.subheadline)
                    Spacer()
                    Text("None (on-device only)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Link(destination: URL(string: "https://smarterpillow.com/privacy")!) {
                    Label("Privacy Policy", systemImage: "link")
                }
            } header: {
                Text("Privacy Info")
            }
        }
        .navigationTitle("Privacy & Data")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete All Sleep Data?", isPresented: $showingDeleteSleepData) {
            Button("Delete", role: .destructive) {
                for session in sessions {
                    modelContext.delete(session)
                }
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all \(sessions.count) sleep sessions. This action cannot be undone.")
        }
        .alert("Delete All Audio Recordings?", isPresented: $showingDeleteAudioRecordings) {
            Button("Delete", role: .destructive) {
                // Delete audio recordings from disk
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all stored audio recordings. This action cannot be undone.")
        }
        .alert("Delete Cloud Data?", isPresented: $showingDeleteCloudData) {
            Button("Delete", role: .destructive) {
                // Delete iCloud data
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all sleep data stored in iCloud. Local data will not be affected.")
        }
    }
}
