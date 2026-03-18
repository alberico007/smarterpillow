//
//  FactorService.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/17/26.
//

import Foundation
import SwiftData

// MARK: - FactorCorrelation

struct FactorCorrelation: Identifiable {
    let id: String
    let factorType: FactorType
    let metric: String           // e.g. "deep sleep", "sleep score"
    let withFactor: Double       // Average metric when factor present
    let withoutFactor: Double    // Average metric when factor absent
    let nightsWithFactor: Int
    let nightsWithoutFactor: Int
    let insight: String          // e.g. "On nights you exercised, deep sleep was 22% higher"

    var difference: Double { withFactor - withoutFactor }
    var percentChange: Double {
        guard withoutFactor != 0 else { return 0 }
        return ((withFactor - withoutFactor) / withoutFactor) * 100
    }
    var isPositive: Bool { difference > 0 }
}

// MARK: - FactorService

enum FactorService {

    /// Minimum number of data points (nights with / without) to generate a correlation.
    private static let minimumSampleSize = 3

    /// Analyzes correlations between logged factors and sleep scores.
    static func analyzeCorrelations(
        factors: [SleepFactor],
        sessions: [SleepSession]
    ) -> [FactorCorrelation] {
        guard sessions.count >= minimumSampleSize else { return [] }

        // Group factors by date (day-level)
        let calendar = Calendar.current
        var factorsByDate: [DateComponents: Set<String>] = [:]
        for factor in factors {
            let key = calendar.dateComponents([.year, .month, .day], from: factor.date)
            factorsByDate[key, default: []].insert(factor.factorType)
        }

        // For each factor type, compare nights with vs without
        var correlations: [FactorCorrelation] = []

        for factorType in FactorType.allCases where factorType != .custom {
            var scoresWithFactor: [Double] = []
            var scoresWithoutFactor: [Double] = []

            for session in sessions {
                let sessionDay = calendar.dateComponents([.year, .month, .day], from: session.startTime)
                let dayFactors = factorsByDate[sessionDay] ?? []
                let score = Double(session.sleepScore)

                if dayFactors.contains(factorType.rawValue) {
                    scoresWithFactor.append(score)
                } else {
                    scoresWithoutFactor.append(score)
                }
            }

            guard scoresWithFactor.count >= minimumSampleSize,
                  scoresWithoutFactor.count >= minimumSampleSize else { continue }

            let avgWith = scoresWithFactor.reduce(0, +) / Double(scoresWithFactor.count)
            let avgWithout = scoresWithoutFactor.reduce(0, +) / Double(scoresWithoutFactor.count)

            let diff = avgWith - avgWithout
            let pctChange = avgWithout != 0 ? abs(diff / avgWithout * 100) : 0
            let direction = diff > 0 ? "higher" : "lower"
            let insight = "On nights with \(factorType.label.lowercased()), your sleep score was \(Int(pctChange.rounded()))% \(direction)"

            correlations.append(FactorCorrelation(
                id: factorType.rawValue,
                factorType: factorType,
                metric: "Sleep Score",
                withFactor: avgWith,
                withoutFactor: avgWithout,
                nightsWithFactor: scoresWithFactor.count,
                nightsWithoutFactor: scoresWithoutFactor.count,
                insight: insight
            ))
        }

        // Sort by absolute impact
        return correlations.sorted { abs($0.difference) > abs($1.difference) }
    }

    /// Generates rule-based coaching tips based on recent sessions and factors.
    static func generateCoachingTip(
        sessions: [SleepSession],
        factors: [SleepFactor]
    ) -> String? {
        guard sessions.count >= 3 else { return nil }

        let recentScores = sessions.prefix(7).map { $0.sleepScore }
        let avgScore = recentScores.reduce(0, +) / recentScores.count

        // Tip based on trend
        if sessions.count >= 3 {
            let last3 = Array(sessions.prefix(3)).map { $0.sleepScore }
            let prev3 = Array(sessions.dropFirst(3).prefix(3)).map { $0.sleepScore }
            if !prev3.isEmpty {
                let lastAvg = Double(last3.reduce(0, +)) / Double(last3.count)
                let prevAvg = Double(prev3.reduce(0, +)) / Double(prev3.count)

                if lastAvg > prevAvg + 5 {
                    return "Your sleep has been improving! Your average score is up \(Int(lastAvg - prevAvg)) points over the past few nights."
                } else if lastAvg < prevAvg - 5 {
                    return "Your sleep quality has dipped recently. Try sticking to a consistent bedtime for the next few nights."
                }
            }
        }

        // Duration-based tip
        let avgHours = sessions.prefix(7).map { $0.durationSeconds / 3600.0 }.reduce(0, +) / Double(min(sessions.count, 7))
        if avgHours < 6.5 {
            return "You've been averaging \(String(format: "%.1f", avgHours)) hours of sleep. Aim for at least 7 hours for optimal recovery."
        }

        // Snoring tip
        let avgSnoring = Double(sessions.prefix(7).map(\.snoringCount).reduce(0, +)) / Double(min(sessions.count, 7))
        if avgSnoring > 5 {
            return "Snoring has been detected frequently. Sleeping on your side and elevating your head may help reduce snoring."
        }

        if avgScore >= 80 {
            return "Great work! Your sleep score has been consistently high. Keep up your current routine."
        }

        return "Track more nights to unlock personalized sleep insights and coaching tips."
    }
}
