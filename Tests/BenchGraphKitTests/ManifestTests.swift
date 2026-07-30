import Testing
import Foundation
@testable import BenchGraphKit

/// Export manifests are plain, key-sorted JSON that round-trip exactly.
@Suite struct ManifestTests {

    @Test func exportManifestRoundTrips() throws {
        let result = AnalysisResult(
            analysis: "Unpaired t test (Welch)",
            formula: "t = (m1 - m2) / SE",
            values: [ResultValue("t", 2.5), ResultValue("p (two-tailed)", 0.03)]
        )
        let m = ExportManifest(
            analysis: "Unpaired t test (Welch)", analysisKey: "ttest.welch", tableKind: "column",
            hasHeader: true, rowCount: 6, columnNames: ["Control", "Treated"],
            errorBar: "SEM", plotStyle: "Bars", showSignificance: true, theme: "Nature",
            result: result, exportedAt: "2026-07-03T00:00:00Z"
        )
        let data = try m.encoded()
        let back = try JSONDecoder().decode(ExportManifest.self, from: data)
        #expect(back == m)

        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"analysisKey\""))
        #expect(json.contains("\"engineVersion\""))
        #expect(json.contains("\"result\""))
        #expect(json.contains("\n"))   // pretty-printed
    }

    @Test func layoutManifestRoundTrips() throws {
        let m = LayoutManifest(
            theme: "Default",
            panels: [.init(label: "A", title: "One"), .init(label: "B", title: "Two")],
            exportedAt: "2026-07-03T00:00:00Z"
        )
        let back = try JSONDecoder().decode(LayoutManifest.self, from: try m.encoded())
        #expect(back == m)
        #expect(back.panels.map(\.label) == ["A", "B"])
    }

    @Test func manifestFilenameFromFigurePath() {
        #expect(ExportManifest.filename(forFigure: "/x/y/figure.pdf") == "figure.manifest.json")
        #expect(ExportManifest.filename(forFigure: "fig.svg") == "fig.manifest.json")
    }
}
