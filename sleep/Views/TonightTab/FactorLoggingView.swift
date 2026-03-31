//
//  FactorLoggingView.swift
//  sleep
//
//
//

import SwiftData
import SwiftUI

struct FactorLoggingView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \SleepFactor.date, order: .reverse)
    private var allFactors: [SleepFactor]

    @State private var selectedFactors: Set<FactorType> = []
    @State private var customLabel = ""
    @State private var showCustomField = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("What happened today that might affect your sleep?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Factor chips
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                        ForEach(FactorType.allCases.filter { $0 != .custom }) { factor in
                            FactorChip(
                                factor: factor,
                                isSelected: selectedFactors.contains(factor)
                            ) {
                                if selectedFactors.contains(factor) {
                                    selectedFactors.remove(factor)
                                } else {
                                    selectedFactors.insert(factor)
                                }
                            }
                        }

                        // Custom factor button
                        Button {
                            showCustomField = true
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.gray)
                                Text("Custom")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)

                    if showCustomField {
                        GlassCard {
                            HStack {
                                TextField("Custom factor...", text: $customLabel)
                                    .textFieldStyle(.plain)
                                Button("Add") {
                                    if !customLabel.isEmpty {
                                        let factor = SleepFactor(date: Date(), type: .custom, customLabel: customLabel)
                                        modelContext.insert(factor)
                                        customLabel = ""
                                        showCustomField = false
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.top)
            }
            .navigationTitle("Log Factors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveFactor()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                let calendar = Calendar.current
                let todayFactors = allFactors.filter { calendar.isDateInToday($0.date) }
                selectedFactors = Set(todayFactors.compactMap { FactorType(rawValue: $0.factorType) })
            }
        }
    }

    private func saveFactor() {
        // Delete today's existing factors first to avoid duplicates
        let calendar = Calendar.current
        for factor in allFactors where calendar.isDateInToday(factor.date) {
            modelContext.delete(factor)
        }

        // Insert the newly selected factors
        for factor in selectedFactors {
            let entry = SleepFactor(date: Date(), type: factor)
            modelContext.insert(entry)
        }
        try? modelContext.save()
    }
}

// MARK: - FactorChip

private struct FactorChip: View {

    let factor: FactorType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: factor.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? factor.color : .secondary)
                Text(factor.label)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? factor.color.opacity(0.12) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? factor.color : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
