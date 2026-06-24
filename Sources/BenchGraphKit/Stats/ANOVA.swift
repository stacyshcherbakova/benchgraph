import Foundation

/// One-way ANOVA across two or more groups.
public enum ANOVA {

    /// Ordinary one-way ANOVA. `groups` is an array of samples, each labeled.
    public static func oneWay(_ groups: [(name: String, values: [Double])]) -> AnalysisResult {
        let valid = groups.filter { $0.values.count >= 1 }
        let k = valid.count
        let all = valid.flatMap { $0.values }
        let grandMean = Descriptive.mean(all)
        let nTotal = all.count

        // Between-group (SSB) and within-group (SSW) sums of squares.
        var ssb = 0.0
        var ssw = 0.0
        for g in valid {
            let m = Descriptive.mean(g.values)
            let n = Double(g.values.count)
            ssb += n * (m - grandMean) * (m - grandMean)
            ssw += g.values.reduce(0) { $0 + ($1 - m) * ($1 - m) }
        }

        let dfBetween = Double(k - 1)
        let dfWithin = Double(nTotal - k)
        let msBetween = ssb / dfBetween
        let msWithin = ssw / dfWithin
        let f = msBetween / msWithin
        let p = Distributions.fUpperTail(f, df1: dfBetween, df2: dfWithin)

        // Eta-squared effect size.
        let etaSquared = ssb / (ssb + ssw)

        var warnings: [String] = []
        let sizes = valid.map { $0.values.count }
        if Set(sizes).count > 1 {
            warnings.append("Unbalanced design (group sizes \(sizes.map(String.init).joined(separator: ", "))).")
        }
        if (sizes.min() ?? 0) < 3 {
            warnings.append("At least one group has n < 3.")
        }

        return AnalysisResult(
            analysis: "One-way ANOVA",
            formula: "F = MS_between / MS_within; df = (k−1, N−k)",
            values: [
                ResultValue("Groups (k)", Double(k)),
                ResultValue("N total", Double(nTotal)),
                ResultValue("SS between", ssb),
                ResultValue("SS within", ssw),
                ResultValue("df between", dfBetween),
                ResultValue("df within", dfWithin),
                ResultValue("MS between", msBetween),
                ResultValue("MS within", msWithin),
                ResultValue("F", f),
                ResultValue("p", p),
                ResultValue("Eta squared", etaSquared)
            ],
            assumptions: [
                "Independent groups.",
                "Approximately normal residuals.",
                "Homogeneous variances across groups."
            ],
            warnings: warnings
        )
    }
}
