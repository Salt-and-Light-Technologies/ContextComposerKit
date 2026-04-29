import Foundation

/// Configuration that controls what optional metadata gets appended to the
/// rendered prompt. The core task/context is always rendered.
public struct RenderConfiguration: Sendable {

    /// Append the source summary section at the end of the prompt.
    /// Useful during development; usually disabled for production pasting.
    public var includeSourceSummary: Bool

    /// Append warning notes at the very end of the prompt.
    public var includeWarningsInPrompt: Bool

    public init(
        includeSourceSummary: Bool = false,
        includeWarningsInPrompt: Bool = false
    ) {
        self.includeSourceSummary = includeSourceSummary
        self.includeWarningsInPrompt = includeWarningsInPrompt
    }

    public static let `default` = RenderConfiguration()
    public static let verbose = RenderConfiguration(includeSourceSummary: true, includeWarningsInPrompt: true)
}

/// A type that can render a ContextPack into a paste-ready RenderedPromptPack.
public protocol PromptRendering: Sendable {

    /// The prompt style this renderer produces.
    var promptStyle: ProviderProfile.PromptStyle { get }

    /// Render the pack into final text.
    func render(
        _ pack: ContextPack,
        configuration: RenderConfiguration
    ) -> RenderedPromptPack
}

// MARK: - Shared Rendering Helpers

/// Internal helpers shared across all renderer implementations.
/// Not public — renderers access these via module scope.
enum RendererHelpers {

    /// Builds the included and excluded summary strings for the RenderedPromptPack metadata.
    static func buildSummaries(from pack: ContextPack) -> (included: [String], excluded: [String]) {
        let included = pack.includedSections.map { "[\($0.sectionType.rawValue)] \($0.title)" }
        let excluded = pack.excludedItems.map { "[\($0.reason.rawValue)] \($0.title)" }
        return (included, excluded)
    }

    /// Renders the warnings block as plain markdown notes.
    static func warningsBlock(from warnings: [ContextWarning]) -> String {
        guard !warnings.isEmpty else { return "" }
        let lines = warnings.map { "- ⚠️ \($0.kind.rawValue): \($0.message)" }.joined(separator: "\n")
        return """

        ---
        **Context Pack Warnings**

        \(lines)
        """
    }

    /// Renders the source summary block.
    static func sourceSummaryBlock(from pack: ContextPack) -> String {
        let lines = pack.includedSections.flatMap { section in
            section.sourceReferences.map { ref in
                "- \(ref.sourceType.rawValue)\(ref.title.map { ": \($0)" } ?? "")"
            }
        }
        guard !lines.isEmpty else { return "" }
        let body = lines.joined(separator: "\n")
        return """

        ---
        **Sources**

        \(body)
        """
    }
}
