import Testing
import Foundation
@testable import ContextComposerKit

@Suite("Prompt Renderers")
struct RendererTests {

    // MARK: - Helpers

    func makePack(sections: [ContextSection]) -> ContextPack {
        let task = UserTask(prompt: "Implement the feature")
        return ContextPack(
            task: task,
            providerProfile: .claudeSonnet,
            tokenBudget: .standard,
            includedSections: sections,
            estimatedTokens: sections.reduce(0) { $0 + $1.estimatedTokens }
        )
    }

    func makeSection(
        type: ContextSection.SectionType,
        title: String,
        content: String
    ) -> ContextSection {
        ContextSection(
            title: title,
            sectionType: type,
            content: content,
            priority: type.defaultPriority,
            estimatedTokens: content.count / 4
        )
    }

    var sampleSections: [ContextSection] {
        [
            makeSection(type: .task, title: "Task", content: "Implement the authentication module."),
            makeSection(type: .hardConstraints, title: "Constraints", content: "- Do not import SwiftUI\n- No singletons"),
            makeSection(type: .projectOverview, title: "Project", content: "MinifyAI is a macOS developer tool."),
            makeSection(type: .memory, title: "Auth Memory", content: "Auth uses JWT tokens.")
        ]
    }

    // MARK: - Claude Renderer

    @Test("Claude renderer produces XML-delimited sections")
    func claudeRendererUsesXMLTags() {
        let renderer = ClaudeMarkdownPromptRenderer()
        let pack = makePack(sections: sampleSections)
        let rendered = renderer.render(pack)
        #expect(rendered.promptText.contains("<task>"))
        #expect(rendered.promptText.contains("</task>"))
        #expect(rendered.promptText.contains("<constraints>"))
        #expect(rendered.promptText.contains("<project_context>"))
        #expect(rendered.promptText.contains("<memory>"))
    }

    @Test("Claude renderer contains the task content")
    func claudeRendererContainsTaskContent() {
        let renderer = ClaudeMarkdownPromptRenderer()
        let pack = makePack(sections: sampleSections)
        let rendered = renderer.render(pack)
        #expect(rendered.promptText.contains("Implement the authentication module."))
    }

    @Test("Claude renderer contains constraint content")
    func claudeRendererContainsConstraints() {
        let renderer = ClaudeMarkdownPromptRenderer()
        let pack = makePack(sections: sampleSections)
        let rendered = renderer.render(pack)
        #expect(rendered.promptText.contains("Do not import SwiftUI"))
    }

    @Test("Claude renderer prompt style matches")
    func claudeRendererPromptStyle() {
        let renderer = ClaudeMarkdownPromptRenderer()
        #expect(renderer.promptStyle == .claudeMarkdown)
    }

    // MARK: - OpenAI Renderer

    @Test("OpenAI renderer produces markdown header sections")
    func openAIRendererUsesMarkdownHeaders() {
        let renderer = OpenAIMarkdownPromptRenderer()
        let pack = makePack(sections: sampleSections)
        let rendered = renderer.render(pack)
        #expect(rendered.promptText.contains("# Task"))
        #expect(rendered.promptText.contains("# Hard Constraints"))
        #expect(rendered.promptText.contains("# Project Context"))
    }

    @Test("OpenAI renderer includes role preamble")
    func openAIRendererIncludesRole() {
        let renderer = OpenAIMarkdownPromptRenderer()
        let pack = makePack(sections: sampleSections)
        let rendered = renderer.render(pack)
        #expect(rendered.promptText.contains("# Role"))
    }

    @Test("OpenAI renderer contains task content")
    func openAIRendererContainsTaskContent() {
        let renderer = OpenAIMarkdownPromptRenderer()
        let pack = makePack(sections: sampleSections)
        let rendered = renderer.render(pack)
        #expect(rendered.promptText.contains("Implement the authentication module."))
    }

    @Test("OpenAI renderer prompt style matches")
    func openAIRendererPromptStyle() {
        let renderer = OpenAIMarkdownPromptRenderer()
        #expect(renderer.promptStyle == .openAIMarkdown)
    }

    // MARK: - Generic Renderer

    @Test("Generic renderer uses double-hash headers")
    func genericRendererUsesSubHeaders() {
        let renderer = GenericMarkdownPromptRenderer()
        let pack = makePack(sections: sampleSections)
        let rendered = renderer.render(pack)
        #expect(rendered.promptText.contains("## Task"))
        #expect(rendered.promptText.contains("## Constraints"))
    }

    @Test("Generic renderer separates sections with horizontal rules")
    func genericRendererUsesDividers() {
        let renderer = GenericMarkdownPromptRenderer()
        let pack = makePack(sections: sampleSections)
        let rendered = renderer.render(pack)
        #expect(rendered.promptText.contains("---"))
    }

    @Test("Generic renderer prompt style matches")
    func genericRendererPromptStyle() {
        let renderer = GenericMarkdownPromptRenderer()
        #expect(renderer.promptStyle == .genericMarkdown)
    }

    // MARK: - Metadata Tests

    @Test("Rendered pack includes summary of included sections")
    func renderedPackIncludesIncludedSummary() {
        let renderer = ClaudeMarkdownPromptRenderer()
        let pack = makePack(sections: sampleSections)
        let rendered = renderer.render(pack)
        #expect(!rendered.includedSummary.isEmpty)
    }

    @Test("Estimated tokens is positive")
    func estimatedTokensIsPositive() {
        let renderer = ClaudeMarkdownPromptRenderer()
        let pack = makePack(sections: sampleSections)
        let rendered = renderer.render(pack)
        #expect(rendered.estimatedTokens > 0)
    }

    @Test("Source summary not included in prompt by default")
    func sourceSummaryNotIncludedByDefault() {
        let renderer = ClaudeMarkdownPromptRenderer()
        let pack = makePack(sections: sampleSections)
        let rendered = renderer.render(pack, configuration: .default)
        #expect(!rendered.promptText.contains("**Sources**"))
    }

    @Test("Source summary included when configured")
    func sourceSummaryIncludedWhenConfigured() {
        let renderer = ClaudeMarkdownPromptRenderer()
        // sourceSummaryBlock only renders when sourceReferences is non-empty.
        // Build the section manually so we can supply a real source reference.
        let sourceRef = ContextSourceReference(
            sourceType: .userTask,
            sourceId: "task-1",
            title: "Task"
        )
        let section = ContextSection(
            title: "Task",
            sectionType: .task,
            content: "Do something.",
            priority: ContextSection.SectionType.task.defaultPriority,
            estimatedTokens: 5,
            sourceReferences: [sourceRef]
        )
        let pack = makePack(sections: [section])
        let rendered = renderer.render(pack, configuration: .verbose)
        #expect(rendered.promptText.contains("**Sources**"))
    }

    // MARK: - Provider Profile Tests

    @Test("Provider profile is preserved in rendered pack")
    func providerProfilePreserved() {
        let renderer = ClaudeMarkdownPromptRenderer()
        let pack = makePack(sections: sampleSections)
        let rendered = renderer.render(pack)
        #expect(rendered.providerProfile.id == ProviderProfile.claudeSonnet.id)
    }
}
