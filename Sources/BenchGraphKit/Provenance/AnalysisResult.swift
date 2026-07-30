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
}

/// Top-level namespace + version stamp for the engine.
public enum BenchGraph {
    public static let version = "0.1.0-mvp"
}
