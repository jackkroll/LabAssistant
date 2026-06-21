//
//  UpsellContext.swift
//  LabAssistant
//

import Foundation

enum UpsellContext: Identifiable, Equatable {
    public static let freeProcessLimit: Int = 2
    case processLimit(current: Int, max: Int)
    case autoTime
    case presets

    var id: String {
        switch self {
        case .processLimit(let current, let max):
            "processLimit-\(current)-\(max)"
        case .autoTime:
            "autoTime"
        case .presets:
            "presets"
        }
    }

    var navigationTitle: String {
        switch self {
        case .processLimit:
            "Keep Building Workflows"
        case .autoTime:
            "Develop at Any Temperature"
        case .presets:
            "Save Your Go-To Times"
        }
    }

    var heroText: String {
        switch self {
        case .processLimit(let current, let max):
            "You've created \(current) of \(max) free workflows. Upgrade to Pro to save unlimited development processes and keep every workflow you rely on."
        case .autoTime:
            "Auto Time estimates development time for any bath temperature using your presets, so you do not have to recalculate when conditions change."
        case .presets:
            "Save temperature and time pairs for each step, then switch between them while editing or developing without re-entering values."
        }
    }

    var purchaseButtonTitle: String {
        switch self {
        case .processLimit:
            "Unlock Unlimited Processes"
        case .autoTime:
            "Enable Auto Time"
        case .presets:
            "Unlock Presets"
        }
    }

    var continueButtonTitle: String {
        switch self {
        case .processLimit:
            "Create Process"
        case .autoTime:
            "Set Up Auto Time"
        case .presets:
            "Add a Preset"
        }
    }

    var dismissesPaywallAfterPurchase: Bool {
        switch self {
        case .processLimit:
            false
        case .autoTime, .presets:
            true
        }
    }

    var reassuranceText: String {
        "One-time purchase. No subscription. Restore anytime."
    }

    var supportIndieText: String {
        "Your purchase supports continued development and keeps Lab Assistant free for everyone."
    }

    struct Feature: Identifiable, Equatable {
        let iconName: String
        let title: String
        let description: String

        var id: String { title }
    }

    var orderedFeatures: [Feature] {
        let unlimitedProcesses = Feature(
            iconName: "infinity",
            title: "Unlimited Processes",
            description: "Build and keep every workflow you use without limits."
        )
        let presets = Feature(
            iconName: "thermometer.medium",
            title: "Temperature/Time Presets",
            description: "Save development times for different temperatures and switch between them instantly."
        )
        let autoTime = Feature(
            iconName: "bolt.badge.clock.fill",
            title: "Auto Time",
            description: "Automatically calculate adjusted development time based on the current temperature."
        )

        switch self {
        case .processLimit:
            return [unlimitedProcesses, presets, autoTime]
        case .autoTime:
            return [autoTime, presets, unlimitedProcesses]
        case .presets:
            return [presets, autoTime, unlimitedProcesses]
        }
    }
}
