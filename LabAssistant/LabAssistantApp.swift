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
import Combine

enum LabAssistantLaunchConfiguration {
    static let uiTestingArgument = "-ui-testing"
    static let uiTestingExampleDataArgument = "-ui-testing-example-data"

    static var isRunningUITests: Bool {
        ProcessInfo.processInfo.arguments.contains(uiTestingArgument)
    }

    /// UI tests and screenshot runs use in-memory storage without CloudKit; show a healthy sync state in the UI.
    static var shouldSimulateCloudKitSyncedStatus: Bool {
        isRunningUITests
    }

    static var shouldSeedExampleData: Bool {
        ProcessInfo.processInfo.arguments.contains(uiTestingExampleDataArgument)
    }

#if DEBUG
    static let debugShowReviewBannerArgument = "-debug-show-review-banner"
    static let debugShowProBannerArgument = "-debug-show-pro-banner"
    static let debugResetPromotionMetricsArgument = "-debug-reset-promotion-metrics"
    static let debugSeedReviewEligibleArgument = "-debug-seed-review-eligible"
    static let debugSeedProEligibleArgument = "-debug-seed-pro-eligible"

    static var debugShowReviewBanner: Bool {
        ProcessInfo.processInfo.arguments.contains(debugShowReviewBannerArgument)
    }

    static var debugShowProBanner: Bool {
        ProcessInfo.processInfo.arguments.contains(debugShowProBannerArgument)
    }

    static var debugResetPromotionMetrics: Bool {
        ProcessInfo.processInfo.arguments.contains(debugResetPromotionMetricsArgument)
    }

    static var debugSeedReviewEligible: Bool {
        ProcessInfo.processInfo.arguments.contains(debugSeedReviewEligibleArgument)
    }

    static var debugSeedProEligible: Bool {
        ProcessInfo.processInfo.arguments.contains(debugSeedProEligibleArgument)
    }
#endif

    static let cloudKitContainerIdentifier = "iCloud.icloud.JackKroll.LabAssistant"

    static let schema = Schema([
        Chemical.self,
        Tag.self,
        DevProcess.self,
        SingleStep.self,
        SubstepProcess.self,
        TemperatureDuration.self
    ])

    static func makeModelConfiguration(isStoredInMemoryOnly: Bool) -> ModelConfiguration {
        ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly,
            cloudKitDatabase: isStoredInMemoryOnly ? .none : .automatic
        )
    }

    static func makeModelContainer() throws -> ModelContainer {
        let modelConfiguration = makeModelConfiguration(isStoredInMemoryOnly: isRunningUITests)

        let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        if shouldSeedExampleData {
            seedExampleData(in: container.mainContext)
        }
        return container
    }

    static func resetPersistentStore() throws {
        guard !isRunningUITests else { return }

        let modelConfiguration = makeModelConfiguration(isStoredInMemoryOnly: false)
        let storeURL = modelConfiguration.url

        let fileManager = FileManager.default
        let relatedPaths = [
            storeURL.path,
            storeURL.path + "-shm",
            storeURL.path + "-wal"
        ]

        for path in relatedPaths where fileManager.fileExists(atPath: path) {
            try fileManager.removeItem(atPath: path)
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

@MainActor
final class ModelStore: ObservableObject {
    @Published private(set) var container: ModelContainer?
    @Published private(set) var loadError: Error?
    @Published private(set) var isResetting = false

    init() {
        loadContainer(resetStore: false)
    }

    func loadContainer(resetStore: Bool) {
        isResetting = resetStore

        do {
            if resetStore {
                try LabAssistantLaunchConfiguration.resetPersistentStore()
            }
            container = try LabAssistantLaunchConfiguration.makeModelContainer()
            loadError = nil
        } catch {
            container = nil
            loadError = error
        }

        isResetting = false
    }
}

struct ModelContainerErrorView: View {
    let error: Error
    let onRetry: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 52))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.red)

            Text("Couldn't Open Your Data")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Text("Lab Assistant couldn't load its local database. Your data is still on this device, but the app needs a fresh local store to continue.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text(error.localizedDescription)
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button("Try Again", action: onRetry)
                .buttonStyle(.borderedProminent)
                .buttonSizing(.flexible)

            Button("Reset Local Data", role: .destructive, action: onReset)
                .buttonSizing(.flexible)

            Text("Resetting removes workflows and chemicals stored on this device. iCloud copies may download again after you sign back in.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }
}

@main
struct LabAssistantApp: App {
    @StateObject private var modelStore = ModelStore()
    @StateObject private var purchaseManager = PurchaseManager()
    @StateObject private var promotionBannerManager = PromotionBannerManager()

    @ViewBuilder
    private var rootContent: some View {
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

    var body: some Scene {
        WindowGroup {
            Group {
                if let container = modelStore.container {
                    rootContent
                        .modelContainer(container)
                } else if let error = modelStore.loadError {
                    ModelContainerErrorView(
                        error: error,
                        onRetry: { modelStore.loadContainer(resetStore: false) },
                        onReset: { modelStore.loadContainer(resetStore: true) }
                    )
                    .overlay {
                        if modelStore.isResetting {
                            ProgressView("Resetting local data…")
                                .padding()
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                } else {
                    ProgressView("Loading…")
                }
            }
            .environmentObject(purchaseManager)
            .environmentObject(promotionBannerManager)
            .onAppear {
                #if DEBUG
                promotionBannerManager.applyDebugMetricsConfigurationIfNeeded()
                #endif
                promotionBannerManager.recordAppLaunchIfNeeded()
                #if DEBUG
                promotionBannerManager.applyDebugBannerOverrideIfNeeded()
                #endif
            }
        }
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
