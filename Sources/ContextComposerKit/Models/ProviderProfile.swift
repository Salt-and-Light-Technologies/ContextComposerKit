import Foundation

/// Describes an LLM provider and how prompts should be formatted for it.
/// The MinifyAI app holds a list of these and lets the user pick one
/// before generating a context pack.
public struct ProviderProfile: Identifiable, Codable, Sendable {

    public let id: String

    public var providerKind: ProviderKind
    public var displayName: String

    /// Default token budget when no override is provided.
    public var defaultTokenBudget: Int

    /// The maximum context window in tokens, if known.
    public var maxContextWindow: Int?

    /// How the rendered markdown should be structured.
    public var preferredPromptStyle: PromptStyle

    /// Whether this provider supports a dedicated system prompt block.
    public var supportsSystemPrompt: Bool

    /// Whether this provider supports an OpenAI-style developer prompt block.
    public var supportsDeveloperPrompt: Bool

    /// Whether this provider supports JSON mode output.
    public var supportsJSONMode: Bool

    /// Optional free-text notes shown in the app (e.g. rate limits, tips).
    public var notes: String?

    public init(
        id: String,
        providerKind: ProviderKind,
        displayName: String,
        defaultTokenBudget: Int,
        maxContextWindow: Int? = nil,
        preferredPromptStyle: PromptStyle,
        supportsSystemPrompt: Bool,
        supportsDeveloperPrompt: Bool,
        supportsJSONMode: Bool,
        notes: String? = nil
    ) {
        self.id = id
        self.providerKind = providerKind
        self.displayName = displayName
        self.defaultTokenBudget = defaultTokenBudget
        self.maxContextWindow = maxContextWindow
        self.preferredPromptStyle = preferredPromptStyle
        self.supportsSystemPrompt = supportsSystemPrompt
        self.supportsDeveloperPrompt = supportsDeveloperPrompt
        self.supportsJSONMode = supportsJSONMode
        self.notes = notes
    }
}

// MARK: - ProviderKind

public extension ProviderProfile {

    enum ProviderKind: String, Codable, Sendable, CaseIterable {
        case anthropicClaude
        case openAIChatGPT
        case googleGemini
        case ollama
        case openRouter
        case custom
    }

    enum PromptStyle: String, Codable, Sendable, CaseIterable {
        /// XML-delimited sections (Claude native style).
        case claudeMarkdown
        /// Markdown headers with Role/Task/Context structure (OpenAI style).
        case openAIMarkdown
        /// Safe generic markdown compatible with any paste-based UI.
        case genericMarkdown
        /// XML-heavy delimited format for precision context passing.
        case xmlDelimited
        /// Minimal formatting for tight token budgets.
        case compact
    }
}

// MARK: - Built-in Profiles

public extension ProviderProfile {

    /// Anthropic Claude Sonnet — default profile for Claude models.
    static let claudeSonnet = ProviderProfile(
        id: "anthropic.claude-sonnet",
        providerKind: .anthropicClaude,
        displayName: "Claude Sonnet",
        defaultTokenBudget: 16_000,
        maxContextWindow: 200_000,
        preferredPromptStyle: .claudeMarkdown,
        supportsSystemPrompt: true,
        supportsDeveloperPrompt: false,
        supportsJSONMode: false,
        notes: "Paste into the Human turn. System prompt is optional."
    )

    /// Anthropic Claude Opus — larger budget for complex tasks.
    static let claudeOpus = ProviderProfile(
        id: "anthropic.claude-opus",
        providerKind: .anthropicClaude,
        displayName: "Claude Opus",
        defaultTokenBudget: 24_000,
        maxContextWindow: 200_000,
        preferredPromptStyle: .claudeMarkdown,
        supportsSystemPrompt: true,
        supportsDeveloperPrompt: false,
        supportsJSONMode: false,
        notes: "Best for complex architectural reasoning."
    )

    /// OpenAI GPT-4o.
    static let gpt4o = ProviderProfile(
        id: "openai.gpt-4o",
        providerKind: .openAIChatGPT,
        displayName: "GPT-4o",
        defaultTokenBudget: 16_000,
        maxContextWindow: 128_000,
        preferredPromptStyle: .openAIMarkdown,
        supportsSystemPrompt: true,
        supportsDeveloperPrompt: true,
        supportsJSONMode: true,
        notes: "Paste into the user turn. Use System for role instructions."
    )

    /// A safe generic fallback for unknown or custom providers.
    static let generic = ProviderProfile(
        id: "generic.default",
        providerKind: .custom,
        displayName: "Generic Provider",
        defaultTokenBudget: 8_000,
        maxContextWindow: nil,
        preferredPromptStyle: .genericMarkdown,
        supportsSystemPrompt: false,
        supportsDeveloperPrompt: false,
        supportsJSONMode: false,
        notes: nil
    )

    /// All built-in profiles.
    static let builtIn: [ProviderProfile] = [
        .claudeSonnet,
        .claudeOpus,
        .gpt4o,
        .generic
    ]
}
