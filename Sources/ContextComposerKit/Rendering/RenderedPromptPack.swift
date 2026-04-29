import Foundation

/// The final output of the rendering pipeline.
/// Contains the paste-ready prompt text and metadata the app can display
/// in its review screen (tokens, sources, warnings).
public struct RenderedPromptPack: Sendable {

    /// The full prompt text ready to be copied to clipboard.
    public let promptText: String

    /// The provider this pack was rendered for.
    public let providerProfile: ProviderProfile

    /// Estimated token count of the rendered text.
    public let estimatedTokens: Int

    /// Human-readable list of what was included.
    public let includedSummary: [String]

    /// Human-readable list of what was excluded and why.
    public let excludedSummary: [String]

    /// Warnings that should be shown in the app review screen.
    public let warnings: [ContextWarning]

    /// When this rendered pack was produced.
    public let renderedAt: Date

    public init(
        promptText: String,
        providerProfile: ProviderProfile,
        estimatedTokens: Int,
        includedSummary: [String],
        excludedSummary: [String],
        warnings: [ContextWarning],
        renderedAt: Date = Date()
    ) {
        self.promptText = promptText
        self.providerProfile = providerProfile
        self.estimatedTokens = estimatedTokens
        self.includedSummary = includedSummary
        self.excludedSummary = excludedSummary
        self.warnings = warnings
        self.renderedAt = renderedAt
    }
}

// MARK: - Computed Helpers

public extension RenderedPromptPack {

    var characterCount: Int { promptText.count }

    var hasWarnings: Bool { !warnings.isEmpty }

    /// A compact summary for display in the app status bar.
    var statusLine: String {
        "~\(estimatedTokens) tokens · \(includedSummary.count) sections · \(warnings.count) warning(s)"
    }
}
