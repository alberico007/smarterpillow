//
//  SummaryView.swift
//  sleepWatch

import SwiftUI

struct SummaryView: View {

    let score: Int
    let duration: TimeInterval
    let quality: String

    private var durationFormatted: String {
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        return "\(h)h \(m)m"
    }

    private var scoreColor: Color {
        switch score {
        case 80...100: return .green
        case 60..<80:  return .cyan
        case 40..<60:  return .yellow
        default:       return .orange
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {

                Image(systemName: "sun.horizon.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Text("Sleep Summary")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 6)
                        .frame(width: 64, height: 64)

                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 100)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))

                    Text("\(score)")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                }

                HStack(spacing: 20) {
                    VStack(spacing: 2) {
                        Text(durationFormatted)
                            .font(.system(.callout, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Duration")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 2) {
                        Text(quality)
                            .font(.system(.callout, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Quality")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}
