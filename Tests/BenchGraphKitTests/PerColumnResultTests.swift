import Testing
import Foundation
@testable import BenchGraphKit

/// Combining independent per-column results into one envelope, used by analyses
/// that run separately on every column (descriptive statistics, normality).
@Suite struct PerColumnResultTests {

    private func columns() -> [(name: String, result: AnalysisResult)] {
        [("Ctrl", Descriptive.analyze(DataColumn(name: "Ctrl", values: [1, 2, 3, 4]))),
         ("Treated", Descriptive.analyze(DataColumn(name: "Treated", values: [5, 6, 7, 8])))]
    }

    @Test func labelsArePrefixedWhenThereIsMoreThanOneColumn() {
        let merged = AnalysisResult.perColumn("Descriptive statistics", formula: "f",
                                              columns: columns())
        #expect(merged.values.contains { $0.label.hasPrefix("Ctrl — ") })
        #expect(merged.values.contains { $0.label.hasPrefix("Treated — ") })
    }

    /// With one column a prefix would just be noise.
    @Test func singleColumnKeepsPlainLabels() {
        let one = Array(columns().prefix(1))
        let merged = AnalysisResult.perColumn("Descriptive statistics", formula: "f", columns: one)
        #expect(merged.values.allSatisfy { !$0.label.contains(" — ") })
        #expect(merged.values.map(\.label) == one[0].result.values.map(\.label))
    }

    /// Every column's outputs must survive — this is the bug being fixed, where
    /// the app reported only the first column.
    @Test func everyColumnsValuesAreCarried() {
        let cols = columns()
        let merged = AnalysisResult.perColumn("Descriptive statistics", formula: "f", columns: cols)
        #expect(merged.values.count == cols.reduce(0) { $0 + $1.result.values.count })
        let means = merged.values.filter { $0.label.hasSuffix("Mean") }
        #expect(means.count == 2)
        #expect(means.map(\.value) == cols.map { $0.result.value("Mean")! })
    }

    /// Assumptions are identical per column, so listing them twice is noise.
    @Test func assumptionsAreDeduplicated() {
        let merged = AnalysisResult.perColumn("Descriptive statistics", formula: "f",
                                              columns: columns())
        #expect(Set(merged.assumptions).count == merged.assumptions.count)
    }

    @Test func warningsAreAttributedToTheirColumn() {
        let noisy: [(name: String, result: AnalysisResult)] = [
            ("A", AnalysisResult(analysis: "x", formula: "f", values: [], warnings: ["small n"])),
            ("B", AnalysisResult(analysis: "x", formula: "f", values: [], warnings: []))
        ]
        let merged = AnalysisResult.perColumn("x", formula: "f", columns: noisy)
        #expect(merged.warnings == ["A: small n"])
    }

    @Test func excludedCountsSum() {
        let cols: [(name: String, result: AnalysisResult)] = [
            ("A", AnalysisResult(analysis: "x", formula: "f", values: [], excludedCount: 2)),
            ("B", AnalysisResult(analysis: "x", formula: "f", values: [], excludedCount: 3))
        ]
        #expect(AnalysisResult.perColumn("x", formula: "f", columns: cols).excludedCount == 5)
    }

    @Test func noColumnsIsEmptyRatherThanACrash() {
        let merged = AnalysisResult.perColumn("x", formula: "f", columns: [])
        #expect(merged.values.isEmpty)
        #expect(merged.excludedCount == 0)
    }
}
