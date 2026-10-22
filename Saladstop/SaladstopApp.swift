//
//  SaladstopApp.swift
//  Saladstop
//
//  Created by Interactive 3D Design on 22/10/26.
//

import SwiftUI

@main
struct SaladstopApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
    }
}
