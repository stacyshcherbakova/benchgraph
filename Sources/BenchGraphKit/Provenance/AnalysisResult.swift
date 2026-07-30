import Foundation

/// A single named numeric output of an analysis (estimate, statistic, p-value…).
public struct ResultValue: Sendable, Codable, Equatable {
    public let label: String
    public let value: Double
    public init(_ label: String, _ value: Double) {
        self.label = label
        self.value = value
    }
}

/// The common, provenance-rich envelope every analysis returns.
///
/// The roadmap insists that "every analysis should show assumptions, model
/// formula, confidence intervals, multiple-comparison correction, excluded
/// rows, and exact test version." This type carries exactly that, so the UI
/// (or CLI) never has to reverse-engineer how a number was produced.
public struct AnalysisResult: Sendable, Codable, Equatable {
    /// Human-readable analysis name, e.g. "Unpaired t test (Welch)".
    public let analysis: String
    /// Model formula or method, e.g. "Welch's t = (m1 - m2) / SE".
    public let formula: String
    /// Primary numeric outputs, in display order.
    public let values: [ResultValue]
    /// Stated assumptions for the test.
    public let assumptions: [String]
    /// Warnings (e.g. small n, excluded values, unequal variances).
    public let warnings: [String]
    /// Count of cells excluded as missing/non-numeric.
    public let excludedCount: Int
    /// Engine version that produced the result (for reproducibility).
    public let engineVersion: String

    public init(
        analysis: String,
        formula: String,
        values: [ResultValue],
        assumptions: [String] = [],
        warnings: [String] = [],
        excludedCount: Int = 0,
        engineVersion: String = BenchGraph.version
    ) {
        self.analysis = analysis
        self.formula = formula
        self.values = values
        self.assumptions = assumptions
        self.warnings = warnings
        self.excludedCount = excludedCount
        self.engineVersion = engineVersion
    }

    /// Look up a single output by label.
    public func value(_ label: String) -> Double? {
        values.first { $0.label == label }?.value
    }

    /// Combine independent per-column results into one envelope, for analyses
    /// that run separately on every column (descriptive statistics, normality).
    ///
    /// Value labels gain a `Column — ` prefix when there is more than one
    /// column, so a reader can tell the groups apart; a single column is left
    /// unprefixed. Assumptions are identical per column and so are deduplicated,
    /// warnings are attributed to the column that raised them, and excluded
    /// counts sum.
    public static func perColumn(
        _ analysis: String,
        formula: String,
        columns: [(name: String, result: AnalysisResult)]
    ) -> AnalysisResult {
        let prefixed = columns.count > 1
        var values: [ResultValue] = []
        var assumptions: [String] = []
        var warnings: [String] = []
        var excluded = 0

        for (name, result) in columns {
            for v in result.values {
                values.append(ResultValue(prefixed ? "\(name) — \(v.label)" : v.label, v.value))
            }
            for a in result.assumptions where !assumptions.contains(a) {
                assumptions.append(a)
            }
            warnings.append(contentsOf: prefixed ? result.warnings.map { "\(name): \($0)" }
                                                 : result.warnings)
            excluded += result.excludedCount
        }

        return AnalysisResult(analysis: analysis, formula: formula, values: values,
                              assumptions: assumptions, warnings: warnings,
                              excludedCount: excluded)
    }
}

/// Top-level namespace + version stamp for the engine.
public enum BenchGraph {
    public static let version = "0.1.0-mvp"
}
