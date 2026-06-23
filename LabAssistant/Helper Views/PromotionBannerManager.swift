//
//  PromotionBannerManager.swift
//  LabAssistant
//

import Foundation
import Combine

enum PromotionBanner: Equatable {
    case review
    case pro
}

enum BannerDismissalAction {
    case close
    case showLessOften
}

/// When to evaluate showing a banner within an app visit.
enum PromotionBannerMoment: Equatable {
    /// User opened the Darkroom tab — a returning visit every few weeks/months.
    case sessionStart
    /// User is leaving a develop run — best time after a long in-session workflow.
    case sessionEnd(completedLegitimately: Bool)
}

struct WorkflowSessionTracker {
    let stepCount: Int
    let estimatedDuration: TimeInterval?
    let startedAt: Date
    var furthestStepIndex: Int = 0
    var reachedLastStep: Bool = false
}

enum WorkflowEngagement {
    static let minimumEstimatedDurationRatio: TimeInterval = 0.08
    static let minimumAbsoluteDuration: TimeInterval = 20
    static let minimumSecondsPerUntimedStep: TimeInterval = 5

    static func isLegitimateCompletion(
        stepCount: Int,
        estimatedDuration: TimeInterval?,
        elapsed: TimeInterval,
        furthestStepIndex: Int,
        reachedLastStep: Bool
    ) -> Bool {
        guard stepCount > 0 else { return false }
        guard reachedLastStep || furthestStepIndex >= stepCount - 1 else { return false }

        if let estimated = estimatedDuration, estimated > 0 {
            let required = max(minimumAbsoluteDuration, estimated * minimumEstimatedDurationRatio)
            return elapsed >= required
        }

        let stepsVisited = max(furthestStepIndex + 1, 1)
        let required = max(minimumAbsoluteDuration, Double(stepsVisited) * minimumSecondsPerUntimedStep)
        return elapsed >= required
    }
}

struct PromotionBannerMetrics: Equatable {
    /// Lifetime app launches — each visit may be weeks apart.
    var visitCount = 0
    var legitimateCompletionCount = 0
    var reviewRequestedAt: Date?
    var reviewDeclinedAt: Date?
    var reviewCloseDismissedAt: Date?
    var reviewLessOftenUntil: Date?
    var proCloseDismissedAt: Date?
    var proLessOftenUntil: Date?
}

enum PromotionEngagement {
    static func score(for metrics: PromotionBannerMetrics, justCompletedWorkflow: Bool = false) -> Double {
        let completionComponent = min(1.0, Double(metrics.legitimateCompletionCount) / 5.0)
        let visitComponent = min(1.0, Double(max(metrics.visitCount - 1, 0)) / 6.0)
        var score = completionComponent * 0.65 + visitComponent * 0.35
        if justCompletedWorkflow {
            score = min(1.0, score + 0.2)
        }
        return score
    }

    static func scaled(fast: Int, slow: Int, score: Double) -> Int {
        let clamped = min(max(score, 0), 1)
        return Int(round(Double(slow) - clamped * Double(slow - fast)))
    }
}

enum PromotionBannerPolicy {
    static let minimumProcessCountForPro = 1

    static let closeDismissCooldownDays = 21
    static let showLessOftenCooldownDays = 60
    static let reviewDeclinedCooldownDays = 90

    private static let fastCloseDismissCooldownDays = 3
    private static let fastShowLessOftenCooldownDays = 21
    private static let fastReviewDeclinedCooldownDays = 30

    static func closeDismissCooldownDays(for metrics: PromotionBannerMetrics, moment: PromotionBannerMoment) -> Int {
        PromotionEngagement.scaled(
            fast: fastCloseDismissCooldownDays,
            slow: closeDismissCooldownDays,
            score: engagementScore(for: metrics, moment: moment)
        )
    }

