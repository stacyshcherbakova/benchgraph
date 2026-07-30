import Testing
import Foundation
@testable import BenchGraphKit

/// Multi-panel composition: geometry, labels, and valid SVG / PDF output.
@Suite struct MultipanelTests {

    private func panels() -> [FigureLayout.Panel] {
        [
            FigureLayout.Panel(
                request: .bars(title: "One", yLabel: "v",
                               groups: [.init(label: "A", value: 3, error: 0.5)], brackets: []),
                label: "A"),
            FigureLayout.Panel(
                request: .scatter(title: "Two", xLabel: "x", yLabel: "y",
                                  series: [.init(name: "d", points: [(1, 2), (3, 4)])],
                                  curve: nil, logX: false),
                label: "B")
        ]
    }

    @Test func svgNestsPanelsAndLabels() {
        let data = FigureLayout.data(panels(), pathExtension: "svg")
        #expect(data != nil)
        let svg = String(data: data!, encoding: .utf8)!
        #expect(svg.hasPrefix("<?xml"))
        // One outer <svg> plus one per panel.
        #expect(svg.components(separatedBy: "<svg").count - 1 >= 3)
        #expect(svg.contains(">A<"))   // panel label A
        #expect(svg.contains(">B<"))   // panel label B
        #expect(svg.hasSuffix("</svg>"))
    }

    @Test func pdfIsValid() {
        let data = FigureLayout.data(panels(), pathExtension: "pdf")
        #expect(data != nil)
        #expect(Array(data!.prefix(4)) == [0x25, 0x50, 0x44, 0x46])  // "%PDF"
        #expect(data!.count > 500)
    }

    @Test func emptyPanelsReturnNil() {
        #expect(FigureLayout.data([], pathExtension: "svg") == nil)
    }

    @Test func unsupportedExtensionReturnsNil() {
        #expect(FigureLayout.data(panels(), pathExtension: "bmp") == nil)
    }

    @Test func defaultLabelSequence() {
        #expect(FigureLayout.defaultLabels(count: 3) == ["A", "B", "C"])
        #expect(FigureLayout.defaultLabels(count: 27).last == "AA")
    }

    @Test func geometryIsGridded() {
        let spec = FigureLayout.Spec(columns: 2, panelWidth: 100, panelHeight: 100,
                                     gap: 10, padding: 10, labelBand: 20)
        #expect(spec.rows(panelCount: 3) == 2)
        let total = spec.totalSize(panelCount: 3)
        #expect(total.w == 230)   // 10*2 + 2*100 + 1*10
        #expect(total.h == 270)   // 10*2 + 2*120 + 1*10
        let cell1 = spec.cellRect(index: 1)
        #expect(cell1.minX == 120) // second column: 10 + 100 + 10
        #expect(cell1.minY == 10)
    }

    @Test func deterministicSVG() {
        let a = FigureLayout.data(panels(), pathExtension: "svg")
        let b = FigureLayout.data(panels(), pathExtension: "svg")
        #expect(a == b)
    }
}
