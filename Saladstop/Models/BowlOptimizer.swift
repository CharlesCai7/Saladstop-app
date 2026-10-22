//
//  BowlOptimizer.swift
//  Saladstop
//
//  Builds bowls that hit a set of macro targets using simulated annealing
//  over SaladStop's real ingredient list, while respecting allergens, diets
//  and anything the user has already put in their bowl.
//

import Foundation

struct BowlSuggestion: Identifiable, Hashable {
    let id = UUID()
    let bowl: Bowl
    let nutrition: NutritionFacts
    let matchPercent: Int
}

/// Small, fast, seedable RNG so "Shuffle" gives new bowls and tests are repeatable.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

struct BowlOptimizer {
    let catalog: Catalog
    let targets: MacroTargets
    /// Items the user already chose; these are kept as-is.
    let locked: Bowl
    var iterations = 3500
    var restarts = 8

    private let bases: [Ingredient]
    private let toppings: [Ingredient]
    private let dressings: [Ingredient]
    private let sprinkles: [Ingredient]

    private let fixedNutrition: NutritionFacts
    private let fixedToppingIDs: Set<String>
    private let fixedStandardCount: Int
    private let fixedPremiumCount: Int
    private let fixedHeroCount: Int
    private let basesFixed: Bool
    private let dressingFixed: Bool
    private let sprinkleFixed: Bool

    init(catalog: Catalog,
         targets: MacroTargets,
         avoiding allergens: Set<Allergen>,
         diets: Set<Diet>,
         keeping locked: Bowl = Bowl()) {
        self.catalog = catalog
        self.targets = targets
        self.locked = locked

        let allowed = catalog.all.filter { $0.isAllowed(excluding: allergens, diets: diets) }
        bases = allowed.filter { $0.category == .base }
        toppings = allowed.filter { $0.category == .topping }
        dressings = allowed.filter { $0.category == .dressing }
        sprinkles = allowed.filter { $0.category == .sprinkle }

        let lockedLines = catalog.lines(for: locked)
        fixedNutrition = lockedLines.reduce(into: NutritionFacts.zero) { $0 += $1.nutrition }
        let lockedToppings = lockedLines.filter { $0.ingredient.category == .topping }.map(\.ingredient)
        fixedToppingIDs = Set(lockedToppings.map(\.id))
        fixedStandardCount = lockedToppings.filter { !$0.isPremium }.count
        fixedPremiumCount = lockedToppings.filter(\.isPremium).count
        fixedHeroCount = lockedToppings.filter(\.isProteinHero).count
        basesFixed = locked.count(in: .base) > 0
        dressingFixed = locked.count(in: .dressing) > 0
        sprinkleFixed = locked.count(in: .sprinkle) > 0
    }

    // MARK: - Search state

    private struct State {
        var bases: [Ingredient] = []
        var toppings: [String: Portion] = [:]
        var dressing: Ingredient?
        var dressingPortion: Portion = .regular
        var sprinkle: Ingredient?
    }

    // MARK: - Public API

    func suggestions(count: Int = 3, seed: UInt64 = 42) -> [BowlSuggestion] {
        var rng = SplitMix64(seed: seed)
        var results: [(score: Double, state: State)] = []
        for _ in 0..<restarts {
            results.append(anneal(using: &rng))
        }
        results.sort { $0.score < $1.score }

        // Keep the picks meaningfully different from each other.
        var picked: [State] = []
        for candidate in results where picked.count < count {
            let ids = signature(of: candidate.state)
            let isDistinct = picked.allSatisfy { similarity(ids, signature(of: $0)) < 0.55 }
            if isDistinct { picked.append(candidate.state) }
        }
        for candidate in results where picked.count < count {
            if !picked.contains(where: { signature(of: $0) == signature(of: candidate.state) }) {
                picked.append(candidate.state)
            }
        }

        return picked.map { state in
            let bowl = makeBowl(from: state)
            let facts = catalog.nutrition(for: bowl)
            return BowlSuggestion(bowl: bowl, nutrition: facts, matchPercent: targets.matchPercent(for: facts))
        }
    }

    // MARK: - Annealing

