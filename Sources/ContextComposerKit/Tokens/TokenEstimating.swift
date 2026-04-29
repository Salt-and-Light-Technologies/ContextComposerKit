import Foundation

/// A type that can estimate how many tokens a piece of text will consume
/// when sent to an LLM provider.
///
/// All implementations in v1 are approximate. The `ApproximateTokenEstimator`
/// uses a character-based heuristic. Provider-specific implementations
/// (e.g. using tiktoken via a subprocess or Swift binding) can be dropped in
/// later without changing any call sites.
public protocol TokenEstimating: Sendable {

    /// Returns an estimated token count for the given text.
    /// Results are approximate unless the implementation uses a real tokenizer.
    func estimateTokens(for text: String) -> Int

    /// Whether this estimator is known to be approximate.
    /// When true, the ContextComposer will emit an `approximateTokenEstimate`
    /// warning on every assembled pack.
    var isApproximate: Bool { get }
}
