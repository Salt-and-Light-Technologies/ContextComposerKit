import Foundation

/// The structured, pre-render output of the ContextComposer.
/// Holds the full picture of what was included, what was excluded,
/// and all warnings. The MinifyAI app uses this to power its review screen.
/// Pass this to a PromptRenderer to get the final paste-ready text.
public struct ContextPack: Identifiable, Codable, Sendable {

    public let id: UUID

    /// The task that anchors this pack.
    public var task: UserTask

    /// The provider the pack was assembled for.
    public var providerProfile: ProviderProfile

    /// The token budget constraints that were applied.
    public var tokenBudget: TokenBudget

    /// The sections that were selected and will appear in the rendered prompt.
    /// Ordered by priority ascending (lowest priority number = first in prompt).
    public var includedSections: [ContextSection]

    /// Items that were considered but excluded, with reasons.
    public var excludedItems: [ExcludedContextItem]

    /// Warnings generated during assembly.
    public var warnings: [ContextWarning]

    /// Total estimated token count across all included sections.
    public var estimatedTokens: Int

    /// When this pack was assembled.
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        task: UserTask,
        providerProfile: ProviderProfile,
        tokenBudget: TokenBudget,
        includedSections: [ContextSection],
        excludedItems: [ExcludedContextItem] = [],
        warnings: [ContextWarning] = [],
        estimatedTokens: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.task = task
        self.providerProfile = providerProfile
        self.tokenBudget = tokenBudget
        self.includedSections = includedSections
        self.excludedItems = excludedItems
        self.warnings = warnings
        self.estimatedTokens = estimatedTokens
        self.createdAt = createdAt
    }
}

// MARK: - Computed Helpers

public extension ContextPack {

    /// Whether the pack has any warnings the UI should highlight.
    var hasWarnings: Bool { !warnings.isEmpty }

    /// Whether any items were excluded during assembly.
    var hasExclusions: Bool { !excludedItems.isEmpty }

    /// Whether the token budget was exceeded before trimming.
    var tokenBudgetWasExceeded: Bool {
        warnings.contains { $0.kind == .tokenBudgetExceeded }
    }

    /// Sections sorted by ascending priority for rendering.
    var sortedSections: [ContextSection] {
        includedSections.sorted { $0.priority < $1.priority }
    }

    /// A brief summary string for display in the app (e.g. status bar).
    var summary: String {
        let sectionCount = includedSections.count
        let excludedCount = excludedItems.count
        let warningCount = warnings.count
        return "\(sectionCount) section(s), ~\(estimatedTokens) tokens, \(excludedCount) excluded, \(warningCount) warning(s)"
    }
}
