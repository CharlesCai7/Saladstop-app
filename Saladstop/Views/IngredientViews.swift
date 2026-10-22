//
//  IngredientViews.swift
//  Saladstop
//

import SwiftUI

/// Ingredient photo from saladstop.com.sg with an offline-friendly fallback.
struct IngredientThumb: View {
    var ingredient: Ingredient
    var size: CGFloat = 56

    var body: some View {
        AsyncImage(url: ingredient.imageURL, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit()
            default:
                placeholder
            }
        }
        .frame(width: size, height: size)
    }

    private var placeholder: some View {
        Circle()
            .fill(Theme.lime.opacity(0.18))
            .overlay(
                Image(systemName: ingredient.category.symbol)
                    .font(.system(size: size * 0.38))
                    .foregroundStyle(Theme.green)
            )
    }
}

struct TagChip: View {
    var title: String
    var systemImage: String?
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage) }
            Text(title)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(tint)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

/// Grid card used in the bowl builder.
struct IngredientCard: View {
    var ingredient: Ingredient
    var portion: Portion?
    var highlight: Nutrient?
    var isTopPick = false
    var onTap: () -> Void
    var onInfo: () -> Void

    private var isSelected: Bool { portion != nil }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    IngredientThumb(ingredient: ingredient, size: 76)
                        .frame(maxWidth: .infinity)
                    if let portion {
                        Text(portion.short)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Theme.green, in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
                Text(ingredient.name)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text("\(ingredient.nutrition.calories.whole) kcal")
                    if let highlight, highlight != .calories {
                        Text("·")
                        Text("\(highlight.formatted(highlight.value(in: ingredient.nutrition))) \(highlight.shortTitle.lowercased())")
                    } else {
                        Text("·")
                        Text("\(ingredient.nutrition.protein.compact)g protein")
                    }
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                HStack(spacing: 4) {
                    if ingredient.isPremium {
                        TagChip(title: "Premium", tint: Theme.carbs)
                    }
                    if isTopPick {
                        TagChip(title: "Fits goal", systemImage: "target", tint: Theme.green)
                    }
                }
                .frame(height: 22)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Theme.green : .clear, lineWidth: 2.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        // Sibling (not nested) button so it gets its own taps.
        .overlay(alignment: .topLeading) {
            Button(action: onInfo) {
                Image(systemName: "info.circle")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Nutrition info for \(ingredient.name)")
        }
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

/// List row used in Explore and bowl review.
struct IngredientRow: View {
    var ingredient: Ingredient
    var highlight: Nutrient = .protein

    var body: some View {
        HStack(spacing: 12) {
            IngredientThumb(ingredient: ingredient, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(ingredient.name).font(.body.weight(.medium))
                MacroInline(nutrition: ingredient.nutrition)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 0) {
                Text(highlight.formatted(highlight.value(in: ingredient.nutrition), withUnit: false))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Theme.color(for: highlight))
                Text(highlight == .calories ? "kcal" : "\(highlight.unit) \(highlight.shortTitle.lowercased())")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Full ingredient sheet: photo, tags, macros, nutrition label, carbon.
struct IngredientDetailView: View {
    @Environment(AppModel.self) var model
    @Environment(\.dismiss) var dismiss
    var ingredient: Ingredient

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    tags
                    macroTiles
                    CalorieSplitBar(nutrition: ingredient.nutrition)
                    if let carbon = ingredient.carbonGrams {
                        carbonCard(carbon)
                    }
                    NutritionLabelView(nutrition: ingredient.nutrition, title: "Per serving")
                }
                .padding()
            }
            .background(Theme.pageBackground)
            .navigationTitle(ingredient.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { addButton }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            IngredientThumb(ingredient: ingredient, size: 110)
            VStack(alignment: .leading, spacing: 6) {
                Text(ingredient.name).font(.title2.weight(.bold))
                Text("\(ingredient.category.title) · \(ingredient.tierTitle)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(ingredient.nutrition.servingGrams.whole) g serving")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var tags: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ingredient.sortedAllergens) { allergen in
                    TagChip(title: "Contains \(allergen.title.lowercased())", systemImage: "exclamationmark.triangle", tint: Theme.over)
                }
                ForEach(ingredient.sortedDiets) { diet in
                    TagChip(title: diet.title, systemImage: diet.symbol, tint: Theme.green)
                }
            }
        }
    }

    private var macroTiles: some View {
        HStack(spacing: 8) {
            ForEach(Macro.allCases) { macro in
                VStack(spacing: 2) {
                    Text(macro.nutrient.formatted(macro.value(ingredient.nutrition), withUnit: false))
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(macro.color)
                    Text(macro == .calories ? "kcal" : "\(macro.title) g")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(macro.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func carbonCard(_ grams: Double) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "globe.asia.australia.fill")
                .font(.title2)
                .foregroundStyle(Theme.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Carbon footprint: \((grams / 1000).formatted(.number.precision(.fractionLength(3)))) kg CO₂e")
                    .font(.subheadline.weight(.semibold))
                Text("Approximate emissions from all greenhouse gases associated with this ingredient.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    @ViewBuilder
    private var addButton: some View {
        let inBowl = model.bowl.contains(ingredient.id)
        let allowed = model.isAllowed(ingredient)
        VStack(spacing: 6) {
            if !allowed {
                Text("Doesn't match your allergen or diet filters")
                    .font(.caption)
                    .foregroundStyle(Theme.over)
            }
            Button {
                let result = model.toggle(ingredient)
                if result != .full { dismiss() }
            } label: {
                Label(inBowl ? "Remove from bowl" : "Add to bowl",
                      systemImage: inBowl ? "minus.circle.fill" : "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(inBowl ? Theme.over : Theme.green)
            .disabled(!inBowl && model.bowl.count(in: ingredient.category) >= ingredient.category.limit && ingredient.category.limit > 1)
        }
        .padding()
        .background(.bar)
    }
}
