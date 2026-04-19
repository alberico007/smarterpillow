//
//  OnboardingView.swift
//  sleep
//

import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore
import MusicKit
import os
import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {

    let onComplete: () -> Void

    @State private var currentPage = 0
    @State private var isNewUser = false
    @State private var needsEmailVerification = false
    @State private var isTransitioning = false
    private let totalPages = 8

    private let permissionService = PermissionService.shared

    var body: some View {
        ZStack(alignment: .top) {
            if currentPage > 0 {
                ProgressBar(current: currentPage, total: totalPages)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
                    .zIndex(1)
            }

            Group {
                switch currentPage {
                case 0:
                    SplashPage { advance() }
                case 1:
                    SignInPage { newUser, needsVerify in
                        isNewUser = newUser
                        needsEmailVerification = needsVerify
                        advance()
                    }
                case 2:
                    // Only rendered when needsEmailVerification is true —
                    // advance() now skips past this page when it's false.
                    VerifyEmailPage { advance() }
                case 3:
                    // Only rendered when isNewUser is true — same skip logic.
                    AccountSetupPage { advance() }
                case 4:
                    PermissionsPage(permissionService: permissionService) { advance() }
                case 5:
                    MediaSetupPage { advance() }
                case 6:
                    FeatureShowcasePage { advance() }
                case 7:
                    InteractiveTutorialPage { onComplete() }
                default:
                    EmptyView()
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.easeInOut(duration: 0.35), value: currentPage)
        }
        .interactiveDismissDisabled()
    }

    private func advance() {
        // Spam-tap guard: a page's "Continue" button stays alive until the
        // transition animation completes (~0.35s). Without this, a double-tap
        // fires advance() twice and currentPage jumps two pages.
        guard !isTransitioning else { return }
        isTransitioning = true

        // Compute the next page that should actually render, skipping any
        // that don't apply to this user (e.g. VerifyEmail for Apple sign-in,
        // AccountSetup for returning users). We must do this here rather
        // than relying on `Color.clear.onAppear { advance() }` because the
        // spam-tap guard would block that auto-advance.
        var next = currentPage + 1
        while shouldSkip(page: next) && next < totalPages {
            next += 1
        }
        let target = next
        withAnimation { currentPage = target }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            isTransitioning = false
        }
    }

    private func shouldSkip(page: Int) -> Bool {
        switch page {
        case 2: return !needsEmailVerification  // VerifyEmailPage
        case 3: return !isNewUser               // AccountSetupPage
        default: return false
        }
    }
}

// MARK: - ProgressBar

private struct ProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1..<total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? Color.cyan : Color.secondary.opacity(0.3))
                    .frame(height: 4)
            }
        }
    }
}

// MARK: - SplashPage

private struct SplashPage: View {

    let onContinue: () -> Void

    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var glowRadius: CGFloat = 0
    @State private var titleOffset: CGFloat = 30
    @State private var titleOpacity: Double = 0
    @State private var subtitleOffset: CGFloat = 20
    @State private var subtitleOpacity: Double = 0
    @State private var teamHeaderOpacity: Double = 0
    @State private var visibleMembers: Int = 0
    @State private var universityOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var pulseScale: CGFloat = 1.0

    private let team = [
        (name: "Simon Alberico", role: "Cyber Security", initials: "SA", colors: [Color.cyan, Color.blue]),
        (name: "Aia Ahmed", role: "Software Engineering", initials: "AA", colors: [Color.purple, Color.pink]),
        (name: "Ananjin Batdelger", role: "Computer Science", initials: "AB", colors: [Color.green, Color.teal])
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 40)

                ZStack {
                    Circle()
                        .stroke(.cyan.opacity(0.2), lineWidth: 2)
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulseScale)
                        .opacity(2 - pulseScale)

                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: .cyan.opacity(0.6), radius: glowRadius)
                        .scaleEffect(iconScale)
                        .opacity(iconOpacity)
                }

                Text("Welcome to Slumberscope")
                    .font(.largeTitle).fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .offset(y: titleOffset).opacity(titleOpacity)

                Text("Track your sleep patterns, detect snoring, and wake up refreshed with intelligent insights.")
                    .font(.body).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .offset(y: subtitleOffset).opacity(subtitleOpacity)

                VStack(spacing: 12) {
                    Text("Meet the Team")
                        .font(.title3).fontWeight(.semibold)
                        .opacity(teamHeaderOpacity)

                    ForEach(Array(team.enumerated()), id: \.offset) { index, member in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: member.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 44, height: 44)
                                Text(member.initials)
                                    .font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.name).font(.subheadline).fontWeight(.semibold)
                                Text(member.role).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .opacity(visibleMembers > index ? 1 : 0)
                        .offset(y: visibleMembers > index ? 0 : 16)
                        .animation(.spring(response: 0.45, dampingFraction: 0.75).delay(Double(index) * 0.15), value: visibleMembers)
                    }
                }
                .padding(.horizontal, 32)

                VStack(spacing: 4) {
                    Text("Gannon University").font(.headline).fontWeight(.semibold)
                    Text("Senior Design \u{2022} Spring 2026").font(.subheadline).foregroundStyle(.secondary)
                }
                .opacity(universityOpacity).padding(.top, 8)

                PrimaryButton(title: "Get Started") { onContinue() }
                    .padding(.horizontal, 32)
                    .opacity(buttonOpacity)
                    .padding(.bottom, 40)
            }
        }
        .scrollIndicators(.hidden)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.1)) {
                iconScale = 1.0; iconOpacity = 1.0
            }
            withAnimation(.easeIn(duration: 0.8).delay(0.4)) { glowRadius = 20 }
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) { titleOffset = 0; titleOpacity = 1 }
            withAnimation(.easeOut(duration: 0.5).delay(0.7)) { subtitleOffset = 0; subtitleOpacity = 1 }
            withAnimation(.easeOut(duration: 0.4).delay(1.2)) { teamHeaderOpacity = 1 }
            withAnimation(.easeOut(duration: 0.1).delay(1.4)) { visibleMembers = team.count }
            withAnimation(.easeOut(duration: 0.5).delay(2.2)) { universityOpacity = 1 }
            withAnimation(.easeIn(duration: 0.4).delay(2.6)) { buttonOpacity = 1 }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false).delay(0.8)) {
                pulseScale = 1.8
            }
        }
    }
}

