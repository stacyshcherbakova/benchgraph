import Foundation

/// t tests: one-sample, unpaired (Student and Welch), and paired.
public enum TTest {

    /// Unpaired two-sample t test.
    ///
    /// - Parameter welch: if true, uses Welch's correction (unequal variances,
    ///   Satterthwaite df). If false, uses the pooled-variance Student t test.
    public static func unpaired(_ a: [Double], _ b: [Double], welch: Bool = true) -> AnalysisResult {
        let n1 = Double(a.count)
        let n2 = Double(b.count)
        let m1 = Descriptive.mean(a)
        let m2 = Descriptive.mean(b)
        let v1 = Descriptive.variance(a)
        let v2 = Descriptive.variance(b)

        let t: Double
        let df: Double
        let formula: String
        if welch {
            let se = (v1 / n1 + v2 / n2).squareRoot()
            t = (m1 - m2) / se
            let num = pow(v1 / n1 + v2 / n2, 2)
            let den = pow(v1 / n1, 2) / (n1 - 1) + pow(v2 / n2, 2) / (n2 - 1)
            df = num / den
            formula = "Welch's t = (m1 − m2) / √(s1²/n1 + s2²/n2); Satterthwaite df"
        } else {
            let pooledVar = ((n1 - 1) * v1 + (n2 - 1) * v2) / (n1 + n2 - 2)
            let se = (pooledVar * (1 / n1 + 1 / n2)).squareRoot()
            t = (m1 - m2) / se
            df = n1 + n2 - 2
            formula = "Student's t = (m1 − m2) / (s_pooled·√(1/n1 + 1/n2)); df = n1 + n2 − 2"
        }

        let p = Distributions.twoTailedTP(t, df: df)
        var warnings: [String] = []
        if a.count < 3 || b.count < 3 {
            warnings.append("Small group size; t test is sensitive to non-normality at low n.")
        }
        if !welch {
            let ratio = max(v1, v2) / min(v1, v2)
            if ratio > 3 {
                warnings.append("Variance ratio ≈ \(String(format: "%.1f", ratio)); consider Welch's correction.")
            }
        }

        return AnalysisResult(
            analysis: welch ? "Unpaired t test (Welch)" : "Unpaired t test (Student)",
            formula: formula,
            values: [
                ResultValue("Mean 1", m1),
                ResultValue("Mean 2", m2),
                ResultValue("Mean difference", m1 - m2),
                ResultValue("t", t),
                ResultValue("df", df),
                ResultValue("p (two-tailed)", p)
            ],
            assumptions: [
                "Independent samples.",
                welch ? "Approximately normal; variances may differ." : "Approximately normal; equal variances."
            ],
            warnings: warnings
        )
    }

    /// Paired t test on matched observations. Pairs with a missing value in
    /// either column are dropped.
    public static func paired(_ a: [Double], _ b: [Double]) -> AnalysisResult {
        precondition(a.count == b.count, "Paired t test requires equal-length inputs")
        let diffs = zip(a, b).map { $0 - $1 }
        let n = Double(diffs.count)
        let md = Descriptive.mean(diffs)
        let sd = Descriptive.standardDeviation(diffs)
        let se = sd / n.squareRoot()
        let t = md / se
        let df = n - 1
        let p = Distributions.twoTailedTP(t, df: df)

        var warnings: [String] = []
        if diffs.count < 3 { warnings.append("Few pairs (n = \(diffs.count)); result is unstable.") }

        return AnalysisResult(
            analysis: "Paired t test",
            formula: "t = mean(d) / (SD(d)/√n), where d = a − b; df = n − 1",
            values: [
                ResultValue("n pairs", n),
                ResultValue("Mean difference", md),
                ResultValue("SD of differences", sd),
                ResultValue("t", t),
                ResultValue("df", df),
                ResultValue("p (two-tailed)", p)
            ],
            assumptions: ["Paired/matched observations.", "Differences approximately normal."],
            warnings: warnings
        )
    }

    /// One-sample t test against a hypothesized mean.
    public static func oneSample(_ x: [Double], mu: Double) -> AnalysisResult {
        let n = Double(x.count)
        let m = Descriptive.mean(x)
        let sd = Descriptive.standardDeviation(x)
        let se = sd / n.squareRoot()
        let t = (m - mu) / se
        let df = n - 1
        let p = Distributions.twoTailedTP(t, df: df)
        return AnalysisResult(
            analysis: "One-sample t test",
            formula: "t = (mean − μ₀) / (SD/√n); df = n − 1",
            values: [
                ResultValue("n", n),
                ResultValue("Mean", m),
                ResultValue("Hypothesized μ₀", mu),
                ResultValue("t", t),
                ResultValue("df", df),
                ResultValue("p (two-tailed)", p)
            ],
            assumptions: ["Approximately normal sample."]
        )
    }
}
