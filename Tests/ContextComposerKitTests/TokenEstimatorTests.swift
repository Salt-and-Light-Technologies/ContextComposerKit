import Testing
@testable import ContextComposerKit

@Suite("ApproximateTokenEstimator")
struct TokenEstimatorTests {

    let estimator = ApproximateTokenEstimator.default

    @Test("Empty string returns zero tokens")
    func emptyStringReturnsZero() {
        #expect(estimator.estimateTokens(for: "") == 0)
    }

    @Test("Short text returns a positive token count")
    func shortTextReturnsPositiveCount() {
        let result = estimator.estimateTokens(for: "Hello world")
        #expect(result > 0)
    }

    @Test("Longer text returns more tokens than shorter text")
    func longerTextReturnMoreTokens() {
        let short = estimator.estimateTokens(for: "Hello")
        let long = estimator.estimateTokens(for: String(repeating: "Hello world. ", count: 100))
        #expect(long > short)
    }

    @Test("Estimator is flagged as approximate")
    func isApproximate() {
        #expect(estimator.isApproximate == true)
    }

    @Test("Token count scales roughly with character count")
    func tokenCountScalesWithCharacterCount() {
        // 400 characters ÷ 4 chars/token = ~100 tokens (plus overhead).
        let text = String(repeating: "a", count: 400)
        let result = estimator.estimateTokens(for: text)
        // Should be roughly 100 ± 30 for overhead.
        #expect(result >= 80 && result <= 130)
    }

    @Test("Custom ratio produces different result")
    func customRatioProducesDifferentResult() {
        let strict = ApproximateTokenEstimator(charactersPerToken: 2.0)
        let standard = ApproximateTokenEstimator(charactersPerToken: 4.0)
        let text = "The quick brown fox jumps over the lazy dog."
        #expect(strict.estimateTokens(for: text) > standard.estimateTokens(for: text))
    }
}
