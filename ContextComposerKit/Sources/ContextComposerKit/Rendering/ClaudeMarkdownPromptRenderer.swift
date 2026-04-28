import Foundation

/// Renders a ContextPack as XML-delimited markdown optimised for Anthropic Claude.
///
/// Claude natively handles XML tags in the Human turn and uses them to
/// separate semantic regions of the prompt. This renderer produces
/// that structure so Claude can reference sections by tag name in its reply.
///
/// Output example:
/// ```
/// # MinifyAI Prompt Pack · Claude
///
/// <task>
/// Refactor the authentication module to use async/await...
/// </task>
///
/// <constraints>
/// - Do not import SwiftUI
/// </constraints>
///
/// <project_context>
/// ...
/// </project_context>
/// ```
public struct ClaudeMarkdownPromptRenderer: PromptRendering {

    public let promptStyle: ProviderProfile.PromptStyle = .claudeMarkdown

    private let estimator: any TokenEstimating

    public init(estimator: any TokenEstimating = ApproximateTokenEstimator.default) {
        self.estimator = estimator
    }

    public func render(
        _ pack: ContextPack,
        configuration: RenderConfiguration = .default
    ) -> RenderedPromptPack {

        var parts: [String] = []

        parts.append("# MinifyAI Prompt Pack · Claude\n")

        let sorted = pack.sortedSections

        for section in sorted {
            guard section.sectionType != .sourceSummary else { continue }
            parts.append(renderSection(section))
        }

        if configuration.includeSourceSummary {
            parts.append(RendererHelpers.sourceSummaryBlock(from: pack))
        }

        if configuration.includeWarningsInPrompt && !pack.warnings.isEmpty {
            parts.append(RendererHelpers.warningsBlock(from: pack.warnings))
        }

        let promptText = parts.joined(separator: "\n")
        let (included, excluded) = RendererHelpers.buildSummaries(from: pack)

        return RenderedPromptPack(
            promptText: promptText,
            providerProfile: pack.providerProfile,
            estimatedTokens: estimator.estimateTokens(for: promptText),
            includedSummary: included,
            excludedSummary: excluded,
            warnings: pack.warnings
        )
    }

    // MARK: - Private Rendering

    private func renderSection(_ section: ContextSection) -> String {
        let tag = xmlTag(for: section.sectionType)
        return """
        <\(tag)>
        \(section.content.trimmingCharacters(in: .whitespacesAndNewlines))
        </\(tag)>
        """
    }

    private func xmlTag(for type: ContextSection.SectionType) -> String {
        switch type {
        case .task:               return "task"
        case .instructions:       return "instructions"
        case .hardConstraints:    return "constraints"
        case .projectOverview:    return "project_context"
        case .architecture:       return "architecture"
        case .moduleContext:      return "relevant_modules"
        case .memory:             return "memory"
        case .decision:           return "decisions"
        case .gotcha:             return "gotchas"
        case .unresolvedQuestion: return "open_questions"
        case .responseFormat:     return "response_format"
        case .sourceSummary:      return "sources"
        }
    }
}
