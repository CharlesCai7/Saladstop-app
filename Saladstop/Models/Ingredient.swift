//
//  Ingredient.swift
//  Saladstop
//
//  Ingredient catalogue sourced from SaladStop!'s Nutritional Calculator
//  (bundled as ingredients.json).
//

import Foundation

enum IngredientCategory: String, Codable, CaseIterable, Identifiable {
    case base, topping, dressing, sprinkle, side

    var id: String { rawValue }

    var title: String {
        switch self {
        case .base: "Base"
        case .topping: "Toppings"
        case .dressing: "Dressing"
        case .sprinkle: "Sprinkles"
        case .side: "On the side"
        }
    }

    var symbol: String {
        switch self {
        case .base: "leaf"
        case .topping: "carrot"
        case .dressing: "drop"
        case .sprinkle: "sparkles"
        case .side: "takeoutbag.and.cup.and.straw"
        }
    }

    /// How many items of this category a bowl may hold.
    var limit: Int {
        switch self {
        case .base: 2          // two bases = half & half
        case .topping: 12
        case .dressing: 2
        case .sprinkle: 3
        case .side: 1
        }
    }

    var rule: String {
        switch self {
        case .base: "Pick 1 base, or 2 for half & half."
        case .topping: "6 standard toppings included. Extra standard and premium toppings are chargeable."
        case .dressing: "Made in-house in small batches every morning."
        case .sprinkle: "Finish with a sprinkle."
        case .side: "One complimentary side."
        }
    }
}

enum Allergen: String, Codable, CaseIterable, Identifiable {
    case dairy, nuts, gluten, meat, seafood, allium

    var id: String { rawValue }

    var title: String { rawValue.capitalized }
    var freeTitle: String { "\(title) free" }

    var symbol: String {
        switch self {
        case .dairy: "drop.circle"
        case .nuts: "tree"
        case .gluten: "laurel.leading"
        case .meat: "fork.knife"
        case .seafood: "fish"
        case .allium: "allergens"
        }
    }
}

enum Diet: String, Codable, CaseIterable, Identifiable {
    case vegan
    case vegetarian
    case highProtein = "high-protein"
    case lowCarb = "low-carb"
    case lowCalorie = "low-calorie"
    case keto
    case paleo
    case heartHealthy = "heart-healthy"
    case antiInflammatory = "anti-inflammatory"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vegan: "Vegan"
        case .vegetarian: "Vegetarian"
        case .highProtein: "High Protein"
        case .lowCarb: "Low Carb"
        case .lowCalorie: "Low Calorie"
        case .keto: "Keto"
        case .paleo: "Paleo"
        case .heartHealthy: "Heart Healthy"
        case .antiInflammatory: "Anti-Inflammatory"
        }
    }

    var symbol: String {
        switch self {
        case .vegan: "leaf.fill"
        case .vegetarian: "carrot.fill"
        case .highProtein: "dumbbell.fill"
        case .lowCarb: "chart.bar.xaxis"
        case .lowCalorie: "flame"
        case .keto: "drop.triangle"
        case .paleo: "mountain.2"
        case .heartHealthy: "heart.fill"
        case .antiInflammatory: "shield.lefthalf.filled"
        }
    }
}

struct Ingredient: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: IngredientCategory
    /// "standard" / "premium" for bases & toppings, "asian" / "western" for dressings,
    /// "sprinkles" / "complimentary" for extras.
    let tier: String
    let imageURL: URL?
    let allergens: Set<Allergen>
    let diets: Set<Diet>
    /// Carbon footprint in grams of CO₂e, when published.
    let carbonGrams: Double?
    let nutrition: NutritionFacts

    var isPremium: Bool { tier == "premium" }
    var isStandardTopping: Bool { category == .topping && tier == "standard" }
    /// A protein-forward ingredient (chicken, salmon, tofu…).
    var isProteinHero: Bool { nutrition.protein >= 9 }

    var tierTitle: String {
        switch tier {
        case "premium": "Premium"
        case "standard": "Standard"
        case "asian": "Asian"
        case "western": "Western"
        case "complimentary": "Complimentary"
        case "sprinkles": "Sprinkle"
        default: tier.capitalized
        }
    }

    var sortedAllergens: [Allergen] { Allergen.allCases.filter { allergens.contains($0) } }
    var sortedDiets: [Diet] { Diet.allCases.filter { diets.contains($0) } }

    func isAllowed(excluding avoided: Set<Allergen>, diets required: Set<Diet>) -> Bool {
        avoided.isDisjoint(with: allergens) && required.isSubset(of: diets)
    }

    /// Protein grams per 100 kcal — a quick "protein density" read.
    var proteinPer100kcal: Double {
        nutrition.calories > 0 ? nutrition.protein / nutrition.calories * 100 : 0
    }
}

/// Fast lookup + bowl maths over the full ingredient list.
struct Catalog {
    let all: [Ingredient]
    let byID: [String: Ingredient]

    init(_ ingredients: [Ingredient]) {
        all = ingredients
        byID = Dictionary(ingredients.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    static func loadBundled() -> Catalog {
        guard let url = Bundle.main.url(forResource: "ingredients", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            assertionFailure("ingredients.json missing from the app bundle")
            return Catalog([])
        }
        do {
            return Catalog(try JSONDecoder().decode([Ingredient].self, from: data))
        } catch {
            assertionFailure("Could not decode ingredients.json: \(error)")
            return Catalog([])
        }
    }

    func items(in category: IngredientCategory) -> [Ingredient] {
        all.filter { $0.category == category }
    }

    /// Resolved lines (ingredient + effective portion factor) for a bowl.
    func lines(for bowl: Bowl) -> [BowlLine] {
        let baseCount = bowl.items.filter { $0.category == .base }.count
        return bowl.items.compactMap { item in
            guard let ingredient = byID[item.ingredientID] else { return nil }
            var factor = item.portion.rawValue
            if item.category == .base && baseCount > 1 {
                factor /= Double(baseCount) // half & half
            }
            return BowlLine(ingredient: ingredient, item: item, factor: factor)
        }
    }

    func nutrition(for bowl: Bowl) -> NutritionFacts {
        lines(for: bowl).reduce(into: NutritionFacts.zero) { $0 += $1.nutrition }
    }

    func carbonGrams(for bowl: Bowl) -> Double {
        lines(for: bowl).reduce(0) { $0 + ($1.ingredient.carbonGrams ?? 0) * $1.factor }
    }
}
