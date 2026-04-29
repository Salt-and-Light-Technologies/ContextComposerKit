import Foundation

/// Controls which context items are eligible for inclusion and how many
/// of each type can appear in the final pack.
///
/// Defaults are set conservatively — suggested and stale items excluded,
/// confidence threshold at 0.5, reasonable per-category caps.
public struct ContextSelectionConfiguration: Sendable {

    // MARK: - Memory Scope

    /// Include memories with global scope (not tied to a specific project).
    public var includeGlobalMemories: Bool

    /// Include memories scoped to the active workspace.
    public var includeWorkspaceMemories: Bool

    /// Include memories scoped to the active project.
    public var includeProjectMemories: Bool

    /// Include memories scoped to a specific module.
    public var includeModuleMemories: Bool

    /// Include memories associated with the active session.
    public var includeSessionMemories: Bool

    // MARK: - Lifecycle Filters

    /// Include memories in 'suggested' status. Default: false.
    /// Suggested memories have not been reviewed and approved by the user.
    public var includeSuggestedMemories: Bool

    /// Include memories or documents marked stale or archived. Default: false.
    public var includeStale: Bool

    // MARK: - Quality Filters

    /// Minimum confidence score for a memory to be eligible (0.0 – 1.0).
    public var minimumConfidence: Double

    // MARK: - Per-Category Caps

    /// Maximum number of Rosetta modules to include.
    public var maxModules: Int

    /// Maximum number of Railroad memories to include.
    public var maxMemories: Int

    /// Maximum number of Railroad decisions to include.
    public var maxDecisions: Int

    /// Maximum number of gotchas to include.
    public var maxGotchas: Int

    // MARK: - Deduplication

    /// Remove candidates whose content is highly similar to an already-selected item.
    public var deduplicate: Bool

    // MARK: - Token Budget

    /// The token budget to enforce during selection.
    public var tokenBudget: TokenBudget

    // MARK: - Staleness

    /// Number of days after which a lastVerified date is considered stale.
    public var stalenesThresholdDays: Int

    // MARK: - Init

    public init(
        includeGlobalMemories: Bool = true,
        includeWorkspaceMemories: Bool = true,
        includeProjectMemories: Bool = true,
        includeModuleMemories: Bool = true,
        includeSessionMemories: Bool = true,
        includeSuggestedMemories: Bool = false,
        includeStale: Bool = false,
        minimumConfidence: Double = 0.5,
        maxModules: Int = 5,
        maxMemories: Int = 8,
        maxDecisions: Int = 5,
        maxGotchas: Int = 5,
        deduplicate: Bool = true,
        tokenBudget: TokenBudget = .standard,
        stalenesThresholdDays: Int = 30
    ) {
        self.includeGlobalMemories = includeGlobalMemories
        self.includeWorkspaceMemories = includeWorkspaceMemories
        self.includeProjectMemories = includeProjectMemories
        self.includeModuleMemories = includeModuleMemories
        self.includeSessionMemories = includeSessionMemories
        self.includeSuggestedMemories = includeSuggestedMemories
        self.includeStale = includeStale
        self.minimumConfidence = minimumConfidence
        self.maxModules = maxModules
        self.maxMemories = maxMemories
        self.maxDecisions = maxDecisions
        self.maxGotchas = maxGotchas
        self.deduplicate = deduplicate
        self.tokenBudget = tokenBudget
        self.stalenesThresholdDays = stalenesThresholdDays
    }
}

// MARK: - Convenience Presets

public extension ContextSelectionConfiguration {

    /// Conservative defaults — good for most tasks.
    static func standard(budget: TokenBudget = .standard) -> ContextSelectionConfiguration {
        ContextSelectionConfiguration(tokenBudget: budget)
    }

    /// Tight configuration for small context windows.
    static func compact(budget: TokenBudget = .minimal) -> ContextSelectionConfiguration {
        ContextSelectionConfiguration(
            maxModules: 2,
            maxMemories: 3,
            maxDecisions: 2,
            maxGotchas: 2,
            tokenBudget: budget
        )
    }

    /// Broad configuration for large context windows where token cost is less
    /// of a concern, but stale items are still excluded by default.
    static func generous(budget: TokenBudget) -> ContextSelectionConfiguration {
        ContextSelectionConfiguration(
            maxModules: 10,
            maxMemories: 15,
            maxDecisions: 10,
            maxGotchas: 10,
            tokenBudget: budget
        )
    }
}