// MARK: - AccountSetupPage

private struct AccountSetupPage: View {

    let onContinue: () -> Void

    @Environment(SleepSettings.self) private var settings
    @Environment(AuthenticationService.self) private var authService
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var age: Int = 22
    @State private var goalHours: Double = 8.0
    @State private var titleOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case first, last }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 50)

                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 64))
                    .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                    .opacity(titleOpacity)

                Text("Create Your Profile")
                    .font(.title).fontWeight(.bold).opacity(titleOpacity)

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("First Name").font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)
                        TextField("First name", text: $firstName)
                            .textContentType(.givenName)
                            .textInputAutocapitalization(.words)
                            .focused($focusedField, equals: .first)
                            .padding(12).background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .submitLabel(.next)
                            .onSubmit { focusedField = .last }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last Name").font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)
                        TextField("Last name", text: $lastName)
                            .textContentType(.familyName)
                            .textInputAutocapitalization(.words)
                            .focused($focusedField, equals: .last)
                            .padding(12).background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .submitLabel(.done)
                            .onSubmit { focusedField = nil }
                    }
                }
                .padding(.horizontal, 32)
                .opacity(contentOpacity)

                VStack(spacing: 8) {
                    Text("Age").font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)
                    HStack(spacing: 24) {
                        Button { if age > 13 { age -= 1; updateGoalForAge() } } label: {
                            Image(systemName: "minus.circle.fill").font(.title).foregroundStyle(.secondary)
                        }
                        Text("\(age)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.cyan).frame(minWidth: 80)
                        Button { if age < 100 { age += 1; updateGoalForAge() } } label: {
                            Image(systemName: "plus.circle.fill").font(.title).foregroundStyle(.secondary)
                        }
                    }
                    Text("Recommended: \(recommendedSleepLabel(forAge: age))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .opacity(contentOpacity)

                VStack(spacing: 8) {
                    Text("Your Sleep Goal").font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)
                    Text("\(String(format: "%.1f", goalHours)) hours")
                        .font(.system(size: 36, weight: .bold, design: .rounded)).foregroundStyle(.green)
                    Slider(value: $goalHours, in: 5...12, step: 0.5).tint(.green).padding(.horizontal, 40)
                    Text("Adjust if you'd like a different target").font(.caption).foregroundStyle(.tertiary)
                }
                .opacity(contentOpacity)

                PrimaryButton(title: "Continue") {
                    saveProfile()
                    onContinue()
                }
                .padding(.horizontal, 32)
                .opacity(contentOpacity)
                .disabled(firstName.trimmingCharacters(in: .whitespaces).isEmpty || lastName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(firstName.trimmingCharacters(in: .whitespaces).isEmpty || lastName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)

                if firstName.trimmingCharacters(in: .whitespaces).isEmpty || lastName.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("Please enter your first and last name to continue")
                        .font(.caption).foregroundStyle(.red.opacity(0.8)).padding(.horizontal, 32)
                }

                Spacer(minLength: 40)
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            firstName = settings.userName
            lastName = settings.userLastName
            age = settings.userAge > 0 ? settings.userAge : 22
            goalHours = recommendedSleepHours(forAge: age)
            withAnimation(.easeOut(duration: 0.4)) { titleOpacity = 1 }
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) { contentOpacity = 1 }
        }
    }

    private func updateGoalForAge() { goalHours = recommendedSleepHours(forAge: age) }

    private func saveProfile() {
        settings.userName = firstName
        settings.userLastName = lastName
        settings.userAge = age
        settings.sleepGoalHours = goalHours
        authService.syncSettings(settings)
    }
}

// MARK: - ForcedPasswordUpdateView

private struct ForcedPasswordUpdateView: View {

