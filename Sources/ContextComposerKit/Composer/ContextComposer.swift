import Foundation

/// The primary public entry point for ContextComposerKit.
///
/// `ContextComposer` orchestrates the full pipeline:
/// 1. Build candidates from RosettaKit and RailroadKit input adapters.
/// 2. Score candidates for relevance to the task.
/// 3. Select which candidates to include, respecting the token budget.
/// 4. Assemble the structured `ContextPack`.
/// 5. Render the pack into a paste-ready `RenderedPromptPack`.
///
/// All dependencies are injected — no singletons, no global state.
/// Create one instance per app session and reuse it.
///
/// ```swift
/// let composer = ContextComposer()
///
/// let pack = composer.buildContextPack(
///     task: task,
///     rosettaContext: rosettaInput,
///     railroadContext: railroadInput,
///     configuration: .standard()
/// )
///
/// let rendered = composer.render(pack, providerProfile: .claudeSonnet)
/// print(rendered.promptText)
/// ```
public final class ContextComposer: Sendable {

    // MARK: - Dependencies

    private let candidateBuilder: ContextCandidateBuilder
    private let selector: ContextSelector
    private let estimator: any TokenEstimating
    private let renderers: [ProviderProfile.PromptStyle: any PromptRendering]

    // MARK: - Init

    /// Creates a ContextComposer with default implementations.
    /// Suitable for production use in the MinifyAI app.
    public convenience init() {
        let estimator = ApproximateTokenEstimator.default
        self.init(
            candidateBuilder: ContextCandidateBuilder(),
            selector: ContextSelector(estimator: estimator),
            estimator: estimator,
            renderers: Self.defaultRenderers(estimator: estimator)
        )
    }

    /// Creates a ContextComposer with injected dependencies.
    /// Use this initialiser in tests to supply mocks or test doubles.
    public init(
        candidateBuilder: ContextCandidateBuilder,
        selector: ContextSelector,
        estimator: any TokenEstimating,
        renderers: [ProviderProfile.PromptStyle: any PromptRendering]
    ) {
        self.candidateBuilder = candidateBuilder
        self.selector = selector
        self.estimator = estimator
        self.renderers = renderers
    }

    // MARK: - Public API

    /// Assembles a `ContextPack` from a task and its associated context inputs.
    ///
    /// - Parameters:
    ///   - task: The user's current task prompt.
    ///   - rosettaContext: Project documentation from RosettaKit.
    ///   - railroadContext: Memories and session context from RailroadKit.
    ///   - configuration: Selection rules and token budget.
    ///   - providerProfile: The target LLM provider (controls token budget defaults).
    /// - Returns: A fully assembled `ContextPack` ready for rendering.
    public func buildContextPack(
        task: UserTask,
        rosettaContext: RosettaContextInput?,
        railroadContext: RailroadContextInput?,
        configuration: ContextSelectionConfiguration,
        providerProfile: ProviderProfile = .claudeSonnet
    ) -> ContextPack {

        // Build candidates from both inputs.
        let candidates = candidateBuilder.build(
            rosettaContext: rosettaContext,
            railroadContext: railroadContext
        )

        // Run selection — scoring, filtering, budget fitting.
        let result = selector.select(
            task: task,
            candidates: candidates,
            configuration: configuration
        )

        // Always add an approximate token warning if the estimator is approximate.
        var warnings = result.warnings
        if estimator.isApproximate {
            warnings.append(ContextWarning(
                kind: .approximateTokenEstimate,
                message: "Token counts are approximate (character-based estimate). Actual token usage may vary by ±15%."
            ))
        }

        return ContextPack(
            task: task,
            providerProfile: providerProfile,
            tokenBudget: configuration.tokenBudget,
            includedSections: result.includedSections,
            excludedItems: result.excludedItems,
            warnings: warnings,
            estimatedTokens: result.estimatedTokens
        )
    }

    /// Renders a `ContextPack` into a paste-ready `RenderedPromptPack`.
    ///
    /// - Parameters:
    ///   - pack: The assembled context pack.
    ///   - providerProfile: Controls which renderer is selected.
    ///   - renderConfiguration: Optional overrides for what metadata to include in the output.
    /// - Returns: A `RenderedPromptPack` with the final prompt text and review metadata.
    public func render(
        _ pack: ContextPack,
        providerProfile: ProviderProfile,
        renderConfiguration: RenderConfiguration = .default
    ) -> RenderedPromptPack {
        let renderer = renderers[providerProfile.preferredPromptStyle] ?? GenericMarkdownPromptRenderer(estimator: estimator)
        return renderer.render(pack, configuration: renderConfiguration)
    }

