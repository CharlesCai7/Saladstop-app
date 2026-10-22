//
//  BuilderView.swift
//  Saladstop
//
//  Step-by-step create-your-own bowl with a live nutrition bar.
//

import SwiftUI

enum BuildStep: String, CaseIterable, Identifiable {
    case base, toppings, dressing, extras

    var id: String { rawValue }

    var title: String {
        switch self {
        case .base: "Base"
        case .toppings: "Toppings"
        case .dressing: "Dressing"
        case .extras: "Extras"
        }
    }

    var categories: [IngredientCategory] {
        switch self {
        case .base: [.base]
        case .toppings: [.topping]
        case .dressing: [.dressing]
        case .extras: [.sprinkle, .side]
        }
    }
}

enum IngredientSort: String, CaseIterable, Identifiable {
    case menu, bestFit, protein, lowCalorie, lowCarb, fiber

    var id: String { rawValue }

    var title: String {
        switch self {
        case .menu: "Menu order"
        case .bestFit: "Best fit for my goal"
        case .protein: "Most protein"
        case .lowCalorie: "Fewest calories"
        case .lowCarb: "Fewest carbs"
        case .fiber: "Most fibre"
        }
    }

    var symbol: String {
        switch self {
        case .menu: "list.bullet"
        case .bestFit: "target"
        case .protein: "dumbbell"
        case .lowCalorie: "flame"
        case .lowCarb: "chart.bar.xaxis"
        case .fiber: "leaf"
        }
    }

    var highlight: Nutrient? {
        switch self {
        case .protein: .protein
        case .lowCalorie: .calories
        case .lowCarb: .carbs
        case .fiber: .fiber
        default: nil
        }
    }
}

struct BuilderView: View {
    @Environment(AppModel.self) var model

    @State private var step: BuildStep = .base
    @State private var sort: IngredientSort = .bestFit
    @State private var showFiltered = false
    @State private var detail: Ingredient?
    @State private var showReview = false
    @State private var showFill = false
    @State private var fullCategoryAlert: IngredientCategory?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Step", selection: $step) {
                        ForEach(BuildStep.allCases) { step in
                            Text(stepLabel(step)).tag(step)
                        }
                    }
                    .pickerStyle(.segmented)

                    ForEach(step.categories) { category in
                        categorySection(category)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Theme.pageBackground)
            .navigationTitle("Build a Bowl")
            .toolbar { toolbar }
            .safeAreaInset(edge: .bottom) {
                BowlBar(onReview: { showReview = true })
            }
            .sheet(item: $detail) { ingredient in
                IngredientDetailView(ingredient: ingredient)
            }
            .sheet(isPresented: $showReview) {
                BowlReviewView()
            }
            .sheet(isPresented: $showFill) {
                NavigationStack {
                    SuggestionsList(completingCurrentBowl: true) { showFill = false }
                        .navigationTitle("Complete my bowl")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showFill = false }
                            }
                        }
                }
            }
            .alert("That's the max", isPresented: Binding(
                get: { fullCategoryAlert != nil },
                set: { if !$0 { fullCategoryAlert = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                if let category = fullCategoryAlert {
                    Text("A bowl can hold up to \(category.limit) \(category.title.lowercased()). Remove one to swap it out.")
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Picker("Sort", selection: $sort) {
                    ForEach(IngredientSort.allCases) { option in
                        Label(option.title, systemImage: option.symbol).tag(option)
                    }
                }
                Toggle("Show filtered-out items", isOn: $showFiltered)
                Divider()
                Button("Clear bowl", systemImage: "trash", role: .destructive) {
                    model.clearBowl()
                    step = .base
                }
                .disabled(model.bowl.isEmpty)
            } label: {
                Label("Sort & options", systemImage: "line.3.horizontal.decrease.circle")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showFill = true
            } label: {
                Label("Fill to my goal", systemImage: "wand.and.stars")
            }
        }
    }

    private func stepLabel(_ step: BuildStep) -> String {
        let count = step.categories.reduce(0) { $0 + model.bowl.count(in: $1) }
        return count > 0 ? "\(step.title) (\(count))" : step.title
    }

    @ViewBuilder
    private func categorySection(_ category: IngredientCategory) -> some View {
        let all = model.catalog.items(in: category)
        let allowed = all.filter { model.isAllowed($0) }
        let hiddenCount = all.count - allowed.count
        let visible = sorted(showFiltered ? all : allowed)
        let topPicks = topPickIDs(in: allowed)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(category.title, systemImage: category.symbol)
                    .font(.title3.weight(.bold))
                Spacer()
                Text("\(model.bowl.count(in: category))/\(category.limit)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(category.rule)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if category == .topping {
                ToppingAllowanceView()
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(visible) { ingredient in
                    IngredientCard(
                        ingredient: ingredient,
                        portion: model.bowl.portion(of: ingredient.id),
                        highlight: sort.highlight,
                        isTopPick: topPicks.contains(ingredient.id),
                        onTap: { tap(ingredient) },
                        onInfo: { detail = ingredient }
                    )
                    .opacity(model.isAllowed(ingredient) ? 1 : 0.45)
                }
            }

            if hiddenCount > 0 && !showFiltered {
                Button {
                    showFiltered = true
                } label: {
                    Label("\(hiddenCount) hidden by your allergen & diet filters", systemImage: "eye.slash")
                        .font(.footnote)
                }
                .padding(.top, 4)
            }
        }
        .padding(.top, 4)
    }

    private func tap(_ ingredient: Ingredient) {
        withAnimation(.snappy) {
            if model.toggle(ingredient) == .full {
                fullCategoryAlert = ingredient.category
            }
        }
    }

    private func sorted(_ items: [Ingredient]) -> [Ingredient] {
        switch sort {
        case .menu:
            return items
        case .bestFit:
            let gains = Dictionary(items.map { ($0.id, model.fitGain(for: $0)) }, uniquingKeysWith: { a, _ in a })
            return items.sorted { (gains[$0.id] ?? 0) > (gains[$1.id] ?? 0) }
        case .protein:
            return items.sorted { $0.nutrition.protein > $1.nutrition.protein }
        case .lowCalorie:
            return items.sorted { $0.nutrition.calories < $1.nutrition.calories }
        case .lowCarb:
            return items.sorted { $0.nutrition.carbs < $1.nutrition.carbs }
        case .fiber:
            return items.sorted { $0.nutrition.fiber > $1.nutrition.fiber }
        }
    }

    /// The few ingredients that move the bowl furthest toward its targets.
    private func topPickIDs(in items: [Ingredient]) -> Set<String> {
        let ranked = items
            .filter { !model.bowl.contains($0.id) }
            .map { ($0.id, model.fitGain(for: $0)) }
            .filter { $0.1 > 0.01 }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
        return Set(ranked.map { $0.0 })
    }
}

