//
//  IdleView.swift
//  sleepWatch

import SwiftUI

struct IdleView: View {

    @State private var pulseAnimation = false

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.indigo.opacity(0.15))
                    .frame(width: 80, height: 80)
                    .scaleEffect(pulseAnimation ? 1.15 : 1.0)
                    .animation(
                        .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                        value: pulseAnimation
                    )
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("Slumberscope")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)

            Text("Waiting for\niPhone to start tracking")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .onAppear { pulseAnimation = true }
    }
}
