import Testing
import Foundation
@testable import BenchGraphKit

/// Golden-value tests for post-hoc pairwise comparisons. Reference values
/// computed independently: pooled MS_within with SciPy t-distribution p-values,
/// then Bonferroni and Holm corrections worked out by hand.
@Suite struct PostHocTests {

    private func close(_ a: Double, _ b: Double, _ tol: Double) -> Bool {
        abs(a - b) <= tol
    }

    // Groups: MS_within = 5/3, df_within = 9.
    private let groups: [(name: String, values: [Double])] = [
        ("A", [1, 2, 3, 4]),
        ("B", [2, 3, 4, 5]),
        ("C", [8, 9, 10, 11])
    ]

    @Test func bonferroniAndHolm() {
        let r = PostHoc.pairwise(groups)

        // Mean differences (exact).
        #expect(close(r.value("A vs B: mean diff")!, -1.0, 1e-9))
        #expect(close(r.value("A vs C: mean diff")!, -7.0, 1e-9))
        #expect(close(r.value("B vs C: mean diff")!, -6.0, 1e-9))

        // Bonferroni (m = 3). Raw p: 0.3017687, 3.1001586e-5, 1.0245187e-4.
        #expect(close(r.value("A vs B: p (Bonferroni)")!, 0.9053061, 1e-4))
        #expect(close(r.value("A vs C: p (Bonferroni)")!, 9.300476e-05, 2e-6))
        #expect(close(r.value("B vs C: p (Bonferroni)")!, 3.073556e-04, 1e-5))

        // Holm (step-down).
        #expect(close(r.value("A vs B: p (Holm)")!, 0.3017687, 1e-4))
        #expect(close(r.value("A vs C: p (Holm)")!, 9.300476e-05, 2e-6))
        #expect(close(r.value("B vs C: p (Holm)")!, 2.049037e-04, 1e-5))
    }
}
