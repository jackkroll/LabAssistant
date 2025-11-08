//
//  LabAssistantApp.swift
//  LabAssistant
//
//  Created by Jack Kroll on 9/28/25.
//

import SwiftUI
import SwiftData
import Onboarding

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
                .showOnboardingIfNeeded(
                    config: .production,
                    appIcon: Image("AppIcon"),
                    dataPrivacyContent: {
                        
                    }
                )
            
        }
        .modelContainer(sharedModelContainer)
    }
}

extension OnboardingConfiguration {
    static let production = OnboardingConfiguration(
        accentColor: .red,
        appDisplayName: "Lab Assistant",
        features: [
            FeatureInfo(
                image: Image(systemName: "bookmark.fill"),
                title: "Save your workflows",
                content: "No need to flip through pages of notes and wind clocks. Your workflows just a click away"
            ),
            FeatureInfo(
                image: Image(systemName: "calendar"),
                title: "Stay on top of your chemicals",
                content: "No more questioning if the chemical you're going to use is expired. See exactly how much longer it has"
            ),
            FeatureInfo(
                image: Image(systemName: "list.number"),
                title: "Be as detailed as you need",
                content: "Your workflows can be as simple, or as complicated as they need to be"
            )
        ],
        titleSectionAlignment: .center
    )
}