    let onCompleted: () -> Void
    let onCancelled: () -> Void

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isUpdating = false
    @State private var errorMessage: String? = nil
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case newPass, confirm }

    private var requirementsMet: Bool {
        PasswordRequirementsView.evaluate(newPassword).allSatisfy { $0.met }
    }

    private var passwordsMatch: Bool {
        !newPassword.isEmpty && newPassword == confirmPassword
    }

    private var canSubmit: Bool { requirementsMet && passwordsMatch && !isUpdating }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 20)

                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.orange)

                    Text("Update Your Password")
                        .font(.title2).fontWeight(.bold)

                    Text("Your current password doesn't meet our security requirements. Please set a new one to continue.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("New Password")
                                .font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)
                            SecureField("New password", text: $newPassword)
                                .textContentType(.newPassword)
                                .focused($focusedField, equals: .newPass)
                                .padding(12).background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .submitLabel(.next)
                                .onSubmit { focusedField = .confirm }

                            PasswordRequirementsView(password: newPassword)
                                .padding(.top, 2)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirm Password")
                                .font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)
                            SecureField("Re-enter new password", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .focused($focusedField, equals: .confirm)
                                .padding(12).background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .submitLabel(.done)
                                .onSubmit { focusedField = nil; Task { await updatePassword() } }

                            if !confirmPassword.isEmpty && !passwordsMatch {
                                Text("Passwords don't match")
                                    .font(.caption).foregroundStyle(.red)
                            }
                        }
                    }
                    .padding(.horizontal, 32)

                    if let error = errorMessage {
                        Text(error).font(.caption).foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    if isUpdating {
                        ProgressView().padding(.vertical, 8)
                    } else {
                        PrimaryButton(title: "Update Password") {
                            Task { await updatePassword() }
                        }
                        .disabled(!canSubmit)
                        .opacity(canSubmit ? 1.0 : 0.5)
                        .padding(.horizontal, 32)
                    }

                    Button("Sign Out", role: .destructive) {
                        onCancelled()
                    }
                    .font(.subheadline)
                    .padding(.top, 4)

                    Text("Need help? Contact \(SignInPage.supportEmail)")
                        .font(.caption2).foregroundStyle(.secondary)
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                }
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .navigationBarBackButtonHidden(true)
            .interactiveDismissDisabled()
        }
    }

    @MainActor
    private func updatePassword() async {
        guard canSubmit else { return }
        guard let user = Auth.auth().currentUser else {
            errorMessage = "Not signed in. Please sign in again."
            return
        }
        isUpdating = true
        errorMessage = nil
        defer { isUpdating = false }

        do {
            try await user.updatePassword(to: newPassword)
            AppLogger.auth.info("🔐 Password updated for \(user.uid)")
            onCompleted()
        } catch {
            let code = (error as NSError).code
            if code == 17014 {
                // requiresRecentLogin — shouldn't happen since they just
                // signed in seconds ago, but cover the case.
                errorMessage = "Please sign out and sign in again, then try once more."
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - VerifyEmailPage

private struct VerifyEmailPage: View {

    let onContinue: () -> Void

    @State private var isChecking = false
    @State private var isResending = false
    @State private var errorMessage: String? = nil
    @State private var resentMessage: String? = nil

    private var email: String {
        Auth.auth().currentUser?.email ?? "your inbox"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 60)

                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.cyan)

                Text("Verify your email")
                    .font(.title).fontWeight(.bold)

                VStack(spacing: 8) {
                    Text("We sent a verification link to")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(email)
                        .font(.subheadline).fontWeight(.semibold)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

                Text("Open the email on this device and tap the link. Then come back here and tap Continue.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                if let error = errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                if let resent = resentMessage {
                    Text(resent).font(.caption).foregroundStyle(.green)
                        .padding(.horizontal, 32)
                }

                VStack(spacing: 12) {
                    if isChecking {
                        ProgressView().padding(.vertical, 8)
                    } else {
                        PrimaryButton(title: "I've verified — Continue") {
                            Task { await checkVerification() }
                        }
                        .padding(.horizontal, 32)
                    }

                    Button {
                        Task { await resendVerification() }
                    } label: {
                        if isResending {
                            ProgressView()
                        } else {
                            Text("Resend email")
                                .font(.subheadline).foregroundStyle(.cyan)
                        }
                    }
                    .disabled(isResending)
                }

                Spacer(minLength: 20)

                Text("Need help? Contact \(SignInPage.supportEmail)")
                    .font(.caption2).foregroundStyle(.secondary)
                    .padding(.bottom, 24)
            }
        }
        .scrollIndicators(.hidden)
    }

    @MainActor
    private func checkVerification() async {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "You're not signed in. Please sign in again."
            return
        }
        isChecking = true
        errorMessage = nil
        resentMessage = nil
        defer { isChecking = false }

        do {
            try await user.reload()
            if user.isEmailVerified {
                AppLogger.auth.info("🔐 Email verified for \(user.uid)")
                onContinue()
            } else {
                errorMessage = "We haven't seen the verification yet. Tap the link in the email, then try again."
            }
        } catch {
            errorMessage = "Couldn't check verification: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func resendVerification() async {
        guard let user = Auth.auth().currentUser else { return }
        isResending = true
        errorMessage = nil
        resentMessage = nil
        defer { isResending = false }

        do {
            try await user.sendEmailVerification()
            resentMessage = "Sent! Check your inbox."
        } catch {
            errorMessage = "Couldn't resend: \(error.localizedDescription)"
        }
    }
}

// MARK: - SignInPage

private struct SignInPage: View {

    /// `isNewUser` drives whether AccountSetupPage is shown next.
    /// `needsEmailVerification` drives whether VerifyEmailPage is shown next.
    let onContinue: (_ isNewUser: Bool, _ needsEmailVerification: Bool) -> Void

