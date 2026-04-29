import Foundation

/// A factor that contributed to a candidate's final relevance score.
/// The app can surface these so users understand exactly why each
/// piece of context was included or deprioritised.
public enum ScoringFactor: Sendable {

    // Positive signals
    case keywordOverlap(matchCount: Int)
    case tagOverlap(matchedTags: [String])
    case projectMatch
    case moduleMatch(moduleName: String)
    case sessionMatch
    case highImportanceKind
    case highConfidence(value: Double)
    case recentlyVerified(daysAgo: Int)
    case userPinned
    case hardConstraintBoost

    // Negative signals
    case stalePenalty(daysStale: Int)
    case lowConfidencePenalty(value: Double)
    case duplicatePenalty
    case lowKeywordOverlap
    case noProjectMatch
    case noTagOverlap

    /// A human-readable explanation of this factor.
    public var explanation: String {
        switch self {
        case .keywordOverlap(let count):
            return "Matched \(count) keyword(s) from the task prompt."
        case .tagOverlap(let tags):
            return "Matched tag(s): \(tags.joined(separator: ", "))."
        case .projectMatch:
            return "Belongs to the active project."
        case .moduleMatch(let name):
            return "Matches hinted module '\(name)'."
        case .sessionMatch:
            return "Associated with the active session."
        case .highImportanceKind:
            return "Category receives a high base weight."
        case .highConfidence(let value):
            return "Confidence is \(String(format: "%.0f", value * 100))%."
        case .recentlyVerified(let days):
            return "Verified \(days) day(s) ago."
        case .userPinned:
            return "Pinned by the user."
        case .hardConstraintBoost:
            return "Hard constraints are always boosted to maximum priority."
        case .stalePenalty(let days):
            return "Stale — last verified \(days) day(s) ago."
        case .lowConfidencePenalty(let value):
            return "Confidence is low (\(String(format: "%.0f", value * 100))%)."
        case .duplicatePenalty:
            return "Similar content already included."
        case .lowKeywordOverlap:
            return "Few keywords matched the task."
        case .noProjectMatch:
            return "Does not belong to the active project."
        case .noTagOverlap:
            return "No tag overlap with the task."
        }
    }

    /// The numeric delta this factor contributes to the raw score.
    public var scoreContribution: Double {
        switch self {
        case .keywordOverlap(let count):      return Double(count) * 0.15
        case .tagOverlap(let tags):           return Double(tags.count) * 0.10
        case .projectMatch:                   return 0.40
        case .moduleMatch:                    return 0.30
        case .sessionMatch:                   return 0.20
        case .highImportanceKind:             return 0.25
        case .highConfidence(let v):          return (v - 0.5) * 0.20
        case .recentlyVerified(let days):     return days < 7 ? 0.10 : 0.0
        case .userPinned:                     return 1.00
        case .hardConstraintBoost:            return 2.00
        case .stalePenalty(let days):         return -min(Double(days) * 0.02, 0.50)
        case .lowConfidencePenalty(let v):    return -(0.5 - v) * 0.20
        case .duplicatePenalty:               return -0.50
        case .lowKeywordOverlap:              return -0.05
        case .noProjectMatch:                 return -0.15
        case .noTagOverlap:                   return -0.05
        }
    }
}

// MARK: - ContextRelevanceScore

/// The scored result of evaluating a single candidate against the current task.
public struct ContextRelevanceScore: Sendable {

    /// The candidate this score applies to.
    public let candidateId: String

    /// Final normalised score (0.0 – 1.0+, can exceed 1.0 for pinned/required items).
    public let score: Double

    /// All factors that contributed to the score, for UI explainability.
    public let factors: [ScoringFactor]

    public init(candidateId: String, score: Double, factors: [ScoringFactor]) {
        self.candidateId = candidateId
        self.score = score
        self.factors = factors
    }

    /// A human-readable breakdown of why this score was given.
    public var explanation: String {
        guard !factors.isEmpty else { return "No scoring factors applied." }
        return factors.map { "• \($0.explanation)" }.joined(separator: "\n")
    }
}
