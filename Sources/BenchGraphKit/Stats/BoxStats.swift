import Foundation

/// The statistics a box-and-whisker plot draws for one sample, using the
/// Tukey convention: the box spans the inter-quartile range, whiskers reach the
/// most extreme observations within 1.5·IQR of the quartiles, and anything
/// beyond those fences is drawn as an individual outlier.
public struct BoxStats: Sendable, Equatable, Codable {
    public let q1: Double
    public let median: Double
    public let q3: Double
    /// Whisker ends: the most extreme data still inside the 1.5·IQR fences.
    public let lowerWhisker: Double
    public let upperWhisker: Double
    /// Mean, drawn as an optional marker (Prism shows a "+" for it).
    public let mean: Double
    /// Observations beyond the fences, drawn as separate points.
    public let outliers: [Double]

    /// Inter-quartile range (box height).
    public var iqr: Double { q3 - q1 }

    public init(q1: Double, median: Double, q3: Double,
                lowerWhisker: Double, upperWhisker: Double,
                mean: Double, outliers: [Double]) {
        self.q1 = q1
        self.median = median
        self.q3 = q3
        self.lowerWhisker = lowerWhisker
        self.upperWhisker = upperWhisker
        self.mean = mean
        self.outliers = outliers
    }

    /// Compute box-plot statistics for a sample. An empty sample yields all
    /// `NaN`; a single value collapses the box to that value.
    public static func compute(_ x: [Double]) -> BoxStats {
        guard !x.isEmpty else {
            return BoxStats(q1: .nan, median: .nan, q3: .nan,
                            lowerWhisker: .nan, upperWhisker: .nan,
                            mean: .nan, outliers: [])
        }
        let sorted = x.sorted()
        let q1 = Descriptive.percentile(sorted, 0.25)
        let q3 = Descriptive.percentile(sorted, 0.75)
        let iqr = q3 - q1
        let lowerFence = q1 - 1.5 * iqr
        let upperFence = q3 + 1.5 * iqr
        let inFence = sorted.filter { $0 >= lowerFence && $0 <= upperFence }
        // `inFence` can only be empty if every point is non-finite; guard anyway.
        let lowerWhisker = inFence.first ?? sorted.first!
        let upperWhisker = inFence.last ?? sorted.last!
        let outliers = sorted.filter { $0 < lowerFence || $0 > upperFence }
        return BoxStats(
            q1: q1,
            median: Descriptive.percentile(sorted, 0.5),
            q3: q3,
            lowerWhisker: lowerWhisker,
            upperWhisker: upperWhisker,
            mean: Descriptive.mean(sorted),
            outliers: outliers
        )
    }

    /// The full vertical extent the plot must show, including outliers.
    public var displayRange: (lo: Double, hi: Double) {
        let lo = Swift.min(lowerWhisker, outliers.min() ?? lowerWhisker)
        let hi = Swift.max(upperWhisker, outliers.max() ?? upperWhisker)
        return (lo, hi)
    }
}
