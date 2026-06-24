import Testing
import Foundation
@testable import BenchGraphKit

/// Golden-value tests for `Wilcoxon.signedRank`. Reference numbers match
/// `scipy.stats.wilcoxon(a, b, zero_method='wilcox', correction=False, mode='approx')`.
///
/// Dataset 1 – all differences equal −1, no zeros (n=6, one tie group of 6):
///   W+=0, W−=21, T=0, mean=10.5, var=18.375 → z=−2.44949, p=0.014253
///
/// Dataset 2 – differences [1,1,1,0,−2,−2,−2], one zero discarded (n=6, two tie groups of 3):
///   W+=6, W−=15, T=6, mean=10.5, var=21.75 → z=−0.96486, p=0.33479
@Suite struct WilcoxonTests {

    private func close(_ a: Double, _ b: Double, _ tol: Double) -> Bool {
        abs(a - b) <= tol
    }

    // MARK: - Dataset 1: all differences equal −1, all tied, no zeros

    @Test func allNegativeAllTied() {
        // a=[1,2,3,4,5,6], b=[2,3,4,5,6,7] → d=[-1,-1,-1,-1,-1,-1]
        // SciPy reference: statistic=0.0, pvalue≈0.014253
        let a = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
        let b = [2.0, 3.0, 4.0, 5.0, 6.0, 7.0]
        let r = Wilcoxon.signedRank(a, b)

        #expect(close(r.value("n pairs")!, 6.0, 1e-9))
        #expect(close(r.value("W+")!, 0.0, 1e-9))
        #expect(close(r.value("W−")!, 21.0, 1e-9))
        #expect(close(r.value("W")!, 0.0, 1e-9))
        // z = (0 − 10.5) / sqrt(18.375) = −2.44949
        #expect(close(r.value("z")!, -2.44949, 1e-4))
        // SciPy reference p = 0.0143059
        #expect(close(r.value("p (two-tailed)")!, 0.0143059, 1e-4))
    }

    // MARK: - Dataset 2: one zero (discarded), two tie groups in |d|

    @Test func zeroDiscardedAndTies() {
        // a=[2,4,6,8,10,12,14], b=[1,3,5,8,12,14,16]
        // d=[1,1,1,0,−2,−2,−2] → discard zero → n=6
        // SciPy reference: statistic=6.0, pvalue≈0.33479
        let a = [2.0, 4.0, 6.0, 8.0, 10.0, 12.0, 14.0]
        let b = [1.0, 3.0, 5.0, 8.0, 12.0, 14.0, 16.0]
        let r = Wilcoxon.signedRank(a, b)

        #expect(close(r.value("n pairs")!, 6.0, 1e-9))
        #expect(close(r.value("W+")!, 6.0, 1e-9))
        #expect(close(r.value("W−")!, 15.0, 1e-9))
        #expect(close(r.value("W")!, 6.0, 1e-9))
        // z = (6 − 10.5) / sqrt(21.75) = −0.96486
        #expect(close(r.value("z")!, -0.96486, 1e-4))
        // SciPy reference p = 0.3345943
        #expect(close(r.value("p (two-tailed)")!, 0.3345943, 1e-4))
    }

    // MARK: - Metadata checks

    @Test func resultMetadata() {
        let r = Wilcoxon.signedRank([1.0, 2.0, 3.0], [1.5, 2.5, 3.5])
        #expect(r.analysis == "Wilcoxon signed-rank test")
        #expect(!r.assumptions.isEmpty)
        #expect(r.warnings.contains { $0.contains("Small n") })
    }
}
