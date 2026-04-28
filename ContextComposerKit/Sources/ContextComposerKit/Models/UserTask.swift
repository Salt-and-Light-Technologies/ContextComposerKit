import Foundation

/// The user's current task that anchors the entire context pack.
/// All context selection and relevance scoring flows from this model.
public struct UserTask: Identifiable, Codable, Sendable {

    public let id: UUID

    /// Optional short title for display in the app UI.
    public var title: String?

    /// The full prompt text the user wants to send to the LLM.
    public var prompt: String

    /// Links this task to a specific RosettaKit project.
    public var projectId: String?

    /// Links this task to an active RailroadKit session.
    public var sessionId: String?

    /// Hints about which modules are relevant to this task.
    /// Used to boost relevance scores for matching modules.
    public var moduleHints: [String]

    /// Free-form tags used during relevance scoring.
    public var tags: [String]

    /// When the task was created.
    public var createdAt: Date

    /// How the user wants the LLM to format its response.
    public var requestedOutputStyle: OutputStyle?

    public init(
        id: UUID = UUID(),
        title: String? = nil,
        prompt: String,
        projectId: String? = nil,
        sessionId: String? = nil,
        moduleHints: [String] = [],
        tags: [String] = [],
        createdAt: Date = Date(),
        requestedOutputStyle: OutputStyle? = nil
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.projectId = projectId
        self.sessionId = sessionId
        self.moduleHints = moduleHints
        self.tags = tags
        self.createdAt = createdAt
        self.requestedOutputStyle = requestedOutputStyle
    }
}

// MARK: - OutputStyle

public extension UserTask {

    /// Controls what the LLM is explicitly instructed to produce.
    enum OutputStyle: String, Codable, Sendable, CaseIterable {
        /// Provide a structured plan with no code.
        case planOnly
        /// Provide a plan first, then implement it.
        case codeAfterPlan
        /// Explain the approach without writing code.
        case noCode
        /// Produce numbered implementation steps.
        case implementationSteps
        /// Review architecture and suggest improvements.
        case architectureReview
        /// Identify and explain bugs.
        case bugHunt
        /// Produce git-style diff output.
        case diffStyle
        /// Explain first, then act.
        case explainFirst

        /// Human-readable instruction injected into the rendered prompt.
        public var renderedInstruction: String {
            switch self {
            case .planOnly:
                return "Provide a structured plan only. Do not write code."
            case .codeAfterPlan:
                return "First provide a clear plan, then implement it with code."
            case .noCode:
                return "Explain your approach in detail. Do not write code."
            case .implementationSteps:
                return "Provide numbered, actionable implementation steps."
            case .architectureReview:
                return "Review the architecture and suggest concrete improvements."
            case .bugHunt:
                return "Identify bugs, explain their root cause, and suggest fixes."
            case .diffStyle:
                return "Present changes in a git-style diff format where possible."
            case .explainFirst:
                return "Explain your reasoning before taking any action."
            }
        }
    }
}