    @Environment(AuthenticationService.self) private var authService
    @Environment(SleepSettings.self) private var settings
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var didSignIn = false
    @State private var showEmailForm = false
    @State private var titleOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var failedAttempts = 0
    @State private var lockoutUntil: Date? = nil
    @State private var showingNoAccountAlert = false
    @State private var showingForgotPasswordPrompt = false
    @State private var showingForgotPasswordSent = false
    @State private var showingForcedPasswordUpdate = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case email, password }

    static let supportEmail = "alberico007@gannon.edu"
    static let maxFailedAttempts = 10
    static let softPromptAtFailedAttempts = 3
    static let lockoutDuration: TimeInterval = 2 * 60 * 60

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 50)

                Image(systemName: "person.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.cyan)
                    .opacity(titleOpacity)

                Text("Your Account")
                    .font(.title).fontWeight(.bold)
                    .opacity(titleOpacity)

                Text("Sign in to securely save your sleep data.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(contentOpacity)

                if didSignIn {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48)).foregroundStyle(.green)
                        Text("Signed in successfully!")
                            .font(.headline)
                    }
                    .transition(.scale.combined(with: .opacity))

                } else {
                    VStack(spacing: 16) {

                        // MARK: Sign in with Apple
                        SignInWithAppleButton(.signIn) { request in
                            AppLogger.auth.info("🔐 Sign In with Apple request initiated")
                            request.requestedScopes = [.fullName, .email]
                            let hashedNonce = authService.prepareNonce()
                            request.nonce = hashedNonce
                        } onCompletion: { result in
                            switch result {
                            case .success(let auth):
                                AppLogger.auth.info("🔐 Sign In with Apple succeeded")
                                authService.lastSignInIsNewUser = nil
                                authService.handleAuthorization(result: auth)
                                withAnimation { didSignIn = true }
                                Task { @MainActor in
                                    // Wait up to 5s for the Firebase exchange to finish
                                    // so we can read the real isNewUser flag.
                                    var waited = 0
                                    while authService.lastSignInIsNewUser == nil && waited < 25 {
                                        try? await Task.sleep(for: .milliseconds(200))
                                        waited += 1
                                    }
                                    let isNew = authService.lastSignInIsNewUser ?? false
                                    // Mirror Apple-provided name into SleepSettings so the
                                    // Profile field is auto-populated. Apple only returns
                                    // fullName on the very first sign-in for this app.
                                    if let given = authService.userGivenName, !given.isEmpty,
                                       settings.userName.isEmpty {
                                        settings.userName = given
                                    }
                                    if let family = authService.userFamilyName, !family.isEmpty,
                                       settings.userLastName.isEmpty {
                                        settings.userLastName = family
                                    }
                                    // Apple pre-verifies email → never needs verification.
                                    onContinue(isNew, false)
                                }
                            case .failure(let error):
                                AppLogger.auth.error("🔐 Apple sign-in failed: \(error.localizedDescription)")
                            }
                        }
                        .signInWithAppleButtonStyle(.whiteOutline)
                        .frame(height: 50)

                        // Divider
                        HStack {
                            Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
                            Text("or").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 8)
                            Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
                        }

                        // MARK: Email option
                        if showEmailForm {
                            VStack(spacing: 14) {

                                // Email field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Email").font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)
                                    TextField("your@email.com", text: $email)
                                        .textContentType(.emailAddress)
                                        .keyboardType(.emailAddress)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .focused($focusedField, equals: .email)
                                        .padding(12).background(.regularMaterial)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .submitLabel(.next)
                                        .onSubmit { focusedField = .password }
                                }

                                // Password field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Password").font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)
                                    SecureField("Password", text: $password)
                                        .textContentType(isSignUp ? .newPassword : .password)
                                        .focused($focusedField, equals: .password)
                                        .padding(12).background(.regularMaterial)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .submitLabel(.done)
                                        .onSubmit { focusedField = nil; handleAuth() }

                                    if isSignUp {
                                        PasswordRequirementsView(password: password)
                                            .padding(.top, 2)
                                    } else {
                                        HStack {
                                            Spacer()
                                            Button("Forgot password?") {
                                                Task { await sendPasswordReset() }
                                            }
                                            .font(.caption)
                                            .foregroundStyle(.cyan)
                                            .disabled(normalizedEmail.isEmpty)
                                        }
                                    }
                                }

                                // Error message
                                if let error = errorMessage {
                                    Text(error).font(.caption).foregroundStyle(.red)
                                        .multilineTextAlignment(.center)
                                }

                                // Submit button
                                if isLoading {
                                    ProgressView().padding()
                                } else {
                                    PrimaryButton(title: isSignUp ? "Create Account" : "Sign In") {
                                        handleAuth()
                                    }
                                    .disabled(!canSubmit)
                                    .opacity(canSubmit ? 1.0 : 0.5)
                                }

                                // Toggle sign in / sign up
                                Button {
                                    withAnimation { isSignUp.toggle(); errorMessage = nil }
                                } label: {
                                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Create one")
                                        .font(.subheadline).foregroundStyle(.cyan)
                                }
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))

                        } else {
                            // Show email button
                            Button {
                                withAnimation { showEmailForm = true }
                            } label: {
                                HStack {
                                    Image(systemName: "envelope.fill")
                                    Text("Continue with Email").font(.headline)
                                }
                                .frame(maxWidth: .infinity).padding()
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 40)
                    .opacity(contentOpacity)
                }

                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill").foregroundStyle(.green)
                    Text("Your data is encrypted and private.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .opacity(contentOpacity)

                Spacer()

                Text("Need help? Contact \(Self.supportEmail)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 30)
                    .opacity(contentOpacity)
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { titleOpacity = 1 }
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) { contentOpacity = 1 }
            loadFailedState()
        }
        .onChange(of: email) { _, _ in loadFailedState() }
        .alert("No Account Found", isPresented: $showingNoAccountAlert) {
            Button("Create Account") {
                withAnimation {
                    isSignUp = true
                    errorMessage = nil
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("No account exists for \(email). Would you like to create one?")
        }
        .alert("Forgot Password?", isPresented: $showingForgotPasswordPrompt) {
            Button("Send Reset Email") {
                Task { await sendPasswordReset() }
            }
            Button("Keep Trying", role: .cancel) { }
        } message: {
            let remaining = Self.maxFailedAttempts - failedAttempts
            Text("That's \(failedAttempts) failed attempts. Would you like to reset your password? You have \(remaining) attempt\(remaining == 1 ? "" : "s") left before your account is locked for 2 hours.")
        }
        .alert("Password Reset Sent", isPresented: $showingForgotPasswordSent) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Check \(email) for reset instructions. If you don't see it, check your spam folder or contact \(Self.supportEmail).")
        }
        .fullScreenCover(isPresented: $showingForcedPasswordUpdate) {
            ForcedPasswordUpdateView(
                onCompleted: {
                    showingForcedPasswordUpdate = false
                    withAnimation { didSignIn = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        onContinue(false, false)
                    }
                },
                onCancelled: {
                    showingForcedPasswordUpdate = false
                    authService.signOut()
                    password = ""
                }
            )
        }
    }

    private var passwordMeetsRequirements: Bool {
        PasswordRequirementsView.evaluate(password).allSatisfy { $0.met }
    }

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var canSubmit: Bool {
        !normalizedEmail.isEmpty && !password.isEmpty && (!isSignUp || passwordMeetsRequirements)
    }

    private var isLockedOut: Bool {
        guard let until = lockoutUntil else { return false }
        return until > Date()
    }

    private func failedAttemptsKey(for email: String) -> String { "authFailedAttempts_\(email)" }
    private func lockoutKey(for email: String) -> String { "authLockoutUntil_\(email)" }

    private func loadFailedState() {
        guard !normalizedEmail.isEmpty else {
            failedAttempts = 0
            lockoutUntil = nil
            return
        }
        failedAttempts = UserDefaults.standard.integer(forKey: failedAttemptsKey(for: normalizedEmail))
        let ts = UserDefaults.standard.double(forKey: lockoutKey(for: normalizedEmail))
        if ts > 0 {
            let date = Date(timeIntervalSince1970: ts)
            lockoutUntil = date > Date() ? date : nil
            if date <= Date() {
                UserDefaults.standard.removeObject(forKey: lockoutKey(for: normalizedEmail))
                UserDefaults.standard.removeObject(forKey: failedAttemptsKey(for: normalizedEmail))
                failedAttempts = 0
            }
        } else {
            lockoutUntil = nil
        }
    }

    private func recordFailedAttempt() {
        failedAttempts += 1
        UserDefaults.standard.set(failedAttempts, forKey: failedAttemptsKey(for: normalizedEmail))
        if failedAttempts >= Self.maxFailedAttempts {
            let until = Date().addingTimeInterval(Self.lockoutDuration)
            lockoutUntil = until
            UserDefaults.standard.set(until.timeIntervalSince1970, forKey: lockoutKey(for: normalizedEmail))
            AppLogger.auth.warning("🔐 Account locked after \(failedAttempts) failed attempts")
        }
    }

    private func resetFailedAttempts() {
        failedAttempts = 0
        lockoutUntil = nil
        UserDefaults.standard.removeObject(forKey: failedAttemptsKey(for: normalizedEmail))
        UserDefaults.standard.removeObject(forKey: lockoutKey(for: normalizedEmail))
    }

    private func lockoutMessage(until: Date) -> String {
        let minutes = max(1, Int(until.timeIntervalSinceNow / 60))
        let hours = minutes / 60
        let remainder = minutes % 60
        let remaining = hours > 0 ? "\(hours)h \(remainder)m" : "\(remainder)m"
        return "Too many failed attempts. Try again in \(remaining). For help, contact \(Self.supportEmail)."
    }

    private func handleAuth() {
        guard canSubmit else { return }
        loadFailedState()
        if let until = lockoutUntil, isLockedOut {
            errorMessage = lockoutMessage(until: until)
            return
        }
        isLoading = true
        errorMessage = nil
        focusedField = nil

        Task {
            do {
                let isNewUser: Bool
                let needsVerification: Bool

                if isSignUp {
                    let result = try await Auth.auth().createUser(withEmail: normalizedEmail, password: password)
                    let uid = result.user.uid
                    let db = Firestore.firestore()
                    try await db.collection("users").document(uid).setData([
                        "email": normalizedEmail,
                        "createdAt": FieldValue.serverTimestamp(),
                        "lastSynced": FieldValue.serverTimestamp(),
                        "platform": "ios"
                    ], merge: true)
                    AppLogger.auth.info("🔐 New account created — uid: \(uid)")

                    // Send the Firebase verification link to the user's inbox.
                    try? await result.user.sendEmailVerification()
                    AppLogger.auth.info("🔐 Verification email sent to \(normalizedEmail)")

                    isNewUser = true
                    needsVerification = true
                } else {
                    let result = try await Auth.auth().signIn(withEmail: normalizedEmail, password: password)
                    AppLogger.auth.info("🔐 Signed in — uid: \(result.user.uid)")
                    resetFailedAttempts()
                    isNewUser = false
                    needsVerification = false

                    // Grandfathered weak password? Force an update before
                    // letting them into the app.
                    if !passwordMeetsRequirements {
                        await MainActor.run {
                            isLoading = false
                            showingForcedPasswordUpdate = true
                        }
                        return
                    }
                }

                await MainActor.run {
                    isLoading = false
                    withAnimation { didSignIn = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        onContinue(isNewUser, needsVerification)
                    }
                }
            } catch {
                if isSignUp {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = friendlyError(error)
                    }
                } else {
                    await handleSignInFailure(error: error)
                }
            }
        }
    }

    @MainActor
    private func handleSignInFailure(error: Error) async {
        isLoading = false
        let code = (error as NSError).code

        switch code {
        case 17008:
            // Malformed email — don't touch attempts.
            errorMessage = friendlyError(error)

        case 17011:
            // Firebase confirmed no account exists (Email Enumeration
            // Protection off) — offer to create.
            showingNoAccountAlert = true

        case 17009, 17004:
            // 17009 = wrongPassword (enumeration off)
            // 17004 = invalidCredential (enumeration on — could be wrong
            // password OR missing account, Firebase hides which).
            // Treat as a credentials failure; the "Don't have an account?
            // Create one" toggle below the submit button covers the other case.
            recordFailedAttempt()
            if let until = lockoutUntil, isLockedOut {
                errorMessage = lockoutMessage(until: until)
            } else if failedAttempts >= Self.softPromptAtFailedAttempts {
                errorMessage = "Incorrect email or password (\(failedAttempts)/\(Self.maxFailedAttempts) attempts used)."
                showingForgotPasswordPrompt = true
            } else {
                errorMessage = "Incorrect email or password. If you don't have an account, tap \"Create one\" below."
            }

        default:
            errorMessage = friendlyError(error)
        }
    }

    @MainActor
    private func sendPasswordReset() async {
        guard !normalizedEmail.isEmpty else {
            errorMessage = "Enter your email above first."
            return
        }
        do {
            try await Auth.auth().sendPasswordReset(withEmail: normalizedEmail)
            AppLogger.auth.info("🔐 Password reset email sent")
            showingForgotPasswordSent = true
        } catch {
            let code = (error as NSError).code
            if code == 17011 {
                showingNoAccountAlert = true
            } else {
                errorMessage = friendlyError(error)
            }
        }
    }

    private func friendlyError(_ error: Error) -> String {
        let code = (error as NSError).code
        switch code {
        case 17007: return "An account with this email already exists."
        case 17009: return "Incorrect password. Please try again."
        case 17011: return "No account found with this email."
        case 17026: return "Password does not meet the requirements."
        case 17008: return "Please enter a valid email address."
        default: return "\(error.localizedDescription) If this persists, contact \(Self.supportEmail)."
        }
    }
}

