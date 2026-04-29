import Foundation

/// A single named section within a ContextPack.
/// Each section maps to a discrete block in the final rendered prompt.
public struct ContextSection: Identifiable, Codable, Sendable {

    public let id: UUID

    /// The display title used as a header in the rendered prompt.
    public var title: String

    /// The semantic category of this section.
    public var sectionType: SectionType

    /// The text content that will be rendered for this section.
    public var content: String

    /// Rendering priority — lower numbers render first.
    /// Required sections (task, constraints) always get priority 0 or 1.
    public var priority: Int

    /// Approximate token count for this section's content.
    public var estimatedTokens: Int

    /// The source items that contributed to this section's content.
    public var sourceReferences: [ContextSourceReference]

    /// Section-level warnings (e.g. stale memory within this section).
    public var warnings: [ContextWarning]

    public init(
        id: UUID = UUID(),
        title: String,
        sectionType: SectionType,
        content: String,
        priority: Int,
        estimatedTokens: Int,
        sourceReferences: [ContextSourceReference] = [],
        warnings: [ContextWarning] = []
    ) {
        self.id = id
        self.title = title
        self.sectionType = sectionType
        self.content = content
        self.priority = priority
        self.estimatedTokens = estimatedTokens
        self.sourceReferences = sourceReferences
        self.warnings = warnings
    }
}

// MARK: - SectionType

public extension ContextSection {

    enum SectionType: String, Codable, Sendable, CaseIterable {
        /// The user's task prompt. Always included, always first.
        case task
        /// System/developer-level instructions for the LLM.
        case instructions
        /// Hard constraints that must never be violated.
        case hardConstraints
        /// High-level project overview from Rosetta.
        case projectOverview
        /// Architecture notes from Rosetta.
        case architecture
        /// Specific module context from Rosetta.
        case moduleContext
        /// Approved memories from Railroad.
        case memory
        /// Architectural or product decisions from Railroad.
        case decision
        /// Known gotchas from Rosetta or Railroad.
        case gotcha
        /// Unresolved questions or known unknowns.
        case unresolvedQuestion
        /// Instructions for how the LLM should format its response.
        case responseFormat
        /// A source summary appended at the end (not pasted by default).
        case sourceSummary

        /// The default rendering priority for this section type.
        /// Lower = rendered earlier in the prompt.
        public var defaultPriority: Int {
            switch self {
            case .task:               return 0
            case .hardConstraints:    return 1
            case .instructions:       return 2
            case .responseFormat:     return 3
            case .projectOverview:    return 4
            case .architecture:       return 5
            case .moduleContext:      return 6
            case .memory:             return 7
            case .decision:           return 8
            case .gotcha:             return 9
            case .unresolvedQuestion: return 10
            case .sourceSummary:      return 11
            }
        }

        /// Whether this section is required and must never be trimmed.
        public var isRequired: Bool {
            switch self {
            case .task, .hardConstraints, .instructions, .responseFormat:
                return true
            default:
                return false
            }
        }
    }
}