    /// Convenience method that builds and renders in a single call.
    public func buildAndRender(
        task: UserTask,
        rosettaContext: RosettaContextInput?,
        railroadContext: RailroadContextInput?,
        configuration: ContextSelectionConfiguration,
        providerProfile: ProviderProfile = .claudeSonnet,
        renderConfiguration: RenderConfiguration = .default
    ) -> RenderedPromptPack {
        let pack = buildContextPack(
            task: task,
            rosettaContext: rosettaContext,
            railroadContext: railroadContext,
            configuration: configuration,
            providerProfile: providerProfile
        )
        return render(pack, providerProfile: providerProfile, renderConfiguration: renderConfiguration)
    }

    // MARK: - Private Helpers

    private static func defaultRenderers(estimator: any TokenEstimating) -> [ProviderProfile.PromptStyle: any PromptRendering] {
        [
            .claudeMarkdown: ClaudeMarkdownPromptRenderer(estimator: estimator),
            .openAIMarkdown: OpenAIMarkdownPromptRenderer(estimator: estimator),
            .genericMarkdown: GenericMarkdownPromptRenderer(estimator: estimator)
        ]
    }
}

// MARK: - ContextCandidateBuilder

/// Converts RosettaKit and RailroadKit input adapters into a flat list
/// of `ContextCandidate` values ready for scoring.
///
/// This is a public type so it can be injected or subclassed in tests.
public struct ContextCandidateBuilder: Sendable {

    public init() {}

    public func build(
        rosettaContext: RosettaContextInput?,
        railroadContext: RailroadContextInput?
    ) -> [ContextCandidate] {
        var candidates: [ContextCandidate] = []

        if let rosetta = rosettaContext {
            candidates.append(contentsOf: buildRosettaCandidates(from: rosetta))
        }

        if let railroad = railroadContext {
            candidates.append(contentsOf: buildRailroadCandidates(from: railroad))
        }

        return candidates
    }

    // MARK: - Rosetta Candidates

    private func buildRosettaCandidates(from input: RosettaContextInput) -> [ContextCandidate] {
        var candidates: [ContextCandidate] = []

        // Project overview.
        if let summary = input.projectSummary {
            candidates.append(ContextCandidate(
                id: "rosetta-overview-\(input.projectId)",
                title: "Project Overview",
                content: summary,
                kind: .projectOverview,
                sourceReference: ContextSourceReference(
                    sourceType: .rosettaDocument,
                    sourceId: input.projectId,
                    title: "Project Overview",
                    confidence: 1.0,
                    lastVerified: input.lastVerified
                ),
                projectId: input.projectId,
                confidence: 1.0,
                lastVerified: input.lastVerified,
                isStale: isStale(lastVerified: input.lastVerified)
            ))
        }

        // Architecture notes.
        if let arch = input.architectureNotes {
            candidates.append(ContextCandidate(
                id: "rosetta-arch-\(input.projectId)",
                title: "Architecture",
                content: arch,
                kind: .architectureNote,
                sourceReference: ContextSourceReference(
                    sourceType: .rosettaDocument,
                    sourceId: input.projectId,
                    title: "Architecture Notes",
                    confidence: 1.0,
                    lastVerified: input.lastVerified
                ),
                projectId: input.projectId,
                confidence: 1.0,
                lastVerified: input.lastVerified,
                isStale: isStale(lastVerified: input.lastVerified)
            ))
        }

        // Modules.
        for module in input.modules {
            candidates.append(ContextCandidate(
                id: "rosetta-module-\(module.id)",
                title: module.name,
                content: module.summary,
                kind: .rosettaModule,
                sourceReference: ContextSourceReference(
                    sourceType: .rosettaModule,
                    sourceId: module.id,
                    title: module.name,
                    path: module.filePath,
                    confidence: 1.0,
                    lastVerified: module.lastVerified
                ),
                tags: module.tags,
                projectId: input.projectId,
                moduleId: module.id,
                confidence: 1.0,
                lastVerified: module.lastVerified,
                isStale: isStale(lastVerified: module.lastVerified)
            ))
        }

        // Gotchas.
        for gotcha in input.gotchas {
            let content = gotcha.description
            candidates.append(ContextCandidate(
                id: "rosetta-gotcha-\(gotcha.id)",
                title: gotcha.title,
                content: content,
                kind: .rosettaGotcha,
                sourceReference: ContextSourceReference(
                    sourceType: .rosettaDocument,
                    sourceId: gotcha.id,
                    title: gotcha.title,
                    confidence: 1.0,
                    lastVerified: input.lastVerified
                ),
                tags: gotcha.tags,
                projectId: input.projectId,
                confidence: 1.0,
                isStale: isStale(lastVerified: input.lastVerified)
            ))
        }

        // Unresolved questions.
        for question in input.unresolvedQuestions {
            var content = question.question
            if let ctx = question.context { content += "\n\nContext: \(ctx)" }
            candidates.append(ContextCandidate(
                id: "rosetta-question-\(question.id)",
                title: question.question,
                content: content,
                kind: .unresolvedQuestion,
                sourceReference: ContextSourceReference(
                    sourceType: .rosettaDocument,
                    sourceId: question.id,
                    title: question.question,
                    confidence: 1.0,
                    lastVerified: input.lastVerified
                ),
                tags: question.tags,
                projectId: input.projectId,
                confidence: 1.0
            ))
        }

        return candidates
    }

