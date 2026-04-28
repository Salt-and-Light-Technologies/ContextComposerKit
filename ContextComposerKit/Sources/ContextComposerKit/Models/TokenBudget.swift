import Foundation

/// Defines how many tokens the context pack may consume and
/// what strategy to use when trimming is required.
public struct TokenBudget: Codable, Sendable {

    /// The absolute maximum number of tokens allowed for the full prompt input.
    public var maxTokens: Int

    /// Tokens reserved for the LLM's response (subtracted from maxTokens).
    /// When set, targetInputTokens = maxTokens - reservedResponseTokens.
    public var reservedResponseTokens: Int?

    /// The effective input token limit after reserving response space.
    /// If reservedResponseTokens is nil, this equals maxTokens.
    public var targetInputTokens: Int {
        maxTokens - (reservedResponseTokens ?? 0)
    }

    /// How to prioritise content when trimming to meet the budget.
    public var trimStrategy: TrimStrategy

    /// The provider profile this budget was derived from, if any.
    public var providerProfileId: String?

    public init(
        maxTokens: Int,
        reservedResponseTokens: Int? = nil,
        trimStrategy: TrimStrategy = .preserveConstraints,
        providerProfileId: String? = nil
    ) {
        self.maxTokens = maxTokens
        self.reservedResponseTokens = reservedResponseTokens
        self.trimStrategy = trimStrategy
        self.providerProfileId = providerProfileId
    }
}

// MARK: - TrimStrategy

public extension TokenBudget {

    /// Controls which content survives when the budget is exceeded.
    enum TrimStrategy: String, Codable, Sendable, CaseIterable {
        /// Preserve task + constraints. Trim everything else by relevance.
        case preserveConstraints
        /// Preserve only task + constraints + response format. Aggressively trim the rest.
        case preserveTaskAndConstraints
        /// Balance between memory, modules, and decisions.
        case balanced
        /// Cut heavily — minimal context, task and constraints only.
        case aggressive
        /// Favour module context over memories and decisions.
        case moduleHeavy
        /// Favour memories and decisions over module context.
        case memoryHeavy

        /// Returns the section types that must never be trimmed under this strategy.
        public var protectedSectionTypes: Set<ContextSection.SectionType> {
            switch self {
            case .preserveConstraints:
                return [.task, .hardConstraints, .instructions, .responseFormat]
            case .preserveTaskAndConstraints:
                return [.task, .hardConstraints, .responseFormat]
            case .balanced:
                return [.task, .hardConstraints, .instructions, .responseFormat]
            case .aggressive:
                return [.task, .hardConstraints, .responseFormat]
            case .moduleHeavy:
                return [.task, .hardConstraints, .instructions, .responseFormat, .moduleContext]
            case .memoryHeavy:
                return [.task, .hardConstraints, .instructions, .responseFormat, .memory, .decision]
            }
        }
    }
}

// MARK: - Convenience Constructors

public extension TokenBudget {

    /// A sensible default budget derived from a provider profile.
    static func from(profile: ProviderProfile, strategy: TrimStrategy = .preserveConstraints) -> TokenBudget {
        TokenBudget(
            maxTokens: profile.defaultTokenBudget,
            reservedResponseTokens: 2_000,
            trimStrategy: strategy,
            providerProfileId: profile.id
        )
    }

    /// A minimal budget for quick drafts or tight context windows.
    static let minimal = TokenBudget(
        maxTokens: 4_000,
        reservedResponseTokens: 1_000,
        trimStrategy: .aggressive
    )

    /// A standard budget for most development tasks.
    static let standard = TokenBudget(
        maxTokens: 16_000,
        reservedResponseTokens: 2_000,
        trimStrategy: .preserveConstraints
    )
}
