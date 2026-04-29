import Foundation

/// Renders a ContextPack as clean, portable markdown that works well
/// in any LLM chat interface, including Gemini, Ollama, and custom providers.
///
/// Uses `##` subheaders (less visually dominant than `#`) and clear
/// horizontal rule dividers between sections. No XML tags, no role preamble.
///
/// Output example:
/// ```
/// # Prompt Pack
///
/// ---
///
/// ## Task
///
/// Refactor the authentication module...
///
/// ---
///
/// ## Hard Constraints
///
/// - Do not import SwiftUI
///
/// ---
/// ```
public struct GenericMarkdownPromptRenderer: PromptRendering {

    public let promptStyle: ProviderProfile.PromptStyle = .genericMarkdown

    private let estimator: any TokenEstimating

    public init(estimator: any TokenEstimating = ApproximateTokenEstimator.default) {
        self.estimator = estimator
    }

    public func render(
        _ pack: ContextPack,
        configuration: RenderConfiguration = .default
    ) -> RenderedPromptPack {

        var parts: [String] = ["# Prompt Pack\n"]

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

        let promptText = parts.joined(separator: "\n\n---\n\n")
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
        let header = sectionHeader(for: section.sectionType)
        let body = section.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        ## \(header)

        \(body)
        """
    }

    private func sectionHeader(for type: ContextSection.SectionType) -> String {
        switch type {
        case .task:               return "Task"
        case .instructions:       return "Instructions"
        case .hardConstraints:    return "Constraints"
        case .projectOverview:    return "Project Context"
        case .architecture:       return "Architecture"
        case .moduleContext:      return "Relevant Modules"
        case .memory:             return "Memory"
        case .decision:           return "Decisions"
        case .gotcha:             return "Gotchas"
        case .unresolvedQuestion: return "Open Questions"
        case .responseFormat:     return "Response Format"
        case .sourceSummary:      return "Sources"
        }
    }
}
