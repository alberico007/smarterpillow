//
//  AboutTeamView.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/17/26.
//

import SwiftUI

struct AboutTeamView: View {

    @State private var headerVisible = false
    @State private var visibleCards: Int = 0

    private let team: [TeamMember] = [
        TeamMember(
            name: "Simon Alberico",
            role: "Cyber Security",
            initials: "SA",
            gradient: [Color.cyan, Color.blue]
        ),
        TeamMember(
            name: "Aia Ahmed",
            role: "Computer Science",
            initials: "AA",
            gradient: [Color.purple, Color.pink]
        ),
        TeamMember(
            name: "Ananjin Batdelger",
            role: "Software Engineering",
            initials: "AB",
            gradient: [Color.green, Color.teal]
        )
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {

                // App header
                VStack(spacing: 12) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom)
                        )

                    Text("Slumberscope")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Built with care to help you sleep better.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)
                .opacity(headerVisible ? 1 : 0)
                .offset(y: headerVisible ? 0 : 20)

                // Team section
                VStack(alignment: .leading, spacing: 16) {
                    Text("The Team")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)

                    ForEach(Array(team.enumerated()), id: \.offset) { index, member in
                        TeamMemberCard(member: member)
                            .padding(.horizontal, 20)
                            .opacity(visibleCards > index ? 1 : 0)
                            .offset(y: visibleCards > index ? 0 : 24)
                            .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(Double(index) * 0.12), value: visibleCards)
                    }
                }

                // Version info
                VStack(spacing: 6) {
                    Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("© 2026 Slumberscope. All rights reserved.")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                }
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                headerVisible = true
            }
            withAnimation(.easeOut(duration: 0.1).delay(0.3)) {
                visibleCards = team.count
            }
        }
    }
}

// MARK: - TeamMember

struct TeamMember {
    let name: String
    let role: String
    let initials: String
    let gradient: [Color]
}

// MARK: - TeamMemberCard

private struct TeamMemberCard: View {

    let member: TeamMember
    @State private var pressed = false

    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: member.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 56, height: 56)

                Text(member.initials)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(member.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(member.role)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
}
