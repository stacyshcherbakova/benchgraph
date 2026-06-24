import Foundation

/// Mann-Whitney U test (nonparametric two-group comparison), with a normal
/// approximation (tie-corrected) for the p-value.
public enum MannWhitney {

    public static func test(_ a: [Double], _ b: [Double]) -> AnalysisResult {
        let n1 = a.count
        let n2 = b.count

        // Rank the combined sample, assigning average ranks to ties.
        let combined = a.map { ($0, 0) } + b.map { ($0, 1) }
        let ranks = averageRanks(combined.map { $0.0 })

        var rankSum1 = 0.0
        for (i, item) in combined.enumerated() where item.1 == 0 {
            rankSum1 += ranks[i]
        }

        let u1 = rankSum1 - Double(n1 * (n1 + 1)) / 2
        let u2 = Double(n1 * n2) - u1
        let u = min(u1, u2)

        // Normal approximation with tie correction.
        let n = Double(n1 + n2)
        let meanU = Double(n1 * n2) / 2
        let tieTerm = tieCorrection(combined.map { $0.0 })
        let varU = Double(n1 * n2) / 12 * ((n + 1) - tieTerm / (n * (n - 1)))
        let z = (u - meanU) / varU.squareRoot()
        let p = 2 * (1 - Distributions.normalCDF(Swift.abs(z)))

        var warnings: [String] = []
        if n1 < 5 || n2 < 5 {
            warnings.append("Small samples; the normal approximation to U is rough below n ≈ 5 per group.")
        }

        return AnalysisResult(
            analysis: "Mann-Whitney U test",
            formula: "U from rank sums; p via tie-corrected normal approximation of U",
            values: [
                ResultValue("n1", Double(n1)),
                ResultValue("n2", Double(n2)),
                ResultValue("Rank sum 1", rankSum1),
                ResultValue("U", u),
                ResultValue("z", z),
                ResultValue("p (two-tailed)", p)
            ],
            assumptions: [
                "Independent samples.",
                "Compares distributions/medians without assuming normality."
            ],
            warnings: warnings
        )
    }

    /// Average ranks (1-based) with ties sharing the mean of their positions.
    static func averageRanks(_ x: [Double]) -> [Double] {
        let indexed = x.enumerated().sorted { $0.element < $1.element }
        var ranks = [Double](repeating: 0, count: x.count)
        var i = 0
        while i < indexed.count {
            var j = i
            while j + 1 < indexed.count && indexed[j + 1].element == indexed[i].element {
                j += 1
            }
            // positions i...j (0-based) -> ranks (i+1)...(j+1)
            let avgRank = Double((i + 1) + (j + 1)) / 2
            for k in i...j {
                ranks[indexed[k].offset] = avgRank
            }
            i = j + 1
        }
        return ranks
    }

    /// Σ(t³ − t) over tie groups, used in the variance correction.
    private static func tieCorrection(_ x: [Double]) -> Double {
        var counts: [Double: Int] = [:]
        for v in x { counts[v, default: 0] += 1 }
        return counts.values.reduce(0.0) { acc, t in
            let td = Double(t)
            return acc + (td * td * td - td)
        }
    }
}
