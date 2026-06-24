import Testing
import Foundation
@testable import BenchGraphKit

/// True when `a` and `b` agree to within `tol`.
private func close(_ a: Double, _ b: Double, _ tol: Double) -> Bool {
    abs(a - b) <= tol
}

/// Golden-value tests. Reference numbers were computed independently with
/// SciPy (scipy.stats), per the validation plan's "compare against at least
/// two independent references" guidance. Tolerances reflect the documented
/// precision of the underlying approximations (erf ~1.5e-7, etc.).
@Suite struct StatsTests {

    // MARK: - Distributions

    @Test func normalCDF() {
        #expect(close(Distributions.normalCDF(0), 0.5, 1e-6))
        #expect(close(Distributions.normalCDF(1.96), 0.9750021, 1e-4))
        #expect(close(Distributions.normalCDF(-1.96), 0.0249979, 1e-4))
    }

    @Test func incompleteBetaSymmetry() {
        // I_x(a,b) + I_{1-x}(b,a) = 1
        let lhs = Distributions.incompleteBeta(0.3, 2.0, 5.0)
        let rhs = Distributions.incompleteBeta(0.7, 5.0, 2.0)
        #expect(close(lhs + rhs, 1.0, 1e-9))
    }

    @Test func studentTTailMatchesReference() {
        // P(|T| > 2), df=8 -> 0.08051624 (SciPy)
        #expect(close(Distributions.twoTailedTP(2, df: 8), 0.08051624, 1e-5))
    }

    @Test func fTailMatchesReference() {
        // ANOVA F=10.4, df=(2,9) -> p=0.004572125 (SciPy)
        #expect(close(Distributions.fUpperTail(10.4, df1: 2, df2: 9), 0.004572125, 1e-5))
    }

    @Test func tQuantileRoundTrip() {
        let q = Distributions.studentTQuantile(0.975, df: 10)
        #expect(close(Distributions.studentTCDF(q, df: 10), 0.975, 1e-6))
        #expect(close(q, 2.228139, 1e-4))   // textbook t(0.975, 10)
    }

    // MARK: - Descriptive

    @Test func descriptive() {
        let s = Descriptive.summary([2, 4, 4, 4, 5, 5, 7, 9])
        #expect(close(s.mean, 5.0, 1e-9))
        #expect(close(s.sd, 2.138089935, 1e-6))   // SciPy ddof=1
        #expect(close(s.median, 4.5, 1e-9))
    }

    // MARK: - t tests

    @Test func unpairedWelchEqualGroups() {
        let r = TTest.unpaired([1, 2, 3, 4, 5], [3, 4, 5, 6, 7], welch: true)
        #expect(close(r.value("t")!, -2.0, 1e-9))
        #expect(close(r.value("df")!, 8.0, 1e-9))
        #expect(close(r.value("p (two-tailed)")!, 0.08051624, 1e-5))
    }

    @Test func unpairedWelchUnequalVariance() {
        // SciPy: t=2.030258905, df=5.934958, p=0.08914999
        let r = TTest.unpaired([10, 12, 14, 16, 18, 20], [11, 11, 12, 13], welch: true)
        #expect(close(r.value("t")!, 2.030258905, 1e-5))
        #expect(close(r.value("df")!, 5.934958, 1e-4))
        #expect(close(r.value("p (two-tailed)")!, 0.08914999, 1e-5))
    }

    @Test func studentPooled() {
        let r = TTest.unpaired([1, 2, 3, 4, 5], [3, 4, 5, 6, 7], welch: false)
        #expect(close(r.value("t")!, -2.0, 1e-9))
        #expect(close(r.value("df")!, 8.0, 1e-9))
        #expect(close(r.value("p (two-tailed)")!, 0.08051624, 1e-5))
    }

    @Test func paired() {
        // SciPy ttest_rel: t=-1.176696811, p=0.3045587847
        let r = TTest.paired([1, 2, 3, 4, 5], [2, 4, 3, 5, 4])
        #expect(close(r.value("t")!, -1.176696811, 1e-6))
        #expect(close(r.value("p (two-tailed)")!, 0.3045588, 1e-5))
    }

    // MARK: - ANOVA

    @Test func oneWayANOVA() {
        let r = ANOVA.oneWay([
            (name: "g1", values: [1, 2, 3, 4]),
            (name: "g2", values: [2, 3, 4, 5]),
            (name: "g3", values: [5, 6, 7, 8])
        ])
        #expect(close(r.value("F")!, 10.4, 1e-6))
        #expect(close(r.value("p")!, 0.004572125, 1e-5))
    }

    // MARK: - Mann-Whitney

    @Test func mannWhitney() {
        // SciPy (no continuity correction): U=4.5 (min), p=0.02976844
        let r = MannWhitney.test([1, 2, 3, 4, 5, 6], [4, 5, 6, 7, 8, 9])
        #expect(close(r.value("U")!, 4.5, 1e-9))
        #expect(close(r.value("p (two-tailed)")!, 0.02976844, 1e-4))
    }

    // MARK: - Correlation

    @Test func pearson() {
        let r = Correlation.pearson([1, 2, 3, 4, 5, 6, 7], [2, 1, 4, 3, 6, 5, 8])
        #expect(close(r.value("r")!, 0.8962582, 1e-6))
        #expect(close(r.value("p (two-tailed)")!, 0.006291660, 1e-5))
    }

    @Test func spearman() {
        let r = Correlation.spearman([1, 2, 3, 4, 5, 6, 7], [2, 1, 4, 3, 6, 5, 8])
        #expect(close(r.value("rho")!, 0.8928571, 1e-6))
    }

    // MARK: - Linear regression

    @Test func linearRegression() {
        let r = LinearRegression.fit([1, 2, 3, 4, 5], [2.1, 4.0, 6.1, 7.9, 10.2])
        #expect(close(r.slope, 2.01, 1e-6))
        #expect(close(r.intercept, 0.03, 1e-6))
        #expect(close(r.rSquared, 0.9987392, 1e-6))
        #expect(close(r.slopeSE, 0.04123106, 1e-6))
    }

    // MARK: - 4PL dose-response

    @Test func fourPLRecoversKnownParameters() {
        // Noise-free data from y = 100 + (0 - 100)/(1 + x/10).
        let x = [1.0, 3, 10, 30, 100, 300]
        let y = x.map { 100.0 + (0.0 - 100.0) / (1.0 + $0 / 10.0) }
        let fit = FourPL.fit(x: x, y: y)
        #expect(close(fit.a, 0.0, 0.5))
        #expect(close(fit.b, 1.0, 0.05))
        #expect(close(fit.c, 10.0, 0.5))    // EC50
        #expect(close(fit.d, 100.0, 0.5))
        #expect(close(fit.rSquared, 1.0, 1e-6))
        // Interpolation: response 50 should occur at the EC50 (x = 10).
        #expect(close(fit.interpolate(y: 50)!, 10.0, 0.5))
    }
}
