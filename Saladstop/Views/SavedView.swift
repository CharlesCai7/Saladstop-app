//
//  SavedView.swift
//  Saladstop
//

import SwiftUI

struct SavedView: View {
    @Environment(AppModel.self) var model
    @State private var selected: Bowl?

    var body: some View {
        NavigationStack {
            Group {
                if model.savedBowls.isEmpty {
                    ContentUnavailableView(
                        "No saved bowls yet",
                        systemImage: "bookmark",
                        description: Text("Save a bowl from the builder or a suggestion to find it here.")
                    )
                } else {
                    List {
                        ForEach(model.savedBowls) { bowl in
                            Button {
                                selected = bowl
                            } label: {
                                SavedBowlRow(bowl: bowl)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .leading) {
                                Button("Build", systemImage: "takeoutbag.and.cup.and.straw") {
                                    model.use(bowl)
                                }
                                .tint(Theme.green)
                            }
                        }
                        .onDelete { model.deleteSaved(at: $0) }
                    }
                }
            }
            .navigationTitle("Saved")
            .toolbar {
                if !model.savedBowls.isEmpty {
                    EditButton()
                }
            }
            .sheet(item: $selected) { bowl in
                SavedBowlDetailView(bowl: bowl, isSaved: true)
            }
        }
    }
}

struct SavedBowlRow: View {
    @Environment(AppModel.self) var model
    var bowl: Bowl

    var body: some View {
        let facts = model.catalog.nutrition(for: bowl)
        let lines = model.catalog.lines(for: bowl)
        HStack(spacing: 12) {
            ZStack {
                ForEach(Array(lines.prefix(3).enumerated()), id: \.offset) { index, line in
                    IngredientThumb(ingredient: line.ingredient, size: 34)
                        .offset(x: CGFloat(index - 1) * 12, y: index == 1 ? -8 : 4)
                }
            }
            .frame(width: 64, height: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(bowl.name).font(.headline).lineLimit(2)
                MacroInline(nutrition: facts)
                Text(bowl.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 4)
            MatchBadge(percent: model.targets.matchPercent(for: facts))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

/// Read-only bowl view used for saved bowls and suggestion details.
struct SavedBowlDetailView: View {
    @Environment(AppModel.self) var model
    @Environment(\.dismiss) var dismiss
    var bowl: Bowl
    var isSaved: Bool

    var body: some View {
        let facts = model.catalog.nutrition(for: bowl)
        let lines = model.catalog.lines(for: bowl)
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Against your current target").font(.headline)
                            Spacer()
                            MatchBadge(percent: model.targets.matchPercent(for: facts))
                        }
                        MacroSummaryView(nutrition: facts, targets: model.targets)
                        CalorieSplitBar(nutrition: facts)
                    }
                    .padding(.vertical, 6)
                }
                ForEach(IngredientCategory.allCases) { category in
                    let rows = lines.filter { $0.ingredient.category == category }
                    if !rows.isEmpty {
                        Section(category.title) {
                            ForEach(rows) { line in
                                HStack(spacing: 12) {
                                    IngredientThumb(ingredient: line.ingredient, size: 40)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(line.ingredient.name)
                                        MacroInline(nutrition: line.nutrition)
                                    }
                                    Spacer()
                                    if line.item.portion != .regular {
                                        Text(line.item.portion.short).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                Section {
                    NutritionLabelView(nutrition: facts)
                        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                }
            }
            .navigationTitle(bowl.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Build this") {
                        model.use(bowl)
                        dismiss()
                    }
                }
                if isSaved {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            model.deleteSaved(bowl)
                            dismiss()
                        }
                        .tint(Theme.over)
                    }
                }
            }
        }
    }
}
