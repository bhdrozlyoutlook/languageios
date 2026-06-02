import Foundation

/// Subscription tier for photo-word learning.
public enum SubscriptionTier: String, Codable, Equatable, Sendable {
    case freemium
    case premium
}

/// How often the free-analysis allowance renews. Used by both the entitlement state and
/// the purchase catalog so the two never disagree about the period vocabulary.
public enum RenewalPeriod: String, Codable, CaseIterable, Sendable {
    case weekly
    case monthly
}

/// What a single analysis was charged against — needed for a correct, typed refund that
/// preserves token carry-over.
public enum AnalysisCharge: Equatable, Sendable {
    case freeQuota
    case token
}

/// Local, testable entitlement state for Gemini object analysis. Mirrors the hearts pool:
/// a pure `Codable, Equatable` value type whose period logic takes an injectable `now` +
/// `calendar`, so it is deterministic and timezone/DST-safe. The free allowance renews each
/// period (weekly/monthly); the token balance is a paid extra that NEVER resets.
public struct EntitlementState: Codable, Equatable, Sendable {
    public var tier: SubscriptionTier
    public var period: RenewalPeriod
    /// Free analyses spent in the current period; reset to 0 on rollover.
    public var freeAnalysesUsed: Int
    /// Start of the period bucket the `freeAnalysesUsed` count belongs to; `nil` until the
    /// first consume binds it (a fresh state reports its full free quota).
    public var periodAnchor: Date?
    /// Purchased tokens. 1 token = 1 extra analysis. Carries over across every rollover.
    public var tokenBalance: Int

    public static let premiumFreeQuota = 10
    public static let freemiumFreeQuota = 0

    public init(
        tier: SubscriptionTier = .freemium,
        period: RenewalPeriod = .weekly,
        freeAnalysesUsed: Int = 0,
        periodAnchor: Date? = nil,
        tokenBalance: Int = 0
    ) {
        self.tier = tier
        self.period = period
        self.freeAnalysesUsed = freeAnalysesUsed
        self.periodAnchor = periodAnchor
        self.tokenBalance = tokenBalance
    }

    /// Backward-compatible decoding: every field is optional so an older/partial blob loads,
    /// defaulting to a fresh freemium/weekly state.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tier = try container.decodeIfPresent(SubscriptionTier.self, forKey: .tier) ?? .freemium
        period = try container.decodeIfPresent(RenewalPeriod.self, forKey: .period) ?? .weekly
        freeAnalysesUsed = try container.decodeIfPresent(Int.self, forKey: .freeAnalysesUsed) ?? 0
        periodAnchor = try container.decodeIfPresent(Date.self, forKey: .periodAnchor)
        tokenBalance = try container.decodeIfPresent(Int.self, forKey: .tokenBalance) ?? 0
    }

    /// Free analyses granted each period: 10 for premium, 0 for freemium.
    public var freeQuota: Int {
        tier == .premium ? Self.premiumFreeQuota : Self.freemiumFreeQuota
    }

    // MARK: Pure reads (reconcile rollover on the fly, never mutate)

    func periodStart(containing now: Date, calendar: Calendar) -> Date {
        let components: Set<Calendar.Component> = period == .weekly
            ? [.yearForWeekOfYear, .weekOfYear]
            : [.year, .month]
        return calendar.date(from: calendar.dateComponents(components, from: now)) ?? now
    }

    func needsReset(now: Date, calendar: Calendar) -> Bool {
        guard let anchor = periodAnchor else { return false }
        switch period {
        case .weekly:
            let sameWeek = calendar.isDate(anchor, equalTo: now, toGranularity: .weekOfYear)
            let sameWeekYear = calendar.component(.yearForWeekOfYear, from: anchor)
                == calendar.component(.yearForWeekOfYear, from: now)
            return !(sameWeek && sameWeekYear)
        case .monthly:
            let sameMonth = calendar.isDate(anchor, equalTo: now, toGranularity: .month)
            let sameYear = calendar.component(.year, from: anchor) == calendar.component(.year, from: now)
            return !(sameMonth && sameYear)
        }
    }

    func effectiveFreeUsed(now: Date, calendar: Calendar) -> Int {
        needsReset(now: now, calendar: calendar) ? 0 : freeAnalysesUsed
    }

    /// Free analyses still available this period (after on-the-fly rollover reconciliation).
    public func freeAnalysesRemaining(now: Date, calendar: Calendar = .current) -> Int {
        max(0, freeQuota - effectiveFreeUsed(now: now, calendar: calendar))
    }

    /// Total analyses available right now: remaining free quota + token balance.
    public func analysesAvailable(now: Date, calendar: Calendar = .current) -> Int {
        freeAnalysesRemaining(now: now, calendar: calendar) + tokenBalance
    }

    public func canStartAnalysis(now: Date, calendar: Calendar = .current) -> Bool {
        analysesAvailable(now: now, calendar: calendar) > 0
    }

    // MARK: Mutations (commit on write)

    /// Idempotent within a period: zeros the free count and re-anchors to the bucket start
    /// on rollover (or binds the anchor on first use). Tokens are never touched.
    mutating func resetIfNeeded(now: Date, calendar: Calendar) {
        if needsReset(now: now, calendar: calendar) {
            freeAnalysesUsed = 0
        }
        periodAnchor = periodStart(containing: now, calendar: calendar)
    }

    /// Spends one analysis: free quota first, then a token. Returns what was charged, or
    /// `nil` if nothing is available (caller must NOT proceed to Gemini).
    public mutating func consumeAnalysis(now: Date, calendar: Calendar = .current) -> AnalysisCharge? {
        resetIfNeeded(now: now, calendar: calendar)
        if freeAnalysesUsed < freeQuota {
            freeAnalysesUsed += 1
            return .freeQuota
        }
        if tokenBalance > 0 {
            tokenBalance -= 1
            return .token
        }
        return nil
    }

    /// Returns a charged unit (e.g. the Gemini call failed). No rollover reconciliation:
    /// a free refund clamps at 0 (harmless no-op if the period already rolled), a token
    /// refund always credits back (carry-over safe).
    public mutating func refundAnalysis(_ charge: AnalysisCharge) {
        switch charge {
        case .freeQuota:
            freeAnalysesUsed = max(0, freeAnalysesUsed - 1)
        case .token:
            tokenBalance += 1
        }
    }

    public mutating func addTokens(_ count: Int) {
        tokenBalance += max(0, count)
    }

    /// Switches tier/period and starts a FRESH period so a new premium's 10 are usable
    /// immediately. Tokens are preserved (a freemium user can still spend tokens).
    public mutating func setTier(_ tier: SubscriptionTier, period: RenewalPeriod, now: Date, calendar: Calendar = .current) {
        self.tier = tier
        self.period = period
        self.freeAnalysesUsed = 0
        self.periodAnchor = periodStart(containing: now, calendar: calendar)
    }
}
