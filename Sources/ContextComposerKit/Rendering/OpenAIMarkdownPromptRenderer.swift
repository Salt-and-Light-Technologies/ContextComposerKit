import Foundation

/// Renders a ContextPack as header-structured markdown optimised for OpenAI ChatGPT.
///
/// OpenAI's chat UI renders markdown well. The standard pattern is to open
/// with a Role section (maps to System prompt in the API), then proceed
/// with Task, Hard Constraints, Project Context, etc. under `#` headers.
///
/// Output example:
/// ```
/// # Role
///
/// You are assisting with the following software project.
///
/// # Task
///
/// Refactor the authentication module to use async/await...
///
/// # Hard Constraints
///
/// - Do not import SwiftUI
///
/// # Project Context
///
/// ...
/// ```
public struct OpenAIMarkdownPromptRenderer: PromptRendering {

    public let promptStyle: ProviderProfile.PromptStyle = .openAIMarkdown

    private let estimator: any TokenEstimating

    public init(estimator: any TokenEstimating = ApproximateTokenEstimator.default) {
        self.estimator = estimator
    }

    public func render(
        _ pack: ContextPack,
        configuration: RenderConfiguration = .default
    ) -> RenderedPromptPack {

        var parts: [String] = []

        // OpenAI style opens with a Role preamble.
        parts.append("""
        # Role

        You are a senior software engineer. You are assisting with the following project.
        """)

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

        let promptText = parts.joined(separator: "\n\n")
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
        let header = markdownHeader(for: section.sectionType)
        let body = section.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        # \(header)

        \(body)
        """
    }

    private func markdownHeader(for type: ContextSection.SectionType) -> String {
        switch type {
        case .task:               return "Task"
        case .instructions:       return "Instructions"
        case .hardConstraints:    return "Hard Constraints"
        case .projectOverview:    return "Project Context"
        case .architecture:       return "Architecture"
        case .moduleContext:      return "Relevant Modules"
        case .memory:             return "Memory and Context"
        case .decision:           return "Key Decisions"
        case .gotcha:             return "Known Gotchas"
        case .unresolvedQuestion: return "Open Questions"
        case .responseFormat:     return "Required Response Format"
        case .sourceSummary:      return "Sources"
        }
    }
}
