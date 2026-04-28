import Testing
import Foundation
@testable import ContextComposerKit

@Suite("ContextSelector")
struct ContextSelectorTests {

    let selector = ContextSelector()

    // MARK: - Helpers

    func makeTask(prompt: String = "Implement the auth flow", projectId: String? = "minifyai") -> UserTask {
        UserTask(prompt: prompt, projectId: projectId)
    }

    func makeMemory(
        id: String = UUID().uuidString,
        title: String = "Memory",
        content: String = "Some memory content",
        status: RailroadContextInput.MemoryStatus = .approved,
        confidence: Double = 1.0,
        isStale: Bool = false,
        projectId: String? = "minifyai"
    ) -> ContextCandidate {
        ContextCandidate(
            id: id,
            title: title,
            content: content,
            kind: .memory,
            sourceReference: ContextSourceReference(sourceType: .railroadMemory, sourceId: id, title: title),
            projectId: projectId,
            confidence: confidence,
            isStale: isStale,
            memoryStatus: status
        )
    }

    func makeConstraint(id: String = UUID().uuidString, content: String = "Do not import SwiftUI") -> ContextCandidate {
        ContextCandidate(
            id: id,
            title: "Hard Constraint",
            content: content,
            kind: .hardConstraint,
            sourceReference: ContextSourceReference(sourceType: .railroadMemory, sourceId: id),
            confidence: 1.0
        )
    }

    func makeModule(id: String = UUID().uuidString, name: String = "AuthModule", summary: String = "Handles authentication") -> ContextCandidate {
        ContextCandidate(
            id: id,
            title: name,
            content: summary,
            kind: .rosettaModule,
            sourceReference: ContextSourceReference(sourceType: .rosettaModule, sourceId: id, title: name),
            tags: ["auth"],
            confidence: 1.0
        )
    }

    var defaultConfig: ContextSelectionConfiguration {
        ContextSelectionConfiguration(
            includeSuggestedMemories: false,
            includeStale: false,
            minimumConfidence: 0.5,
            tokenBudget: .standard
        )
    }

    // MARK: - Memory Lifecycle Tests

    @Test("Rejected memories are always excluded")
    func rejectedMemoriesAlwaysExcluded() {
        let rejected = makeMemory(status: .rejected)
        let result = selector.select(task: makeTask(), candidates: [rejected], configuration: defaultConfig)
        let ids = result.includedSections.flatMap { $0.sourceReferences.compactMap(\.sourceId) }
        #expect(!ids.contains(rejected.id))
        let reasons = result.excludedItems.map(\.reason)
        #expect(reasons.contains(.rejected))
    }

    @Test("Suggested memories are excluded by default")
    func suggestedMemoriesExcludedByDefault() {
        let suggested = makeMemory(status: .suggested)
        let result = selector.select(task: makeTask(), candidates: [suggested], configuration: defaultConfig)
        let reasons = result.excludedItems.map(\.reason)
        #expect(reasons.contains(.suggestedOnly))
    }

    @Test("Suggested memories included when config allows")
    func suggestedMemoriesIncludedWhenConfigAllows() {
        let suggested = makeMemory(id: "sug-1", title: "Suggested memory", content: "Implement auth flow", status: .suggested)
        var config = defaultConfig
        config.includeSuggestedMemories = true
        let result = selector.select(task: makeTask(), candidates: [suggested], configuration: config)
        let ids = result.includedSections.flatMap { $0.sourceReferences.compactMap(\.sourceId) }
        #expect(ids.contains("sug-1"))
    }

    @Test("Stale memories excluded by default")
    func staleMemoriesExcludedByDefault() {
        let stale = makeMemory(isStale: true)
        let result = selector.select(task: makeTask(), candidates: [stale], configuration: defaultConfig)
        let reasons = result.excludedItems.map(\.reason)
        #expect(reasons.contains(.stale))
    }

    @Test("Stale memories included when config allows")
    func staleMemoriesIncludedWhenConfigAllows() {
        let stale = makeMemory(id: "stale-1", content: "Implement auth flow with stale context", isStale: true)
        var config = defaultConfig
        config.includeStale = true
        let result = selector.select(task: makeTask(), candidates: [stale], configuration: config)
        let ids = result.includedSections.flatMap { $0.sourceReferences.compactMap(\.sourceId) }
        #expect(ids.contains("stale-1"))
    }

    @Test("Low confidence memory excluded when below threshold")
    func lowConfidenceMemoryExcluded() {
        let lowConf = makeMemory(confidence: 0.3)
        var config = defaultConfig
        config.minimumConfidence = 0.5
        let result = selector.select(task: makeTask(), candidates: [lowConf], configuration: config)
        let reasons = result.excludedItems.map(\.reason)
        #expect(reasons.contains(.lowConfidence))
    }

    @Test("Archived memory excluded unless stale is allowed")
    func archivedMemoryExcluded() {
        let archived = makeMemory(status: .archived)
        let result = selector.select(task: makeTask(), candidates: [archived], configuration: defaultConfig)
        let reasons = result.excludedItems.map(\.reason)
        #expect(reasons.contains(.archived))
    }

    // MARK: - Required Section Tests

    @Test("Task section is always included")
    func taskSectionAlwaysIncluded() {
        let result = selector.select(task: makeTask(), candidates: [], configuration: defaultConfig)
        let types = result.includedSections.map(\.sectionType)
        #expect(types.contains(.task))
    }

