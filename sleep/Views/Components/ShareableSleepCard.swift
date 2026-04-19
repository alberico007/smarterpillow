//
//  ShareableSleepCard.swift
//  sleep
//
//  Renders a polished 1080x1920 (portrait story size) card summarizing last
//  night's sleep, designed to be shared to TikTok / Instagram / Messages.
//  Uses SwiftUI ImageRenderer to rasterize the view into a UIImage that
//  ShareLink can export as a PNG.
//

import os
import SwiftUI
import UIKit

// MARK: - ShareableSleepCard (the rendered layout)

struct ShareableSleepCard: View {

    let session: SleepSession
    let aiSummary: String?

    private var scoreColor: Color {
        switch session.sleepScore {
        case 80...:  return .green
        case 60..<80: return .yellow
        default:      return .orange
        }
    }

    private var durationString: String {
        let h = Int(session.durationSeconds) / 3600
        let m = (Int(session.durationSeconds) % 3600) / 60
        return "\(h)h \(m)m"
    }

    var body: some View {
        ZStack {
            // Background gradient tinted by score
            LinearGradient(
                colors: [scoreColor.opacity(0.95), .indigo.opacity(0.75), .black],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .overlay(
                // Sparkles for visual interest
                ForEach(0..<10, id: \.self) { i in
                    Image(systemName: "sparkle")
                        .foregroundStyle(.white.opacity(0.25))
                        .font(.system(size: CGFloat(12 + (i % 4) * 6)))
                        .offset(x: CGFloat([-160, 120, -60, 180, -100, 140, 60, -180, 80, 0][i]),
                                y: CGFloat([-300, -200, -100, 50, 150, 250, 350, -50, 100, -250][i]))
                }
            )

            VStack(spacing: 28) {
                // Header
                HStack {
                    Image(systemName: "moon.stars.fill")
                        .foregroundStyle(.white)
                    Text("SLUMBERSCOPE")
                        .font(.caption).fontWeight(.bold)
                        .kerning(2)
                        .foregroundStyle(.white)
                    Spacer()
                    Text(session.startTime.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                // Sleep score — hero
                VStack(spacing: 8) {
                    Text("\(session.sleepScore)")
                        .font(.system(size: 120, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Sleep Score")
                        .font(.caption).fontWeight(.semibold)
                        .kerning(1.5)
                        .foregroundStyle(.white.opacity(0.85))
                }

                // Stats row
                HStack(spacing: 28) {
                    StatBlock(icon: "clock.fill", label: "Duration", value: durationString)
                    StatBlock(icon: "star.fill", label: "Quality", value: session.quality.label)
                    if let hrv = session.hrvAverageMS {
                        StatBlock(icon: "waveform.path.ecg", label: "HRV", value: "\(Int(hrv)) ms")
                    } else {
                        StatBlock(icon: "zzz", label: "Snores", value: "\(session.snoringCount)")
                    }
                }
                .padding(.top, 8)

                // Stage distribution bar
                if !session.sleepStages.isEmpty {
                    StageDistributionBar(stages: session.sleepStages)
                        .frame(height: 14)
                }

                Spacer()

                // AI tip or fallback quote
                if let summary = aiSummary, !summary.isEmpty {
                    Text("\u{201C}\(summary)\u{201D}")
                        .font(.callout).italic()
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .padding(.horizontal, 4)
                }

                Spacer(minLength: 12)

                // App handle at bottom
                HStack(spacing: 6) {
                    Image(systemName: "moon.zzz.fill")
                    Text("Tracked with Slumberscope")
                        .font(.caption2).fontWeight(.semibold)
                }
                .foregroundStyle(.white.opacity(0.7))
            }
            .padding(24)
        }
        .frame(width: 1080, height: 1920)
    }

    private struct StatBlock: View {
        let icon: String
        let label: String
        let value: String
        var body: some View {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(.white.opacity(0.85))
                    .font(.title3)
                Text(value)
                    .font(.title3).fontWeight(.bold)
                    .foregroundStyle(.white)
                Text(label.uppercased())
                    .font(.caption2).kerning(1)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private struct StageDistributionBar: View {
        let stages: [SleepStageEntry]

        private var total: TimeInterval {
            stages.reduce(0) { $0 + $1.endTime.timeIntervalSince($1.startTime) }
        }

        var body: some View {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(stages) { stage in
                        let duration = stage.endTime.timeIntervalSince(stage.startTime)
                        let width = total > 0 ? geo.size.width * CGFloat(duration / total) : 0
                        Rectangle()
                            .fill(color(for: stage.stage))
                            .frame(width: width)
                    }
                }
            }
            .clipShape(Capsule())
        }

        private func color(for stage: SleepStageType) -> Color {
            switch stage {
            case .awake: return .orange
            case .light: return .cyan
            case .deep: return .indigo
            case .rem: return .purple
            }
        }
    }
}

// MARK: - Rendering helper

/// Rasterizes a `ShareableSleepCard` into a PNG data blob that can be shared
/// via `ShareLink` or `UIActivityViewController`.
enum SleepCardRenderer {

    @MainActor
    static func render(session: SleepSession, aiSummary: String?) -> Data? {
        let renderer = ImageRenderer(content: ShareableSleepCard(session: session, aiSummary: aiSummary))
        // Resolve screen scale from the first active window scene to avoid
        // the iOS 26 deprecation of `UIScreen.main`.
        let scale = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen.scale ?? 2.0
        renderer.scale = scale
        guard let uiImage = renderer.uiImage else {
            AppLogger.ui.error("🖼️ Failed to render shareable sleep card")
            return nil
        }
        AppLogger.ui.info("🖼️ Rendered share card: \(Int(uiImage.size.width))x\(Int(uiImage.size.height))")
        return uiImage.pngData()
    }
}

// MARK: - Share Link wrapper

/// Drop this into any view. When tapped it renders the card on the fly and
/// hands the PNG to the system share sheet.
struct SleepCardShareLink: View {

    let session: SleepSession
    let aiSummary: String?

    var body: some View {
        if let data = SleepCardRenderer.render(session: session, aiSummary: aiSummary),
           let image = UIImage(data: data) {
            ShareLink(
                item: Image(uiImage: image),
                preview: SharePreview(
                    "Sleep Score \(session.sleepScore)/100",
                    image: Image(uiImage: image)
                )
            ) {
                Label("Share Sleep Card", systemImage: "square.and.arrow.up")
            }
        } else {
            // If rendering failed, at least offer a text-based share.
            ShareLink(item: "Sleep Score \(session.sleepScore)/100 — tracked with Slumberscope") {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }
}
