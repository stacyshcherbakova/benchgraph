import Foundation

/// Descriptive statistics for a single sample.
public enum Descriptive {

    public struct Summary: Sendable, Codable {
        public let n: Int
        public let mean: Double
        public let sd: Double          // sample SD (n-1)
        public let sem: Double
        public let median: Double
        public let min: Double
        public let max: Double
        public let q1: Double
        public let q3: Double
        public let ci95Lower: Double
        public let ci95Upper: Double
    }

    /// Sample mean.
    public static func mean(_ x: [Double]) -> Double {
        guard !x.isEmpty else { return .nan }
        return x.reduce(0, +) / Double(x.count)
    }

    /// Sample variance (n-1 denominator).
    public static func variance(_ x: [Double]) -> Double {
        guard x.count > 1 else { return .nan }
        let m = mean(x)
        let ss = x.reduce(0) { $0 + ($1 - m) * ($1 - m) }
        return ss / Double(x.count - 1)
    }

    public static func standardDeviation(_ x: [Double]) -> Double {
        variance(x).squareRoot()
    }

    /// Linear-interpolation percentile (the "type 7"/spreadsheet convention).
    public static func percentile(_ x: [Double], _ p: Double) -> Double {
        guard !x.isEmpty else { return .nan }
        if x.count == 1 { return x[0] }
        let sorted = x.sorted()
        let rank = p * Double(sorted.count - 1)
        let lo = Int(rank.rounded(.down))
        let hi = Int(rank.rounded(.up))
        let frac = rank - Double(lo)
        return sorted[lo] + frac * (sorted[hi] - sorted[lo])
    }

    public static func median(_ x: [Double]) -> Double { percentile(x, 0.5) }

    /// Full descriptive summary, including a 95% CI of the mean (t-based).
    public static func summary(_ x: [Double]) -> Summary {
        let n = x.count
        let m = mean(x)
        let sd = standardDeviation(x)
        let sem = n > 0 ? sd / Double(n).squareRoot() : .nan
        var ciLo = Double.nan
        var ciHi = Double.nan
        if n > 1 {
            let tCrit = Distributions.studentTQuantile(0.975, df: Double(n - 1))
            ciLo = m - tCrit * sem
            ciHi = m + tCrit * sem
        }
        return Summary(
            n: n,
            mean: m,
            sd: sd,
            sem: sem,
            median: median(x),
            min: x.min() ?? .nan,
            max: x.max() ?? .nan,
            q1: percentile(x, 0.25),
            q3: percentile(x, 0.75),
            ci95Lower: ciLo,
            ci95Upper: ciHi
        )
    }

    /// Provenance-rich descriptive result for one column.
    public static func analyze(_ column: DataColumn) -> AnalysisResult {
        let x = column.present
        let s = summary(x)
        var warnings: [String] = []
        if x.count < 3 { warnings.append("Very small sample (n = \(x.count)); estimates are unstable.") }
        return AnalysisResult(
            analysis: "Descriptive statistics",
            formula: "mean = Σx/n; SD uses n−1; 95% CI = mean ± t(0.975, n−1)·SEM",
            values: [
                ResultValue("n", Double(s.n)),
                ResultValue("Mean", s.mean),
                ResultValue("SD", s.sd),
                ResultValue("SEM", s.sem),
                ResultValue("Median", s.median),
                ResultValue("Min", s.min),
                ResultValue("Max", s.max),
                ResultValue("Q1", s.q1),
                ResultValue("Q3", s.q3),
                ResultValue("95% CI lower", s.ci95Lower),
                ResultValue("95% CI upper", s.ci95Upper)
            ],
            assumptions: ["CI of the mean assumes approximately normal sampling distribution."],
            warnings: warnings,
            excludedCount: column.missingCount
        )
    }
}
