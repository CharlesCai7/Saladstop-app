//
//  Nutrition.swift
//  Saladstop
//
//  Nutrition facts for a single ingredient serving or a whole bowl,
//  plus the nutrient metadata used for labels, sorting and %DV.
//

import Foundation

struct NutritionFacts: Codable, Hashable {
    var servingGrams: Double = 0
    var calories: Double = 0
    var totalFat: Double = 0
    var saturatedFat: Double = 0
    var transFat: Double = 0
    var cholesterol: Double = 0
    var sodium: Double = 0
    var carbs: Double = 0
    var fiber: Double = 0
    var sugar: Double = 0
    var addedSugar: Double = 0
    var protein: Double = 0
    var calcium: Double = 0
    var iron: Double = 0
    var potassium: Double = 0
    var vitaminD: Double = 0
    var phosphorus: Double = 0

    static let zero = NutritionFacts()

    /// Returns these facts multiplied by `factor` (e.g. 0.5 for a light portion).
    func scaled(by factor: Double) -> NutritionFacts {
        NutritionFacts(
            servingGrams: servingGrams * factor,
            calories: calories * factor,
            totalFat: totalFat * factor,
            saturatedFat: saturatedFat * factor,
            transFat: transFat * factor,
            cholesterol: cholesterol * factor,
            sodium: sodium * factor,
            carbs: carbs * factor,
            fiber: fiber * factor,
            sugar: sugar * factor,
            addedSugar: addedSugar * factor,
            protein: protein * factor,
            calcium: calcium * factor,
            iron: iron * factor,
            potassium: potassium * factor,
            vitaminD: vitaminD * factor,
            phosphorus: phosphorus * factor
        )
    }

    static func + (lhs: NutritionFacts, rhs: NutritionFacts) -> NutritionFacts {
        NutritionFacts(
            servingGrams: lhs.servingGrams + rhs.servingGrams,
            calories: lhs.calories + rhs.calories,
            totalFat: lhs.totalFat + rhs.totalFat,
            saturatedFat: lhs.saturatedFat + rhs.saturatedFat,
            transFat: lhs.transFat + rhs.transFat,
            cholesterol: lhs.cholesterol + rhs.cholesterol,
            sodium: lhs.sodium + rhs.sodium,
            carbs: lhs.carbs + rhs.carbs,
            fiber: lhs.fiber + rhs.fiber,
            sugar: lhs.sugar + rhs.sugar,
            addedSugar: lhs.addedSugar + rhs.addedSugar,
            protein: lhs.protein + rhs.protein,
            calcium: lhs.calcium + rhs.calcium,
            iron: lhs.iron + rhs.iron,
            potassium: lhs.potassium + rhs.potassium,
            vitaminD: lhs.vitaminD + rhs.vitaminD,
            phosphorus: lhs.phosphorus + rhs.phosphorus
        )
    }

    static func += (lhs: inout NutritionFacts, rhs: NutritionFacts) {
        lhs = lhs + rhs
    }

    /// Share of calories coming from each macro (0...1).
    var calorieSplit: (protein: Double, carbs: Double, fat: Double) {
        let p = protein * 4, c = carbs * 4, f = totalFat * 9
        let total = p + c + f
        guard total > 0 else { return (0, 0, 0) }
        return (p / total, c / total, f / total)
    }
}

/// Every nutrient the SaladStop calculator reports.
enum Nutrient: String, CaseIterable, Identifiable, Codable {
    case calories, protein, carbs, totalFat, fiber, sugar, addedSugar
    case saturatedFat, transFat, cholesterol, sodium
    case calcium, iron, potassium, vitaminD, phosphorus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calories: "Calories"
        case .protein: "Protein"
        case .carbs: "Carbohydrates"
        case .totalFat: "Total Fat"
        case .fiber: "Dietary Fibre"
        case .sugar: "Total Sugars"
        case .addedSugar: "Added Sugars"
        case .saturatedFat: "Saturated Fat"
        case .transFat: "Trans Fat"
        case .cholesterol: "Cholesterol"
        case .sodium: "Sodium"
        case .calcium: "Calcium"
        case .iron: "Iron"
        case .potassium: "Potassium"
        case .vitaminD: "Vitamin D"
        case .phosphorus: "Phosphorus"
        }
    }

    var shortTitle: String {
        switch self {
        case .carbs: "Carbs"
        case .totalFat: "Fat"
        case .fiber: "Fibre"
        case .sugar: "Sugar"
        case .saturatedFat: "Sat. Fat"
        default: title
        }
    }

    var unit: String {
        switch self {
        case .calories: "kcal"
        case .protein, .carbs, .totalFat, .fiber, .sugar, .addedSugar, .saturatedFat, .transFat: "g"
        case .vitaminD: "mcg"
        default: "mg"
        }
    }

    /// FDA reference daily values (2,000 kcal diet).
    var dailyValue: Double? {
        switch self {
        case .calories: 2000
        case .protein: 50
        case .carbs: 275
        case .totalFat: 78
        case .fiber: 28
        case .sugar: nil
        case .addedSugar: 50
        case .saturatedFat: 20
        case .transFat: nil
        case .cholesterol: 300
        case .sodium: 2300
        case .calcium: 1300
        case .iron: 18
        case .potassium: 4700
        case .vitaminD: 20
        case .phosphorus: 1250
        }
    }

    var keyPath: KeyPath<NutritionFacts, Double> {
        switch self {
        case .calories: \.calories
        case .protein: \.protein
        case .carbs: \.carbs
        case .totalFat: \.totalFat
        case .fiber: \.fiber
        case .sugar: \.sugar
        case .addedSugar: \.addedSugar
        case .saturatedFat: \.saturatedFat
        case .transFat: \.transFat
        case .cholesterol: \.cholesterol
        case .sodium: \.sodium
        case .calcium: \.calcium
        case .iron: \.iron
        case .potassium: \.potassium
        case .vitaminD: \.vitaminD
        case .phosphorus: \.phosphorus
        }
    }

    func value(in facts: NutritionFacts) -> Double { facts[keyPath: keyPath] }

    func formatted(_ value: Double, withUnit: Bool = true) -> String {
        let number = self == .calories
            ? value.formatted(.number.precision(.fractionLength(0)))
            : value.formatted(.number.precision(.fractionLength(0...1)))
        return withUnit ? "\(number)\(self == .calories ? " " : "")\(unit)" : number
    }
}

extension Double {
    /// "12" or "12.5" — for compact nutrient read-outs.
    var compact: String { formatted(.number.precision(.fractionLength(0...1))) }
    var whole: String { formatted(.number.precision(.fractionLength(0))) }
}
