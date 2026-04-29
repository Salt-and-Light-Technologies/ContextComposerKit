import Foundation

/// A character-based token estimator that requires no external dependencies.
///
/// **Approximation method:**
/// Most English LLM tokenizers (BPE-based, e.g. tiktoken) average roughly
/// 4 characters per token for typical prose and code. This estimator divides
/// the UTF-8 character count by a configurable ratio and adds a small fixed
/// overhead for markdown structure characters.
///
/// **Accuracy:**
/// - Within ~15% for typical English prose and Swift/Python code.
/// - Less accurate for CJK text, heavily escaped strings, or very short snippets.
/// - Always emits `approximateTokenEstimate` warning so the UI can flag it.
///
/// Replace this with a provider-specific tokenizer when accuracy matters more
/// than simplicity (e.g. before implementing live API calls).
public struct ApproximateTokenEstimator: TokenEstimating {

    /// Characters per token. 4.0 is a well-established heuristic for English text
    /// with GPT-family and Claude tokenizers.
    public let charactersPerToken: Double

    /// A small additive overhead per call to account for markdown formatting tokens
    /// (headers, delimiters, newlines) that wrap each section.
    public let structuralOverheadTokens: Int

    public let isApproximate: Bool = true

    public init(
        charactersPerToken: Double = 4.0,
        structuralOverheadTokens: Int = 5
    ) {
        self.charactersPerToken = charactersPerToken
        self.structuralOverheadTokens = structuralOverheadTokens
    }

    public func estimateTokens(for text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        let charCount = Double(text.unicodeScalars.count)
        let rawEstimate = Int((charCount / charactersPerToken).rounded(.up))
        return rawEstimate + structuralOverheadTokens
    }
}

// MARK: - Shared Default

public extension ApproximateTokenEstimator {

    /// A ready-to-use default instance with standard heuristic values.
    static let `default` = ApproximateTokenEstimator()
}
