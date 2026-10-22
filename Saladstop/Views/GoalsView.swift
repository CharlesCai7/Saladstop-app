//
//  GoalsView.swift
//  Saladstop
//
//  Profile → calorie & macro targets, plus allergen / diet filters.
//

import SwiftUI

struct GoalsView: View {
    @Environment(AppModel.self) private var model

    private let chipColumns = [GridItem(.adaptive(minimum: 140), spacing: 8)]

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        TargetTiles(targets: model.targets)
                        if !model.profile.useCustomTargets {
                            Text(verbatim: "≈ \(model.profile.dailyCalories.whole) kcal a day · this bowl covers \(Int((model.profile.mealShare * 100).rounded()))%")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Per-bowl target")
                }

                Section("Eating style") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(MacroStyle.allCases) { style in
                            StyleCard(style: style, isSelected: model.profile.style == style) {
                                model.profile.style = style
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .disabled(model.profile.useCustomTargets)
                    .opacity(model.profile.useCustomTargets ? 0.4 : 1)
                }

                Section {
                    Picker("Goal", selection: $model.profile.goal) {
                        ForEach(WeightGoal.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    Picker("Sex", selection: $model.profile.sex) {
                        ForEach(Sex.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    Stepper(value: $model.profile.age, in: 14...90) {
                        LabeledContent("Age", value: "\(model.profile.age)")
                    }
                    Stepper(value: $model.profile.heightCm, in: 120...220, step: 1) {
                        LabeledContent("Height", value: "\(model.profile.heightCm.whole) cm")
                    }
                    Stepper(value: $model.profile.weightKg, in: 35...200, step: 0.5) {
                        LabeledContent("Weight", value: "\(model.profile.weightKg.compact) kg")
                    }
                    Picker("Activity", selection: $model.profile.activity) {
                        ForEach(ActivityLevel.allCases) { level in
                            VStack(alignment: .leading) {
                                Text(level.title)
                                Text(level.detail).font(.caption).foregroundStyle(.secondary)
                            }
                            .tag(level)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("This bowl is", value: "\(Int((model.profile.mealShare * 100).rounded()))% of my day")
                        Slider(value: $model.profile.mealShare, in: 0.2...0.6, step: 0.05)
                            .tint(Theme.green)
                    }
                } header: {
                    Text("About you")
                } footer: {
                    Text("Daily needs are estimated with the Mifflin–St Jeor equation. This is general guidance, not medical advice.")
                }
                .disabled(model.profile.useCustomTargets)

                Section {
                    Toggle("Set exact macros", isOn: $model.profile.useCustomTargets.animation())
                        .tint(Theme.green)
                    if model.profile.useCustomTargets {
                        Stepper(value: $model.profile.customTargets.calories, in: 150...1500, step: 10) {
                            LabeledContent("Calories", value: "\(model.profile.customTargets.calories.whole) kcal")
                        }
                        Stepper(value: $model.profile.customTargets.protein, in: 0...150, step: 1) {
                            LabeledContent("Protein", value: "\(model.profile.customTargets.protein.whole) g")
                        }
                        Stepper(value: $model.profile.customTargets.carbs, in: 0...200, step: 1) {
                            LabeledContent("Carbs", value: "\(model.profile.customTargets.carbs.whole) g")
                        }
                        Stepper(value: $model.profile.customTargets.fat, in: 0...120, step: 1) {
                            LabeledContent("Fat", value: "\(model.profile.customTargets.fat.whole) g")
                        }
                        let macroKcal = model.profile.customTargets.protein * 4
                            + model.profile.customTargets.carbs * 4
                            + model.profile.customTargets.fat * 9
                        Text("Your macros add up to \(macroKcal.whole) kcal.")
                            .font(.footnote)
                            .foregroundStyle(abs(macroKcal - model.profile.customTargets.calories) > 60 ? Theme.over : .secondary)
                    }
                } header: {
                    Text("Custom targets")
                }

                Section {
                    Stepper(value: $model.profile.customTargets.fiberMin, in: 0...30, step: 1) {
                        LabeledContent("Fibre at least", value: "\(model.profile.customTargets.fiberMin.whole) g")
                    }
                    .disabled(!model.profile.useCustomTargets)
                    Stepper(value: $model.profile.customTargets.sodiumMax, in: 300...2000, step: 50) {
                        LabeledContent("Sodium at most", value: "\(model.profile.customTargets.sodiumMax.whole) mg")
                    }
                    .disabled(!model.profile.useCustomTargets)
                } header: {
                    Text("Fibre & sodium")
                } footer: {
                    Text(model.profile.useCustomTargets
                         ? "Used by auto-built bowls and the review tips."
                         : "Defaults: at least \(model.targets.fiberMin.whole) g fibre, at most \(model.targets.sodiumMax.whole) mg sodium. Turn on exact macros to change.")
                }

                Section {
                    LazyVGrid(columns: chipColumns, spacing: 8) {
                        ForEach(Allergen.allCases) { allergen in
                            FilterChip(
                                title: allergen.freeTitle,
                                systemImage: allergen.symbol,
                                isOn: model.profile.avoidedAllergens.contains(allergen)
                            ) {
                                model.profile.avoidedAllergens.formSymmetricDifference([allergen])
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Allergens to avoid")
                } footer: {
                    Text("Ingredients containing these are hidden from the builder and never used in auto-built bowls.")
                }

                Section {
                    LazyVGrid(columns: chipColumns, spacing: 8) {
                        ForEach(Diet.allCases) { diet in
                            FilterChip(
                                title: diet.title,
                                systemImage: diet.symbol,
                                isOn: model.profile.requiredDiets.contains(diet)
                            ) {
                                model.profile.requiredDiets.formSymmetricDifference([diet])
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Diet preferences")
                } footer: {
                    Text("Only ingredients SaladStop! tags with every selected diet are shown.")
                }
            }
            .navigationTitle("My Goals")
            .onAppear { model.profile.hasSetGoals = true }
            .onChange(of: model.profile.useCustomTargets) { _, isCustom in
                // Start custom macros from the current computed plan.
                if isCustom {
                    let computed = model.profile.computedTargets
                    model.profile.customTargets.calories = computed.calories
                    model.profile.customTargets.protein = computed.protein
                    model.profile.customTargets.carbs = computed.carbs
                    model.profile.customTargets.fat = computed.fat
                }
            }
        }
    }
}

private struct StyleCard: View {
    var style: MacroStyle
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: style.symbol)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : Theme.green)
                Text(style.title)
                    .font(.subheadline.weight(.semibold))
                Text(style.detail)
                    .font(.caption2)
                    .opacity(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? Theme.green : Theme.green.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct FilterChip: View {
    var title: String
    var systemImage: String
    var isOn: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "checkmark.circle.fill" : systemImage)
                Text(title).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .background(isOn ? Theme.green : Color.secondary.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
