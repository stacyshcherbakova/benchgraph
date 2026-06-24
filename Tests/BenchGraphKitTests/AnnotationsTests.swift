import Testing
import Foundation
@testable import BenchGraphKit

/// Covers the figure-annotation layer: error-bar statistics, significance star
/// codes, bracket stacking, and that brackets actually reach the SVG output.
@Suite struct AnnotationsTests {

    // MARK: - Error bars

    @Test func errorBarKindsMatchSummary() {
        // 95% CI half-length must exceed SEM (t(0.975) > 1), and SEM = SD/√n.
        let sample = [4.0, 5.0, 6.0, 5.0, 4.0, 6.0]
        let s = Descriptive.summary(sample)
        #expect(ErrorBarKind.sd.halfLength(s) == s.sd)
        #expect(abs(ErrorBarKind.sem.halfLength(s) - s.sd / Double(sample.count).squareRoot()) < 1e-12)
        let ci = ErrorBarKind.ci95.halfLength(s)
        #expect(ci > ErrorBarKind.sem.halfLength(s))
        // CI half-length should reproduce the summary's symmetric CI.
        #expect(abs(ci - (s.ci95Upper - s.mean)) < 1e-9)
    }

    @Test func errorBarCaptionsAreDistinct() {
        let captions = Set(ErrorBarKind.allCases.map(\.caption))
        #expect(captions.count == ErrorBarKind.allCases.count)
        #expect(ErrorBarKind.sem.caption == "Mean ± SEM")
    }

    // MARK: - Significance stars

    @Test func starThresholds() {
        #expect(Significance.stars(0.00005) == "****")
        #expect(Significance.stars(0.0005)  == "***")
        #expect(Significance.stars(0.005)   == "**")
        #expect(Significance.stars(0.03)    == "*")
        #expect(Significance.stars(0.2)     == "ns")
        #expect(Significance.stars(.nan)    == "")
        // Boundaries are exclusive: exactly 0.05 is not significant.
        #expect(Significance.stars(0.05)    == "ns")
    }

    // MARK: - Bracket stacking

    @Test func nonOverlappingBracketsShareLevelZero() {
        let laid = BracketLayout.assignLevels([
            BarBracket(fromIndex: 0, toIndex: 1, label: "*"),
            BarBracket(fromIndex: 2, toIndex: 3, label: "*")
        ])
        #expect(laid.allSatisfy { $0.level == 0 })
    }

    @Test func overlappingBracketsStack() {
        // A wide bracket enclosing two narrow ones must sit above both.
        let laid = BracketLayout.assignLevels([
            BarBracket(fromIndex: 0, toIndex: 2, label: "*"),   // wide
            BarBracket(fromIndex: 0, toIndex: 1, label: "**"),  // narrow
            BarBracket(fromIndex: 1, toIndex: 2, label: "ns")   // narrow, touches the first
        ])
        let levels = Dictionary(uniqueKeysWithValues: laid.map { ($0.lo * 10 + $0.hi, $0.level) })
        // Narrow brackets are placed first at level 0; the wide one rises above.
        #expect(levels[0 * 10 + 1] == 0)
        #expect(levels[1 * 10 + 2] == 0)
        #expect(levels[0 * 10 + 2]! >= 1)
    }

    // MARK: - Rendering

    @Test func svgBarChartEmbedsBracketLabels() {
        let bars = [
            SVGRenderer.BarGroup(label: "A", value: 10, error: 2),
            SVGRenderer.BarGroup(label: "B", value: 14, error: 3)
        ]
        let brackets = [BarBracket(fromIndex: 0, toIndex: 1, label: "**")]
        let withMark = SVGRenderer().barChart(title: "T", yLabel: "V", groups: bars, brackets: brackets)
        let plain = SVGRenderer().barChart(title: "T", yLabel: "V", groups: bars)
        #expect(withMark.contains(">**<"))
        #expect(!plain.contains(">**<"))
        // The bracket adds geometry, so the annotated SVG is strictly larger.
        #expect(withMark.count > plain.count)
    }

    @Test func cgBarChartWithBracketsRendersValidPDF() {
        let bars = [
            SVGRenderer.BarGroup(label: "A", value: 10, error: 2),
            SVGRenderer.BarGroup(label: "B", value: 14, error: 3),
            SVGRenderer.BarGroup(label: "C", value: 9, error: 1)
        ]
        let brackets = BracketLayout.assignLevels([
            BarBracket(fromIndex: 0, toIndex: 1, label: "*"),
            BarBracket(fromIndex: 0, toIndex: 2, label: "ns")
        ])
        let data = CGChartRenderer().barChart(format: .pdf, title: "Means", yLabel: "V",
                                              groups: bars, brackets: brackets)
        #expect(data != nil)
        #expect(Array(data!.prefix(4)) == [0x25, 0x50, 0x44, 0x46])  // "%PDF"
    }
}
