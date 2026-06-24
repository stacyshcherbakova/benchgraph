import Foundation

/// Ordinary least-squares simple linear regression.
public enum LinearRegression {

    public struct Fit: Sendable, Codable {
        public let slope: Double
        public let intercept: Double
        public let rSquared: Double
        public let slopeSE: Double
        public let interceptSE: Double
        public let n: Int

        /// Predicted y at a given x.
        public func predict(_ x: Double) -> Double { slope * x + intercept }
    }

    public static func fit(_ x: [Double], _ y: [Double]) -> Fit {
        precondition(x.count == y.count, "Regression requires equal-length inputs")
        let n = Double(x.count)
        let mx = Descriptive.mean(x)
        let my = Descriptive.mean(y)
        var sxx = 0.0, sxy = 0.0
        for i in x.indices {
            sxx += (x[i] - mx) * (x[i] - mx)
            sxy += (x[i] - mx) * (y[i] - my)
        }
        let slope = sxy / sxx
        let intercept = my - slope * mx

        // Residual variance and standard errors.
        var ssRes = 0.0, ssTot = 0.0
        for i in x.indices {
            let pred = slope * x[i] + intercept
            ssRes += (y[i] - pred) * (y[i] - pred)
            ssTot += (y[i] - my) * (y[i] - my)
        }
        let rSquared = 1 - ssRes / ssTot
        let s2 = ssRes / (n - 2)
        let slopeSE = (s2 / sxx).squareRoot()
        let interceptSE = (s2 * (1 / n + mx * mx / sxx)).squareRoot()

        return Fit(slope: slope, intercept: intercept, rSquared: rSquared,
                   slopeSE: slopeSE, interceptSE: interceptSE, n: x.count)
    }

    public static func analyze(_ x: [Double], _ y: [Double]) -> AnalysisResult {
        let f = fit(x, y)
        let df = Double(f.n - 2)
        let tSlope = f.slope / f.slopeSE
        let pSlope = Distributions.twoTailedTP(tSlope, df: df)
        return AnalysisResult(
            analysis: "Simple linear regression",
            formula: "y = slope·x + intercept (ordinary least squares)",
            values: [
                ResultValue("n", Double(f.n)),
                ResultValue("Slope", f.slope),
                ResultValue("Slope SE", f.slopeSE),
                ResultValue("Intercept", f.intercept),
                ResultValue("Intercept SE", f.interceptSE),
                ResultValue("R squared", f.rSquared),
                ResultValue("t (slope ≠ 0)", tSlope),
                ResultValue("p (slope)", pSlope)
            ],
            assumptions: [
                "Linear relationship.",
                "Independent, homoscedastic, approximately normal residuals."
            ]
        )
    }
}
