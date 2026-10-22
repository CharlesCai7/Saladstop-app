//
//  ContentView.swift
//  Saladstop
//
//  Created by Interactive 3D Design on 22/10/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            Tab("For You", systemImage: "sparkles", value: AppTab.forYou) {
                ForYouView()
            }
            Tab("Build", systemImage: "takeoutbag.and.cup.and.straw", value: AppTab.build) {
                BuilderView()
            }
            Tab("Explore", systemImage: "magnifyingglass", value: AppTab.explore) {
                ExploreView()
            }
            Tab("Saved", systemImage: "bookmark", value: AppTab.saved) {
                SavedView()
            }
            Tab("Goals", systemImage: "target", value: AppTab.goals) {
                GoalsView()
            }
        }
        .tint(Theme.green)
        .onChange(of: model.profile) { model.persist() }
        .onChange(of: model.bowl) { model.persist() }
        .onChange(of: model.savedBowls) { model.persist() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.persist() }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
}
