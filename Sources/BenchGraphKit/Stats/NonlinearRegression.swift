import Foundation

/// Four-parameter logistic (4PL) dose-response curve fitting via the
/// Levenberg-Marquardt algorithm with a numerical Jacobian.
///
/// Model:  y = D + (A − D) / (1 + (x / C)^B)
///   A = response as x → 0 (bottom)
///   D = response as x → ∞ (top)
///   C = inflection point (EC50/IC50)
///   B = Hill slope
public enum FourPL {

    public struct Fit: Sendable, Codable {
        public let a: Double   // bottom
        public let b: Double   // Hill slope
        public let c: Double   // EC50
        public let d: Double   // top
        public let rSquared: Double
        public let iterations: Int
        public let converged: Bool

        /// Model prediction at x.
        public func predict(_ x: Double) -> Double {
            FourPL.model(x, a: a, b: b, c: c, d: d)
        }

        /// Interpolate the x that produces response y (inverse of the model).
        /// Returns nil when y is outside the (A, D) range.
        public func interpolate(y: Double) -> Double? {
            let lo = Swift.min(a, d)
            let hi = Swift.max(a, d)
            guard y > lo, y < hi else { return nil }
            let ratio = (a - d) / (y - d) - 1
            guard ratio > 0 else { return nil }
            return c * pow(ratio, 1 / b)
        }
    }

    static func model(_ x: Double, a: Double, b: Double, c: Double, d: Double) -> Double {
        if x <= 0 { return a }
        return d + (a - d) / (1 + pow(x / c, b))
    }

    /// Fit the 4PL model to (x, y) data.
    public static func fit(
        x: [Double],
        y: [Double],
        maxIterations: Int = 200,
        tolerance: Double = 1e-9
    ) -> Fit {
        precondition(x.count == y.count && x.count >= 4, "4PL needs ≥ 4 points")

        // Initial parameter guesses from the data.
        let yMin = y.min()!
        let yMax = y.max()!
        let positiveX = x.filter { $0 > 0 }
        let cGuess = positiveX.isEmpty ? 1.0 : Descriptive.median(positiveX)
        var params = [yMin, 1.0, cGuess, yMax]   // [A, B, C, D]

        var lambda = 1e-3
        var currentSSE = sse(params, x: x, y: y)
        var converged = false
        var iteration = 0

        while iteration < maxIterations {
            iteration += 1
            let j = jacobian(params, x: x)          // n × 4
            let residuals = zip(x, y).map { $0.1 - model($0.0, a: params[0], b: params[1], c: params[2], d: params[3]) }

            // Normal equations: (JᵀJ + λ·diag(JᵀJ)) δ = Jᵀr
            var jtj = [[Double]](repeating: [Double](repeating: 0, count: 4), count: 4)
            var jtr = [Double](repeating: 0, count: 4)
            for row in 0..<x.count {
                for p in 0..<4 {
                    jtr[p] += j[row][p] * residuals[row]
                    for q in 0..<4 {
                        jtj[p][q] += j[row][p] * j[row][q]
                    }
                }
            }

            var improved = false
            // Inner loop adjusts the damping until SSE decreases.
            for _ in 0..<30 {
                var augmented = jtj
                for p in 0..<4 { augmented[p][p] += lambda * jtj[p][p] }

                guard let delta = solve4x4(augmented, jtr) else {
                    lambda *= 10
                    continue
                }
                let candidate = zip(params, delta).map(+)
                // Keep C and B physically meaningful.
                if candidate[2] <= 0 { lambda *= 10; continue }
                let candidateSSE = sse(candidate, x: x, y: y)
                if candidateSSE < currentSSE {
                    let relativeGain = (currentSSE - candidateSSE) / Swift.max(currentSSE, 1e-30)
                    params = candidate
                    currentSSE = candidateSSE
                    lambda = Swift.max(lambda / 10, 1e-12)
                    improved = true
                    if relativeGain < tolerance { converged = true }
                    break
                } else {
                    lambda *= 10
                }
            }
            if !improved || converged { converged = converged || !improved; break }
        }

        // R² relative to total sum of squares.
        let my = Descriptive.mean(y)
        let ssTot = y.reduce(0) { $0 + ($1 - my) * ($1 - my) }
        let rSquared = ssTot > 0 ? 1 - currentSSE / ssTot : .nan

        return Fit(a: params[0], b: params[1], c: params[2], d: params[3],
                   rSquared: rSquared, iterations: iteration, converged: converged)
    }

