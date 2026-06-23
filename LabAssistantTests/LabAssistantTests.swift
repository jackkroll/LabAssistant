import XCTest
import SwiftUI
@testable import LabAssistant

@MainActor
final class LabAssistantTests: XCTestCase {
    func testColorHexRoundTripsThroughHelpers() {
        let resolved = Color.Resolved(red: 84 / 255, green: 170 / 255, blue: 255 / 255)

        let hex = colorToHex(resolvedColor: resolved)
        XCTAssertEqual(hex, "54AAFF")

        let roundTripped = hexToColor(hex: hex).resolve(in: EnvironmentValues())
        XCTAssertEqual(roundTripped.red, resolved.red, accuracy: 0.001)
        XCTAssertEqual(roundTripped.green, resolved.green, accuracy: 0.001)
        XCTAssertEqual(roundTripped.blue, resolved.blue, accuracy: 0.001)
        XCTAssertEqual(roundTripped.opacity, resolved.opacity, accuracy: 0.001)
    }

    func testDevProcessEstimatedTimeUsesSortedStepDurations() {
        let lateStep = SingleStep(
            title: "Finish",
            index: 1,
            notes: "",
            autoAdvance: true,
            associatedChemicals: [],
            totalDuration: 45
        )
        let earlyStep = SingleStep(
            title: "Start",
            index: 0,
            notes: "",
            autoAdvance: true,
            associatedChemicals: [],
            totalDuration: 75
        )

        let process = DevProcess(nickname: "Demo", notes: "", steps: [lateStep, earlyStep])

        XCTAssertEqual(process.sortedSteps.map(\.title), ["Start", "Finish"])
        XCTAssertEqual(process.estTime, 120)
    }