// MARK: - PasswordRequirementsView

private struct PasswordRequirementsView: View {

    let password: String

    struct Requirement: Identifiable {
        let id = UUID()
        let text: String
        let met: Bool
    }

    static func evaluate(_ password: String) -> [Requirement] {
        let specials = "!@#$%^&*()-_=+[]{};:,.<>?/\\|`~\"'"
        return [
            Requirement(text: "At least 8 characters", met: password.count >= 8),
            Requirement(text: "One uppercase letter", met: password.contains(where: { $0.isUppercase })),
            Requirement(text: "One lowercase letter", met: password.contains(where: { $0.isLowercase })),
            Requirement(text: "One number", met: password.contains(where: { $0.isNumber })),
            Requirement(text: "One special character (!@#$…)", met: password.contains(where: { specials.contains($0) }))
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Self.evaluate(password)) { req in
                HStack(spacing: 6) {
                    Image(systemName: req.met ? "checkmark.circle.fill" : "circle")
                        .font(.caption)
                        .foregroundStyle(req.met ? .green : .secondary)
                    Text(req.text)
                        .font(.caption)
                        .foregroundStyle(req.met ? .primary : .secondary)
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: password)
    }
}

// MARK: - PermissionsPage

private struct PermissionsPage: View {

    let permissionService: PermissionService
    let onContinue: () -> Void

    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var visibleRows: Int = 0
    @State private var buttonOpacity: Double = 0
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                .opacity(titleOpacity)

