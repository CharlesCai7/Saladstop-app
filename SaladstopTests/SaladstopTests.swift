//
//  SaladstopTests.swift
//  SaladstopTests
//
//  Created by Interactive 3D Design on 22/10/26.
//

import Foundation
import Testing
@testable import Saladstop

@MainActor
struct SaladstopTests {
    let catalog = Catalog.loadBundled()

    @Test func catalogLoadsEveryIngredient() {
        #expect(catalog.all.count == 96)
        #expect(catalog.items(in: .base).count == 8)
        #expect(catalog.items(in: .dressing).count == 20)
        #expect(catalog.byID["base-romaine"]?.nutrition.calories == 15)
    }

    @Test func halfAndHalfBasesSplitThePortion() throws {
        let romaine = try #require(catalog.byID["base-romaine"])
        let kale = try #require(catalog.byID["base-kale"])
        var bowl = Bowl()
        bowl.toggle(romaine)
        bowl.toggle(kale)
        let facts = catalog.nutrition(for: bowl)
        #expect(abs(facts.calories - (15 + 28) / 2) < 0.001)
    }

    @Test func categoryLimitsAreEnforced() throws {
        var bowl = Bowl()
        let bases = catalog.items(in: .base)
        let first = bowl.toggle(bases[0])
        let second = bowl.toggle(bases[1])
        let third = bowl.toggle(bases[2])
        #expect(first == .added)
        #expect(second == .added)
        #expect(third == .full)

        let sides = catalog.items(in: .side)
        bowl.toggle(sides[0])
        let swapped = bowl.toggle(sides[1])
        #expect(swapped == .replaced)
        #expect(bowl.count(in: .side) == 1)
    }

    @Test func profileTargetsFollowMifflinStJeor() {
        var profile = NutritionProfile()
        profile.sex = .male
        profile.age = 30
        profile.heightCm = 175
        profile.weightKg = 70
        #expect(abs(profile.bmr - 1648.75) < 0.01)
        profile.activity = .sedentary
        profile.goal = .maintain
        profile.mealShare = 0.5
        #expect(profile.computedTargets.calories == 990)
    }

    @Test func optimizerHitsTargets() {
        let targets = MacroTargets(calories: 550, protein: 40, carbs: 45, fat: 22)
        let optimizer = BowlOptimizer(catalog: catalog, targets: targets, avoiding: [], diets: [])
        let picks = optimizer.suggestions(count: 3, seed: 7)
        #expect(picks.count == 3)
        for pick in picks {
            #expect(pick.matchPercent >= 80)
            #expect(pick.bowl.count(in: .base) >= 1)
        }
    }

    @Test func optimizerRespectsAllergensAndDiets() {
        let targets = MacroTargets(calories: 500, protein: 25, carbs: 50, fat: 22)
        let optimizer = BowlOptimizer(catalog: catalog, targets: targets, avoiding: [.dairy, .gluten], diets: [.vegan])
        for pick in optimizer.suggestions(count: 3, seed: 3) {
            for line in catalog.lines(for: pick.bowl) {
                #expect(line.ingredient.allergens.isDisjoint(with: [.dairy, .gluten]))
                #expect(line.ingredient.diets.contains(.vegan))
            }
        }
    }

    @Test func optimizerKeepsLockedItems() throws {
        let salmon = try #require(catalog.byID["topping-smoked-salmon"])
        var locked = Bowl()
        locked.toggle(salmon)
        let targets = MacroTargets(calories: 500, protein: 35, carbs: 35, fat: 22)
        let optimizer = BowlOptimizer(catalog: catalog, targets: targets, avoiding: [], diets: [], keeping: locked)
        for pick in optimizer.suggestions(count: 2, seed: 11) {
            #expect(pick.bowl.contains(salmon.id))
        }
    }
}
