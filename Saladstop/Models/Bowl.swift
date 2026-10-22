//
//  Bowl.swift
//  Saladstop
//

import Foundation

enum Portion: Double, Codable, CaseIterable, Identifiable {
    case light = 0.5
    case regular = 1
    case double = 2

    var id: Double { rawValue }

    var title: String {
        switch self {
        case .light: "Light"
        case .regular: "Regular"
        case .double: "Double"
        }
    }

    var short: String {
        switch self {
        case .light: "½×"
        case .regular: "1×"
        case .double: "2×"
        }
    }
}

struct BowlItem: Codable, Hashable, Identifiable {
    var ingredientID: String
    var category: IngredientCategory
    var portion: Portion = .regular

    var id: String { ingredientID }
}

struct Bowl: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String = "My Bowl"
    var createdAt = Date()
    var items: [BowlItem] = []

    var isEmpty: Bool { items.isEmpty }

    func contains(_ ingredientID: String) -> Bool {
        items.contains { $0.ingredientID == ingredientID }
    }

    func portion(of ingredientID: String) -> Portion? {
        items.first { $0.ingredientID == ingredientID }?.portion
    }

    func count(in category: IngredientCategory) -> Int {
        items.filter { $0.category == category }.count
    }

    func items(in category: IngredientCategory) -> [BowlItem] {
        items.filter { $0.category == category }
    }

    enum ToggleResult { case added, removed, replaced, full }

    /// Adds or removes an ingredient, respecting category limits.
    /// Single-slot categories (sides) swap instead of refusing.
    @discardableResult
    mutating func toggle(_ ingredient: Ingredient) -> ToggleResult {
        if let index = items.firstIndex(where: { $0.ingredientID == ingredient.id }) {
            items.remove(at: index)
            return .removed
        }
        let category = ingredient.category
        if count(in: category) >= category.limit {
            guard category.limit == 1 else { return .full }
            items.removeAll { $0.category == category }
            items.append(BowlItem(ingredientID: ingredient.id, category: category))
            return .replaced
        }
        items.append(BowlItem(ingredientID: ingredient.id, category: category))
        return .added
    }

    mutating func setPortion(_ portion: Portion, for ingredientID: String) {
        guard let index = items.firstIndex(where: { $0.ingredientID == ingredientID }) else { return }
        items[index].portion = portion
    }

    mutating func remove(_ ingredientID: String) {
        items.removeAll { $0.ingredientID == ingredientID }
    }
}

/// One resolved row of a bowl: the ingredient and the effective portion factor
/// (portion × half-and-half split for bases).
struct BowlLine: Identifiable, Hashable {
    let ingredient: Ingredient
    let item: BowlItem
    let factor: Double

    var id: String { ingredient.id }
    var nutrition: NutritionFacts { ingredient.nutrition.scaled(by: factor) }
}
