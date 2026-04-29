import Testing
import Foundation
@testable import ContextComposerKit

@Suite("ContextRelevanceScorer")
struct RelevanceScorerTests {

    let scorer = ContextRelevanceScorer()

    // MARK: - Helpers

    func makeTask(prompt: String, tags: [String] = [], moduleHints: [String] = [], projectId: String? = nil) -> UserTask {
        UserTask(prompt: prompt, projectId: projectId, moduleHints: moduleHints, tags: tags)
    }

    func makeCandidate(
        id: String = UUID().uuidString,
        title: String = "Test",
        content: String,
        kind: CandidateKind = .memory,
        tags: [String] = [],
        projectId: String? = nil,
        moduleId: String? = nil,
        confidence: Double = 1.0,
        isStale: Bool = false,
        memoryStatus: RailroadContextInput.MemoryStatus? = .approved
    ) -> ContextCandidate {
        ContextCandidate(
            id: id,
            title: title,
            content: content,
            kind: kind,
            sourceReference: ContextSourceReference(sourceType: .railroadMemory),
            tags: tags,
            projectId: projectId,
            moduleId: moduleId,
            confidence: confidence,
            isStale: isStale,
            memoryStatus: memoryStatus
        )
    }

    // MARK: - Tests

    @Test("High keyword overlap produces higher score than zero overlap")
    func highKeywordOverlapScoresHigher() {
        let task = makeTask(prompt: "Refactor the authentication module using async await Swift concurrency")
        let relevant = makeCandidate(content: "The authentication module was refactored to use async await patterns")
        let irrelevant = makeCandidate(content: "The database schema was updated last Tuesday")

        let scores = scorer.score(candidates: [relevant, irrelevant], task: task)
        let relevantScore = scores.first(where: { $0.candidateId == relevant.id })!
        let irrelevantScore = scores.first(where: { $0.candidateId == irrelevant.id })!

        #expect(relevantScore.score > irrelevantScore.score)
    }

    @Test("Tag overlap contributes positively to score")
    func tagOverlapBoostsScore() {
        let task = makeTask(prompt: "Update the auth flow", tags: ["authentication", "security"])
        let tagged = makeCandidate(content: "Security policy update", tags: ["authentication", "security"])
        let untagged = makeCandidate(content: "Security policy update")

        let scores = scorer.score(candidates: [tagged, untagged], task: task)
        let taggedScore = scores.first(where: { $0.candidateId == tagged.id })!
        let untaggedScore = scores.first(where: { $0.candidateId == untagged.id })!

        #expect(taggedScore.score > untaggedScore.score)
    }

    @Test("Project match boosts score")
    func projectMatchBoostsScore() {
        let task = makeTask(prompt: "Fix the login flow", projectId: "minifyai")
        let matched = makeCandidate(content: "Fix the login flow implementation", projectId: "minifyai")
        let mismatched = makeCandidate(content: "Fix the login flow implementation", projectId: "other-project")

        let scores = scorer.score(candidates: [matched, mismatched], task: task)
        let matchedScore = scores.first(where: { $0.candidateId == matched.id })!
        let mismatchedScore = scores.first(where: { $0.candidateId == mismatched.id })!

        #expect(matchedScore.score > mismatchedScore.score)
    }

    @Test("Module hint match boosts score")
    func moduleHintMatchBoostsScore() {
        let task = makeTask(prompt: "Update the auth module", moduleHints: ["auth"])
        let inModule = makeCandidate(content: "Auth module update", moduleId: "auth")
        let outOfModule = makeCandidate(content: "Auth module update", moduleId: "payments")

        let scores = scorer.score(candidates: [inModule, outOfModule], task: task)
        let inScore = scores.first(where: { $0.candidateId == inModule.id })!
        let outScore = scores.first(where: { $0.candidateId == outOfModule.id })!

        #expect(inScore.score > outScore.score)
    }

    @Test("Hard constraint always gets maximum score boost")
    func hardConstraintGetsMaximumBoost() {
        let task = makeTask(prompt: "Build a UI component")
        let constraint = makeCandidate(content: "Do not import SwiftUI", kind: .hardConstraint)
        let memory = makeCandidate(content: "Do not import SwiftUI", kind: .memory)

        let scores = scorer.score(candidates: [constraint, memory], task: task)
        let constraintScore = scores.first(where: { $0.candidateId == constraint.id })!
        let memoryScore = scores.first(where: { $0.candidateId == memory.id })!

        #expect(constraintScore.score > memoryScore.score)
    }

    @Test("Stale candidate receives a score penalty")
    func staleCandidateReceivesPenalty() {
        let task = makeTask(prompt: "Update the database layer")
        let fresh = makeCandidate(content: "Database layer uses GRDB for persistence", isStale: false)
        let stale = makeCandidate(content: "Database layer uses GRDB for persistence", isStale: true)

        let scores = scorer.score(candidates: [fresh, stale], task: task)
        let freshScore = scores.first(where: { $0.candidateId == fresh.id })!
        let staleScore = scores.first(where: { $0.candidateId == stale.id })!

        #expect(freshScore.score > staleScore.score)
    }

    @Test("Low confidence candidate receives penalty")
    func lowConfidenceCandidateReceivesPenalty() {
        let task = makeTask(prompt: "Fix the network layer")
        let confident = makeCandidate(content: "Network layer uses URLSession", confidence: 0.95)
        let uncertain = makeCandidate(content: "Network layer uses URLSession", confidence: 0.20)

        let scores = scorer.score(candidates: [confident, uncertain], task: task)
        let highScore = scores.first(where: { $0.candidateId == confident.id })!
        let lowScore = scores.first(where: { $0.candidateId == uncertain.id })!

        #expect(highScore.score > lowScore.score)
    }

    @Test("Score factors are non-empty and provide explanations")
    func scoreFactorsAreExplainable() {
        let task = makeTask(prompt: "Implement token estimation for the composer")
        let candidate = makeCandidate(content: "Token estimation is done via character count divided by four")

        let scores = scorer.score(candidates: [candidate], task: task)
        let score = scores.first!

        #expect(!score.factors.isEmpty)
        #expect(!score.explanation.isEmpty)
    }

    @Test("Score returns one result per input candidate")
    func scoreCountMatchesCandidateCount() {
        let task = makeTask(prompt: "Some task")
        let candidates = (0..<10).map { i in
            makeCandidate(id: "\(i)", content: "Candidate \(i) content")
        }
        let scores = scorer.score(candidates: candidates, task: task)
        #expect(scores.count == candidates.count)
    }
}