    static func showLessOftenCooldownDays(for metrics: PromotionBannerMetrics) -> Int {
        PromotionEngagement.scaled(
            fast: fastShowLessOftenCooldownDays,
            slow: showLessOftenCooldownDays,
            score: engagementScore(for: metrics, moment: .sessionStart)
        )
    }

    static func reviewDeclinedCooldownDays(for metrics: PromotionBannerMetrics) -> Int {
        PromotionEngagement.scaled(
            fast: fastReviewDeclinedCooldownDays,
            slow: reviewDeclinedCooldownDays,
            score: engagementScore(for: metrics, moment: .sessionStart)
        )
    }

    static func activeBanner(
        metrics: PromotionBannerMetrics,
        processCount: Int?,
        hasPro: Bool,
        moment: PromotionBannerMoment,
        now: Date,
        calendar: Calendar = .current
    ) -> PromotionBanner? {
        if let review = reviewBannerIfEligible(metrics: metrics, moment: moment, now: now, calendar: calendar) {
            return review
        }

        if !hasPro,
           let pro = proBannerIfEligible(
               metrics: metrics,
               processCount: processCount,
               moment: moment,
               now: now,
               calendar: calendar
           ) {
            return pro
        }

        return nil
    }

    static func reviewBannerIfEligible(
        metrics: PromotionBannerMetrics,
        moment: PromotionBannerMoment,
        now: Date,
        calendar: Calendar = .current
    ) -> PromotionBanner? {
        if metrics.reviewRequestedAt != nil { return nil }
        if isBeforeCooldownEnd(metrics.reviewLessOftenUntil, now: now) { return nil }
        if isWithinDayCooldown(
            from: metrics.reviewDeclinedAt,
            days: reviewDeclinedCooldownDays(for: metrics),
            now: now,
            calendar: calendar
        ) { return nil }
        if isWithinDayCooldown(
            from: metrics.reviewCloseDismissedAt,
            days: closeDismissCooldownDays(for: metrics, moment: moment),
            now: now,
            calendar: calendar
        ) { return nil }

        switch moment {
        case .sessionStart:
            guard metrics.visitCount >= 2, metrics.legitimateCompletionCount >= 1 else { return nil }
            return .review
        case .sessionEnd(let completedLegitimately):
            guard completedLegitimately else { return nil }
            return .review
        }
    }

    static func proBannerIfEligible(
        metrics: PromotionBannerMetrics,
        processCount: Int?,
        moment: PromotionBannerMoment,
        now: Date,
        calendar: Calendar = .current
    ) -> PromotionBanner? {
        guard let processCount else { return nil }
        if isBeforeCooldownEnd(metrics.proLessOftenUntil, now: now) { return nil }
        if isWithinDayCooldown(
            from: metrics.proCloseDismissedAt,
            days: closeDismissCooldownDays(for: metrics, moment: moment),
            now: now,
            calendar: calendar
        ) { return nil }

        switch moment {
        case .sessionStart:
            guard metrics.visitCount >= 2, processCount >= minimumProcessCountForPro else { return nil }
            return .pro
        case .sessionEnd:
            return nil
        }
    }

    private static func engagementScore(for metrics: PromotionBannerMetrics, moment: PromotionBannerMoment) -> Double {
        let justCompleted = if case .sessionEnd(let completed) = moment { completed } else { false }
        return PromotionEngagement.score(for: metrics, justCompletedWorkflow: justCompleted)
    }

    private static func isBeforeCooldownEnd(_ cooldownEnd: Date?, now: Date) -> Bool {
        guard let cooldownEnd else { return false }
        return now < cooldownEnd
    }

    private static func isWithinDayCooldown(
        from start: Date?,
        days: Int,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        guard let start,
              let cooldownEnd = calendar.date(byAdding: .day, value: days, to: start) else {
            return false
        }
        return now < cooldownEnd
    }
}

@MainActor
final class PromotionBannerManager: ObservableObject {
    @Published private(set) var activeBanner: PromotionBanner?

    private let defaults: UserDefaults
    private let now: () -> Date
    private let calendar: Calendar

