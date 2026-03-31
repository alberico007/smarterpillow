//
//  IntelligenceService.swift
//  sleep
//
//

import Foundation
import os

#if canImport(FoundationModels)
import FoundationModels
#endif

@Observable
final class IntelligenceService {

    // MARK: - Observable State

    var isAvailable: Bool {
        #if targetEnvironment(simulator)
        // FoundationModels is not reliably available on simulator
        return false
        #else
        if #available(iOS 26, *) {
            #if canImport(FoundationModels)
            return true
            #else
            return false
            #endif
        }
        return false
        #endif
    }

    var isGenerating = false

    // MARK: - System Prompt

    private static let sleepCoachSystemPrompt = """
    You are a knowledgeable and supportive sleep coach embedded in the Slumberscope sleep tracking app. \
    Provide concise, actionable, and evidence-based sleep advice. Keep responses to 2-3 sentences. \
    Be warm and encouraging. Reference the user's actual data when giving tips. \
    Do not provide medical diagnoses or replace professional medical advice.
    """

    // MARK: - Generate Coaching Tip

    func generateCoachingTip(sessions: [SleepSession], factors: [SleepFactor]) async -> String? {
        guard !sessions.isEmpty else { return nil }

        await MainActor.run { isGenerating = true }
        defer { Task { @MainActor in isGenerating = false } }

        #if !targetEnvironment(simulator)
        if #available(iOS 26, *) {
            #if canImport(FoundationModels)
            do {
                AppLogger.intelligence.info("🤖 Generating coaching tip...")
                let prompt = buildCoachingPrompt(sessions: sessions, factors: factors)
                let instructions = Instructions(Self.sleepCoachSystemPrompt)
                let session = LanguageModelSession(instructions: instructions)
                let response = try await session.respond(to: prompt)
                AppLogger.intelligence.info("🤖 Coaching tip generated successfully")
                return response.content
            } catch {
                AppLogger.intelligence.error("Intelligence coaching tip generation failed: \(error.localizedDescription)")
            }
            #endif
        }
        #endif

        // Fallback to rule-based tips
        AppLogger.intelligence.info("Using rule-based fallback")
        return FactorService.generateCoachingTip(sessions: sessions, factors: factors)
    }

    // MARK: - Generate Morning Summary

    func generateMorningSummary(session: SleepSession) async -> String? {
        await MainActor.run { isGenerating = true }
        defer { Task { @MainActor in isGenerating = false } }

        #if !targetEnvironment(simulator)
        if #available(iOS 26, *) {
            #if canImport(FoundationModels)
            do {
                AppLogger.intelligence.info("🤖 Generating morning summary...")
                let prompt = buildMorningSummaryPrompt(session: session)
                let instructions = Instructions(Self.sleepCoachSystemPrompt)
                let languageSession = LanguageModelSession(instructions: instructions)
                let response = try await languageSession.respond(to: prompt)
                AppLogger.intelligence.info("🤖 Morning summary generated successfully")
                return response.content
            } catch {
                AppLogger.intelligence.error("Intelligence morning summary generation failed: \(error.localizedDescription)")
            }
            #endif
        }
        #endif

        // Fallback: formatted string with key metrics
        return buildFallbackMorningSummary(session: session)
    }

    // MARK: - Generate Factor Insight

    func generateFactorInsight(correlation: FactorCorrelation) async -> String? {
        await MainActor.run { isGenerating = true }
        defer { Task { @MainActor in isGenerating = false } }

        #if !targetEnvironment(simulator)
        if #available(iOS 26, *) {
            #if canImport(FoundationModels)
            do {
                AppLogger.intelligence.info("🤖 Generating factor insight...")
                let prompt = buildFactorInsightPrompt(correlation: correlation)
                let instructions = Instructions(Self.sleepCoachSystemPrompt)
                let session = LanguageModelSession(instructions: instructions)
                let response = try await session.respond(to: prompt)
                AppLogger.intelligence.info("🤖 Factor insight generated successfully")
                return response.content
            } catch {
                AppLogger.intelligence.error("Intelligence factor insight generation failed: \(error.localizedDescription)")
            }
            #endif
        }
        #endif

        // Fallback: return the pre-computed insight string
        return correlation.insight
    }

    // MARK: - Prompt Builders

    private func buildCoachingPrompt(sessions: [SleepSession], factors: [SleepFactor]) -> String {
        let recentSessions = Array(sessions.prefix(7))
        let count = max(recentSessions.count, 1)
        let scores: [Int] = recentSessions.map { $0.sleepScore }
        let avgScore = scores.reduce(0, +) / count
        let durations: [Double] = recentSessions.map { $0.durationSeconds / 3600.0 }
        let avgHours = durations.reduce(0, +) / Double(count)
        let snoringCounts: [Int] = recentSessions.map { $0.snoringCount }
        let avgSnoring = snoringCounts.reduce(0, +) / count

        let factorLabels: [String] = factors.prefix(14).map { $0.displayLabel }
        let recentFactors = factorLabels.joined(separator: ", ")

        return """
        Based on the user's recent sleep data, provide a personalized coaching tip.

        Recent stats (last \(recentSessions.count) nights):
        - Average sleep score: \(avgScore)/100
        - Average duration: \(String(format: "%.1f", avgHours)) hours
        - Average snoring events per night: \(avgSnoring)
        - Recent factors logged: \(recentFactors.isEmpty ? "none" : recentFactors)

        Provide one specific, actionable tip in 2-3 sentences.
        """
    }

    private func buildMorningSummaryPrompt(session: SleepSession) -> String {
        let totalSeconds = Int(session.durationSeconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let stages = session.sleepStages
        let deepStages = stages.filter { $0.stage == .deep }
        let deepSeconds = deepStages.reduce(0.0) { $0 + $1.endTime.timeIntervalSince($1.startTime) }
        let deepMinutes = deepSeconds / 60.0
        let remStages = stages.filter { $0.stage == .rem }
        let remSeconds = remStages.reduce(0.0) { $0 + $1.endTime.timeIntervalSince($1.startTime) }
        let remMinutes = remSeconds / 60.0

        return """
        Write a brief, friendly morning sleep summary for the user.

        Last night's sleep data:
        - Total time: \(hours)h \(minutes)m
        - Sleep score: \(session.sleepScore)/100
        - Quality rating: \(session.quality.label)
        - Deep sleep: \(Int(deepMinutes)) minutes
        - REM sleep: \(Int(remMinutes)) minutes
        - Snoring events: \(session.snoringCount)
        - Awakenings: \(session.awakeningCount)
        - Sleep efficiency: \(Int(session.sleepEfficiency * 100))%

        Summarize in 2-3 friendly sentences with one quick insight.
        """
    }

    private func buildFactorInsightPrompt(correlation: FactorCorrelation) -> String {
        return """
        Explain this sleep factor correlation in plain language with actionable advice.

        Factor: \(correlation.factorType.label)
        Metric affected: \(correlation.metric)
        Average \(correlation.metric) with factor: \(String(format: "%.1f", correlation.withFactor))
        Average \(correlation.metric) without factor: \(String(format: "%.1f", correlation.withoutFactor))
        Nights with factor: \(correlation.nightsWithFactor)
        Nights without factor: \(correlation.nightsWithoutFactor)
        Percent change: \(String(format: "%.1f", correlation.percentChange))%
        Direction: \(correlation.isPositive ? "positive" : "negative")

        Provide a 2-3 sentence explanation of what this means and one suggestion.
        """
    }

    // MARK: - Fallback Helpers

    private func buildFallbackMorningSummary(session: SleepSession) -> String {
        let totalSeconds = Int(session.durationSeconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let stages = session.sleepStages
        let deepStages = stages.filter { $0.stage == .deep }
        let deepSec = deepStages.reduce(0.0) { $0 + $1.endTime.timeIntervalSince($1.startTime) }
        let deepMinutes = Int(deepSec / 60.0)
        let remStages = stages.filter { $0.stage == .rem }
        let remSec = remStages.reduce(0.0) { $0 + $1.endTime.timeIntervalSince($1.startTime) }
        let remMinutes = Int(remSec / 60.0)

        var summary = "You slept \(hours)h \(minutes)m with a sleep score of \(session.sleepScore)/100."

        if deepMinutes > 0 || remMinutes > 0 {
            summary += " You got \(deepMinutes)m of deep sleep and \(remMinutes)m of REM sleep."
        }

        if session.snoringCount > 0 {
            summary += " \(session.snoringCount) snoring event\(session.snoringCount == 1 ? " was" : "s were") detected."
        }

        if session.sleepScore >= 80 {
            summary += " Great night!"
        } else if session.sleepScore < 50 {
            summary += " Try to get to bed earlier tonight for better rest."
        }

        return summary
    }
}
