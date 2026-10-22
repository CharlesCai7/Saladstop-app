//
//  AppModel.swift
//  Saladstop
//

import Foundation
import SwiftUI
import Observation

enum AppTab: Hashable {
    case forYou, build, explore, saved, goals
}

@Observable
final class AppModel {
    let catalog: Catalog

    var profile: NutritionProfile
    var bowl: Bowl
    var savedBowls: [Bowl]
    var selectedTab: AppTab = .forYou

    private let defaults: UserDefaults

    private enum Keys {
        static let profile = "saladstop.profile.v1"
        static let bowl = "saladstop.draftBowl.v1"
        static let saved = "saladstop.savedBowls.v1"
    }

    init(catalog: Catalog = .loadBundled(), defaults: UserDefaults = .standard) {
        self.catalog = catalog
        self.defaults = defaults
        profile = Self.decode(NutritionProfile.self, from: defaults, key: Keys.profile) ?? NutritionProfile()
        bowl = Self.decode(Bowl.self, from: defaults, key: Keys.bowl) ?? Bowl()
        savedBowls = Self.decode([Bowl].self, from: defaults, key: Keys.saved) ?? []
    }

    // MARK: - Derived

    var targets: MacroTargets { profile.targets }
    var bowlLines: [BowlLine] { catalog.lines(for: bowl) }
    var bowlNutrition: NutritionFacts { catalog.nutrition(for: bowl) }
    var bowlMatch: Int { targets.matchPercent(for: bowlNutrition) }

    func isAllowed(_ ingredient: Ingredient) -> Bool {
        ingredient.isAllowed(excluding: profile.avoidedAllergens, diets: profile.requiredDiets)
    }

    /// Positive when adding `ingredient` moves the current bowl closer to the targets.
    func fitGain(for ingredient: Ingredient) -> Double {
        let current = bowlNutrition
        var factor = 1.0
        if ingredient.category == .base {
            let existing = bowl.count(in: .base)
            if existing > 0 { factor = 1 / Double(existing + 1) }
        }
        let next = current + ingredient.nutrition.scaled(by: factor)
        return macroDistance(current) - macroDistance(next)
    }

    private func macroDistance(_ facts: NutritionFacts) -> Double {
        let t = targets
        func d(_ v: Double, _ target: Double, _ floor: Double, _ w: Double) -> Double {
            let x = (v - target) / max(target, floor)
            return w * x * x
        }
        return d(facts.calories, t.calories, 100, 3)
            + d(facts.protein, t.protein, 5, 2)
            + d(facts.carbs, t.carbs, 10, 1)
            + d(facts.totalFat, t.fat, 5, 1)
    }

    // MARK: - Bowl editing

    @discardableResult
    func toggle(_ ingredient: Ingredient) -> Bowl.ToggleResult {
        bowl.toggle(ingredient)
    }

    func setPortion(_ portion: Portion, for ingredientID: String) {
        bowl.setPortion(portion, for: ingredientID)
    }

    func remove(_ ingredientID: String) {
        bowl.remove(ingredientID)
    }

    func clearBowl() {
        bowl = Bowl()
    }

    /// Puts a suggestion or saved bowl into the builder.
    func use(_ newBowl: Bowl) {
        var copy = newBowl
        copy.id = UUID()
        bowl = copy
        selectedTab = .build
    }

    // MARK: - Suggestions

    func suggestions(seed: UInt64, completingCurrentBowl: Bool = false) -> [BowlSuggestion] {
        let optimizer = BowlOptimizer(
            catalog: catalog,
            targets: targets,
            avoiding: profile.avoidedAllergens,
            diets: profile.requiredDiets,
            keeping: completingCurrentBowl ? bowl : Bowl()
        )
        return optimizer.suggestions(count: 3, seed: seed)
    }

    // MARK: - Saved bowls

    func save(_ bowlToSave: Bowl, name: String? = nil) {
        var copy = bowlToSave
        copy.id = UUID()
        copy.createdAt = Date()
        if let name, !name.trimmingCharacters(in: .whitespaces).isEmpty {
            copy.name = name
        } else if copy.name == "My Bowl" {
            copy.name = BowlOptimizer.suggestedName(for: copy, catalog: catalog)
        }
        savedBowls.insert(copy, at: 0)
    }

    func deleteSaved(at offsets: IndexSet) {
        savedBowls.remove(atOffsets: offsets)
    }

    func deleteSaved(_ saved: Bowl) {
        savedBowls.removeAll { $0.id == saved.id }
    }

    // MARK: - Persistence

    func persist() {
        Self.encode(profile, to: defaults, key: Keys.profile)
        Self.encode(bowl, to: defaults, key: Keys.bowl)
        Self.encode(savedBowls, to: defaults, key: Keys.saved)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from defaults: UserDefaults, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func encode<T: Encodable>(_ value: T, to defaults: UserDefaults, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }
}
