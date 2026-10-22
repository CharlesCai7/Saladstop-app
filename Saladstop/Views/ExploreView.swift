//
//  ExploreView.swift
//  Saladstop
//
//  Browse and rank every ingredient by any nutrient.
//

import SwiftUI

struct ExploreView: View {
    @Environment(AppModel.self) private var model

    @State private var search = ""
    @State private var category: IngredientCategory?
    @State private var nutrient: Nutrient = .protein
    @State private var ascending = false
    @State private var perCalorie = false
    @State private var onlyMatching = true
    @State private var detail: Ingredient?

    private let sortableNutrients: [Nutrient] = [
        .calories, .protein, .carbs, .totalFat, .fiber, .sugar, .sodium,
        .saturatedFat, .potassium, .calcium, .iron, .phosphorus,
    ]

    private var results: [Ingredient] {
        let query = search.trimmingCharacters(in: .whitespaces)
        let filtered = model.catalog.all.filter { ingredient in
            (category == nil || ingredient.category == category)
                && (!onlyMatching || model.isAllowed(ingredient))
                && (query.isEmpty || ingredient.name.localizedCaseInsensitiveContains(query))
        }
        return filtered.sorted { lhs, rhs in
            let l = sortValue(lhs), r = sortValue(rhs)
            return ascending ? l < r : l > r
        }
    }

    private func sortValue(_ ingredient: Ingredient) -> Double {
        let value = nutrient.value(in: ingredient.nutrition)
        guard perCalorie, nutrient != .calories else { return value }
        return ingredient.nutrition.calories > 0 ? value / ingredient.nutrition.calories * 100 : 0
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            categoryChip(nil, title: "All")
                            ForEach(IngredientCategory.allCases) { category in
                                categoryChip(category, title: category.title)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(results) { ingredient in
                        Button {
                            detail = ingredient
                        } label: {
                            IngredientRow(ingredient: ingredient, highlight: nutrient)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button {
                                model.toggle(ingredient)
                            } label: {
                                Label(model.bowl.contains(ingredient.id) ? "Remove" : "Add",
                                      systemImage: model.bowl.contains(ingredient.id) ? "minus" : "plus")
                            }
                            .tint(model.bowl.contains(ingredient.id) ? Theme.over : Theme.green)
                        }
                    }
                } header: {
                    Text(headerText)
                } footer: {
                    if results.isEmpty {
                        Text("Nothing matches. Try another search or turn off “Only my filters”.")
                    } else {
                        Text("Swipe left on an ingredient to add it to your bowl.")
                    }
                }
            }
            .navigationTitle("Explore")
            .searchable(text: $search, prompt: "Search ingredients")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Rank by", selection: $nutrient) {
                            ForEach(sortableNutrients) { n in
                                Text(n.title).tag(n)
                            }
                        }
                        Toggle("Lowest first", isOn: $ascending)
                        Toggle("Per 100 kcal", isOn: $perCalorie)
                        Divider()
                        Toggle("Only my filters", isOn: $onlyMatching)
                    } label: {
                        Label("Rank", systemImage: "arrow.up.arrow.down.circle")
                    }
                }
            }
            .sheet(item: $detail) { ingredient in
                IngredientDetailView(ingredient: ingredient)
            }
        }
    }

    private var headerText: String {
        let order = ascending ? "lowest" : "highest"
        let unit = perCalorie && nutrient != .calories ? " per 100 kcal" : ""
        return "\(results.count) ingredients · \(order) \(nutrient.title.lowercased())\(unit)"
    }

    private func categoryChip(_ value: IngredientCategory?, title: String) -> some View {
        let selected = category == value
        return Button {
            withAnimation(.snappy) { category = value }
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(selected ? Theme.green : Theme.cardBackground, in: Capsule())
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}
