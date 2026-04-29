import Foundation

/// The category of content a candidate represents.
/// Used by the scorer to apply category-specific base weights.
public enum CandidateKind: String, Sendable, CaseIterable {
    case memory
    case decision
    case sessionNote
    case rosettaModule
    case rosettaGotcha
    case unresolvedQuestion
    case hardConstraint
    case projectOverview
    case architectureNote
}

/// A scoreable unit of context — anything that might be included in the prompt.
/// Every piece of Railroad or Rosetta content is wrapped in a ContextCandidate
/// before being passed to the ContextRelevanceScorer.
public struct ContextCandidate: Identifiable, Sendable {

    public let id: String

    /// Human-readable label for the UI and exclusion records.
    public var title: String

    /// The full text content of this candidate.
    public var content: String

    /// What kind of content this is.
    public var kind: CandidateKind

    /// Where this candidate came from.
    public var sourceReference: ContextSourceReference

    /// Free-form tags for overlap scoring.
    public var tags: [String]

    /// Linked project, if any.
    public var projectId: String?

    /// Linked module, if any.
    public var moduleId: String?

    /// Linked session, if any.
    public var sessionId: String?

    /// How confident the system is in this candidate (0.0 – 1.0).
    public var confidence: Double

    /// When this candidate was created.
    public var createdAt: Date

    /// When this candidate was last verified. Nil if never verified.
    public var lastVerified: Date?

    /// Whether the content is considered stale by its source system.
    public var isStale: Bool

    /// The Railroad memory status, if applicable.
    public var memoryStatus: RailroadContextInput.MemoryStatus?

    public init(
        id: String,
        title: String,
        content: String,
        kind: CandidateKind,
        sourceReference: ContextSourceReference,
        tags: [String] = [],
        projectId: String? = nil,
        moduleId: String? = nil,
        sessionId: String? = nil,
        confidence: Double = 1.0,
        createdAt: Date = Date(),
        lastVerified: Date? = nil,
        isStale: Bool = false,
        memoryStatus: RailroadContextInput.MemoryStatus? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.kind = kind
        self.sourceReference = sourceReference
        self.tags = tags
        self.projectId = projectId
        self.moduleId = moduleId
        self.sessionId = sessionId
        self.confidence = confidence
        self.createdAt = createdAt
        self.lastVerified = lastVerified
        self.isStale = isStale
        self.memoryStatus = memoryStatus
    }
}
