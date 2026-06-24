import Foundation

/// Pearson and Spearman correlation for paired X/Y data.
public enum Correlation {

    /// Pearson product-moment correlation.
    public static func pearson(_ x: [Double], _ y: [Double]) -> AnalysisResult {
        precondition(x.count == y.count, "Pearson requires equal-length inputs")
        let n = Double(x.count)
        let mx = Descriptive.mean(x)
        let my = Descriptive.mean(y)
        var sxy = 0.0, sxx = 0.0, syy = 0.0
        for i in x.indices {
            let dx = x[i] - mx
            let dy = y[i] - my
            sxy += dx * dy
            sxx += dx * dx
            syy += dy * dy
        }
        let r = sxy / (sxx * syy).squareRoot()
        let df = n - 2
        let t = r * (df / (1 - r * r)).squareRoot()
        let p = Distributions.twoTailedTP(t, df: df)

        return AnalysisResult(
            analysis: "Pearson correlation",
            formula: "r = Σ(dx·dy) / √(Σdx²·Σdy²); t = r·√(df/(1−r²)), df = n−2",
            values: [
                ResultValue("n", n),
                ResultValue("r", r),
                ResultValue("R squared", r * r),
                ResultValue("t", t),
                ResultValue("df", df),
                ResultValue("p (two-tailed)", p)
            ],
            assumptions: ["Linear relationship.", "Approximately bivariate normal for the p-value."]
        )
    }

    /// Spearman rank correlation (Pearson on ranks).
    public static func spearman(_ x: [Double], _ y: [Double]) -> AnalysisResult {
        precondition(x.count == y.count, "Spearman requires equal-length inputs")
        let rx = MannWhitney.averageRanks(x)
        let ry = MannWhitney.averageRanks(y)
        // Reuse Pearson math on the ranks.
        let base = pearson(rx, ry)
        let rho = base.value("r") ?? .nan
        let n = Double(x.count)
        let df = n - 2
        let t = rho * (df / (1 - rho * rho)).squareRoot()
        let p = Distributions.twoTailedTP(t, df: df)
        return AnalysisResult(
            analysis: "Spearman correlation",
            formula: "ρ = Pearson r on ranks; p via t approximation, df = n−2",
            values: [
                ResultValue("n", n),
                ResultValue("rho", rho),
                ResultValue("t", t),
                ResultValue("df", df),
                ResultValue("p (two-tailed)", p)
            ],
            assumptions: ["Monotonic relationship.", "No distributional assumption on X or Y."]
        )
    }
}
