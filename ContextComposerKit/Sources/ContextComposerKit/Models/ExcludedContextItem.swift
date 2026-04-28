import Foundation

/// Records a context item that was considered but not included in the pack.
/// The app can surface these to the user so they understand exactly what
/// was left out and why, without having to guess.
public struct ExcludedContextItem: Codable, Sendable {

    /// Display title for the excluded item.
    public let title: String

    /// Where the item came from.
    public let sourceReference: ContextSourceReference

    /// Why it was excluded.
    public let reason: ExclusionReason

    /// How many tokens this item would have consumed, if known.
    public var estimatedTokens: Int?

    public init(
        title: String,
        sourceReference: ContextSourceReference,
        reason: ExclusionReason,
        estimatedTokens: Int? = nil
    ) {
        self.title = title
        self.sourceReference = sourceReference
        self.reason = reason
        self.estimatedTokens = estimatedTokens
    }
}

// MARK: - ExclusionReason

public enum ExclusionReason: String, Codable, Sendable, CaseIterable {
    /// Removed to stay within the token budget.
    case tokenBudget
    /// Relevance score was too low for the current task.
    case lowRelevance
    /// The item is older than the configured staleness threshold.
    case stale
    /// The item is explicitly archived.
    case archived
    /// The item is in a suggested (not yet approved) state.
    case suggestedOnly
    /// The item was explicitly rejected by the user.
    case rejected
    /// The item belongs to a different project.
    case wrongProject
    /// The item belongs to a module not relevant to this task.
    case wrongModule
    /// An equivalent item was already included.
    case duplicate
    /// Confidence score is below the configured minimum.
    case lowConfidence
    /// Reason could not be determined.
    case unknown
}
