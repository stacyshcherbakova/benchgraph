import Foundation

/// Numerical special functions and statistical distributions used by the
/// analysis engine. These are implemented from standard numerical recipes
/// (Lentz continued fractions, Lanczos gamma) so that p-values do not depend
/// on any external library and can be pinned with golden-value tests.
public enum Distributions {

    // MARK: - Gamma

    /// Natural log of the gamma function (Lanczos approximation, g = 7).
    public static func lnGamma(_ x: Double) -> Double {
        let coefficients = [
            0.99999999999980993,
            676.5203681218851,
            -1259.1392167224028,
            771.32342877765313,
            -176.61502916214059,
            12.507343278686905,
            -0.13857109526572012,
            9.9843695780195716e-6,
            1.5056327351493116e-7
        ]
        if x < 0.5 {
            // Reflection formula.
            return log(Double.pi / sin(Double.pi * x)) - lnGamma(1 - x)
        }
        let xm1 = x - 1
        var a = coefficients[0]
        let t = xm1 + 7.5
        for i in 1..<coefficients.count {
            a += coefficients[i] / (xm1 + Double(i))
        }
        return 0.5 * log(2 * Double.pi) + (xm1 + 0.5) * log(t) - t + log(a)
    }

    // MARK: - Error function

    /// Error function via Abramowitz & Stegun 7.1.26 (max error ~1.5e-7).
    public static func erf(_ x: Double) -> Double {
        let t = 1.0 / (1.0 + 0.3275911 * Swift.abs(x))
        let y = 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-x * x)
        return x >= 0 ? y : -y
    }

    /// Standard normal cumulative distribution function.
    public static func normalCDF(_ x: Double) -> Double {
        return 0.5 * (1.0 + erf(x / 2.0.squareRoot()))
    }

    // MARK: - Incomplete beta

    /// Regularized incomplete beta function I_x(a, b).
    ///
    /// Uses the continued fraction expansion (Lentz's method), with the
    /// symmetry relation to keep the expansion in its region of fast
    /// convergence. This underpins the t and F distribution tail areas.
    public static func incompleteBeta(_ x: Double, _ a: Double, _ b: Double) -> Double {
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }

        let lnBeta = lnGamma(a) + lnGamma(b) - lnGamma(a + b)
        let front = exp(log(x) * a + log(1 - x) * b - lnBeta) / a

        // Choose the faster-converging side.
        if x < (a + 1) / (a + b + 2) {
            return front * betaContinuedFraction(x, a, b)
        } else {
            return 1 - exp(log(1 - x) * b + log(x) * a - lnBeta) / b * betaContinuedFraction(1 - x, b, a)
        }
    }

    private static func betaContinuedFraction(_ x: Double, _ a: Double, _ b: Double) -> Double {
        let tiny = 1e-30
        let epsilon = 1e-12
        let maxIterations = 300

        var c = 1.0
        var d = 1.0 - (a + b) * x / (a + 1)
        if Swift.abs(d) < tiny { d = tiny }
        d = 1.0 / d
        var result = d

        var m = 1
        while m <= maxIterations {
            let mDouble = Double(m)
            let m2 = 2 * mDouble

            // Even step.
            var numerator = mDouble * (b - mDouble) * x / ((a + m2 - 1) * (a + m2))
            d = 1.0 + numerator * d
            if Swift.abs(d) < tiny { d = tiny }
            c = 1.0 + numerator / c
            if Swift.abs(c) < tiny { c = tiny }
            d = 1.0 / d
            result *= d * c

            // Odd step.
            numerator = -(a + mDouble) * (a + b + mDouble) * x / ((a + m2) * (a + m2 + 1))
            d = 1.0 + numerator * d
            if Swift.abs(d) < tiny { d = tiny }
            c = 1.0 + numerator / c
            if Swift.abs(c) < tiny { c = tiny }
            d = 1.0 / d
            let delta = d * c
            result *= delta

            if Swift.abs(delta - 1.0) < epsilon { break }
            m += 1
        }
        return result
    }

    // MARK: - Student's t

    /// CDF of Student's t distribution with `df` degrees of freedom.
    public static func studentTCDF(_ t: Double, df: Double) -> Double {
        let x = df / (df + t * t)
        let ib = 0.5 * incompleteBeta(x, df / 2, 0.5)
        return t >= 0 ? 1 - ib : ib
    }

    /// Two-tailed p-value for a t statistic.
    public static func twoTailedTP(_ t: Double, df: Double) -> Double {
        let x = df / (df + t * t)
        return incompleteBeta(x, df / 2, 0.5)
    }

    /// Inverse CDF (quantile) of Student's t via bisection. Used for CIs.
    public static func studentTQuantile(_ p: Double, df: Double) -> Double {
        guard p > 0, p < 1 else { return p <= 0 ? -.infinity : .infinity }
        var lo = -100.0
        var hi = 100.0
        for _ in 0..<200 {
            let mid = (lo + hi) / 2
            if studentTCDF(mid, df: df) < p {
                lo = mid
            } else {
                hi = mid
            }
        }
        return (lo + hi) / 2
    }

    // MARK: - F distribution

    /// Upper-tail probability P(F > f) for the F distribution.
    public static func fUpperTail(_ f: Double, df1: Double, df2: Double) -> Double {
        if f <= 0 { return 1 }
        let x = df2 / (df2 + df1 * f)
        return incompleteBeta(x, df2 / 2, df1 / 2)
    }

    // MARK: - Normal quantile

    /// Inverse standard normal CDF (Acklam's rational approximation).
    public static func normalQuantile(_ p: Double) -> Double {
        guard p > 0, p < 1 else { return p <= 0 ? -.infinity : .infinity }
        let a = [-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
                 1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00]
        let b = [-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
                 6.680131188771972e+01, -1.328068155288572e+01]
        let c = [-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
                 -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00]
        let d = [7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00,
                 3.754408661907416e+00]
        let pLow = 0.02425
        let pHigh = 1 - pLow

        if p < pLow {
            let q = (-2 * log(p)).squareRoot()
            return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
                   ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
        } else if p <= pHigh {
            let q = p - 0.5
            let r = q * q
            return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q /
                   (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1)
        } else {
            let q = (-2 * log(1 - p)).squareRoot()
            return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
                    ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
        }
    }
}
