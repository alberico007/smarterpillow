//
//  InfoFlipCard.swift
//  sleep
//
//  Wraps chart content in a GlassCard with an (i) button in the top-right.
//  Tapping the button flips the card over to reveal an explanation of what
//  the chart is showing and how it's computed. Tap again to flip back.
//

import SwiftUI

struct InfoFlipCard<Content: View>: View {

    let title: String
    let explanation: String
    @ViewBuilder let content: Content

    @State private var isFlipped = false

    var body: some View {
        ZStack {
            // Front — the chart
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(title).font(.headline)
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                                isFlipped = true
                            }
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.title3)
                                .foregroundStyle(.cyan)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("About \(title)")
                    }
                    content
                }
            }
            .opacity(isFlipped ? 0 : 1)
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))

            // Back — the explanation
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(title).font(.headline)
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                                isFlipped = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close explanation")
                    }
                    ScrollView {
                        Text(explanation)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 220)
                }
            }
            .opacity(isFlipped ? 1 : 0)
            .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
    }
}
