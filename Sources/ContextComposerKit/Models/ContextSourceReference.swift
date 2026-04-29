import Foundation

/// Tracks where a piece of context came from.
/// Included in every ContextSection and ExcludedContextItem so the app
/// can display provenance and the user can verify staleness.
public struct ContextSourceReference: Codable, Sendable {

    public let sourceType: SourceType

    /// The ID of the specific item in its home package (e.g. memory UUID).
    public var sourceId: String?

    /// Display title for the source item.
    public var title: String?

    /// File path, if applicable (e.g. a Rosetta module file).
    public var path: String?

    /// How confident the system is in this source (0.0 – 1.0).
    public var confidence: Double?

    /// When the source was last verified or updated.
    public var lastVerified: Date?

    public init(
        sourceType: SourceType,
        sourceId: String? = nil,
        title: String? = nil,
        path: String? = nil,
        confidence: Double? = nil,
        lastVerified: Date? = nil
    ) {
        self.sourceType = sourceType
        self.sourceId = sourceId
        self.title = title
        self.path = path
        self.confidence = confidence
        self.lastVerified = lastVerified
    }
}

// MARK: - SourceType

public extension ContextSourceReference {

    enum SourceType: String, Codable, Sendable, CaseIterable {
        case railroadMemory
        case railroadDecision
        case railroadSession
        case rosettaDocument
        case rosettaModule
        case userTask
        case appGenerated
    }
}
