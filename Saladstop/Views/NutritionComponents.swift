//
//  NutritionComponents.swift
//  Saladstop
//

import SwiftUI

/// Calorie progress ring against the bowl target.
struct CalorieRing: View {
    var value: Double
    var target: Double
    var size: CGFloat = 120
    var lineWidth: CGFloat = 12
    var showsLabel = true

    private var progress: Double { target > 0 ? value / target : 0 }
    private var isOver: Bool { progress > 1.05 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.calories.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(progress, 1))
                .stroke(isOver ? Theme.over : Theme.calories,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if showsLabel {
                VStack(spacing: 0) {
                    Text(value.whole)
                        .font(.system(size: size * 0.24, weight: .bold, design: .rounded))
                        .contentTransition(.numericText(value: value))
                    Text("of \(target.whole) kcal")
                        .font(.system(size: max(9, size * 0.095)))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .animation(.snappy, value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value.whole) of \(target.whole) calories")
    }
}

/// A labelled bar for one macro, with the target as 100%.
struct MacroBar: View {
    var macro: Macro
    var value: Double
    var target: Double
    var compact = false

    private var progress: Double { target > 0 ? value / target : 0 }
    private var isOver: Bool { progress > 1.1 }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(macro.title)
                    .font(compact ? .caption2.weight(.semibold) : .subheadline.weight(.semibold))
                Spacer(minLength: 4)
                Text("\(value.whole)\(compact ? "" : " / \(target.whole)")g")
                    .font(compact ? .caption2.monospacedDigit() : .subheadline.monospacedDigit())
                    .foregroundStyle(isOver ? Theme.over : .secondary)
                    .contentTransition(.numericText(value: value))
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(macro.color.opacity(0.15))
                    Capsule()
                        .fill(isOver ? Theme.over : macro.color)
                        .frame(width: proxy.size.width * min(progress, 1))
                }
            }
            .frame(height: compact ? 5 : 8)
        }
        .animation(.snappy, value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(macro.title) \(value.whole) of \(target.whole) grams")
    }
}

/// Ring + macro bars + match score.
struct MacroSummaryView: View {
    var nutrition: NutritionFacts
    var targets: MacroTargets

    var body: some View {
        HStack(spacing: 20) {
            CalorieRing(value: nutrition.calories, target: targets.calories, size: 116)
            VStack(spacing: 12) {
                ForEach([Macro.protein, .carbs, .fat]) { macro in
                    MacroBar(macro: macro, value: macro.value(nutrition), target: macro.target(targets))
                }
            }
        }
    }
}

struct MatchBadge: View {
    var percent: Int

    private var color: Color {
        switch percent {
        case 90...: Theme.green
        case 75..<90: Theme.lime
        case 50..<75: Theme.carbs
        default: .secondary
        }
    }

    var body: some View {
        Label("\(percent)% match" as String, systemImage: "target")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(color)
            .background(color.opacity(0.14), in: Capsule())
    }
}

/// Tiny "kcal · P · C · F" row.
struct MacroInline: View {
    var nutrition: NutritionFacts

    var body: some View {
        HStack(spacing: 10) {
            Text("\(nutrition.calories.whole) kcal").fontWeight(.semibold)
            dot("P", nutrition.protein, Theme.protein)
            dot("C", nutrition.carbs, Theme.carbs)
            dot("F", nutrition.totalFat, Theme.fat)
        }
        .font(.caption.monospacedDigit())
    }

    private func dot(_ letter: String, _ value: Double, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(letter) \(value.whole)g")
        }
        .foregroundStyle(.secondary)
    }
}