    /// Provenance-rich result; optionally interpolate unknown responses.
    public static func analyze(
        x: [Double],
        y: [Double],
        interpolateY: [Double] = []
    ) -> AnalysisResult {
        let f = fit(x: x, y: y)
        var values: [ResultValue] = [
            ResultValue("Bottom (A)", f.a),
            ResultValue("Hill slope (B)", f.b),
            ResultValue("EC50 (C)", f.c),
            ResultValue("Top (D)", f.d),
            ResultValue("R squared", f.rSquared),
            ResultValue("Iterations", Double(f.iterations))
        ]
        for target in interpolateY {
            if let xv = f.interpolate(y: target) {
                values.append(ResultValue("x at y=\(target)", xv))
            }
        }
        var warnings: [String] = []
        if !f.converged { warnings.append("Fit did not fully converge; inspect residuals and starting values.") }
        if x.count < 5 { warnings.append("Few points for a 4-parameter model (n = \(x.count)).") }

        return AnalysisResult(
            analysis: "4PL dose-response (nonlinear regression)",
            formula: "y = D + (A − D) / (1 + (x/C)^B); fit by Levenberg-Marquardt",
            values: values,
            assumptions: ["Sigmoidal dose-response.", "Independent, approximately constant-variance residuals."],
            warnings: warnings
        )
    }

    // MARK: - Internals

    private static func sse(_ p: [Double], x: [Double], y: [Double]) -> Double {
        var total = 0.0
        for i in x.indices {
            let r = y[i] - model(x[i], a: p[0], b: p[1], c: p[2], d: p[3])
            total += r * r
        }
        return total
    }

    /// Numerical Jacobian: ∂model/∂param via central differences.
    private static func jacobian(_ p: [Double], x: [Double]) -> [[Double]] {
        var j = [[Double]](repeating: [Double](repeating: 0, count: 4), count: x.count)
        for param in 0..<4 {
            let h = Swift.max(1e-6, Swift.abs(p[param]) * 1e-6)
            var pUp = p, pDown = p
            pUp[param] += h
            pDown[param] -= h
            for i in x.indices {
                let up = model(x[i], a: pUp[0], b: pUp[1], c: pUp[2], d: pUp[3])
                let down = model(x[i], a: pDown[0], b: pDown[1], c: pDown[2], d: pDown[3])
                j[i][param] = (up - down) / (2 * h)
            }
        }
        return j
    }

    /// Solve a 4×4 linear system by Gaussian elimination with partial pivoting.
    private static func solve4x4(_ matrix: [[Double]], _ rhs: [Double]) -> [Double]? {
        var a = matrix
        var b = rhs
        let n = 4
        for col in 0..<n {
            // Pivot.
            var pivot = col
            for row in (col + 1)..<n where Swift.abs(a[row][col]) > Swift.abs(a[pivot][col]) {
                pivot = row
            }
            if Swift.abs(a[pivot][col]) < 1e-300 { return nil }
            if pivot != col { a.swapAt(pivot, col); b.swapAt(pivot, col) }
            // Eliminate.
            for row in (col + 1)..<n {
                let factor = a[row][col] / a[col][col]
                for k in col..<n { a[row][k] -= factor * a[col][k] }
                b[row] -= factor * b[col]
            }
        }
        // Back-substitute.
        var solution = [Double](repeating: 0, count: n)
        for row in stride(from: n - 1, through: 0, by: -1) {
            var sum = b[row]
            for k in (row + 1)..<n { sum -= a[row][k] * solution[k] }
            solution[row] = sum / a[row][row]
        }
        return solution
    }
}
