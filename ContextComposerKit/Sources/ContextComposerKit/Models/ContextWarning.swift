import Foundation

/// A warning produced during context pack assembly.
/// Warnings appear in ContextPack.warnings and are surfaced to the UI.
/// They are NOT included in the rendered prompt text by default.
public struct ContextWarning: Codable, Sendable {

    public let kind: Kind

    /// Human-readable explanation of the warning.
    public let message: String

    /// The source item this warning relates to, if applicable.
    public var affectedSource: ContextSourceReference?

    public init(
        kind: Kind,
        message: String,
        affectedSource: ContextSourceReference? = nil
    ) {
        self.kind = kind
        self.message = message
        self.affectedSource = affectedSource
    }
}

// MARK: - Kind

public extension ContextWarning {

    enum Kind: String, Codable, Sendable, CaseIterable {
        /// The full context exceeded the token budget and was trimmed.
        case tokenBudgetExceeded
        /// One or more context items were removed to fit the budget.
        case contextTrimmed
        /// The Rosetta project documentation is stale (old lastVerified date).
        case staleProjectDocs
        /// One or more memories are older than the staleness threshold.
        case staleMemory
        /// One or more memories have confidence below the configured minimum.
        case lowConfidenceMemory
        /// No Rosetta document was found for the linked project.
        case missingRosettaDocument
        /// No modules matched the task or its module hints.
        case noRelevantModules
        /// No approved memories are available for this task.
        case noApprovedMemories
        /// Token counts are approximate (character-based estimator).
        case approximateTokenEstimate
        /// Two or more context items appear to contain duplicate content.
        case possibleDuplicateContext
    }
}
