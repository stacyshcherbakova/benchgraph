import Foundation

/// A smoothed density estimate used to draw violin plots. The profile is a set
/// of `(value, density)` samples along the data axis; renderers map `density`
/// to a half-width to form the symmetric violin shape.
public enum KernelDensity {

    public struct Sample: Sendable, Equatable, Codable {
        public let value: Double
        public let density: Double
        public init(value: Double, density: Double) {
            self.value = value
            self.density = density
        }
    }

    /// Gaussian kernel density estimate over an evenly spaced grid.
    ///
    /// The bandwidth uses Silverman's rule of thumb
    /// (`h = 1.06·σ·n^(-1/5)`). Samples with fewer than two points, or no
    /// spread, can't support a meaningful estimate and return an empty profile,
    /// which renderers fall back from (e.g. to a box).
    public static func gaussian(_ x: [Double], gridCount: Int = 64) -> [Sample] {
        guard x.count >= 2, gridCount > 1 else { return [] }
        let n = Double(x.count)
        let sd = Descriptive.standardDeviation(x)
        guard sd.isFinite, sd > 0 else { return [] }

        let h = 1.06 * sd * pow(n, -0.2)
        guard h > 0 else { return [] }

        let lo = x.min()! - 3 * h
        let hi = x.max()! + 3 * h
        let step = (hi - lo) / Double(gridCount - 1)
        let norm = 1.0 / (n * h * (2 * Double.pi).squareRoot())

        return (0..<gridCount).map { i in
            let v = lo + Double(i) * step
            var acc = 0.0
            for xi in x {
                let u = (v - xi) / h
                acc += exp(-0.5 * u * u)
            }
            return Sample(value: v, density: norm * acc)
        }
    }
}
