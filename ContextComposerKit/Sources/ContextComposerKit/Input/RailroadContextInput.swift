import Foundation

/// A lightweight adapter that carries RailroadKit memory and session context
/// into ContextComposerKit without creating a hard package dependency.
///
/// The MinifyAI app is responsible for mapping from real RailroadKit types
/// into this struct before calling the ContextComposer.
public struct RailroadContextInput: Sendable {

    /// All memories available for selection. The selector will filter
    /// and score these based on status, confidence, and relevance.
    public var memories: [MemoryInput]

    /// Architectural and product decisions from Railroad.
    public var decisions: [DecisionInput]

    /// Notes and summaries from the active or recent session.
    public var sessionNotes: [SessionNoteInput]

    /// Hard constraints that must always be included in the prompt.
    public var hardConstraints: [HardConstraintInput]

    public init(
        memories: [MemoryInput] = [],
        decisions: [DecisionInput] = [],
        sessionNotes: [SessionNoteInput] = [],
        hardConstraints: [HardConstraintInput] = []
    ) {
        self.memories = memories
        self.decisions = decisions
        self.sessionNotes = sessionNotes
        self.hardConstraints = hardConstraints
    }
}

// MARK: - Nested Input Types

public extension RailroadContextInput {

    /// The approval/lifecycle status of a memory.
    enum MemoryStatus: String, Sendable {
        case approved
        case suggested
        case rejected
        case archived
    }

    /// A single memory entry from RailroadKit.
    struct MemoryInput: Sendable {
        public var id: String
        public var title: String
        public var content: String
        public var status: MemoryStatus
        public var tags: [String]
        public var projectId: String?
        public var moduleId: String?
        public var sessionId: String?
        public var confidence: Double
        public var createdAt: Date
        public var lastVerified: Date?

        public init(
            id: String,
            title: String,
            content: String,
            status: MemoryStatus,
            tags: [String] = [],
            projectId: String? = nil,
            moduleId: String? = nil,
            sessionId: String? = nil,
            confidence: Double = 1.0,
            createdAt: Date = Date(),
            lastVerified: Date? = nil
        ) {
            self.id = id
            self.title = title
            self.content = content
            self.status = status
            self.tags = tags
            self.projectId = projectId
            self.moduleId = moduleId
            self.sessionId = sessionId
            self.confidence = confidence
            self.createdAt = createdAt
            self.lastVerified = lastVerified
        }
    }

    /// An architectural or product decision from RailroadKit.
    struct DecisionInput: Sendable {
        public var id: String
        public var title: String
        public var rationale: String
        public var outcome: String?
        public var tags: [String]
        public var projectId: String?
        public var createdAt: Date

        public init(
            id: String,
            title: String,
            rationale: String,
            outcome: String? = nil,
            tags: [String] = [],
            projectId: String? = nil,
            createdAt: Date = Date()
        ) {
            self.id = id
            self.title = title
            self.rationale = rationale
            self.outcome = outcome
            self.tags = tags
            self.projectId = projectId
            self.createdAt = createdAt
        }
    }

    /// A note or summary from a Railroad session.
    struct SessionNoteInput: Sendable {
        public var id: String
        public var sessionId: String
        public var content: String
        public var tags: [String]
        public var createdAt: Date

        public init(
            id: String,
            sessionId: String,
            content: String,
            tags: [String] = [],
            createdAt: Date = Date()
        ) {
            self.id = id
            self.sessionId = sessionId
            self.content = content
            self.tags = tags
            self.createdAt = createdAt
        }
    }

    /// A hard constraint that must appear in every prompt, unconditionally.
    struct HardConstraintInput: Sendable {
        public var id: String
        public var title: String
        public var content: String
        public var projectId: String?

        public init(
            id: String,
            title: String,
            content: String,
            projectId: String? = nil
        ) {
            self.id = id
            self.title = title
            self.content = content
            self.projectId = projectId
        }
    }
}