    private var metrics = PromotionBannerMetrics()
    private var bannerPresentedThisVisit = false

#if DEBUG
    private var debugForcedBanner: PromotionBanner?
#endif

    init(
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.defaults = defaults
        self.now = now
        self.calendar = calendar
        loadPersistedState()
    }

    func recordAppLaunchIfNeeded() {
        guard !LabAssistantLaunchConfiguration.isRunningUITests else { return }

        metrics.visitCount += 1
        bannerPresentedThisVisit = false
        persistState()
    }

    func startWorkflowSession(process: DevProcess) -> WorkflowSessionTracker {
        WorkflowSessionTracker(
            stepCount: process.sortedSteps.count,
            estimatedDuration: process.estTime,
            startedAt: now()
        )
    }

    func completeWorkflowSession(_ session: WorkflowSessionTracker) {
        guard session.stepCount > 0 else { return }

        let elapsed = now().timeIntervalSince(session.startedAt)
        let isLegitimate = WorkflowEngagement.isLegitimateCompletion(
            stepCount: session.stepCount,
            estimatedDuration: session.estimatedDuration,
            elapsed: elapsed,
            furthestStepIndex: session.furthestStepIndex,
            reachedLastStep: session.reachedLastStep
        )

        if isLegitimate {
            metrics.legitimateCompletionCount += 1
            persistState()
        }

        recomputeActiveBanner(
            processCount: nil,
            moment: .sessionEnd(completedLegitimately: isLegitimate)
        )
    }

    func recomputeActiveBanner(
        processCount: Int?,
        hasPro: Bool = false,
        moment: PromotionBannerMoment = .sessionStart
    ) {
        guard !LabAssistantLaunchConfiguration.isRunningUITests else {
            activeBanner = nil
            return
        }

#if DEBUG
        if let debugForcedBanner {
            activeBanner = debugForcedBanner
            return
        }
#endif

        guard !bannerPresentedThisVisit else { return }

        if let banner = PromotionBannerPolicy.activeBanner(
            metrics: metrics,
            processCount: processCount,
            hasPro: hasPro,
            moment: moment,
            now: now(),
            calendar: calendar
        ) {
            activeBanner = banner
            bannerPresentedThisVisit = true
        } else {
            activeBanner = nil
        }
    }

    func handleReviewAccepted() {
        metrics.reviewRequestedAt = now()
        metrics.reviewDeclinedAt = nil
        metrics.reviewCloseDismissedAt = nil
        metrics.reviewLessOftenUntil = nil
        persistState()
        activeBanner = nil
    }

    func handleReviewDeclined() {
        metrics.reviewDeclinedAt = now()
        persistState()
        activeBanner = nil
    }

    func dismissBanner(_ banner: PromotionBanner, action: BannerDismissalAction) {
        let currentDate = now()

        switch banner {
        case .review:
            switch action {
            case .close:
                metrics.reviewCloseDismissedAt = currentDate
            case .showLessOften:
                metrics.reviewLessOftenUntil = calendar.date(
                    byAdding: .day,
                    value: PromotionBannerPolicy.showLessOftenCooldownDays(for: metrics),
                    to: currentDate
                )
            }
        case .pro:
            switch action {
            case .close:
                metrics.proCloseDismissedAt = currentDate
            case .showLessOften:
                metrics.proLessOftenUntil = calendar.date(
                    byAdding: .day,
                    value: PromotionBannerPolicy.showLessOftenCooldownDays(for: metrics),
                    to: currentDate
                )
            }
        }

        persistState()
        activeBanner = nil
    }

    private enum Keys {
        static let visitCount = "labassistant.promotion.visitCount"
        static let legitimateCompletionCount = "labassistant.promotion.legitimateCompletionCount"
        static let reviewRequestedAt = "labassistant.promotion.reviewRequestedAt"
        static let reviewDeclinedAt = "labassistant.promotion.reviewDeclinedAt"
        static let reviewCloseDismissedAt = "labassistant.promotion.reviewCloseDismissedAt"
        static let reviewLessOftenUntil = "labassistant.promotion.reviewLessOftenUntil"
        static let proCloseDismissedAt = "labassistant.promotion.proCloseDismissedAt"
        static let proLessOftenUntil = "labassistant.promotion.proLessOftenUntil"

