//
//  LabAssistantApp.swift
//  LabAssistant
//
//  Created by Jack Kroll on 9/28/25.
//

import SwiftUI
import SwiftData

@main
struct LabAssistantApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Chemical.self,
            DevProcess.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            HomeScreenView()
        }
        .modelContainer(sharedModelContainer)
    }
}