/// "4 of 6 standard toppings included" read-out.
struct ToppingAllowanceView: View {
    @Environment(AppModel.self) var model

    var body: some View {
        let lines = model.bowlLines.filter { $0.ingredient.category == .topping }
        let standard = lines.filter { !$0.ingredient.isPremium }.count
        let premium = lines.filter { $0.ingredient.isPremium }.count
        let extraStandard = max(0, standard - 6)

        HStack(spacing: 10) {
            ProgressView(value: Double(min(standard, 6)), total: 6)
                .tint(Theme.green)
                .frame(width: 70)
            Text("\(min(standard, 6)) of 6 standard included")
            if extraStandard > 0 {
                Text("+\(extraStandard) extra").foregroundStyle(Theme.carbs)
            }
            if premium > 0 {
                Text("+\(premium) premium").foregroundStyle(Theme.carbs)
            }
        }
        .font(.caption.weight(.medium))
    }
}

/// Sticky bottom bar: live calories + macros vs target.
struct BowlBar: View {
    @Environment(AppModel.self) var model
    var onReview: () -> Void

    var body: some View {
        let facts = model.bowlNutrition
        let targets = model.targets
        Button(action: onReview) {
            HStack(spacing: 14) {
                CalorieRing(value: facts.calories, target: targets.calories, size: 54, lineWidth: 6, showsLabel: false)
                    .overlay {
                        Text(facts.calories.whole)
                            .font(.caption.weight(.bold).monospacedDigit())
                    }
                VStack(spacing: 6) {
                    ForEach([Macro.protein, .carbs, .fat]) { macro in
                        MacroBar(macro: macro, value: macro.value(facts), target: macro.target(targets), compact: true)
                    }
                }
                VStack(spacing: 2) {
                    Image(systemName: "chevron.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.green)
                    Text("\(model.bowl.items.count) items")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
            .padding(.horizontal)
            .padding(.bottom, 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Review bowl, \(facts.calories.whole) calories")
    }
}