        static let all: [String] = [
            visitCount,
            legitimateCompletionCount,
            reviewRequestedAt,
            reviewDeclinedAt,
            reviewCloseDismissedAt,
            reviewLessOftenUntil,
            proCloseDismissedAt,
            proLessOftenUntil
        ]
    }

    private func loadPersistedState() {
        metrics.visitCount = defaults.integer(forKey: Keys.visitCount)
        metrics.legitimateCompletionCount = defaults.integer(forKey: Keys.legitimateCompletionCount)
        metrics.reviewRequestedAt = defaults.object(forKey: Keys.reviewRequestedAt) as? Date
        metrics.reviewDeclinedAt = defaults.object(forKey: Keys.reviewDeclinedAt) as? Date
        metrics.reviewCloseDismissedAt = defaults.object(forKey: Keys.reviewCloseDismissedAt) as? Date
        metrics.reviewLessOftenUntil = defaults.object(forKey: Keys.reviewLessOftenUntil) as? Date
        metrics.proCloseDismissedAt = defaults.object(forKey: Keys.proCloseDismissedAt) as? Date
        metrics.proLessOftenUntil = defaults.object(forKey: Keys.proLessOftenUntil) as? Date
    }

    private func persistState() {
        defaults.set(metrics.visitCount, forKey: Keys.visitCount)
        defaults.set(metrics.legitimateCompletionCount, forKey: Keys.legitimateCompletionCount)
        defaults.set(metrics.reviewRequestedAt, forKey: Keys.reviewRequestedAt)
        defaults.set(metrics.reviewDeclinedAt, forKey: Keys.reviewDeclinedAt)
        defaults.set(metrics.reviewCloseDismissedAt, forKey: Keys.reviewCloseDismissedAt)
        defaults.set(metrics.reviewLessOftenUntil, forKey: Keys.reviewLessOftenUntil)
        defaults.set(metrics.proCloseDismissedAt, forKey: Keys.proCloseDismissedAt)
        defaults.set(metrics.proLessOftenUntil, forKey: Keys.proLessOftenUntil)
    }
}

#if DEBUG
extension PromotionBannerManager {
    func applyDebugMetricsConfigurationIfNeeded() {
        if LabAssistantLaunchConfiguration.debugResetPromotionMetrics {
            debugResetMetrics()
        }
        if LabAssistantLaunchConfiguration.debugSeedReviewEligible {
            debugSeedReviewEligibleMetrics()
        }
        if LabAssistantLaunchConfiguration.debugSeedProEligible {
            debugSeedProEligibleMetrics()
        }
    }

    func applyDebugBannerOverrideIfNeeded() {
        if LabAssistantLaunchConfiguration.debugShowReviewBanner {
            debugForcedBanner = .review
        } else if LabAssistantLaunchConfiguration.debugShowProBanner {
            debugForcedBanner = .pro
        } else {
            debugForcedBanner = nil
        }

        if debugForcedBanner != nil {
            activeBanner = debugForcedBanner
        }
    }

    func debugResetMetrics() {
        metrics = PromotionBannerMetrics()
        bannerPresentedThisVisit = false
        debugForcedBanner = nil
        for key in Keys.all {
            defaults.removeObject(forKey: key)
        }
        activeBanner = nil
    }

    func debugSeedReviewEligibleMetrics() {
        metrics = PromotionBannerMetrics(visitCount: 3, legitimateCompletionCount: 2)
        persistState()
    }

    func debugSeedProEligibleMetrics() {
        metrics = PromotionBannerMetrics(visitCount: 3, legitimateCompletionCount: 1)
        metrics.reviewRequestedAt = now()
        persistState()
    }
}
#endif
