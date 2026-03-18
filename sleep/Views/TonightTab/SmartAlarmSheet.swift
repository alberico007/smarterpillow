//
//  SmartAlarmSheet.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/17/26.
//

import SwiftUI

struct SmartAlarmSheet: View {

    @Environment(SleepSettings.self) private var settings
    @Environment(SleepTrackingService.self) private var trackingService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                Section {
                    Toggle("Smart Alarm", isOn: $settings.smartAlarmEnabled)
                }

                if settings.smartAlarmEnabled {
                    Section("Wake Time") {
                        DatePicker(
                            "Wake up at",
                            selection: $settings.smartAlarmTime,
                            displayedComponents: .hourAndMinute
                        )
                    }

                    Section("Detection Window") {
                        Picker("Window", selection: $settings.smartAlarmWindowMinutes) {
                            Text("15 minutes").tag(15)
                            Text("30 minutes").tag(30)
                            Text("45 minutes").tag(45)
                            Text("60 minutes").tag(60)
                        }
                        .pickerStyle(.menu)
                    }

                    Section(footer: Text("The smart alarm will monitor your sleep patterns and wake you during a light sleep phase within the detection window before your set wake time.")) {
                        EmptyView()
                    }
                }
            }
            .navigationTitle("Smart Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // Update the smart alarm service configuration
                        trackingService.smartAlarmService.configure(
                            time: settings.smartAlarmTime,
                            windowMinutes: settings.smartAlarmWindowMinutes,
                            enabled: settings.smartAlarmEnabled
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}