    // MARK: - Railroad Candidates

    private func buildRailroadCandidates(from input: RailroadContextInput) -> [ContextCandidate] {
        var candidates: [ContextCandidate] = []

        // Hard constraints — always included, maximum priority.
        for constraint in input.hardConstraints {
            candidates.append(ContextCandidate(
                id: "railroad-constraint-\(constraint.id)",
                title: constraint.title,
                content: constraint.content,
                kind: .hardConstraint,
                sourceReference: ContextSourceReference(
                    sourceType: .railroadMemory,
                    sourceId: constraint.id,
                    title: constraint.title,
                    confidence: 1.0
                ),
                projectId: constraint.projectId,
                confidence: 1.0
            ))
        }

        // Memories.
        for memory in input.memories {
            candidates.append(ContextCandidate(
                id: "railroad-memory-\(memory.id)",
                title: memory.title,
                content: memory.content,
                kind: .memory,
                sourceReference: ContextSourceReference(
                    sourceType: .railroadMemory,
                    sourceId: memory.id,
                    title: memory.title,
                    confidence: memory.confidence,
                    lastVerified: memory.lastVerified
                ),
                tags: memory.tags,
                projectId: memory.projectId,
                moduleId: memory.moduleId,
                sessionId: memory.sessionId,
                confidence: memory.confidence,
                createdAt: memory.createdAt,
                lastVerified: memory.lastVerified,
                isStale: isStale(lastVerified: memory.lastVerified),
                memoryStatus: memory.status
            ))
        }

        // Decisions.
        for decision in input.decisions {
            var content = "**Rationale:** \(decision.rationale)"
            if let outcome = decision.outcome { content += "\n\n**Outcome:** \(outcome)" }
            candidates.append(ContextCandidate(
                id: "railroad-decision-\(decision.id)",
                title: decision.title,
                content: content,
                kind: .decision,
                sourceReference: ContextSourceReference(
                    sourceType: .railroadDecision,
                    sourceId: decision.id,
                    title: decision.title,
                    confidence: 1.0
                ),
                tags: decision.tags,
                projectId: decision.projectId,
                confidence: 1.0,
                createdAt: decision.createdAt
            ))
        }

        // Session notes.
        for note in input.sessionNotes {
            candidates.append(ContextCandidate(
                id: "railroad-session-\(note.id)",
                title: "Session Note",
                content: note.content,
                kind: .sessionNote,
                sourceReference: ContextSourceReference(
                    sourceType: .railroadSession,
                    sourceId: note.id,
                    title: "Session Note",
                    confidence: 1.0
                ),
                tags: note.tags,
                sessionId: note.sessionId,
                confidence: 1.0,
                createdAt: note.createdAt
            ))
        }

        return candidates
    }

    // MARK: - Helpers

    private func isStale(lastVerified: Date?, thresholdDays: Int = 30) -> Bool {
        guard let date = lastVerified else { return false }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        return days >= thresholdDays
    }
}