            Text("Permissions")
                .font(.title).fontWeight(.bold).opacity(titleOpacity)

            Text("Slumberscope needs a few permissions to track your sleep effectively.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
                .opacity(subtitleOpacity)

            VStack(spacing: 16) {
                let rows: [(icon: String, color: Color, title: String, desc: String, granted: Bool)] = [
                    ("mic.fill", .yellow, "Microphone", "Detects snoring patterns", permissionService.microphoneGranted),
                    ("move.3d", .green, "Motion", "Accelerometer (no permission needed)", permissionService.motionAvailable),
                    ("heart.fill", .red, "HealthKit", "Syncs with Apple Health", permissionService.healthKitAuthorized),
                    ("bell.fill", .blue, "Notifications", "Bedtime reminders & summaries", permissionService.notificationsAuthorized),
                    ("location.fill", .cyan, "Location", "Weather when you wake up", permissionService.locationAuthorized)
                ]
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    PermissionRow(icon: row.icon, color: row.color, title: row.title, description: row.desc, granted: row.granted)
                        .opacity(visibleRows > index ? 1 : 0)
                        .offset(x: visibleRows > index ? 0 : 20)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.1), value: visibleRows)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    isRequesting = true
                    Task {
                        await permissionService.requestAllPermissions()
                        isRequesting = false
                        onContinue()
                    }
                } label: {
                    HStack {
                        if isRequesting { ProgressView().tint(.white).padding(.trailing, 4) }
                        Text(isRequesting ? "Requesting\u{2026}" : "Grant Permissions & Continue").font(.headline)
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 32).opacity(buttonOpacity).disabled(isRequesting)

                Button("Skip for Now") { onContinue() }
                    .font(.subheadline).foregroundStyle(.secondary).opacity(buttonOpacity)
            }
            .padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { titleOpacity = 1 }
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) { subtitleOpacity = 1 }
            withAnimation(.easeOut(duration: 0.1).delay(0.35)) { visibleRows = 4 }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.7)) { buttonOpacity = 1 }
        }
    }
}

// MARK: - InteractiveTutorialPage

// MARK: - MediaSetupPage

private struct MediaSetupPage: View {

    let onContinue: () -> Void

    @Environment(SleepSettings.self) private var settings
    @Environment(MediaPlaybackService.self) private var mediaService
    @State private var isRequestingAppleMusic = false
    @State private var appleMusicAuthorized = false
    @State private var titleOpacity: Double = 0
    @State private var contentOpacity: Double = 0

    var body: some View {
        @Bindable var settings = settings
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 60)

