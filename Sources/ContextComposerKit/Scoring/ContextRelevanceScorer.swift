import Foundation

/// Scores each context candidate against the current task.
///
/// Scoring is purely keyword/tag/metadata-based — no embeddings, no LLM calls.
/// Results are fully deterministic and explainable via `ScoringFactor` lists.
///
/// The scorer does NOT filter candidates. Filtering (stale, rejected, etc.)
/// is handled by the ContextSelector. The scorer only assigns scores so the
/// selector can make informed decisions.
public struct ContextRelevanceScorer: Sendable {

    /// How old (in days) a lastVerified date must be to trigger a stale penalty.
    public let stalenessThresholdDays: Int

    public init(stalenessThresholdDays: Int = 30) {
        self.stalenessThresholdDays = stalenessThresholdDays
    }

    // MARK: - Public API

    /// Score a collection of candidates against the given task.
    /// Returns scores in the same order as the input candidates.
    public func score(
        candidates: [ContextCandidate],
        task: UserTask
    ) -> [ContextRelevanceScore] {
        let taskKeywords = extractKeywords(from: task.prompt)
        let taskTags = Set(task.tags.map { $0.lowercased() })
        let moduleHints = Set(task.moduleHints.map { $0.lowercased() })

        return candidates.map { candidate in
            scoreCandidate(
                candidate,
                taskKeywords: taskKeywords,
                taskTags: taskTags,
                moduleHints: moduleHints,
                task: task
            )
        }
    }

    // MARK: - Private Scoring

    private func scoreCandidate(
        _ candidate: ContextCandidate,
        taskKeywords: Set<String>,
        taskTags: Set<String>,
        moduleHints: Set<String>,
        task: UserTask
    ) -> ContextRelevanceScore {
        var factors: [ScoringFactor] = []

        // Hard constraints get an unconditional maximum boost.
        if candidate.kind == .hardConstraint {
            factors.append(.hardConstraintBoost)
            let rawScore = factors.reduce(0.0) { $0 + $1.scoreContribution }
            return ContextRelevanceScore(
                candidateId: candidate.id,
                score: rawScore,
                factors: factors
            )
        }

        // --- Keyword overlap ---
        let candidateKeywords = extractKeywords(from: candidate.content + " " + candidate.title)
        let keywordMatches = taskKeywords.intersection(candidateKeywords).count
        if keywordMatches > 0 {
            factors.append(.keywordOverlap(matchCount: keywordMatches))
        } else {
            factors.append(.lowKeywordOverlap)
        }

        // --- Tag overlap ---
        let candidateTags = Set(candidate.tags.map { $0.lowercased() })
        let matchedTags = taskTags.intersection(candidateTags)
        if !matchedTags.isEmpty {
            factors.append(.tagOverlap(matchedTags: Array(matchedTags)))
        } else {
            factors.append(.noTagOverlap)
        }

        // --- Project match ---
        if let taskProject = task.projectId, let candidateProject = candidate.projectId {
            if taskProject == candidateProject {
                factors.append(.projectMatch)
            } else {
                factors.append(.noProjectMatch)
            }
        }

        // --- Module match ---
        if let moduleId = candidate.moduleId {
            let lowercasedModuleId = moduleId.lowercased()
            if moduleHints.contains(where: { lowercasedModuleId.contains($0) || $0.contains(lowercasedModuleId) }) {
                factors.append(.moduleMatch(moduleName: moduleId))
            }
        }
        // Also check if the candidate name itself matches a module hint.
        let candidateNameLower = candidate.title.lowercased()
        if !moduleHints.isEmpty && moduleHints.contains(where: { candidateNameLower.contains($0) || $0.contains(candidateNameLower) }) {
            if !factors.contains(where: { if case .moduleMatch = $0 { return true }; return false }) {
                factors.append(.moduleMatch(moduleName: candidate.title))
            }
        }

        // --- Session match ---
        if let taskSession = task.sessionId, let candidateSession = candidate.sessionId {
            if taskSession == candidateSession {
                factors.append(.sessionMatch)
            }
        }

        // --- Category weight ---
        if highImportanceKinds.contains(candidate.kind) {
            factors.append(.highImportanceKind)
        }

        // --- Confidence ---
        if candidate.confidence >= 0.8 {
            factors.append(.highConfidence(value: candidate.confidence))
        } else if candidate.confidence < 0.5 {
            factors.append(.lowConfidencePenalty(value: candidate.confidence))
        }

        // --- Recency / staleness ---
        let now = Date()
        if let lastVerified = candidate.lastVerified {
            let daysAgo = Calendar.current.dateComponents([.day], from: lastVerified, to: now).day ?? 0
            if daysAgo < 7 {
                factors.append(.recentlyVerified(daysAgo: daysAgo))
            } else if daysAgo >= stalenessThresholdDays {
                factors.append(.stalePenalty(daysStale: daysAgo))
            }
        } else if candidate.isStale {
            factors.append(.stalePenalty(daysStale: stalenessThresholdDays))
        }

        // Sum contributions, clamp to 0.0 minimum (score can exceed 1.0 — that's intentional for pinned items).
        let rawScore = factors.reduce(0.0) { $0 + $1.scoreContribution }
        let finalScore = max(0.0, rawScore)

        return ContextRelevanceScore(
            candidateId: candidate.id,
            score: finalScore,
            factors: factors
        )
    }

    // MARK: - Keyword Extraction

    /// Tokenises text into a set of lowercase words, stripping punctuation
    /// and filtering out common stop words and very short tokens.
    private func extractKeywords(from text: String) -> Set<String> {
        let lowercased = text.lowercased()
        // Split on whitespace and common punctuation.
        let tokens = lowercased.components(separatedBy: CharacterSet.alphanumerics.inverted)
        return Set(
            tokens
                .filter { $0.count >= 3 }
                .filter { !stopWords.contains($0) }
        )
    }

    // MARK: - Static Data

    private let highImportanceKinds: Set<CandidateKind> = [
        .hardConstraint,
        .decision,
        .rosettaGotcha
    ]

    private let stopWords: Set<String> = [
        "the", "and", "for", "that", "this", "with", "from", "have", "will",
        "are", "was", "not", "but", "what", "all", "can", "into", "its",
        "one", "our", "out", "use", "has", "how", "any", "been", "more",
        "when", "there", "their", "they", "also", "which", "would", "about",
        "should", "could", "then", "than", "some", "each", "make", "like",
        "him", "her", "his", "she", "you", "your", "they", "them", "just",
        "over", "after", "such", "only", "well", "may", "two", "way", "yes",
        "need", "want", "add", "new", "see", "set", "get", "put", "run"
    ]
}