    func testPresetStepSerializationPreservesNestedTimingData() throws {
        let substep = SubstepProcess(title: "Agitation", duration: 15, gap: 45)
        let preset = TemperatureDuration(temperature: 20, units: .celsius, duration: 540)
        let original = SingleStep(
            title: "Develop",
            index: 2,
            notes: "Watch carefully",
            autoAdvance: false,
            associatedChemicals: [],
            totalDuration: 540,
            requestedTemperature: 68,
            requestedTemperatureUnits: .fahrenheit,
            usesAutoTimeTiming: true,
            substep: substep,
            tempDuration: [preset]
        )

        let data = try PresetStepSerialization.encodeSteps([original])
        let decoded = PresetStepSerialization.decodeSteps(from: data).first!

        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.index, original.index)
        XCTAssertEqual(decoded.requestedTemperature, original.requestedTemperature)
        XCTAssertEqual(decoded.requestedTemperatureUnits, .fahrenheit)
        XCTAssertTrue(decoded.usesAutoTimeTiming)
        XCTAssertEqual(decoded.substep?.title, "Agitation")
        XCTAssertEqual(decoded.substep?.duration, 15)
        XCTAssertEqual(decoded.tempDuration?.first?.duration, 540)
        XCTAssertEqual(decoded.tempDuration?.first?.units, .celsius)
    }

    func testAutoTimeBasicUsesStandardKWithOnePreset() {
        let step = SingleStep(
            title: "Develop",
            index: 0,
            autoAdvance: true,
            associatedChemicals: [],
            requestedTemperature: 21,
            requestedTemperatureUnits: .celsius,
            tempDuration: [
                TemperatureDuration(temperature: 20, units: .celsius, duration: 600)
            ]
        )

        let estimate = step.timeEstimate(at: Measurement(value: 21, unit: UnitTemperature.celsius))

        XCTAssertEqual(step.autoTimeCalculationMode, .basic)
        if let est = estimate {
            XCTAssertEqual(est.estimatedK, 0.08, accuracy: 0.0001)
            XCTAssertEqual(est.duration, 600 * exp(-0.08), accuracy: 0.001)
        }
    }

    func testAutoTimeEnhancedUsesPresetRange() {
        let step = SingleStep(
            title: "Develop",
            index: 0,
            autoAdvance: true,
            associatedChemicals: [],
            requestedTemperature: 21,
            requestedTemperatureUnits: .celsius,
            tempDuration: [
                TemperatureDuration(temperature: 20, units: .celsius, duration: 600),
                TemperatureDuration(temperature: 24, units: .celsius, duration: 420)
            ]
        )

        XCTAssertEqual(step.autoTimeCalculationMode, .enhanced)
    }

    func testTagsCompareByTitleOnly() {
        let left = Tag(title: "Acid", storedColor: "FF0000")
        let right = Tag(title: "Acid", storedColor: "00FF00")

        XCTAssertEqual(left, right)
    }

    func testWorkflowEngagementRejectsFastCompletion() {
        XCTAssertFalse(
            WorkflowEngagement.isLegitimateCompletion(
                stepCount: 4,
                estimatedDuration: 600,
                elapsed: 5,
                furthestStepIndex: 3,
                reachedLastStep: true
            )
        )
    }

    func testWorkflowEngagementAcceptsReasonableCompletion() {
        XCTAssertTrue(
            WorkflowEngagement.isLegitimateCompletion(
                stepCount: 4,
                estimatedDuration: 600,
                elapsed: 60,
                furthestStepIndex: 3,
                reachedLastStep: true
            )
        )
    }

    func testWorkflowEngagementRequiresReachingFinalStep() {
        XCTAssertFalse(
            WorkflowEngagement.isLegitimateCompletion(
                stepCount: 4,
                estimatedDuration: 600,
                elapsed: 120,
                furthestStepIndex: 1,
                reachedLastStep: false
            )
        )
    }

    func testPromotionBannerPolicySuppressesReviewAfterAcceptance() {
        var metrics = PromotionBannerMetrics()
        metrics.reviewRequestedAt = Date()

        XCTAssertNil(
            PromotionBannerPolicy.activeBanner(
                metrics: metrics,
                processCount: 2,
                hasPro: false,
                moment: .sessionStart,
                now: Date()
            )
        )
    }

    func testPromotionBannerPolicyShowsReviewOnHopInForReturningUsers() {
        let metrics = PromotionBannerMetrics(
            visitCount: 3,
            legitimateCompletionCount: 2
        )

        XCTAssertEqual(
            PromotionBannerPolicy.activeBanner(
                metrics: metrics,
                processCount: 1,
                hasPro: false,
                moment: .sessionStart,
                now: Date()
            ),
            .review
        )
    }

    func testPromotionBannerPolicyShowsReviewWhenLeavingAfterLegitimateWorkflow() {
        let metrics = PromotionBannerMetrics(visitCount: 1)

        XCTAssertEqual(
            PromotionBannerPolicy.reviewBannerIfEligible(
                metrics: metrics,
                moment: .sessionEnd(completedLegitimately: true),
                now: Date()
            ),
            .review
        )
    }

    func testPromotionBannerPolicyDoesNotShowReviewOnHopInForFirstVisit() {
        let metrics = PromotionBannerMetrics(visitCount: 1)

        XCTAssertNil(
            PromotionBannerPolicy.reviewBannerIfEligible(
                metrics: metrics,
                moment: .sessionStart,
                now: Date()
            )
        )
    }

    func testPromotionBannerPolicyDoesNotShowReviewWhenLeavingWithoutCompleting() {
        let metrics = PromotionBannerMetrics(visitCount: 2, legitimateCompletionCount: 1)

        XCTAssertNil(
            PromotionBannerPolicy.reviewBannerIfEligible(
                metrics: metrics,
                moment: .sessionEnd(completedLegitimately: false),
                now: Date()
            )
        )
    }

    func testPromotionEngagementShortensDismissCooldownsAfterMoreCompletions() {
        let newer = PromotionBannerMetrics(visitCount: 2, legitimateCompletionCount: 1)
        let experienced = PromotionBannerMetrics(visitCount: 5, legitimateCompletionCount: 4)

        XCTAssertGreaterThan(
            PromotionBannerPolicy.closeDismissCooldownDays(for: newer, moment: .sessionStart),
            PromotionBannerPolicy.closeDismissCooldownDays(for: experienced, moment: .sessionStart)
        )
    }

    func testPromotionBannerPolicyHidesProBannerForProUsers() {
        let metrics = PromotionBannerMetrics(visitCount: 3)

        XCTAssertNil(
            PromotionBannerPolicy.activeBanner(
                metrics: metrics,
                processCount: 2,
                hasPro: true,
                moment: .sessionStart,
                now: Date()
            )
        )
    }

    func testPromotionBannerPolicyHonorsShowLessOftenForProBanner() {
        let now = Date()
        let metrics = PromotionBannerMetrics(
            visitCount: 3,
            proLessOftenUntil: Calendar.current.date(
                byAdding: .day,
                value: PromotionBannerPolicy.showLessOftenCooldownDays(for: PromotionBannerMetrics(visitCount: 3)),
                to: now
            )
        )

        XCTAssertNil(
            PromotionBannerPolicy.activeBanner(
                metrics: metrics,
                processCount: 2,
                hasPro: false,
                moment: .sessionStart,
                now: now
            )
        )
    }
}
