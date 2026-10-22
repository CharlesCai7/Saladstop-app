//
//  ForYouView.swift
//  Saladstop
//
//  Home tab: your targets + bowls auto-built to hit them.
//

import SwiftUI

struct ForYouView: View {
    @Environment(AppModel.self) var model
    @State var seed = UInt64.random(in: 1...UInt64.max)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !model.profile.hasSetGoals {
                        personaliseCard
                    }
                    targetCard
                    HStack {
                        Text("Bowls built for you")
                            .font(.title2.weight(.bold))
                        Spacer()
                        Button {
                            seed = UInt64.random(in: 1...UInt64.max)
                        } label: {
                            Label("Shuffle", systemImage: "shuffle")
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.green)
                    }
                    SuggestionCards(seed: seed, completingCurrentBowl: false)
                    Text("Bowls are generated from SaladStop!'s published ingredient nutrition. Values may vary with portioning.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .background(Theme.pageBackground)
            .navigationTitle("For You")
        }
    }

    private var personaliseCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Personalise your targets", systemImage: "person.crop.circle.badge.checkmark")
                .font(.headline)
            Text("Tell us about you and your goal and we'll size every bowl to fit — or set exact macros yourself.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                model.selectedTab = .goals
            } label: {
                Text("Set my goals")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.green)
        }
        .card()
    }

    private var targetCard: some View {
        let profile = model.profile
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your bowl target").font(.headline)
                    Text(verbatim: profile.useCustomTargets
                         ? "Custom macros"
                         : "\(profile.style.title) · \(profile.goal.title) · \(Int((profile.mealShare * 100).rounded()))% of your day")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Adjust") { model.selectedTab = .goals }
                    .buttonStyle(.bordered)
            }
            TargetTiles(targets: model.targets)
            if let filters = profile.filterSummary {
                Label(filters, systemImage: "line.3.horizontal.decrease.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }
}

/// Generates and shows three suggestion cards for the current targets & filters.
struct SuggestionCards: View {
    @Environment(AppModel.self) var model
    var seed: UInt64
    var completingCurrentBowl: Bool
    var onUse: () -> Void = {}

    @State var suggestions: [BowlSuggestion] = []
    @State var isWorking = true

    private struct Inputs: Equatable {
        var seed: UInt64
        var targets: MacroTargets
        var avoided: Set<Allergen>
        var diets: Set<Diet>
        var locked: [BowlItem]
    }

    private var inputs: Inputs {
        Inputs(
            seed: seed,
            targets: model.targets,
            avoided: model.profile.avoidedAllergens,
            diets: model.profile.requiredDiets,
            locked: completingCurrentBowl ? model.bowl.items : []
        )
    }

    var body: some View {
        VStack(spacing: 14) {
            if isWorking && suggestions.isEmpty {
                ProgressView("Building bowls…")
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else if suggestions.isEmpty {
                ContentUnavailableView(
                    "No bowls fit these filters",
                    systemImage: "leaf",
                    description: Text("Try relaxing a diet or allergen filter in Goals.")
                )
            } else {
                ForEach(suggestions) { suggestion in
                    SuggestionCard(suggestion: suggestion, targets: model.targets) {
                        model.use(suggestion.bowl)
                        onUse()
                    }
                }
            }
        }
        .opacity(isWorking && !suggestions.isEmpty ? 0.5 : 1)
        .task(id: inputs) {
            isWorking = true
            // Let the spinner render before the (quick) search runs.
            try? await Task.sleep(for: .milliseconds(30))
            guard !Task.isCancelled else { return }
            let result = model.suggestions(seed: inputs.seed, completingCurrentBowl: completingCurrentBowl)
            withAnimation(.snappy) {
                suggestions = result.filter { !$0.bowl.isEmpty }
                isWorking = false
            }
        }
    }
}

struct SuggestionCard: View {
    @Environment(AppModel.self) var model
    var suggestion: BowlSuggestion
    var targets: MacroTargets
    var onUse: () -> Void

    @State var saved = false
    @State var showDetail = false

    var body: some View {
        let lines = model.catalog.lines(for: suggestion.bowl)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(suggestion.bowl.name)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                MatchBadge(percent: suggestion.matchPercent)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(lines) { line in
                        IngredientThumb(ingredient: line.ingredient, size: 46)
                    }
                }
            }

            Text(ingredientSummary(lines))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ForEach(Macro.allCases) { macro in
                    MacroDelta(macro: macro, value: macro.value(suggestion.nutrition), target: macro.target(targets))
                }
            }

            HStack(spacing: 10) {
                Button(action: onUse) {
                    Label("Build this", systemImage: "takeoutbag.and.cup.and.straw.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.green)

                Button {
                    showDetail = true
                } label: {
                    Image(systemName: "list.bullet.rectangle")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Nutrition details")

                Button {
                    model.save(suggestion.bowl)
                    saved = true
                } label: {
                    Image(systemName: saved ? "bookmark.fill" : "bookmark")
                }
                .buttonStyle(.bordered)
                .disabled(saved)
                .accessibilityLabel(saved ? "Saved" : "Save bowl")
            }
            .tint(Theme.green)
        }
        .card()
        .sheet(isPresented: $showDetail) {
            SavedBowlDetailView(bowl: suggestion.bowl, isSaved: false)
        }
    }

    private func ingredientSummary(_ lines: [BowlLine]) -> String {
        lines.map { line -> String in
            let name = line.ingredient.name
            return line.item.portion == .regular ? name : "\(name) (\(line.item.portion.title.lowercased()))"
        }
        .joined(separator: " · ")
    }
}

/// "Protein 38g  +3" — value with difference from target.
struct MacroDelta: View {
    var macro: Macro
    var value: Double
    var target: Double

    var body: some View {
        let diff = value - target
        let deltaText: String = abs(diff) < 0.5
            ? "on target"
            : (diff > 0 ? "+" : "−") + abs(diff).whole
        VStack(spacing: 1) {
            Text(macro == .calories ? value.whole : "\(value.whole)g")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(macro.color)
            Text(macro.title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(deltaText)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Sheet wrapper used by the builder's "Fill to my goal".
struct SuggestionsList: View {
    @Environment(AppModel.self) var model
    var completingCurrentBowl: Bool
    var onUse: () -> Void

    @State var seed = UInt64.random(in: 1...UInt64.max)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if completingCurrentBowl && !model.bowl.isEmpty {
                    Label("Keeping your \(model.bowl.items.count) chosen items and filling the rest to hit your target.",
                          systemImage: "lock.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                TargetTiles(targets: model.targets)
                SuggestionCards(seed: seed, completingCurrentBowl: completingCurrentBowl, onUse: onUse)
            }
            .padding()
        }
        .background(Theme.pageBackground)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Shuffle", systemImage: "shuffle") {
                    seed = UInt64.random(in: 1...UInt64.max)
                }
            }
        }
    }
}