    private func anneal(using rng: inout SplitMix64) -> (score: Double, state: State) {
        var current = initialState(using: &rng)
        var currentScore = score(current)
        var best = current
        var bestScore = currentScore

        for i in 0..<iterations {
            let temperature = 0.3 * (1 - Double(i) / Double(iterations)) + 0.0001
            var candidate = current
            mutate(&candidate, using: &rng)
            let candidateScore = score(candidate)
            let accept = candidateScore < currentScore
                || Double.random(in: 0..<1, using: &rng) < exp((currentScore - candidateScore) / temperature)
            if accept {
                current = candidate
                currentScore = candidateScore
                if currentScore < bestScore {
                    best = current
                    bestScore = currentScore
                }
            }
        }
        return (bestScore, best)
    }

    private func initialState(using rng: inout SplitMix64) -> State {
        var state = State()
        if !basesFixed, let base = bases.randomElement(using: &rng) {
            state.bases = [base]
        }
        let freeToppings = toppings.filter { !fixedToppingIDs.contains($0.id) }
        let wanted = max(0, 5 - fixedToppingIDs.count)
        for topping in freeToppings.shuffled(using: &rng).prefix(wanted) {
            state.toppings[topping.id] = .regular
        }
        if !dressingFixed {
            state.dressing = dressings.randomElement(using: &rng)
        }
        return state
    }

    private func mutate(_ state: inout State, using rng: inout SplitMix64) {
        let roll = Double.random(in: 0..<1, using: &rng)
        let totalToppings = state.toppings.count + fixedToppingIDs.count

        if roll < 0.12 {
            guard !basesFixed, let first = bases.randomElement(using: &rng) else { return }
            state.bases = [first]
            if Double.random(in: 0..<1, using: &rng) < 0.3,
               let second = bases.randomElement(using: &rng), second.id != first.id {
                state.bases.append(second)
            }
        } else if roll < 0.35 {
            guard totalToppings < 10, let pick = randomFreeTopping(excluding: state, using: &rng) else { return }
            state.toppings[pick.id] = .regular
        } else if roll < 0.50 {
            guard totalToppings > 3, let key = state.toppings.keys.randomElement(using: &rng) else { return }
            state.toppings.removeValue(forKey: key)
        } else if roll < 0.70 {
            guard let key = state.toppings.keys.randomElement(using: &rng),
                  let pick = randomFreeTopping(excluding: state, using: &rng) else { return }
            state.toppings.removeValue(forKey: key)
            state.toppings[pick.id] = .regular
        } else if roll < 0.78 {
            // Double up on a protein-ish topping (or undo it).
            guard let key = state.toppings.keys.randomElement(using: &rng),
                  let ingredient = catalog.byID[key] else { return }
            if state.toppings[key] == .double {
                state.toppings[key] = .regular
            } else if ingredient.nutrition.protein >= 5 {
                state.toppings[key] = .double
            }
        } else if roll < 0.90 {
            guard !dressingFixed else { return }
            state.dressing = Double.random(in: 0..<1, using: &rng) < 0.95
                ? dressings.randomElement(using: &rng)
                : nil
        } else if roll < 0.95 {
            guard !dressingFixed else { return }
            state.dressingPortion = Bool.random(using: &rng) ? .light : .regular
        } else {
            guard !sprinkleFixed else { return }
            state.sprinkle = Bool.random(using: &rng) ? nil : sprinkles.randomElement(using: &rng)
        }
    }

    private func randomFreeTopping(excluding state: State, using rng: inout SplitMix64) -> Ingredient? {
        let options = toppings.filter { !fixedToppingIDs.contains($0.id) && state.toppings[$0.id] == nil }
        return options.randomElement(using: &rng)
    }

    // MARK: - Scoring (lower is better)

    private func nutrition(of state: State) -> NutritionFacts {
        var facts = fixedNutrition
        let baseShare = state.bases.isEmpty ? 0 : 1 / Double(state.bases.count)
        for base in state.bases {
            facts += base.nutrition.scaled(by: baseShare)
        }
        for (id, portion) in state.toppings {
            if let topping = catalog.byID[id] {
                facts += topping.nutrition.scaled(by: portion.rawValue)
            }
        }
        if let dressing = state.dressing {
            facts += dressing.nutrition.scaled(by: state.dressingPortion.rawValue)
        }
        if let sprinkle = state.sprinkle {
            facts += sprinkle.nutrition
        }
        return facts
    }

