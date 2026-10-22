//
//  BowlReviewView.swift
//  Saladstop
//

import SwiftUI

/// The current bowl: portions, full nutrition label, carbon, save.
struct BowlReviewView: View {
    @Environment(AppModel.self) var model
    @Environment(\.dismiss) var dismiss
    @State private var showSave = false
    @State private var bowlName = ""
    @State private var savedToast = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Your bowl vs. target").font(.headline)
                            Spacer()
                            MatchBadge(percent: model.bowlMatch)
                        }
                        MacroSummaryView(nutrition: model.bowlNutrition, targets: model.targets)
                        CalorieSplitBar(nutrition: model.bowlNutrition)
                        GoalInsights(nutrition: model.bowlNutrition, targets: model.targets)
                    }
                    .padding(.vertical, 6)
                }

                if model.bowl.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "Your bowl is empty",
                            systemImage: "leaf",
                            description: Text("Pick a base and toppings, or let us build one for your goal.")
                        )
                    }
                } else {
                    BowlLinesSection(editable: true)

                    Section {
                        NutritionLabelView(nutrition: model.bowlNutrition)
                            .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                    }

                    Section {
                        Label {
                            Text("\((model.catalog.carbonGrams(for: model.bowl) / 1000).formatted(.number.precision(.fractionLength(2)))) kg CO₂e")
                        } icon: {
                            Image(systemName: "globe.asia.australia.fill").foregroundStyle(Theme.green)
                        }
                    } header: {
                        Text("Carbon footprint")
                    } footer: {
                        Text("Based on published values for each ingredient; some items have no published figure.")
                    }
                }
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "bookmark") {
                        bowlName = BowlOptimizer.suggestedName(for: model.bowl, catalog: model.catalog)
                        showSave = true
                    }
                    .disabled(model.bowl.isEmpty)
                }
            }
            .alert("Save bowl", isPresented: $showSave) {
                TextField("Name", text: $bowlName)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    model.save(model.bowl, name: bowlName)
                    savedToast = true
                }
            } message: {
                Text("Find it later in Saved.")
            }
            .overlay(alignment: .top) {
                if savedToast {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task {
                            try? await Task.sleep(for: .seconds(1.6))
                            withAnimation { savedToast = false }
                        }
                }
            }
            .animation(.snappy, value: savedToast)
        }
    }
}

/// Bowl contents grouped by category, with portion menus.
struct BowlLinesSection: View {
    @Environment(AppModel.self) var model
    var editable: Bool

    var body: some View {
        ForEach(IngredientCategory.allCases) { category in
            let lines = model.bowlLines.filter { $0.ingredient.category == category }
            if !lines.isEmpty {
                Section(category.title) {
                    ForEach(lines) { line in
                        BowlLineRow(line: line, editable: editable)
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { lines[$0].id }
                        withAnimation { ids.forEach { model.remove($0) } }
                    }
                    .deleteDisabled(!editable)
                }
            }
        }
    }
}

struct BowlLineRow: View {
    @Environment(AppModel.self) var model
    var line: BowlLine
    var editable: Bool

    var body: some View {
        HStack(spacing: 12) {
            IngredientThumb(ingredient: line.ingredient, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(line.ingredient.name).font(.body.weight(.medium))
                MacroInline(nutrition: line.nutrition)
                if line.ingredient.category == .base && line.factor < line.item.portion.rawValue {
                    Text("Half & half")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            if editable {
                Menu {
                    Picker("Portion", selection: Binding(
                        get: { line.item.portion },
                        set: { model.setPortion($0, for: line.id) }
                    )) {
                        ForEach(Portion.allCases) { portion in
                            Text(portion.title).tag(portion)
                        }
                    }
                } label: {
                    Text(line.item.portion.short)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.green.opacity(0.12), in: Capsule())
                        .foregroundStyle(Theme.green)
                }
            } else if line.item.portion != .regular {
                Text(line.item.portion.short)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Plain-language nudges: what's over, what's short, and how to fix it.
struct GoalInsights: View {
    var nutrition: NutritionFacts
    var targets: MacroTargets

    private var insights: [(symbol: String, color: Color, text: String)] {
        var out: [(symbol: String, color: Color, text: String)] = []
        let kcalGap = targets.calories - nutrition.calories
        if nutrition.calories == 0 { return [] }
        if kcalGap > 80 {
            out.append(("plus.circle", Theme.calories, "\(kcalGap.whole) kcal left — room for another topping."))
        } else if kcalGap < -80 {
            out.append(("exclamationmark.circle", Theme.over, "\((-kcalGap).whole) kcal over — try a light dressing portion."))
        }
        let proteinGap = targets.protein - nutrition.protein
        if proteinGap > 8 {
            out.append(("dumbbell", Theme.protein, "\(proteinGap.whole)g protein short — add chicken, salmon, tuna or tofu."))
        }
        if nutrition.carbs - targets.carbs > 15 {
            out.append(("chart.bar.xaxis", Theme.carbs, "Carbs are high — swap a grain base for greens."))
        }
        if nutrition.totalFat - targets.fat > 10 {
            out.append(("drop", Theme.fat, "Fat is high — dressings and cheese are the usual suspects."))
        }
        if nutrition.fiber < targets.fiberMin {
            out.append(("leaf", Theme.lime, "Fibre \(nutrition.fiber.compact)g — beans, kale or broccoli add more."))
        }
        if nutrition.sodium > targets.sodiumMax {
            out.append(("saltshaker", Theme.over, "Sodium \(nutrition.sodium.whole)mg is above your \(targets.sodiumMax.whole)mg cap."))
        }
        if out.isEmpty {
            out.append(("checkmark.seal.fill", Theme.green, "Right on target. Nice bowl!"))
        }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(insights.enumerated()), id: \.offset) { _, insight in
                Label {
                    Text(insight.text).font(.footnote)
                } icon: {
                    Image(systemName: insight.symbol).foregroundStyle(insight.color)
                }
            }
        }
    }
}