    @Test("Hard constraints are always included even under tight budget")
    func hardConstraintsAlwaysIncluded() {
        let constraint = makeConstraint()
        var config = defaultConfig
        // Tiny budget — only enough for the task section itself.
        config.tokenBudget = TokenBudget(maxTokens: 50, reservedResponseTokens: 0, trimStrategy: .aggressive)
        let result = selector.select(task: makeTask(prompt: "Fix auth"), candidates: [constraint], configuration: config)
        let types = result.includedSections.map(\.sectionType)
        #expect(types.contains(.hardConstraints))
    }

    // MARK: - Token Budget Tests

    @Test("Warning emitted when budget is exceeded")
    func warningEmittedWhenBudgetExceeded() {
        // Create many large candidates to force budget overflow.
        let heavyContent = String(repeating: "token ", count: 5000)
        let candidates = (0..<10).map { i in
            makeMemory(id: "\(i)", content: heavyContent)
        }
        var config = defaultConfig
        config.tokenBudget = TokenBudget(maxTokens: 200, trimStrategy: .preserveConstraints)
        let result = selector.select(task: makeTask(), candidates: candidates, configuration: config)
        let kinds = result.warnings.map(\.kind)
        #expect(kinds.contains(.tokenBudgetExceeded))
    }

    @Test("Context trimmed warning emitted when items are removed for budget")
    func contextTrimmedWarningEmitted() {
        let heavyContent = String(repeating: "word ", count: 5000)
        let candidates = (0..<5).map { i in makeMemory(id: "\(i)", content: heavyContent) }
        var config = defaultConfig
        config.tokenBudget = TokenBudget(maxTokens: 200, trimStrategy: .preserveConstraints)
        let result = selector.select(task: makeTask(), candidates: candidates, configuration: config)
        let kinds = result.warnings.map(\.kind)
        #expect(kinds.contains(.contextTrimmed))
    }

    @Test("Total included tokens do not exceed budget target")
    func includedTokensDoNotExceedBudget() {
        let heavyContent = String(repeating: "word ", count: 1000)
        let candidates = (0..<10).map { i in makeMemory(id: "\(i)", content: heavyContent) }
        var config = defaultConfig
        config.tokenBudget = TokenBudget(maxTokens: 500, trimStrategy: .preserveConstraints)
        let result = selector.select(task: makeTask(), candidates: candidates, configuration: config)
        #expect(result.estimatedTokens <= 500)
    }

    // MARK: - Module Tests

    @Test("Relevant module included when it matches task keywords")
    func relevantModuleIncluded() {
        let task = makeTask(prompt: "Update the authentication logic in the auth module")
        let authModule = makeModule(name: "AuthModule", summary: "Handles authentication and session management")
        let unrelatedModule = makeModule(name: "PaymentsModule", summary: "Processes credit card payments and invoices")

        let result = selector.select(task: task, candidates: [authModule, unrelatedModule], configuration: defaultConfig)
        let ids = result.includedSections.flatMap { $0.sourceReferences.compactMap(\.sourceId) }
        #expect(ids.contains(authModule.id))
    }

    @Test("No relevant modules warning emitted when all modules are filtered out")
    func noRelevantModulesWarningEmitted() {
        let task = makeTask(prompt: "Fix a bug")
        let module = makeModule(name: "ZModule", summary: "Unrelated content about payments invoices billing")
        var config = defaultConfig
        // Setting maxModules to 0 forces every module through the category cap exclusion path,
        // which happens before the warning check. This guarantees hasModules == false in the
        // selector and the noRelevantModules warning fires deterministically.
        config.maxModules = 0
        let result = selector.select(task: task, candidates: [module], configuration: config)
        let kinds = result.warnings.map(\.kind)
        #expect(kinds.contains(.noRelevantModules))
    }

    // MARK: - Deduplication Tests

    @Test("Duplicate candidates are deduplicated")
    func duplicatesAreRemoved() {
        let content = "The authentication module must use async await for all network calls to the token endpoint."
        let a = makeMemory(id: "a", content: content)
        let b = makeMemory(id: "b", content: content) // identical content
        let result = selector.select(task: makeTask(), candidates: [a, b], configuration: defaultConfig)
        let ids = result.includedSections.flatMap { $0.sourceReferences.compactMap(\.sourceId) }
        // Only one of the two should be included.
        let duplicateIncluded = ids.contains("a") && ids.contains("b")
        #expect(!duplicateIncluded)
    }

    @Test("Exclusion reasons are always populated for excluded items")
    func exclusionReasonsAlwaysPopulated() {
        let rejected = makeMemory(status: .rejected)
        let suggested = makeMemory(status: .suggested)
        let stale = makeMemory(isStale: true)
        let result = selector.select(task: makeTask(), candidates: [rejected, suggested, stale], configuration: defaultConfig)
        for item in result.excludedItems {
            #expect(item.reason != .unknown)
        }
    }

    // MARK: - Approved Memory Tests

    @Test("Approved memory is included when relevant")
    func approvedMemoryIsIncluded() {
        let approved = makeMemory(id: "approved-1", content: "Auth flow must use JWT tokens for session management", status: .approved)
        let task = makeTask(prompt: "Update the auth flow session management")
        let result = selector.select(task: task, candidates: [approved], configuration: defaultConfig)
        let ids = result.includedSections.flatMap { $0.sourceReferences.compactMap(\.sourceId) }
        #expect(ids.contains("approved-1"))
    }

    @Test("No approved memories warning emitted when only rejected exist")
    func noApprovedMemoriesWarningEmitted() {
        let rejected = makeMemory(status: .rejected)
        let result = selector.select(task: makeTask(), candidates: [rejected], configuration: defaultConfig)
        let kinds = result.warnings.map(\.kind)
        #expect(kinds.contains(.noApprovedMemories))
    }
}