/// Macro target tiles (used on Goals and For You).
struct TargetTiles: View {
    var targets: MacroTargets

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Macro.allCases) { macro in
                VStack(spacing: 2) {
                    Text(macro.target(targets).whole)
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(macro.color)
                        .contentTransition(.numericText(value: macro.target(targets)))
                    Text(macro == .calories ? "kcal" : "\(macro.title) g")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(macro.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .animation(.snappy, value: targets)
    }
}

/// Classic nutrition-facts panel with % daily values.
struct NutritionLabelView: View {
    var nutrition: NutritionFacts
    var title = "Nutrition Facts"

    private struct Row: Identifiable {
        let nutrient: Nutrient
        let indent: Bool
        let bold: Bool
        var id: Nutrient { nutrient }
    }

    private static let macroRows: [Row] = [
        Row(nutrient: .totalFat, indent: false, bold: true),
        Row(nutrient: .saturatedFat, indent: true, bold: false),
        Row(nutrient: .transFat, indent: true, bold: false),
        Row(nutrient: .cholesterol, indent: false, bold: true),
        Row(nutrient: .sodium, indent: false, bold: true),
        Row(nutrient: .carbs, indent: false, bold: true),
        Row(nutrient: .fiber, indent: true, bold: false),
        Row(nutrient: .sugar, indent: true, bold: false),
        Row(nutrient: .addedSugar, indent: true, bold: false),
        Row(nutrient: .protein, indent: false, bold: true),
    ]

    private static let microRows: [Row] = [
        Row(nutrient: .vitaminD, indent: false, bold: false),
        Row(nutrient: .calcium, indent: false, bold: false),
        Row(nutrient: .iron, indent: false, bold: false),
        Row(nutrient: .potassium, indent: false, bold: false),
        Row(nutrient: .phosphorus, indent: false, bold: false),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.title2.weight(.black))
            Text("Serving size \(nutrition.servingGrams.whole) g")
                .font(.subheadline)
                .padding(.bottom, 4)
            thickRule
            HStack(alignment: .lastTextBaseline) {
                Text("Calories").font(.title3.weight(.heavy))
                Spacer()
                Text(nutrition.calories.whole).font(.title.weight(.heavy).monospacedDigit())
            }
            .padding(.vertical, 2)
            thickRule
            HStack {
                Spacer()
                Text(verbatim: "% Daily Value*").font(.caption.weight(.bold))
            }
            .padding(.vertical, 3)
            ForEach(Self.macroRows) { row in
                thinRule
                rowView(row)
            }
            thickRule
            ForEach(Self.microRows) { row in
                rowView(row)
                thinRule
            }
            Text(verbatim: "*% Daily Value is based on a 2,000 calorie diet. Nutritional information may vary depending on portioning.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
        .padding(14)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary, lineWidth: 1.5))
    }

    private func rowView(_ row: Row) -> some View {
        let value = row.nutrient.value(in: nutrition)
        return HStack {
            Text(row.nutrient.title)
                .fontWeight(row.bold ? .bold : .regular)
            Text(row.nutrient.formatted(value))
            Spacer()
            if let dv = row.nutrient.dailyValue {
                Text(verbatim: "\(Int((value / dv * 100).rounded()))%")
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
        }
        .font(.subheadline)
        .padding(.leading, row.indent ? 16 : 0)
        .padding(.vertical, 3)
    }

    private var thickRule: some View {
        Rectangle().fill(Color.primary).frame(height: 6).padding(.vertical, 2)
    }

    private var thinRule: some View {
        Rectangle().fill(Color.primary.opacity(0.6)).frame(height: 0.5)
    }
}

/// Stacked bar of where the calories come from.
struct CalorieSplitBar: View {
    var nutrition: NutritionFacts

    var body: some View {
        let split = nutrition.calorieSplit
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                HStack(spacing: 2) {
                    Theme.protein.frame(width: max(0, proxy.size.width * split.protein - 1))
                    Theme.carbs.frame(width: max(0, proxy.size.width * split.carbs - 1))
                    Theme.fat.frame(width: max(0, proxy.size.width * split.fat - 1))
                }
                .clipShape(Capsule())
            }
            .frame(height: 10)
            HStack(spacing: 12) {
                legend("Protein", split.protein, Theme.protein)
                legend("Carbs", split.carbs, Theme.carbs)
                legend("Fat", split.fat, Theme.fat)
            }
            .font(.caption)
        }
    }

    private func legend(_ title: String, _ share: Double, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(verbatim: "\(title) \(Int((share * 100).rounded()))%").foregroundStyle(.secondary)
        }
    }
}
