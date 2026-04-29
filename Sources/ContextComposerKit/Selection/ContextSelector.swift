import Foundation

/// The result of a context selection pass.
public struct ContextSelectionResult: Sendable {
    public let includedSections: [ContextSection]
    public let excludedItems: [ExcludedContextItem]
    public let warnings: [ContextWarning]
    public let estimatedTokens: Int

    public init(
        includedSections: [ContextSection],
        excludedItems: [ExcludedContextItem],
        warnings: [ContextWarning],
        estimatedTokens: Int
    ) {
        self.includedSections = includedSections
        self.excludedItems = excludedItems
        self.warnings = warnings
        self.estimatedTokens = estimatedTokens
    }
}

/// Selects which context candidates to include in the final pack.
///
/// Responsibilities:
/// 1. Hard-filter candidates by lifecycle rules (rejected, suggested, stale, confidence).
/// 2. Apply per-category caps.
/// 3. Deduplicate by content similarity.
/// 4. Sort by score.
/// 5. Fit into the token budget, trimming from lowest score upward.
/// 6. Build ContextSections from the survivors.
/// 7. Record all exclusions with reasons.
/// 8. Emit warnings for notable conditions.
public struct ContextSelector: Sendable {

    private let scorer: ContextRelevanceScorer
    private let estimator: any TokenEstimating

    public init(
        scorer: ContextRelevanceScorer = ContextRelevanceScorer(),
        estimator: any TokenEstimating = ApproximateTokenEstimator.default
    ) {
        self.scorer = scorer
        self.estimator = estimator
    }

    // MARK: - Public API

    public func select(
        task: UserTask,
        candidates: [ContextCandidate],
        configuration: ContextSelectionConfiguration
    ) -> ContextSelectionResult {

        var excluded: [ExcludedContextItem] = []
        var warnings: [ContextWarning] = []

        // 1. Hard filter — lifecycle and config rules.
        let (eligible, lifecycleExclusions) = applyLifecycleFilters(
            candidates: candidates,
            task: task,
            configuration: configuration
        )
        excluded.append(contentsOf: lifecycleExclusions)

        // 2. Score eligible candidates.
        let scores = scorer.score(candidates: eligible, task: task)
        let scoreMap = Dictionary(uniqueKeysWithValues: scores.map { ($0.candidateId, $0) })

        // 3. Sort by score descending.
        let sorted = eligible.sorted {
            (scoreMap[$0.id]?.score ?? 0) > (scoreMap[$1.id]?.score ?? 0)
        }

        // 4. Apply per-category caps.
        let (capped, capExclusions) = applyCategoryCaps(sorted: sorted, configuration: configuration, scoreMap: scoreMap)
        excluded.append(contentsOf: capExclusions)

        // 5. Deduplicate.
        let (deduped, dupeExclusions) = configuration.deduplicate
            ? deduplicate(candidates: capped, scoreMap: scoreMap)
            : (capped, [])
        excluded.append(contentsOf: dupeExclusions)

        // 6. Warn if no approved memories.
        let hasApprovedMemory = deduped.contains { $0.kind == .memory }
        if !hasApprovedMemory && !candidates.filter({ $0.kind == .memory }).isEmpty {
            warnings.append(ContextWarning(
                kind: .noApprovedMemories,
                message: "No approved memories were found for this task."
            ))
        }

        // 7. Warn if no relevant modules.
        let hasModules = deduped.contains { $0.kind == .rosettaModule }
        if !hasModules && !candidates.filter({ $0.kind == .rosettaModule }).isEmpty {
            warnings.append(ContextWarning(
                kind: .noRelevantModules,
                message: "No modules scored high enough to be included."
            ))
        }

        // 8. Build sections from survivors.
        var sections: [ContextSection] = []

        // Task section is always first — built from the UserTask, not candidates.
        sections.append(makeTaskSection(task: task))

        // Build sections from selected candidates.
        for candidate in deduped {
            let section = makeSection(from: candidate)
            sections.append(section)
        }

        // 9. Fit into token budget.
        let budget = configuration.tokenBudget
        let protected = Set(budget.trimStrategy.protectedSectionTypes)

        let (fitted, trimExclusions, budgetWarnings) = fitToBudget(
            sections: sections,
            budget: budget,
            protectedTypes: protected,
            candidates: deduped
        )
        excluded.append(contentsOf: trimExclusions)
        warnings.append(contentsOf: budgetWarnings)

        let totalTokens = fitted.reduce(0) { $0 + $1.estimatedTokens }

        return ContextSelectionResult(
            includedSections: fitted,
            excludedItems: excluded,
            warnings: warnings,
            estimatedTokens: totalTokens
        )
    }

