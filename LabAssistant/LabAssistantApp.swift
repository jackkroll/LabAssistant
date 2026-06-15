//
//  LabAssistantApp.swift
//  LabAssistant
//
//  Created by Jack Kroll on 9/28/25.
//

import SwiftUI
import SwiftData
import Onboarding
import Foundation

enum LabAssistantLaunchConfiguration {
    static let uiTestingArgument = "-ui-testing"
    static let uiTestingExampleDataArgument = "-ui-testing-example-data"

    static var isRunningUITests: Bool {
        ProcessInfo.processInfo.arguments.contains(uiTestingArgument)
    }

    static var shouldSeedExampleData: Bool {
        ProcessInfo.processInfo.arguments.contains(uiTestingExampleDataArgument)
    }

    static let schema = Schema([
        Chemical.self,
        Tag.self,
        DevProcess.self,
        SingleStep.self,
        SubstepProcess.self,
        TemperatureDuration.self
    ])

    static func makeModelContainer() -> ModelContainer {
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isRunningUITests
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            if shouldSeedExampleData {
                seedExampleData(in: container.mainContext)
            }
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    static func seedExampleData(in context: ModelContext) {
        let concentrate = Tag(title: "Concentrate")
        let workingSol = Tag(title: "Working Solution")

        let water = Chemical(
            nickname: "Distilled Water",
            expiryDate: nil,
            max: 1000,
            current: 850,
            notes: "",
            tags: [],
            units: .ml
        )

        let ddx = Chemical(
            nickname: "DD-X Concentrate",
            expiryDate: Calendar.current.date(byAdding: .month, value: 6, to: .now),
            max: 500,
            current: 250,
            notes: "",
            tags: [concentrate],
            units: .ml
        )
        
        let workingSolution = Chemical(
            nickname: "DD-X",
            expiryDate: Calendar.current.date(byAdding: .day, value: 7, to: .now),
            max: 1000,
            current: 100,
            notes: "",
            tags: [workingSol],
            units: .ml
        )
        
        let expired = Chemical(
            nickname: "DF96",
            expiryDate: .distantPast,
            max: 1000,
            current: 100,
            notes: "",
            tags: [workingSol],
            units: .ml
        )
        

        let agitation = SubstepProcess(title: "Agitation", duration: 10, gap: 50)
        let sampleSteps = [
            SingleStep(
                title: "Prepare Chemicals",
                index: 0,
                notes: "Set up the tank and organize chemicals",
                autoAdvance: true,
                associatedChemicals: [ddx, water],
                totalDuration: 120
            ),
            SingleStep(
                title: "Develop",
                index: 1,
                notes: "@ 20ºC",
                autoAdvance: false,
                associatedChemicals: [],
                totalDuration: 540,
                substep: agitation
            ),
            SingleStep(
                title: "Wash",
                index: 2,
                notes: "Rinse thoroughly.",
                autoAdvance: true,
                associatedChemicals: [water],
                totalDuration: 420
            )
        ]

        let process = DevProcess(
            nickname: "HP5+ in DD-X",
            notes: "",
            steps: sampleSteps
        )

        context.insert(workingSol)
        context.insert(concentrate)
        context.insert(water)
        context.insert(workingSolution)
        context.insert(ddx)
        context.insert(process)
        context.insert(expired)

        try? context.save()
    }
}

@main
struct LabAssistantApp: App {
    var sharedModelContainer: ModelContainer = LabAssistantLaunchConfiguration.makeModelContainer()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if LabAssistantLaunchConfiguration.isRunningUITests {
                    HomeScreenView()
                } else {
                    HomeScreenView()
                        .showOnboardingIfNeeded(
                            config: .production,
                            appIcon: Image("AppIcon")
                        )
                }
            }
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
