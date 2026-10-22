//
//  NutritionGoal.swift
//  Saladstop
//
//  The user's profile → per-bowl macro targets.
//

import Foundation

enum Sex: String, Codable, CaseIterable, Identifiable {
    case female, male
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary, light, moderate, active, athlete

    var id: String { rawValue }

    var factor: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .active: 1.725
        case .athlete: 1.9
        }
    }

    var title: String {
        switch self {
        case .sedentary: "Sedentary"
        case .light: "Lightly active"
        case .moderate: "Moderately active"
        case .active: "Very active"
        case .athlete: "Athlete"
        }
    }

    var detail: String {
        switch self {
        case .sedentary: "Desk job, little exercise"
        case .light: "Exercise 1–3 days a week"
        case .moderate: "Exercise 3–5 days a week"
        case .active: "Hard exercise 6–7 days a week"
        case .athlete: "Twice-a-day training"
        }
    }
}

enum WeightGoal: String, Codable, CaseIterable, Identifiable {
    case lose, maintain, gain

    var id: String { rawValue }

    var factor: Double {
        switch self {
        case .lose: 0.8
        case .maintain: 1.0
        case .gain: 1.1
        }
    }

    var title: String {
        switch self {
        case .lose: "Lose fat"
        case .maintain: "Maintain"
        case .gain: "Build muscle"
        }
    }
}

enum MacroStyle: String, Codable, CaseIterable, Identifiable {
    case balanced, highProtein, lowCarb, keto

    var id: String { rawValue }

    /// Share of calories from protein / carbs / fat.
    var split: (protein: Double, carbs: Double, fat: Double) {
        switch self {
        case .balanced: (protein: 0.25, carbs: 0.45, fat: 0.30)
        case .highProtein: (protein: 0.35, carbs: 0.35, fat: 0.30)
        case .lowCarb: (protein: 0.30, carbs: 0.20, fat: 0.50)
        case .keto: (protein: 0.25, carbs: 0.07, fat: 0.68)
        }
    }

    var title: String {
        switch self {
        case .balanced: "Balanced"
        case .highProtein: "High Protein"
        case .lowCarb: "Low Carb"
        case .keto: "Keto"
        }
    }

    var detail: String {
        let s = split
        return "P \(Int(s.protein * 100))% · C \(Int(s.carbs * 100))% · F \(Int(s.fat * 100))%"
    }

    var symbol: String {
        switch self {
        case .balanced: "circle.grid.cross"
        case .highProtein: "dumbbell.fill"
        case .lowCarb: "chart.bar.xaxis"
        case .keto: "drop.triangle.fill"
        }
    }
}

struct MacroTargets: Codable, Hashable {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiberMin: Double = 8
    var sodiumMax: Double = 900

    /// 0–100: how closely `facts` hits calories, protein, carbs and fat.
    func matchPercent(for facts: NutritionFacts) -> Int {
        let pairs: [(Double, Double, Double)] = [
            (facts.calories, calories, 100),
            (facts.protein, protein, 10),
            (facts.carbs, carbs, 10),
            (facts.totalFat, fat, 10),
        ]
        let accuracy = pairs.map { value, target, floor in
            max(0, 1 - abs(value - target) / max(target, floor))
        }
        return Int((accuracy.reduce(0, +) / Double(accuracy.count) * 100).rounded())
    }

    func target(for nutrient: Nutrient) -> Double? {
        switch nutrient {
        case .calories: calories
        case .protein: protein
        case .carbs: carbs
        case .totalFat: fat
        case .fiber: fiberMin
        case .sodium: sodiumMax
        default: nil
        }
    }
}

struct NutritionProfile: Codable, Hashable {
    var sex: Sex = .female
    var age: Int = 30
    var heightCm: Double = 165
    var weightKg: Double = 60
    var activity: ActivityLevel = .moderate
    var goal: WeightGoal = .maintain
    var style: MacroStyle = .balanced
    /// Fraction of the day's calories this bowl should cover.
    var mealShare: Double = 0.35

    var useCustomTargets = false
    var customTargets = MacroTargets(calories: 550, protein: 35, carbs: 50, fat: 22)

    var avoidedAllergens: Set<Allergen> = []
    var requiredDiets: Set<Diet> = []

    var hasSetGoals = false

    /// Mifflin–St Jeor basal metabolic rate (kcal/day).
    var bmr: Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return sex == .male ? base + 5 : base - 161
    }

    var dailyCalories: Double { bmr * activity.factor * goal.factor }

    var computedTargets: MacroTargets {
        let kcal = (dailyCalories * mealShare / 10).rounded() * 10
        let split = style.split
        var protein = kcal * split.protein / 4
        if goal == .gain {
            // Make sure muscle-building plans get at least ~0.5 g/kg per bowl.
            protein = max(protein, weightKg * 0.5)
        }
        return MacroTargets(
            calories: kcal,
            protein: protein.rounded(),
            carbs: (kcal * split.carbs / 4).rounded(),
            fat: (kcal * split.fat / 9).rounded(),
            fiberMin: style == .keto ? 6 : 8,
            sodiumMax: 900
        )
    }

    var targets: MacroTargets { useCustomTargets ? customTargets : computedTargets }

    var filterSummary: String? {
        let parts = sortedAvoided.map(\.freeTitle) + sortedDiets.map(\.title)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var sortedAvoided: [Allergen] { Allergen.allCases.filter { avoidedAllergens.contains($0) } }
    var sortedDiets: [Diet] { Diet.allCases.filter { requiredDiets.contains($0) } }
}