    // MARK: - Lifecycle Filtering

    private func applyLifecycleFilters(
        candidates: [ContextCandidate],
        task: UserTask,
        configuration: ContextSelectionConfiguration
    ) -> ([ContextCandidate], [ExcludedContextItem]) {
        var eligible: [ContextCandidate] = []
        var excluded: [ExcludedContextItem] = []

        for candidate in candidates {
            if let reason = lifecycleExclusionReason(for: candidate, task: task, configuration: configuration) {
                excluded.append(ExcludedContextItem(
                    title: candidate.title,
                    sourceReference: candidate.sourceReference,
                    reason: reason,
                    estimatedTokens: estimator.estimateTokens(for: candidate.content)
                ))
            } else {
                eligible.append(candidate)
            }
        }

        return (eligible, excluded)
    }

    private func lifecycleExclusionReason(
        for candidate: ContextCandidate,
        task: UserTask,
        configuration: ContextSelectionConfiguration
    ) -> ExclusionReason? {

        // Rejected memories are NEVER included.
        if candidate.memoryStatus == .rejected { return .rejected }

        // Archived memories are excluded unless config explicitly allows stale.
        if candidate.memoryStatus == .archived && !configuration.includeStale { return .archived }

        // Suggested memories are excluded by default.
        if candidate.memoryStatus == .suggested && !configuration.includeSuggestedMemories { return .suggestedOnly }

        // Stale items are excluded unless config allows them.
        if candidate.isStale && !configuration.includeStale { return .stale }

        // Confidence below threshold.
        if candidate.confidence < configuration.minimumConfidence { return .lowConfidence }

        // Wrong project.
        if let taskProject = task.projectId,
           let candidateProject = candidate.projectId,
           taskProject != candidateProject {
            return .wrongProject
        }

        return nil
    }

    // MARK: - Category Caps

    private func applyCategoryCaps(
        sorted: [ContextCandidate],
        configuration: ContextSelectionConfiguration,
        scoreMap: [String: ContextRelevanceScore]
    ) -> ([ContextCandidate], [ExcludedContextItem]) {
        var counts: [CandidateKind: Int] = [:]
        var selected: [ContextCandidate] = []
        var excluded: [ExcludedContextItem] = []

        for candidate in sorted {
            let cap = categoryCap(for: candidate.kind, configuration: configuration)
            let current = counts[candidate.kind, default: 0]

            if current < cap {
                selected.append(candidate)
                counts[candidate.kind] = current + 1
            } else {
                excluded.append(ExcludedContextItem(
                    title: candidate.title,
                    sourceReference: candidate.sourceReference,
                    reason: .lowRelevance,
                    estimatedTokens: estimator.estimateTokens(for: candidate.content)
                ))
            }
        }

        return (selected, excluded)
    }

    private func categoryCap(for kind: CandidateKind, configuration: ContextSelectionConfiguration) -> Int {
        switch kind {
        case .rosettaModule:       return configuration.maxModules
        case .memory:              return configuration.maxMemories
        case .decision:            return configuration.maxDecisions
        case .rosettaGotcha:       return configuration.maxGotchas
        case .hardConstraint:      return .max
        case .projectOverview:     return 1
        case .architectureNote:    return 1
        case .sessionNote:         return 3
        case .unresolvedQuestion:  return 5
        }
    }

    // MARK: - Deduplication

    private func deduplicate(
        candidates: [ContextCandidate],
        scoreMap: [String: ContextRelevanceScore]
    ) -> ([ContextCandidate], [ExcludedContextItem]) {
        var seen: [String] = []
        var selected: [ContextCandidate] = []
        var excluded: [ExcludedContextItem] = []

        for candidate in candidates {
            let fingerprint = makeFingerprint(for: candidate.content)
            let isDuplicate = seen.contains { isSimilar(fingerprint, $0) }

            if isDuplicate {
                excluded.append(ExcludedContextItem(
                    title: candidate.title,
                    sourceReference: candidate.sourceReference,
                    reason: .duplicate,
                    estimatedTokens: estimator.estimateTokens(for: candidate.content)
                ))
            } else {
                seen.append(fingerprint)
                selected.append(candidate)
            }
        }

        return (selected, excluded)
    }

