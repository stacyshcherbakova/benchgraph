import Testing
import Foundation
@testable import BenchGraphKit

/// Standard-curve interpolation: parsing the user's target list, and reading x
/// back at a given response.
@Suite struct InterpolationTests {

    /// A clean 4PL curve with a known EC50, so interpolation has a right answer.
    private func curve() -> (x: [Double], y: [Double]) {
        let x = [1.0, 3, 10, 30, 100, 300, 1000]
        let y = x.map { 100 / (1 + pow($0 / 50, 1.0)) }
        return (x, y)
    }

    // MARK: - parseTargets

    @Test func parsesACommaSeparatedList() {
        #expect(FourPL.parseTargets("50,75") == [50, 75])
    }

    /// `Double.init?` rejects leading whitespace, so an unfrimmed parse silently
    /// dropped every value after the first — the CLI's `--interpolate 50, 75`.
    @Test func parsesValuesWithSurroundingWhitespace() {
        #expect(FourPL.parseTargets(" 50, 75 ") == [50, 75])
        #expect(FourPL.parseTargets("50 , 75") == [50, 75])
    }

    @Test func skipsEmptyAndUnparseableComponents() {
        #expect(FourPL.parseTargets("50,,75") == [50, 75])
        #expect(FourPL.parseTargets("50,abc,75") == [50, 75])
        #expect(FourPL.parseTargets("abc") == [])
        #expect(FourPL.parseTargets("") == [])
        #expect(FourPL.parseTargets("   ") == [])
    }

    @Test func parsesDecimalsAndNegatives() {
        #expect(FourPL.parseTargets("12.5, -3") == [12.5, -3])
    }

    /// A half-typed list must not throw away what is already valid, since the
    /// app recomputes on every keystroke.
    @Test func handlesATrailingCommaMidTyping() {
        #expect(FourPL.parseTargets("50,") == [50])
    }

    // MARK: - analyze(interpolateY:)

    @Test func interpolatesWithinTheFittedRange() {
        let (x, y) = curve()
        let result = FourPL.analyze(x: x, y: y, interpolateY: [50])
        let row = result.values.first { $0.label.hasPrefix("x at y=") }
        #expect(row != nil)
        // At half-maximal response the interpolated x is the EC50, ~50.
        #expect(abs((row?.value ?? 0) - 50) < 1.0)
    }

    /// A whole-number target reads as "x at y=50", not "x at y=50.0".
    @Test func targetLabelDropsATrailingZero() {
        let (x, y) = curve()
        let result = FourPL.analyze(x: x, y: y, interpolateY: [50])
        #expect(result.values.contains { $0.label == "x at y=50" })
    }

    /// Out-of-range targets used to be dropped in silence, leaving the user with
    /// no row and no explanation.
    @Test func outOfRangeTargetWarnsInsteadOfVanishing() {
        let (x, y) = curve()
        let result = FourPL.analyze(x: x, y: y, interpolateY: [150])
        #expect(!result.values.contains { $0.label.hasPrefix("x at y=") })
        #expect(result.warnings.contains { $0.contains("150") && $0.contains("outside the fitted range") })
    }

    @Test func belowRangeAlsoWarns() {
        let (x, y) = curve()
        let result = FourPL.analyze(x: x, y: y, interpolateY: [-20])
        #expect(result.warnings.contains { $0.contains("outside the fitted range") })
    }

    /// Mixing valid and invalid targets yields a row for one and a warning for
    /// the other, not an all-or-nothing failure.
    @Test func mixedTargetsProduceBothARowAndAWarning() {
        let (x, y) = curve()
        let result = FourPL.analyze(x: x, y: y, interpolateY: [50, 999])
        #expect(result.values.contains { $0.label == "x at y=50" })
        #expect(result.warnings.contains { $0.contains("999") })
    }

    @Test func noTargetsAddsNoRowsAndNoWarnings() {
        let (x, y) = curve()
        let result = FourPL.analyze(x: x, y: y)
        #expect(!result.values.contains { $0.label.hasPrefix("x at y=") })
        #expect(!result.warnings.contains { $0.contains("outside the fitted range") })
    }
}
