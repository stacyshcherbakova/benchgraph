import Foundation

/// Wilcoxon signed-rank test (paired nonparametric), implemented to match
/// `scipy.stats.wilcoxon` with `zero_method='wilcox'`, `correction=False`,
/// and `mode='approx'` (normal approximation with tie correction).
public enum Wilcoxon {

    /// Performs the Wilcoxon signed-rank test on paired observations `a` and `b`.
    ///
    /// - Parameters:
    ///   - a: First sample of paired observations.
    ///   - b: Second sample of paired observations (must be same length as `a`).
    /// - Returns: An `AnalysisResult` containing n (pairs used), W+, W−, T (= min(W+,W−)),
    ///   z, and two-tailed p-value.
    /// - Precondition: `a.count == b.count`
    public static func signedRank(_ a: [Double], _ b: [Double]) -> AnalysisResult {
        precondition(a.count == b.count, "Wilcoxon: a and b must have the same length.")

        // Step 1: compute differences and discard zeros (zero_method='wilcox').
        let differences = zip(a, b).map { $0 - $1 }
        let nonzero = differences.filter { $0 != 0.0 }
        let n = nonzero.count

        // Step 2: rank absolute differences with average ranks for ties.
        // Reuse MannWhitney.averageRanks which implements tied average ranking.
        let absDiffs = nonzero.map { Swift.abs($0) }
        let ranks = MannWhitney.averageRanks(absDiffs)

        // Step 3: compute W+ and W−.
        var wPlus = 0.0
        var wMinus = 0.0
        for (i, d) in nonzero.enumerated() {
            if d > 0 { wPlus += ranks[i] } else { wMinus += ranks[i] }
        }
        let T = min(wPlus, wMinus)

        // Step 4: mean and variance with tie correction.
        // mean = n(n+1)/4
        let nD = Double(n)
        let mean = nD * (nD + 1) / 4.0

        // var = n(n+1)(2n+1)/24 − Σ(t³−t)/48 over tie groups of |d|
        let baseVar = nD * (nD + 1) * (2 * nD + 1) / 24.0
        let tieAdj = tieCorrection(absDiffs) / 48.0
        let variance = baseVar - tieAdj

        // Step 5: z-statistic and two-tailed p-value.
        let z = (T - mean) / variance.squareRoot()
        let p = 2.0 * Distributions.normalCDF(-Swift.abs(z))

        // Step 6: build warnings.
        var warnings: [String] = []
        if n < 6 {
            warnings.append("Small n (\(n)); normal approximation is rough.")
        }

        return AnalysisResult(
            analysis: "Wilcoxon signed-rank test",
            formula: "T = min(W+, W−); z = (T − n(n+1)/4) / √(n(n+1)(2n+1)/24 − Σ(t³−t)/48); p = 2·Φ(−|z|)",
            values: [
                ResultValue("n pairs", Double(n)),
                ResultValue("W+", wPlus),
                ResultValue("W−", wMinus),
                ResultValue("W", T),
                ResultValue("z", z),
                ResultValue("p (two-tailed)", p)
            ],
            assumptions: [
                "Paired/matched observations.",
                "Symmetric distribution of differences; no normality assumption."
            ],
            warnings: warnings
        )
    }

    // MARK: - Private helpers

    /// Σ(t³ − t) over tie groups in `x`, used in the variance tie correction.
    private static func tieCorrection(_ x: [Double]) -> Double {
        var counts: [Double: Int] = [:]
        for v in x { counts[v, default: 0] += 1 }
        return counts.values.reduce(0.0) { acc, t in
            let td = Double(t)
            return acc + (td * td * td - td)
        }
    }
}
