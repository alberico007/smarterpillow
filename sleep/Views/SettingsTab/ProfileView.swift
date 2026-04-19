//
//  ProfileView.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/17/26.
//

import AuthenticationServices
import FirebaseAuth
import os
import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(SleepSettings.self) private var settings
    @Environment(AuthenticationService.self) private var authService
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [SleepSession]
    @State private var showingDeleteConfirmation = false
    @State private var showingSignOutConfirmation = false
    @State private var isDeleting = false
    @State private var firebaseUser: FirebaseAuth.User? = Auth.auth().currentUser

    private let genderOptions = ["Not specified", "Male", "Female", "Non-binary", "Prefer not to say"]

    var body: some View {
        @Bindable var settings = settings

        Form {
            // MARK: Profile Info
            Section {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.cyan)

                    VStack(alignment: .leading, spacing: 4) {
                        if !settings.userName.isEmpty {
                            Text(settings.userName)
                                .font(.title3)
                                .fontWeight(.semibold)
                        } else {
                            Text("Set up your profile")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                        }

                        if let user = firebaseUser {
                            let isApple = user.providerData.first?.providerID == "apple.com"
                            Label(isApple ? "Signed in with Apple" : "Signed in with Email",
                                  systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                TextField("Name", text: $settings.userName)

                Stepper("Age: \(settings.userAge)", value: $settings.userAge, in: 13...120)

                Picker("Gender", selection: $settings.userGender) {
                    ForEach(genderOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
            } footer: {
                Text("Used for age-based sleep recommendations and benchmark comparisons.")
            }

            Section("Sleep Goal") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target: \(String(format: "%.1f", settings.sleepGoalHours)) hours")
                        .font(.subheadline)
                    Slider(value: $settings.sleepGoalHours, in: 5...12, step: 0.5)
                        .tint(.green)

                    let recommended = recommendedSleep(age: settings.userAge)
                    Text("Recommended for your age: \(recommended)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: Account (read-only info — sign-out lives at the very
            // bottom of Settings, not here)
            Section("Account") {
                if let user = firebaseUser {
                    HStack {
                        Text(user.providerData.first?.providerID == "apple.com" ? "Apple ID" : "Email")
                        Spacer()
                        Text(user.email ?? "Connected")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            authService.handleAuthorization(result: authorization)
                            if let given = authService.userGivenName, !given.isEmpty,
                               settings.userName.isEmpty {
                                settings.userName = given
                            }
                            if let family = authService.userFamilyName, !family.isEmpty,
                               settings.userLastName.isEmpty {
                                settings.userLastName = family
                            }
                            firebaseUser = Auth.auth().currentUser
                        case .failure(let error):
                            print("Sign in failed: \(error)")
                        }
                    }
                    .frame(height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // MARK: Danger Zone
            Section {
                Button("Delete Account & All Data", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            } footer: {
                Text("This will permanently delete your account and all sleep data. This action cannot be undone.")
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            firebaseUser = Auth.auth().currentUser
        }
        .onDisappear {
            authService.syncSettings(settings)
        }
        .alert("Sign Out?", isPresented: $showingSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                LocalDataCleanup.wipeUserData(modelContext: modelContext, settings: settings)
                authService.signOut()
                firebaseUser = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Signing out will remove your sleep data from this device. It stays backed up in the cloud and will return when you sign back in.")
        }
        .alert("Delete Everything?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteEverything()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account, \(sessions.count) sleep sessions, and all settings. This cannot be undone.")
        }
    }

    private func deleteEverything() {
        AppLogger.auth.info("User requested account & data deletion")

        authService.deleteFirebaseAccount()
        LocalDataCleanup.wipeUserData(modelContext: modelContext, settings: settings)
        authService.signOut()
        firebaseUser = nil

        AppLogger.auth.info("All data deleted and settings reset")
    }

    private func recommendedSleep(age: Int) -> String {
        recommendedSleepLabel(forAge: age)
    }
}