                Image(systemName: "music.note.list")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(colors: [.red, .purple], startPoint: .leading, endPoint: .trailing)
                    )
                    .opacity(titleOpacity)

                Text("Sleep Audio")
                    .font(.title).fontWeight(.bold)
                    .opacity(titleOpacity)

                Text("Fall asleep to Apple Music or a podcast. Optional — flip either one on if you want it in your wind-down chooser.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(contentOpacity)

                VStack(spacing: 14) {
                    // Apple Music
                    mediaRow(
                        icon: "music.note",
                        iconColor: .red,
                        title: "Apple Music",
                        subtitle: appleMusicAuthorized
                            ? "Connected — you can pick songs or playlists"
                            : "Connect to pick songs and playlists at bedtime",
                        isOn: $settings.appleMusicEnabled,
                        trailing: {
                            AnyView(
                                Group {
                                    if settings.appleMusicEnabled && !appleMusicAuthorized {
                                        Button {
                                            Task { await authorizeAppleMusic() }
                                        } label: {
                                            Text(isRequestingAppleMusic ? "…" : "Connect")
                                                .font(.caption).fontWeight(.semibold)
                                                .padding(.horizontal, 12).padding(.vertical, 6)
                                                .background(Color.red.opacity(0.15))
                                                .foregroundStyle(.red)
                                                .clipShape(Capsule())
                                        }
                                        .disabled(isRequestingAppleMusic)
                                    }
                                }
                            )
                        }
                    )

                    // Podcasts
                    mediaRow(
                        icon: "waveform.badge.mic",
                        iconColor: .purple,
                        title: "Podcasts",
                        subtitle: "Search any podcast via Apple's directory and play inside the app",
                        isOn: $settings.podcastsEnabled,
                        trailing: { AnyView(EmptyView()) }
                    )
                }
                .padding(.horizontal, 20)
                .opacity(contentOpacity)

                Spacer(minLength: 20)

                PrimaryButton(title: "Continue") { onContinue() }
                    .padding(.horizontal, 32)
                    .opacity(contentOpacity)

                Button("Skip for Now") { onContinue() }
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(.bottom, 30)
                    .opacity(contentOpacity)
            }
        }
        .scrollIndicators(.hidden)
        .onAppear {
            appleMusicAuthorized = MusicAuthorization.currentStatus == .authorized
            withAnimation(.easeOut(duration: 0.4)) { titleOpacity = 1 }
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) { contentOpacity = 1 }
        }
    }

    private func mediaRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        trailing: @escaping () -> AnyView
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden()
            trailing()
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @MainActor
    private func authorizeAppleMusic() async {
        isRequestingAppleMusic = true
        defer { isRequestingAppleMusic = false }
        let status = await mediaService.requestAppleMusicAuthorization()
        appleMusicAuthorized = status == .authorized
    }
}

private struct InteractiveTutorialPage: View {

    let onComplete: () -> Void

    @Environment(SleepSettings.self) private var settings
    @State private var tutorialStep = 0
    @State private var stepOpacity: Double = 0
    @State private var phoneOffset: CGFloat = 50
    @State private var mockTracking = false
    @State private var mockScore: Double = 0

    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip Tutorial") { onComplete() }
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(.trailing, 24).padding(.top, 16)
            }

            Spacer()

            Group {
                switch tutorialStep {
                case 0: placementStep
                case 1: trackingStep
                case 2: resultsStep
                case 3: aiStep
                default: EmptyView()
                }
            }
            .opacity(stepOpacity)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.easeInOut(duration: 0.3), value: tutorialStep)

            Spacer()

            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Circle()
                        .fill(i == tutorialStep ? Color.cyan : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 16)

            PrimaryButton(title: tutorialStep < totalSteps - 1 ? "Next" : "Start Sleeping Better") {
                if tutorialStep < totalSteps - 1 {
                    withAnimation { stepOpacity = 0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        tutorialStep += 1
                        withAnimation(.easeOut(duration: 0.3)) { stepOpacity = 1 }
                    }
                } else {
                    onComplete()
                }
            }
            .padding(.horizontal, 32).padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { stepOpacity = 1 }
        }
    }

    private var placementStep: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(colors: [.indigo.opacity(0.3), .purple.opacity(0.2)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 260, height: 140)
                Capsule().fill(.white.opacity(0.15)).frame(width: 100, height: 50).offset(x: -60, y: -10)
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [.cyan.opacity(0.8), .blue.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 35, height: 65)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.3), lineWidth: 1))
                    .offset(x: 20, y: phoneOffset > 0 ? phoneOffset : 0)
                    .shadow(color: .cyan.opacity(0.4), radius: 8)
            }
            .onAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.3)) { phoneOffset = 0 }
            }

            Text("Place Your Phone").font(.title2).fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                TutorialBullet(icon: "bed.double.fill", color: .indigo, text: "Place on mattress near your pillow")
                TutorialBullet(icon: "iphone.gen3", color: .cyan, text: "Keep face down to reduce light")
                TutorialBullet(icon: "battery.100.bolt", color: .green, text: "Plug in or ensure good charge")
                TutorialBullet(icon: "mic.fill", color: .yellow, text: "Keep microphone unobstructed")
            }
            .padding(.horizontal, 40)
        }
    }

    private var trackingStep: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().stroke(.cyan.opacity(0.2), lineWidth: 3).frame(width: 160, height: 160)
                Circle()
                    .trim(from: 0, to: mockTracking ? 0.7 : 0)
                    .stroke(
                        LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 160, height: 160).rotationEffect(.degrees(-90))
                VStack(spacing: 4) {
                    Image(systemName: "moon.zzz.fill").font(.system(size: 32)).foregroundStyle(.cyan)
                    Text(mockTracking ? "Tracking..." : "Ready").font(.caption).foregroundStyle(.secondary)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).delay(0.5)) { mockTracking = true }
            }

            Text("Sleep Tracking").font(.title2).fontWeight(.bold)
            Text("Tap \"Track\" to start recording. Slumberscope monitors your movement, audio, and sleep stages throughout the night.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
        }
    }

    private var resultsStep: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().stroke(.secondary.opacity(0.2), lineWidth: 8).frame(width: 140, height: 140)
                Circle()
                    .trim(from: 0, to: mockScore)
                    .stroke(
                        LinearGradient(colors: [.green, .cyan], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 140, height: 140).rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(Int(mockScore * 100))").font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("Sleep Score").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 1.5).delay(0.3)) { mockScore = 0.85 }
            }

            Text("Morning Review").font(.title2).fontWeight(.bold)
            Text("Each morning you'll get a sleep score, detailed breakdown of your sleep stages, snoring events, and personalized tips.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)

            HStack(spacing: 24) {
                MockStat(label: "Deep", value: "1h 42m", color: .indigo)
                MockStat(label: "REM", value: "2h 05m", color: .cyan)
                MockStat(label: "Snoring", value: "12 min", color: .orange)
            }
        }
    }

    private var aiStep: some View {
        VStack(spacing: 20) {
            @Bindable var settings = settings

            Image(systemName: "brain.head.profile.fill")
                .font(.system(size: 64))
                .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .top, endPoint: .bottom))

            Text("AI Sleep Coach").font(.title2).fontWeight(.bold)

            if #available(iOS 26, *) {
                Text("Your device supports Apple Intelligence! Get personalized insights powered by on-device AI.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 40)
                Toggle("Enable AI Coaching", isOn: $settings.aiCoachingEnabled).padding(.horizontal, 40)
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill").foregroundStyle(.green)
                    Text("All AI runs on-device. No data leaves your phone.").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 40)
            } else {
                Text("AI coaching requires iPhone 15 Pro or newer. You'll still get rule-based sleep tips and insights.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 40)
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("Rule-based coaching is enabled by default.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Reusable Components

private struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(.headline)
                .frame(maxWidth: .infinity).padding()
                .background(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

private struct TutorialBullet: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.body).foregroundStyle(color).frame(width: 32)
            Text(text).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

private struct MockStat: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.subheadline).fontWeight(.bold).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct PermissionRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    let granted: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.medium)
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .secondary)
        }
    }
}

