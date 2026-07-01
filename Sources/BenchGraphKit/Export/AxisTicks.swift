import Foundation

/// Computes "nice" round axis tick values for a numeric range, so axes read
/// `0, 2, 4, 6, 8` instead of data-derived fractions like `-0.38, 1.31, 2.99`.
///
/// Uses Heckbert's nice-numbers method ("Nice Numbers for Graph Labels",
/// Graphics Gems, 1990): pick a round step from {1, 2, 5} × 10ⁿ, then emit the
/// round multiples of that step that fall within the (already padded) domain.
/// Both the SVG and CoreGraphics renderers share this so figures match.
public enum AxisTicks {

    /// Round tick values lying within `[lo, hi]`. `count` is the approximate
    /// number of intervals desired (the result may have a few more or fewer).
    public static func nice(_ lo: Double, _ hi: Double, count: Int = 5) -> [Double] {
        guard hi > lo, count >= 2, lo.isFinite, hi.isFinite else { return [lo] }

        let range = niceNum(hi - lo, round: false)
        let step = niceNum(range / Double(count - 1), round: true)
        guard step > 0 else { return [lo] }

        let start = (lo / step).rounded(.down) * step
        let end = (hi / step).rounded(.up) * step
        let eps = step * 1e-6

        var ticks: [Double] = []
        var v = start
        while v <= end + eps {
            if v >= lo - eps && v <= hi + eps {
                // Snap a value sitting on zero to exactly 0 to avoid "-0".
                ticks.append(abs(v) < eps ? 0 : v)
            }
            v += step
        }
        return ticks.isEmpty ? [lo, hi] : ticks
    }

    /// Rounds `x` to the nearest "nice" number (1, 2, 5 × 10ⁿ). When `round` is
    /// false it rounds up, giving a range that comfortably contains the data.
    private static func niceNum(_ x: Double, round: Bool) -> Double {
        guard x > 0 else { return 0 }
        let exponent = log10(x).rounded(.down)
        let fraction = x / pow(10, exponent)
        let niceFraction: Double
        if round {
            switch fraction {
            case ..<1.5: niceFraction = 1
            case ..<3:   niceFraction = 2
            case ..<7:   niceFraction = 5
            default:     niceFraction = 10
            }
        } else {
            switch fraction {
            case ...1: niceFraction = 1
            case ...2: niceFraction = 2
            case ...5: niceFraction = 5
            default:   niceFraction = 10
            }
        }
        return niceFraction * pow(10, exponent)
    }
}
