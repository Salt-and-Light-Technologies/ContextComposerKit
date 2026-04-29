import Foundation

/// A lightweight adapter that carries RosettaKit project context into
/// ContextComposerKit without creating a hard package dependency.
///
/// The MinifyAI app (or any caller) is responsible for mapping from
/// real RosettaKit types into this struct. This means if RosettaKit's
/// internal models change, only the mapping code at the call site breaks —
/// not this package.
public struct RosettaContextInput: Sendable {

    /// The identifier of the Rosetta project.
    public var projectId: String

    /// A high-level summary of the project for the projectOverview section.
    public var projectSummary: String?

    /// Architecture notes for the architecture section.
    public var architectureNotes: String?

    /// Individual modules within the project.
    public var modules: [ModuleInput]

    /// Known gotchas from the Rosetta document.
    public var gotchas: [GotchaInput]

    /// Unresolved questions recorded in the Rosetta document.
    public var unresolvedQuestions: [UnresolvedQuestionInput]

    /// When the Rosetta document was last verified or updated.
    public var lastVerified: Date?

    public init(
        projectId: String,
        projectSummary: String? = nil,
        architectureNotes: String? = nil,
        modules: [ModuleInput] = [],
        gotchas: [GotchaInput] = [],
        unresolvedQuestions: [UnresolvedQuestionInput] = [],
        lastVerified: Date? = nil
    ) {
        self.projectId = projectId
        self.projectSummary = projectSummary
        self.architectureNotes = architectureNotes
        self.modules = modules
        self.gotchas = gotchas
        self.unresolvedQuestions = unresolvedQuestions
        self.lastVerified = lastVerified
    }
}

// MARK: - Nested Input Types

public extension RosettaContextInput {

    /// A single Rosetta module (e.g. a specific feature area or package).
    struct ModuleInput: Sendable {
        public var id: String
        public var name: String
        public var summary: String
        public var tags: [String]
        public var filePath: String?
        public var lastVerified: Date?

        public init(
            id: String,
            name: String,
            summary: String,
            tags: [String] = [],
            filePath: String? = nil,
            lastVerified: Date? = nil
        ) {
            self.id = id
            self.name = name
            self.summary = summary
            self.tags = tags
            self.filePath = filePath
            self.lastVerified = lastVerified
        }
    }

    /// A known gotcha or trap from the Rosetta document.
    struct GotchaInput: Sendable {
        public var id: String
        public var title: String
        public var description: String
        public var tags: [String]
        public var severity: Severity

        public enum Severity: String, Sendable {
            case low, medium, high, critical
        }

        public init(
            id: String,
            title: String,
            description: String,
            tags: [String] = [],
            severity: Severity = .medium
        ) {
            self.id = id
            self.title = title
            self.description = description
            self.tags = tags
            self.severity = severity
        }
    }

    /// An open question recorded in the Rosetta document.
    struct UnresolvedQuestionInput: Sendable {
        public var id: String
        public var question: String
        public var context: String?
        public var tags: [String]

        public init(
            id: String,
            question: String,
            context: String? = nil,
            tags: [String] = []
        ) {
            self.id = id
            self.question = question
            self.context = context
            self.tags = tags
        }
    }
}
