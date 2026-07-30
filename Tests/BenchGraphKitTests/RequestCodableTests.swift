import Testing
import Foundation
@testable import BenchGraphKit

/// `FigureExport.Request` is persisted verbatim into `.benchgraph` project files
/// (spec D5), so its encoding is a file-format contract. These tests prove a
/// decoded request renders identically to the original, and pin the synthesized
/// coding keys so a case or label rename breaks here rather than in a user's
/// saved work.
@Suite struct RequestCodableTests {

    private let brackets = [BarBracket(fromIndex: 0, toIndex: 1, label: "**", level: 0)]

    private func requests() -> [FigureExport.Request] {
        let samples = [12.0, 14.0, 15.0, 15.5, 17.0, 21.0]
        return [
            .bars(title: "Bars", yLabel: "Mean ± SEM",
                  groups: [.init(label: "A", value: 3, error: 0.4),
                           .init(label: "B", value: 5, error: 0.6)],
                  brackets: brackets),
            .box(title: "Box", yLabel: "Value",
                 groups: [.init(label: "A", stats: BoxStats.compute(samples)),
                          .init(label: "B", stats: BoxStats.compute(samples.map { $0 * 1.4 }))],
                 brackets: brackets),
            .violin(title: "Violin", yLabel: "Value",
                    groups: [.init(label: "A",
                                   density: KernelDensity.gaussian(samples),
                                   stats: BoxStats.compute(samples))],
                    brackets: []),
            .scatter(title: "Scatter", xLabel: "X", yLabel: "Y",
                     series: [.init(name: "d", points: [.init(x: 1, y: 2), .init(x: 3, y: 4.5)])],
                     curve: [.init(x: 1, y: 2), .init(x: 3, y: 4)], logX: false)
        ]
    }

    /// The load-bearing guarantee: a request that has been through the project
    /// file renders byte-identically to the one that was staged.
    ///
    /// Byte equality is asserted on SVG only. PDF carries a per-render `/ID`
    /// stamped by CoreGraphics, so two renders of the same figure never match
    /// byte-for-byte — a pre-existing property of the format, unrelated to
    /// persistence. PDF is checked for validity instead.
    @Test func roundTripRendersIdentically() throws {
        for original in requests() {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(FigureExport.Request.self, from: data)
            #expect(decoded == original)

            let before = FigureExport.data(original, pathExtension: "svg")
            let after = FigureExport.data(decoded, pathExtension: "svg")
            #expect(before != nil)
            #expect(before == after, "SVG output differed after a round trip")

            let pdf = FigureExport.data(decoded, pathExtension: "pdf")
            #expect(pdf != nil)
            #expect(Array(pdf!.prefix(4)) == [0x25, 0x50, 0x44, 0x46])
        }
    }

    /// A log-x dose-response curve is the case most likely to lose precision.
    @Test func logScatterCurveSurvivesRoundTrip() throws {
        let curve = stride(from: -1.0, through: 3.0, by: 0.05).map {
            PlotPoint(x: pow(10, $0), y: 100 / (1 + pow(10, $0) / 42))
        }
        let original = FigureExport.Request.scatter(
            title: "4PL", xLabel: "Concentration", yLabel: "Response",
            series: [.init(name: "obs", points: curve)], curve: curve, logX: true)
        let decoded = try JSONDecoder().decode(
            FigureExport.Request.self, from: try JSONEncoder().encode(original))
        #expect(decoded == original)
        #expect(FigureExport.data(decoded, pathExtension: "svg")
                == FigureExport.data(original, pathExtension: "svg"))
    }

    /// Pin the synthesized keys. Renaming a case or an associated-value label is
    /// a breaking file-format change; it should fail here first.
    @Test func encodingKeysArePinned() throws {
        let encoded = try requests().map {
            String(data: try JSONEncoder().encode($0), encoding: .utf8)!
        }
        #expect(encoded[0].contains("\"bars\""))
        #expect(encoded[1].contains("\"box\""))
        #expect(encoded[2].contains("\"violin\""))
        #expect(encoded[3].contains("\"scatter\""))
        for json in encoded.prefix(3) {
            #expect(json.contains("\"groups\""))
            #expect(json.contains("\"brackets\""))
        }
        #expect(encoded[3].contains("\"series\""))
        #expect(encoded[3].contains("\"curve\""))
        #expect(encoded[3].contains("\"logX\""))
        #expect(encoded[3].contains("\"title\""))
    }

    /// A nil curve must round-trip as nil, not as an empty array — an empty
    /// array would draw a zero-length path element.
    @Test func nilCurveStaysNil() throws {
        let original = FigureExport.Request.scatter(
            title: "T", xLabel: "X", yLabel: "Y",
            series: [.init(name: "d", points: [.init(x: 1, y: 1)])], curve: nil, logX: false)
        let decoded = try JSONDecoder().decode(
            FigureExport.Request.self, from: try JSONEncoder().encode(original))
        guard case let .scatter(_, _, _, _, curve, _) = decoded else {
            Issue.record("expected a scatter case")
            return
        }
        #expect(curve == nil)
    }
}
