import Foundation

/// Entitlement / monetization events for photo-word learning.
public enum EntitlementAnalytics {
    private static func chargeName(_ charge: AnalysisCharge) -> String {
        charge == .freeQuota ? "free_quota" : "token"
    }

    public static func analysisConsumed(charge: AnalysisCharge, freeLeft: Int, tokens: Int) -> AnalyticsEvent {
        AnalyticsEvent(name: "analysis_consumed", params: [
            "charge": chargeName(charge), "free_left": String(freeLeft), "tokens": String(tokens),
        ])
    }

    public static func analysisRefunded(charge: AnalysisCharge) -> AnalyticsEvent {
        AnalyticsEvent(name: "analysis_refunded", params: ["charge": chargeName(charge)])
    }

    public static func purchaseStarted(product: PurchaseProduct) -> AnalyticsEvent {
        AnalyticsEvent(name: "purchase_started", params: ["product": product.productID])
    }

    public static func purchaseSucceeded(grant: PurchaseGrant) -> AnalyticsEvent {
        let detail: String
        switch grant.kind {
        case .premium(let period, _): detail = "premium.\(period.rawValue)"
        case .tokens(let count): detail = "tokens.\(count)"
        }
        return AnalyticsEvent(name: "purchase_succeeded", params: ["grant": detail, "transaction": grant.transactionID])
    }

    public static func restore() -> AnalyticsEvent {
        AnalyticsEvent(name: "purchases_restored")
    }
}

/// Typed analytics taxonomy — all event names live here (snake_case), so call sites are
/// type-safe and the catalog is the single source of truth for the funnel.
public enum OnboardingFunnel {
    public static func stepViewed(_ step: OnboardingStep) -> AnalyticsEvent {
        AnalyticsEvent(name: "onboarding_step_viewed", params: ["step": step.analyticsName])
    }

    public static func stepAnswered(_ step: OnboardingStep, value: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "onboarding_step_answered", params: ["step": step.analyticsName, "value": value])
    }

    public static func completed(_ profile: UserProfile) -> AnalyticsEvent {
        var params: [String: String] = [:]
        if let language = profile.targetLanguage { params["language"] = language.rawValue }
        if let age = profile.ageRange { params["age"] = age.rawValue }
        if let goal = profile.dailyGoal { params["daily_goal"] = String(goal.rawValue) }
        params["purpose_count"] = String(profile.learningPurposes.count)
        params["style_count"] = String(profile.learningStyles.count)
        return AnalyticsEvent(name: "onboarding_completed", params: params)
    }

    public static func authChosen(provider: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "onboarding_auth_chosen", params: ["provider": provider])
    }

    public static func flowReset() -> AnalyticsEvent {
        AnalyticsEvent(name: "onboarding_flow_reset")
    }
}

public enum LearningPathAnalytics {
    public static func mapViewed(language: TargetLanguage, completed: Int, total: Int) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "learning_path_map_viewed",
            params: ["language": language.rawValue, "completed": String(completed), "total": String(total)]
        )
    }

    public static func stopCompleted(language: TargetLanguage, index: Int, total: Int) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "learning_path_stop_completed",
            params: ["language": language.rawValue, "index": String(index), "total": String(total)]
        )
    }

    public static func journeyFinished(language: TargetLanguage, total: Int) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "learning_path_journey_finished",
            params: ["language": language.rawValue, "total": String(total)]
        )
    }

    public static func progressReset(language: TargetLanguage) -> AnalyticsEvent {
        AnalyticsEvent(name: "learning_path_progress_reset", params: ["language": language.rawValue])
    }

    public static func appReset() -> AnalyticsEvent {
        AnalyticsEvent(name: "app_reset")
    }
}

public enum LessonAnalytics {
    public static func started(stopId: String, language: TargetLanguage) -> AnalyticsEvent {
        AnalyticsEvent(name: "lesson_started", params: ["stop": stopId, "language": language.rawValue])
    }

    public static func exerciseAnswered(stopId: String, kind: ExerciseKind, correct: Bool) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "lesson_exercise_answered",
            params: ["stop": stopId, "kind": kind.rawValue, "correct": String(correct)]
        )
    }

    public static func completed(stopId: String, stars: Int, hearts: Int) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "lesson_completed",
            params: ["stop": stopId, "stars": String(stars), "hearts": String(hearts)]
        )
    }

    public static func failed(stopId: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "lesson_failed", params: ["stop": stopId])
    }
}

public enum GamificationAnalytics {
    public static func xpEarned(amount: Int, total: Int) -> AnalyticsEvent {
        AnalyticsEvent(name: "xp_earned", params: ["amount": String(amount), "total": String(total)])
    }

    public static func streakExtended(days: Int) -> AnalyticsEvent {
        AnalyticsEvent(name: "streak_extended", params: ["days": String(days)])
    }

    public static func heartsDepleted() -> AnalyticsEvent {
        AnalyticsEvent(name: "hearts_depleted")
    }
}

extension OnboardingStep {
    /// Stable snake_case identifier for analytics (independent of display order).
    var analyticsName: String {
        switch self {
        case .welcome: "welcome"
        case .targetLanguage: "target_language"
        case .nativeLanguage: "native_language"
        case .ageRange: "age_range"
        case .learningPurpose: "learning_purpose"
        case .currentLevel: "current_level"
        case .learningStyle: "learning_style"
        case .dailyGoal: "daily_goal"
        case .reminderTime: "reminder_time"
        case .planSummary: "plan_summary"
        case .auth: "auth"
        }
    }
}
