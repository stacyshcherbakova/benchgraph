import Testing
import Foundation
@testable import BenchGraphKit

/// Verifies the CoreGraphics renderer emits valid PDF / PNG / TIFF files by
/// checking each format's magic bytes and that output is non-trivial.
@Suite struct ExportFormatsTests {

    private let series = [SVGRenderer.Series(name: "d", points: [.init(x: 1, y: 2), .init(x: 2, y: 4),
                                                                 .init(x: 3, y: 5), .init(x: 4, y: 8)])]
    private let bars = [
        SVGRenderer.BarGroup(label: "A", value: 10, error: 2),
        SVGRenderer.BarGroup(label: "B", value: 14, error: 3)
    ]

    private func startsWith(_ data: Data, _ bytes: [UInt8]) -> Bool {
        guard data.count >= bytes.count else { return false }
        return Array(data.prefix(bytes.count)) == bytes
    }

    @Test func pdfHasHeader() {
        let data = CGChartRenderer().scatter(format: .pdf, title: "T", xLabel: "X", yLabel: "Y", series: series)
        #expect(data != nil)
        // "%PDF"
        #expect(startsWith(data!, [0x25, 0x50, 0x44, 0x46]))
        #expect(data!.count > 500)
    }

    @Test func pngHasSignature() {
        let data = CGChartRenderer().barChart(format: .png, title: "Means", yLabel: "V", groups: bars)
        #expect(data != nil)
        // 0x89 'P' 'N' 'G'
        #expect(startsWith(data!, [0x89, 0x50, 0x4E, 0x47]))
        #expect(data!.count > 500)
    }

    @Test func tiffHasSignature() {
        let data = CGChartRenderer().scatter(format: .tiff, title: "T", xLabel: "X", yLabel: "Y", series: series)
        #expect(data != nil)
        let d = data!
        // little-endian "II*\0" or big-endian "MM\0*"
        let le = startsWith(d, [0x49, 0x49, 0x2A, 0x00])
        let be = startsWith(d, [0x4D, 0x4D, 0x00, 0x2A])
        #expect(le || be)
    }

    @Test func curveAndLogAxisRender() {
        // 4PL-style curve on a log X axis should still produce a valid PDF.
        let curve = (0...20).map { i -> PlotPoint in
            let x = pow(10, Double(i) / 5)
            return PlotPoint(x: x, y: 100 / (1 + 10 / x))
        }
        let data = CGChartRenderer().scatter(
            format: .pdf, title: "Dose-response", xLabel: "Conc", yLabel: "Resp",
            series: series, curve: curve, logX: true
        )
        #expect(data != nil)
        #expect(startsWith(data!, [0x25, 0x50, 0x44, 0x46]))
    }
}
