import Testing
import Foundation
@testable import BenchGraphKit

/// Golden-value tests for the D'Agostino-Pearson normality test. References
/// from SciPy: `stats.skew`, `stats.kurtosis` (Fisher), and `stats.normaltest`.
@Suite struct NormalityTests {

    private func close(_ a: Double, _ b: Double, _ tol: Double) -> Bool {
        abs(a - b) <= tol
    }

    // n = 30 fixed sample.
    private let sample: [Double] = [
        2.1, 3.4, 1.9, 5.6, 2.2, 3.3, 4.1, 2.8, 3.0, 3.7,
        2.5, 4.4, 3.1, 2.9, 3.6, 5.1, 2.0, 3.8, 4.0, 2.7,
        3.2, 3.9, 2.6, 4.5, 3.5, 2.4, 4.2, 3.3, 2.3, 4.8
    ]

    @Test func matchesSciPyReference() {
        let r = Normality.dagostinoPearson(sample)
        // SciPy: skew=0.42318271, kurtosis(excess)=-0.48155324
        #expect(close(r.value("Skewness (g1)")!, 0.42318271, 1e-4))
        #expect(close(r.value("Excess kurtosis (g2)")!, -0.48155324, 1e-4))
        // SciPy normaltest: K²=1.24478744, p=0.53665829
        #expect(close(r.value("K²")!, 1.24478744, 1e-3))
        #expect(close(r.value("p")!, 0.53665829, 1e-3))
    }

    @Test func smallSampleWarns() {
        let r = Normality.dagostinoPearson([1, 2, 3, 4, 5, 6, 7])
        #expect(r.warnings.contains { $0.contains("n < 8") })
    }
}
