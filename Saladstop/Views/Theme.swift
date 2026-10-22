//
//  Theme.swift
//  Saladstop
//

import SwiftUI

enum Theme {
    static let green = Color(red: 0.13, green: 0.47, blue: 0.27)
    static let lime = Color(red: 0.55, green: 0.76, blue: 0.24)
    static let cream = Color(red: 0.97, green: 0.96, blue: 0.91)

    static let calories = Color(red: 0.13, green: 0.55, blue: 0.32)
    static let protein = Color(red: 0.89, green: 0.37, blue: 0.29)
    static let carbs = Color(red: 0.95, green: 0.64, blue: 0.18)
    static let fat = Color(red: 0.25, green: 0.53, blue: 0.80)
    static let over = Color(red: 0.86, green: 0.25, blue: 0.22)

    static func color(for nutrient: Nutrient) -> Color {
        switch nutrient {
        case .calories: calories
        case .protein: protein
        case .carbs, .sugar, .addedSugar: carbs
        case .totalFat, .saturatedFat, .transFat: fat
        case .fiber: lime
        default: .secondary
        }
    }

    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let pageBackground = Color(uiColor: .systemGroupedBackground)
}

/// The four macros shown everywhere in the app.
enum Macro: CaseIterable, Identifiable {
    case calories, protein, carbs, fat

    var id: Self { self }

    var nutrient: Nutrient {
        switch self {
        case .calories: .calories
        case .protein: .protein
        case .carbs: .carbs
        case .fat: .totalFat
        }
    }

    var title: String { nutrient.shortTitle }
    var color: Color { Theme.color(for: nutrient) }

    func value(_ facts: NutritionFacts) -> Double { nutrient.value(in: facts) }

    func target(_ targets: MacroTargets) -> Double {
        switch self {
        case .calories: targets.calories
        case .protein: targets.protein
        case .carbs: targets.carbs
        case .fat: targets.fat
        }
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}