    /// Creates a compact fingerprint for similarity comparison.
    private func makeFingerprint(for content: String) -> String {
        let words = content
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count >= 4 }
        let unique = Array(Set(words)).sorted()
        return unique.prefix(20).joined(separator: " ")
    }

    /// Two fingerprints are similar if >70% of tokens overlap.
    private func isSimilar(_ a: String, _ b: String) -> Bool {
        let setA = Set(a.components(separatedBy: " "))
        let setB = Set(b.components(separatedBy: " "))
        guard !setA.isEmpty && !setB.isEmpty else { return false }
        let overlap = setA.intersection(setB).count
        let smaller = min(setA.count, setB.count)
        return smaller > 0 && Double(overlap) / Double(smaller) >= 0.70
    }

    // MARK: - Token Budget Fitting

    private func fitToBudget(
        sections: [ContextSection],
        budget: TokenBudget,
        protectedTypes: Set<ContextSection.SectionType>,
        candidates: [ContextCandidate]
    ) -> ([ContextSection], [ExcludedContextItem], [ContextWarning]) {
        var warnings: [ContextWarning] = []
        var excluded: [ExcludedContextItem] = []

        let totalBeforeTrim = sections.reduce(0) { $0 + $1.estimatedTokens }

        guard totalBeforeTrim > budget.targetInputTokens else {
            return (sections, excluded, warnings)
        }

        // Budget exceeded — need to trim.
        warnings.append(ContextWarning(
            kind: .tokenBudgetExceeded,
            message: "Estimated tokens (\(totalBeforeTrim)) exceeded budget (\(budget.targetInputTokens)). Trimming lower-priority sections."
        ))

        // Separate protected from trimmable.
        let protected = sections.filter { protectedTypes.contains($0.sectionType) || $0.sectionType.isRequired }
        let protectedTokens = protected.reduce(0) { $0 + $1.estimatedTokens }
        var remainingBudget = budget.targetInputTokens - protectedTokens

        var surviving: [ContextSection] = protected
        var trimmed = false

        // Add trimmable sections one by one (already sorted lowest priority first) until budget is full.
        let ordered = sections
            .filter { !protectedTypes.contains($0.sectionType) && !$0.sectionType.isRequired }
            .sorted { $0.priority < $1.priority } // lowest priority number = most important

        for section in ordered {
            if section.estimatedTokens <= remainingBudget {
                surviving.append(section)
                remainingBudget -= section.estimatedTokens
            } else {
                trimmed = true
                // Find the candidate that produced this section for the exclusion record.
                let sourceRef = section.sourceReferences.first ?? ContextSourceReference(sourceType: .appGenerated)
                excluded.append(ExcludedContextItem(
                    title: section.title,
                    sourceReference: sourceRef,
                    reason: .tokenBudget,
                    estimatedTokens: section.estimatedTokens
                ))
            }
        }

        if trimmed {
            warnings.append(ContextWarning(
                kind: .contextTrimmed,
                message: "One or more context sections were removed to stay within the token budget."
            ))
        }

        return (surviving.sorted { $0.priority < $1.priority }, excluded, warnings)
    }

    // MARK: - Section Construction

    private func makeTaskSection(task: UserTask) -> ContextSection {
        var content = task.prompt
        if let style = task.requestedOutputStyle {
            content += "\n\n**Response instructions:** \(style.renderedInstruction)"
        }
        let tokens = estimator.estimateTokens(for: content)
        return ContextSection(
            title: task.title ?? "Task",
            sectionType: .task,
            content: content,
            priority: ContextSection.SectionType.task.defaultPriority,
            estimatedTokens: tokens,
            sourceReferences: [ContextSourceReference(
                sourceType: .userTask,
                sourceId: task.id.uuidString,
                title: task.title
            )]
        )
    }

    private func makeSection(from candidate: ContextCandidate) -> ContextSection {
        let sectionType = sectionType(for: candidate.kind)
        let tokens = estimator.estimateTokens(for: candidate.content)
        return ContextSection(
            title: candidate.title,
            sectionType: sectionType,
            content: candidate.content,
            priority: sectionType.defaultPriority,
            estimatedTokens: tokens,
            sourceReferences: [candidate.sourceReference]
        )
    }

    private func sectionType(for kind: CandidateKind) -> ContextSection.SectionType {
        switch kind {
        case .memory:               return .memory
        case .decision:             return .decision
        case .sessionNote:          return .memory
        case .rosettaModule:        return .moduleContext
        case .rosettaGotcha:        return .gotcha
        case .unresolvedQuestion:   return .unresolvedQuestion
        case .hardConstraint:       return .hardConstraints
        case .projectOverview:      return .projectOverview
        case .architectureNote:     return .architecture
        }
    }
}
