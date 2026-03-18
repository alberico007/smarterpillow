//
//  TermsOfServiceView.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/17/26.
//

import SwiftUI

struct TermsOfServiceView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Header
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 48))
                                .foregroundStyle(.cyan)
                            Text("Terms of Service")
                                .font(.title)
                                .fontWeight(.bold)
                            Text("Last updated: March 2026")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 8)

                    // Section 1: Acceptance
                    TermsSection(title: "1. Acceptance of Terms") {
                        Text("By downloading, installing, or using Slumberscope (\"the App\"), you agree to be bound by these Terms of Service. If you do not agree to these terms, do not use the App.")
                    }

                    // Section 2: Description
                    TermsSection(title: "2. Description of Service") {
                        Text("Slumberscope is a sleep tracking application that uses your device's sensors (accelerometer and microphone) to monitor sleep patterns, detect snoring, and provide sleep quality insights. The App processes data locally on your device to generate sleep scores, movement analysis, and audio-based snoring detection.")
                    }

                    // Section 3: Medical Disclaimer
                    TermsSection(title: "3. MEDICAL DISCLAIMER") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("IMPORTANT: PLEASE READ CAREFULLY")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.red)

                            Text("Slumberscope is NOT a medical device and is NOT intended to diagnose, treat, cure, or prevent any disease or medical condition.")

                            Text("The sleep data, scores, and insights provided by this App are for informational and entertainment purposes only. They should NOT be used as a substitute for professional medical advice, diagnosis, or treatment.")

                            Text("If you suspect you have a sleep disorder (such as sleep apnea, insomnia, narcolepsy, or restless leg syndrome), you should consult a qualified healthcare professional. Snoring detection features are not a substitute for a clinical sleep study (polysomnography).")

                            Text("Never disregard professional medical advice or delay seeking treatment because of information provided by this App.")
                        }
                    }

                    // Section 4: User Responsibilities
                    TermsSection(title: "4. User Responsibilities") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("As a user, you agree to:")
                            TermsBullet("Use the App only for its intended purpose of personal sleep tracking")
                            TermsBullet("Ensure your device is placed safely during sleep tracking sessions")
                            TermsBullet("Not rely solely on the Smart Alarm feature for critical wake-up needs")
                            TermsBullet("Maintain your device's charge during tracking sessions")
                            TermsBullet("Keep your device's operating system updated for security and compatibility")
                        }
                    }

                    // Section 5: Data and Privacy
                    TermsSection(title: "5. Data and Privacy") {
                        Text("Your use of the App is also governed by our Privacy Policy, which is incorporated into these Terms by reference. All data processing occurs locally on your device. We do not collect, transmit, or store your data on external servers.")
                    }

                    // Section 6: HealthKit
                    TermsSection(title: "6. HealthKit Integration") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("If you enable HealthKit integration:")
                            TermsBullet("Sleep data written to Apple Health is governed by Apple's HealthKit terms")
                            TermsBullet("You are responsible for managing your HealthKit data and permissions")
                            TermsBullet("We are not responsible for how other apps access sleep data written to HealthKit")
                            TermsBullet("HealthKit integration is optional and can be disabled at any time")
                        }
                    }

                    // Section 7: Smart Alarm
                    TermsSection(title: "7. Smart Alarm Disclaimer") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("The Smart Alarm feature attempts to wake you during a light sleep phase:")
                            TermsBullet("This feature is provided as a convenience and should not be relied upon as your sole alarm")
                            TermsBullet("We do not guarantee the alarm will trigger at the optimal time or at all")
                            TermsBullet("Always set a backup alarm for critical wake-up times")
                            TermsBullet("The App is not responsible for any consequences of missed alarms")
                        }
                    }

                    // Section 8: Intellectual Property
                    TermsSection(title: "8. Intellectual Property") {
                        Text("All content, features, and functionality of Slumberscope, including but not limited to the design, code, algorithms, graphics, icons, and user interface, are owned by the developer and are protected by copyright, trademark, and other intellectual property laws. You may not copy, modify, distribute, or reverse-engineer any part of the App.")
                    }

                    // Section 9: Limitation of Liability
                    TermsSection(title: "9. Limitation of Liability") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TO THE MAXIMUM EXTENT PERMITTED BY LAW:")
                                .fontWeight(.semibold)
                            TermsBullet("The App is provided \"AS IS\" and \"AS AVAILABLE\" without warranties of any kind")
                            TermsBullet("We disclaim all warranties, express or implied, including merchantability, fitness for a particular purpose, and non-infringement")
                            TermsBullet("We shall not be liable for any indirect, incidental, special, consequential, or punitive damages")
                            TermsBullet("Our total liability shall not exceed the amount you paid for the App")
                        }
                    }

                    // Section 10: Sensor Accuracy
                    TermsSection(title: "10. Sensor Accuracy") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Regarding sensor data accuracy:")
                            TermsBullet("Sleep tracking accuracy depends on device placement, sensor quality, and environmental factors")
                            TermsBullet("Snoring detection is probabilistic and may produce false positives or false negatives")
                            TermsBullet("Sleep stage estimation is approximate and based on motion and audio patterns, not clinical EEG data")
                            TermsBullet("Sleep scores are calculated using proprietary algorithms and are relative indicators, not clinical measurements")
                        }
                    }

                    // Section 11: Third-Party
                    TermsSection(title: "11. Third-Party Services") {
                        Text("The App does not currently integrate with third-party services beyond Apple's HealthKit. If future updates include third-party integrations, this section will be updated accordingly, and you will be notified.")
                    }

                    // Section 12: Modifications
                    TermsSection(title: "12. Modifications to Terms") {
                        Text("We reserve the right to modify these Terms at any time. Material changes will be communicated through in-app notifications. Your continued use of the App after modifications constitutes acceptance of the updated Terms. If you disagree with any changes, you should discontinue use of the App.")
                    }

                    // Section 13: Termination
                    TermsSection(title: "13. Termination") {
                        Text("You may terminate your use of the App at any time by uninstalling it. All locally stored data will be removed upon uninstallation. We reserve the right to terminate or suspend access to the App for violations of these Terms.")
                    }

                    // Section 14: Governing Law
                    TermsSection(title: "14. Governing Law") {
                        Text("These Terms shall be governed by and construed in accordance with the laws of the United States and the state in which the developer resides, without regard to conflict of law principles. Any disputes arising from these Terms shall be resolved through binding arbitration.")
                    }

                    // Section 15: Apple's Role
                    TermsSection(title: "15. Apple's Role") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("As required by Apple's App Store guidelines:")
                            TermsBullet("Apple is not a party to these Terms of Service")
                            TermsBullet("Apple has no obligation to furnish maintenance or support services for the App")
                            TermsBullet("Apple is not responsible for any claims related to the App")
                            TermsBullet("Apple is a third-party beneficiary of these Terms")
                        }
                    }

                    // Section 16: Contact
                    TermsSection(title: "16. Contact Us") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("For questions about these Terms of Service:")
                            TermsBullet("Email: legal@slumberscope.app")
                            TermsBullet("Website: https://slumberscope.app/terms")
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - TermsSection

private struct TermsSection<Content: View>: View {

    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - TermsBullet

private struct TermsBullet: View {

    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\u{2022}")
                .fontWeight(.bold)
            Text(text)
        }
    }
}
