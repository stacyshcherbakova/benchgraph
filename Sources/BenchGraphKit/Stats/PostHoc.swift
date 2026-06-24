import Foundation

/// Post-hoc pairwise multiple-comparison tests following a one-way ANOVA.
///
/// All pairwise comparisons use the pooled within-group mean square (MS_within)
/// from the ANOVA as the error term, equivalent to Fisher's LSD standard error
/// but with Bonferroni and Holm family-wise error rate (FWER) corrections.
public enum PostHoc {

    /// Perform all pairwise comparisons across `groups` using the pooled
    /// within-group variance, and return Bonferroni- and Holm-corrected p-values.
    ///
    /// - Parameter groups: Two or more labeled samples. Groups with fewer than
    ///   one observation are silently dropped.
    /// - Returns: An ``AnalysisResult`` whose `values` list contains three
    ///   `ResultValue` entries per pair: the mean difference, the Bonferroni
    ///   p-value, and the Holm p-value.
    public static func pairwise(_ groups: [(name: String, values: [Double])]) -> AnalysisResult {
        let valid = groups.filter { $0.values.count >= 1 }
        let k = valid.count

        // Pooled within-group sum of squares and degrees of freedom.
        var ssw = 0.0
        for g in valid {
            let m = Descriptive.mean(g.values)
            ssw += g.values.reduce(0) { $0 + ($1 - m) * ($1 - m) }
        }
        let nTotal = valid.reduce(0) { $0 + $1.values.count }
        let dfWithin = Double(nTotal - k)
        let msWithin = ssw / dfWithin

        // Enumerate every unordered pair (i < j).
        struct Pair {
            let nameI: String
            let nameJ: String
            let meanDiff: Double
            let pRaw: Double
        }

        var rawPairs: [Pair] = []
        for i in 0..<valid.count {
            for j in (i + 1)..<valid.count {
                let gi = valid[i]
                let gj = valid[j]
                let ni = Double(gi.values.count)
                let nj = Double(gj.values.count)
                let mi = Descriptive.mean(gi.values)
                let mj = Descriptive.mean(gj.values)
                let meanDiff = mi - mj
                let se = (msWithin * (1.0 / ni + 1.0 / nj)).squareRoot()
                let t = meanDiff / se
                let pRaw = Distributions.twoTailedTP(t, df: dfWithin)
                rawPairs.append(Pair(nameI: gi.name, nameJ: gj.name, meanDiff: meanDiff, pRaw: pRaw))
            }
        }

        let m = rawPairs.count   // total number of pairs

        // Bonferroni correction.
        let bonferroni: [Double] = rawPairs.map { min(1.0, $0.pRaw * Double(m)) }

        // Holm correction: sort ascending by raw p, then step-down with
        // monotonic enforcement.
        let sortedIndices = rawPairs.indices.sorted { rawPairs[$0].pRaw < rawPairs[$1].pRaw }
        var holmAdj = [Double](repeating: 0.0, count: m)
        var runningMax = 0.0
        for (rank, idx) in sortedIndices.enumerated() {
            let r = rank + 1   // 1-based rank
            let adj = Double(m - r + 1) * rawPairs[idx].pRaw
            runningMax = max(runningMax, adj)
            holmAdj[idx] = min(1.0, runningMax)
        }

        // Build output values in the original enumeration order.
        var resultValues: [ResultValue] = []
        for (idx, pair) in rawPairs.enumerated() {
            let label = "\(pair.nameI) vs \(pair.nameJ)"
            resultValues.append(ResultValue("\(label): mean diff", pair.meanDiff))
            resultValues.append(ResultValue("\(label): p (Bonferroni)", bonferroni[idx]))
            resultValues.append(ResultValue("\(label): p (Holm)", holmAdj[idx]))
        }

        return AnalysisResult(
            analysis: "One-way ANOVA — post-hoc pairwise comparisons",
            formula: "pooled SE from MS_within; Bonferroni & Holm adjusted",
            values: resultValues,
            assumptions: [
                "Equal variances across groups (pooled error).",
                "Approximately normal residuals."
            ]
        )
    }
}