// MARK: - FeatureShowcasePage
//
// A scrollable gallery of the app's differentiators, each card animating in
// as the user scrolls. The goal: users know these features exist before they
// ever hit a sleep session, because a feature nobody knows about might as
// well not ship.

private struct FeatureShowcasePage: View {

    let onContinue: () -> Void

    @State private var headerOpacity: Double = 0
    @State private var cardsVisible: Int = 0
    @State private var pulseScale: CGFloat = 1.0

    private struct Feature: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let tagline: String
        let detail: String
        let color: Color
    }

    private let features: [Feature] = [
        Feature(
            icon: "applewatch.radiowaves.left.and.right",
            title: "Works with Apple Watch",
            tagline: "Real heart rate + HRV, not just estimates",
            detail: "If you wear your Apple Watch, Slumberscope uses its sleep stages, HRV, blood oxygen, and resting heart rate. Apple's HRV readings are within 10 ms of clinical ECG.",
            color: .red
        ),
        Feature(
            icon: "waveform.badge.magnifyingglass",
            title: "Smart noise filtering",
            tagline: "Your fan is not snoring",
            detail: "On-device sound classification detects fans, air conditioners, dogs, and speech so they never get counted as snoring events. No other sleep app does this.",
            color: .cyan
        ),
        Feature(
            icon: "music.note.list",
            title: "Fall asleep to your own stuff",
            tagline: "Apple Music + Podcasts built in",
            detail: "Pick a playlist from your library or search any podcast. Set a sleep timer. We will not count our own audio as snoring while it plays.",
            color: .pink
        ),
        Feature(
            icon: "sparkles",
            title: "Apple Intelligence coach",
            tagline: "Personalized tips from your actual data",
            detail: "Morning summaries and coaching run on Apple's on-device language model. Nothing leaves your phone. References your sleep score, HRV, and patterns directly.",
            color: .purple
        ),
        Feature(
            icon: "alarm.waves.left.and.right.fill",
            title: "Smart alarm",
            tagline: "Wake during light sleep",
            detail: "Set a wake window. We watch your motion (and Apple Watch stages when present) and ring the alarm the moment you drift into light sleep inside that window.",
            color: .orange
        ),
        Feature(
            icon: "square.and.arrow.up",
            title: "Share your night",
            tagline: "One-tap story card",
            detail: "After every session, tap share to post a beautifully rendered sleep card to Instagram, TikTok, or wherever you share. Good sleep is worth celebrating.",
            color: .indigo
        )
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer(minLength: 40)

                // Animated header
                VStack(spacing: 12) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(colors: [.cyan, .indigo, .purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .scaleEffect(pulseScale)
                    Text("What makes Slumberscope different")
                        .font(.title2).fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    Text("A quick tour of the features you might not know about")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .opacity(headerOpacity)
                .padding(.bottom, 4)

                // Feature cards — each reveals with a small delay
                ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                    FeatureCard(feature: feature)
                        .opacity(index < cardsVisible ? 1 : 0)
                        .offset(y: index < cardsVisible ? 0 : 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: cardsVisible)
                }

                Spacer(minLength: 16)

                PrimaryButton(title: "Let's go") { onContinue() }
                    .padding(.horizontal, 32)
                    .opacity(headerOpacity)

                Spacer(minLength: 30)
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { headerOpacity = 1 }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.08
            }
            // Stagger the card reveals.
            for index in features.indices {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(index) * 0.15) {
                    cardsVisible = index + 1
                }
            }
        }
    }

    // MARK: - FeatureCard

    private struct FeatureCard: View {
        let feature: Feature

        var body: some View {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: feature.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        LinearGradient(
                            colors: [feature.color, feature.color.opacity(0.7)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(feature.title)
                        .font(.headline)
                    Text(feature.tagline)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(feature.color)
                    Text(feature.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(feature.color.opacity(0.15), lineWidth: 1)
            )
        }
    }
}