    private func score(_ state: State) -> Double {
        let facts = nutrition(of: state)

        func term(_ value: Double, _ target: Double, floor: Double, weight: Double) -> Double {
            let delta = (value - target) / max(target, floor)
            return weight * delta * delta
        }

        var total = term(facts.calories, targets.calories, floor: 100, weight: 3)
            + term(facts.protein, targets.protein, floor: 5, weight: 2)
            + term(facts.carbs, targets.carbs, floor: 10, weight: 1)
            + term(facts.totalFat, targets.fat, floor: 5, weight: 1)

        // Keep it a salad: variety of veg, sensible topping count, not five meats.
        let freeToppings = state.toppings.keys.compactMap { catalog.byID[$0] }
        let standardCount = fixedStandardCount + freeToppings.filter { !$0.isPremium }.count
        let premiumCount = fixedPremiumCount + freeToppings.filter(\.isPremium).count
        let heroCount = fixedHeroCount + freeToppings.filter(\.isProteinHero).count
        let toppingCount = fixedToppingIDs.count + freeToppings.count

        total += 0.04 * Double(max(0, 4 - standardCount))
        total += 0.15 * Double(max(0, toppingCount - 8))
        total += 0.05 * Double(max(0, premiumCount - 3))
        total += 0.06 * Double(max(0, heroCount - 2))
        if !basesFixed && state.bases.isEmpty && !bases.isEmpty { total += 0.3 }
        if !dressingFixed && state.dressing == nil && !dressings.isEmpty { total += 0.08 }

        if facts.sodium > targets.sodiumMax {
            let over = (facts.sodium - targets.sodiumMax) / targets.sodiumMax
            total += 0.3 * over * over
        }
        if facts.fiber < targets.fiberMin {
            let under = (targets.fiberMin - facts.fiber) / max(targets.fiberMin, 1)
            total += 0.2 * under * under
        }
        return total
    }

    // MARK: - Helpers

    private func makeBowl(from state: State) -> Bowl {
        var bowl = locked
        bowl.id = UUID()
        bowl.createdAt = Date()
        for base in state.bases {
            bowl.items.append(BowlItem(ingredientID: base.id, category: .base))
        }
        // Proteins first, then the rest alphabetically, for a tidy read-out.
        let toppingIDs = state.toppings.keys.sorted { lhs, rhs in
            let l = catalog.byID[lhs], r = catalog.byID[rhs]
            let lp = l?.nutrition.protein ?? 0, rp = r?.nutrition.protein ?? 0
            return lp == rp ? (l?.name ?? "") < (r?.name ?? "") : lp > rp
        }
        for id in toppingIDs {
            bowl.items.append(BowlItem(ingredientID: id, category: .topping, portion: state.toppings[id] ?? .regular))
        }
        if let dressing = state.dressing {
            bowl.items.append(BowlItem(ingredientID: dressing.id, category: .dressing, portion: state.dressingPortion))
        }
        if let sprinkle = state.sprinkle {
            bowl.items.append(BowlItem(ingredientID: sprinkle.id, category: .sprinkle))
        }
        bowl.name = Self.suggestedName(for: bowl, catalog: catalog)
        return bowl
    }

    private func signature(of state: State) -> Set<String> {
        var ids = Set(state.toppings.keys)
        state.bases.forEach { ids.insert($0.id) }
        if let dressing = state.dressing { ids.insert(dressing.id) }
        return ids
    }

    private func similarity(_ a: Set<String>, _ b: Set<String>) -> Double {
        let union = a.union(b).count
        return union == 0 ? 1 : Double(a.intersection(b).count) / Double(union)
    }

    /// e.g. "Sous-vide Chicken Breast & Kale Bowl".
    static func suggestedName(for bowl: Bowl, catalog: Catalog) -> String {
        let lines = catalog.lines(for: bowl)
        let hero = lines
            .filter { $0.ingredient.category == .topping }
            .max { $0.nutrition.protein < $1.nutrition.protein }?
            .ingredient.name
        let base = lines.first { $0.ingredient.category == .base }?.ingredient.name
        switch (hero, base) {
        case let (hero?, base?): return "\(hero) & \(base) Bowl"
        case let (hero?, nil): return "\(hero) Bowl"
        case let (nil, base?): return "\(base) Bowl"
        default: return "My Bowl"
        }
    }
}
