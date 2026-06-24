import Foundation

/// D'Agostino-Pearson omnibus normality test, plus sample skewness and excess
/// kurtosis. Implemented to match `scipy.stats.normaltest` (which combines
/// `skewtest` and `kurtosistest` into K² = Z_skew² + Z_kurt² ~ χ²(2)).
public enum Normality {

    public static func dagostinoPearson(_ x: [Double]) -> AnalysisResult {
        let n = Double(x.count)
        let mean = Descriptive.mean(x)

        // Biased central moments.
        var m2 = 0.0, m3 = 0.0, m4 = 0.0
        for v in x {
            let d = v - mean
            let d2 = d * d
            m2 += d2; m3 += d2 * d; m4 += d2 * d2
        }
        m2 /= n; m3 /= n; m4 /= n

        let g1 = m3 / pow(m2, 1.5)        // biased skewness
        let b2 = m4 / (m2 * m2)           // Pearson kurtosis (normal = 3)
        let excessKurtosis = b2 - 3.0

        let zSkew = skewTestZ(g1: g1, n: n)
        let zKurt = kurtosisTestZ(b2: b2, n: n)
        let k2 = zSkew * zSkew + zKurt * zKurt
        let p = exp(-k2 / 2.0)            // χ²(2) survival function

        var warnings: [String] = []
        if x.count < 8 {
            warnings.append("n < 8: the kurtosis component is unreliable; treat the result with caution.")
        } else if x.count < 20 {
            warnings.append("n < 20: the kurtosis test approximation is only approximate at this sample size.")
        }

        return AnalysisResult(
            analysis: "D'Agostino-Pearson normality test",
            formula: "K² = Z_skew² + Z_kurt² ~ χ²(2); p = exp(−K²/2)",
            values: [
                ResultValue("n", n),
                ResultValue("Skewness (g1)", g1),
                ResultValue("Excess kurtosis (g2)", excessKurtosis),
                ResultValue("Z (skewness)", zSkew),
                ResultValue("Z (kurtosis)", zKurt),
                ResultValue("K²", k2),
                ResultValue("p", p)
            ],
            assumptions: ["Null hypothesis: the data are drawn from a normal distribution."],
            warnings: warnings
        )
    }

    // MARK: - Component tests

    /// D'Agostino (1970) skewness test transform to an approximate Z.
    private static func skewTestZ(g1: Double, n: Double) -> Double {
        let y = g1 * ((n + 1) * (n + 3) / (6.0 * (n - 2))).squareRoot()
        let beta2 = 3.0 * (n * n + 27 * n - 70) * (n + 1) * (n + 3)
            / ((n - 2) * (n + 5) * (n + 7) * (n + 9))
        let w2 = -1 + (2 * (beta2 - 1)).squareRoot()
        let delta = 1.0 / (0.5 * log(w2)).squareRoot()
        let alpha = (2.0 / (w2 - 1)).squareRoot()
        let yy = y == 0 ? 1.0 : y
        return delta * log(yy / alpha + ((yy / alpha) * (yy / alpha) + 1).squareRoot())
    }

    /// Anscombe-Glynn kurtosis test transform to an approximate Z.
    private static func kurtosisTestZ(b2: Double, n: Double) -> Double {
        let e = 3.0 * (n - 1) / (n + 1)
        let varB2 = 24.0 * n * (n - 2) * (n - 3) / ((n + 1) * (n + 1) * (n + 3) * (n + 5))
        let xStd = (b2 - e) / varB2.squareRoot()
        let sqrtBeta1 = 6.0 * (n * n - 5 * n + 2) / ((n + 7) * (n + 9))
            * (6.0 * (n + 3) * (n + 5) / (n * (n - 2) * (n - 3))).squareRoot()
        let a = 6.0 + 8.0 / sqrtBeta1 * (2.0 / sqrtBeta1 + (1 + 4.0 / (sqrtBeta1 * sqrtBeta1)).squareRoot())
        let term1 = 1 - 2.0 / (9.0 * a)
        let denom = 1 + xStd * (2.0 / (a - 4.0)).squareRoot()
        let sign = denom < 0 ? -1.0 : 1.0
        let term2 = sign * cbrt((1 - 2.0 / a) / Swift.abs(denom))
        return (term1 - term2) / (2.0 / (9.0 * a)).squareRoot()
    }
}
