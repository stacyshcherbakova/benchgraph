import Testing
import Foundation
@testable import BenchGraphKit

@Suite struct ProjectDocumentTests {

    private func sample() -> ProjectDocument {
        ProjectDocument(
            tableKind: .xy,
            data: "Concentration,Response\n1,9.1\n10,49.5\n100,90.9",
            hasHeader: true,
            analysisName: "4PL dose-response"
        )
    }

    @Test func roundTripPreservesEverything() throws {
        let original = sample()
        let data = try original.encoded()
        let restored = try ProjectDocument.decoded(from: data)
        #expect(restored == original)
        #expect(restored.tableKind == .xy)
        #expect(restored.data == original.data)
        #expect(restored.hasHeader)
        #expect(restored.analysisName == "4PL dose-response")
        #expect(restored.version == ProjectDocument.currentVersion)
    }

    @Test func jsonIsHumanReadable() throws {
        let json = String(data: try sample().encoded(), encoding: .utf8)!
        #expect(json.contains("\"analysisName\""))
        #expect(json.contains("\"version\""))
        #expect(json.contains("\"tableKind\""))
        // Pretty-printed and key-sorted -> stable, diffable.
        #expect(json.contains("\n"))
    }

    @Test func rejectsFutureVersion() throws {
        var future = sample()
        future.version = ProjectDocument.currentVersion + 1
        let data = try future.encoded()
        #expect(throws: ProjectDocument.LoadError.unsupportedVersion(future.version)) {
            try ProjectDocument.decoded(from: data)
        }
    }

    @Test func reportsMalformedData() {
        let garbage = Data("not json".utf8)
        #expect(throws: (any Error).self) {
            try ProjectDocument.decoded(from: garbage)
        }
    }

    @Test func savesAndLoadsFromDisk() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).benchgraph")
        defer { try? FileManager.default.removeItem(at: url) }
        let original = sample()
        try original.save(to: url)
        let loaded = try ProjectDocument.load(from: url)
        #expect(loaded == original)
    }

    // MARK: - v2 presentation options

    @Test func presentationOptionsRoundTrip() throws {
        let doc = ProjectDocument(
            tableKind: .column, data: "A,B\n1,2", hasHeader: true, analysisName: "ttest.welch",
            errorBar: .ci95, plotStyle: "Box", showSignificance: false, themeName: "Nature"
        )
        let restored = try ProjectDocument.decoded(from: doc.encoded())
        #expect(restored == doc)
        #expect(restored.errorBar == .ci95)
        #expect(restored.plotStyle == "Box")
        #expect(restored.showSignificance == false)
        #expect(restored.themeName == "Nature")
        #expect(restored.version == ProjectDocument.currentVersion)
    }

    /// A v1 file (no option keys) must still load, with options coming back nil.
    @Test func legacyV1FileStillLoads() throws {
        let v1 = #"""
        {"analysisName":"ttest.welch","data":"A,B\n1,2","hasHeader":true,"savedWithEngine":"0.1.0-mvp","tableKind":"column","version":1}
        """#
        let doc = try ProjectDocument.decoded(from: Data(v1.utf8))
        #expect(doc.version == 1)
        #expect(doc.analysisName == "ttest.welch")
        #expect(doc.errorBar == nil)
        #expect(doc.plotStyle == nil)
        #expect(doc.showSignificance == nil)
        #expect(doc.themeName == nil)
        #expect(doc.panels == nil)
    }

    /// A v2 file (options but no panel keys) must still load, with the v3 fields
    /// coming back nil rather than failing to decode.
    @Test func legacyV2FileStillLoads() throws {
        let v2 = #"""
        {"analysisName":"anova.oneway","data":"A,B\n1,2","errorBar":"SD","hasHeader":true,"plotStyle":"Box","savedWithEngine":"0.1.0-mvp","showResiduals":false,"showSignificance":true,"tableKind":"column","themeName":"Nature","version":2}
        """#
        let doc = try ProjectDocument.decoded(from: Data(v2.utf8))
        #expect(doc.version == 2)
        #expect(doc.errorBar == .sd)
        #expect(doc.plotStyle == "Box")
        #expect(doc.themeName == "Nature")
        #expect(doc.panels == nil)
        #expect(doc.layoutColumns == nil)
        #expect(doc.interpolateTargets == nil)
    }

    // MARK: - v3 multi-panel staging

    @Test func panelsRoundTrip() throws {
        let panels = [
            PanelRecord(request: .bars(title: "Groups", yLabel: "Mean ± SEM",
                                       groups: [.init(label: "Ctrl", value: 5, error: 0.3)],
                                       brackets: []),
                        title: "Groups", sourceData: "Ctrl\n5\n"),
            PanelRecord(request: .scatter(title: "Fit", xLabel: "X", yLabel: "Y",
                                          series: [.init(name: "d", points: [.init(x: 1, y: 2)])],
                                          curve: nil, logX: true),
                        title: "Fit", sourceData: "X,Y\n1,2\n")
        ]
        let doc = ProjectDocument(
            tableKind: .xy, data: "X,Y\n1,2", hasHeader: true, analysisName: "doseresponse.4pl",
            panels: panels, layoutColumns: 3, interpolateTargets: [50, 75]
        )
        let restored = try ProjectDocument.decoded(from: doc.encoded())
        #expect(restored == doc)
        #expect(restored.version == 3)
        #expect(restored.panels?.count == 2)
        #expect(restored.panels?[0].title == "Groups")
        #expect(restored.panels?[1].sourceData == "X,Y\n1,2\n")
        #expect(restored.layoutColumns == 3)
        #expect(restored.interpolateTargets == [50, 75])
    }

    /// Panel order is the A/B/C order, so it must survive verbatim.
    @Test func panelOrderIsPreserved() throws {
        let titles = ["First", "Second", "Third"]
        let doc = ProjectDocument(
            tableKind: .column, data: "A\n1", hasHeader: true, analysisName: "descriptive",
            panels: titles.map {
                PanelRecord(request: .bars(title: $0, yLabel: "y",
                                           groups: [.init(label: "g", value: 1, error: 0)],
                                           brackets: []),
                            title: $0)
            })
        let restored = try ProjectDocument.decoded(from: doc.encoded())
        #expect(restored.panels?.map(\.title) == titles)
    }

    /// The end-to-end guarantee a user relies on: build a multi-panel figure,
    /// save the project, reopen it, export — and get the same figure back.
    @Test func composedFigureSurvivesASaveAndReopen() throws {
        let requests: [FigureExport.Request] = [
            .bars(title: "A", yLabel: "y", groups: [.init(label: "g1", value: 3, error: 0.4),
                                                    .init(label: "g2", value: 6, error: 0.5)],
                  brackets: [BarBracket(fromIndex: 0, toIndex: 1, label: "**", level: 0)]),
            .box(title: "B", yLabel: "Value",
                 groups: [.init(label: "g", stats: BoxStats.compute([2, 4, 5, 7, 9]))], brackets: []),
            .scatter(title: "C", xLabel: "X", yLabel: "Y",
                     series: [.init(name: "d", points: [.init(x: 1, y: 2), .init(x: 4, y: 9)])],
                     curve: [.init(x: 1, y: 2), .init(x: 4, y: 9)], logX: false)
        ]
        let labels = FigureLayout.defaultLabels(count: requests.count)
        let before = FigureLayout.data(zip(requests, labels).map {
            FigureLayout.Panel(request: $0, label: $1)
        }, pathExtension: "svg", layout: .init(columns: 2))

        let doc = ProjectDocument(
            tableKind: .column, data: "g1,g2\n3,6", hasHeader: true, analysisName: "anova.oneway",
            panels: zip(requests, labels).map { PanelRecord(request: $0, title: $1) },
            layoutColumns: 2)
        let reopened = try ProjectDocument.decoded(from: doc.encoded())

        let restored = try #require(reopened.panels)
        #expect(reopened.layoutColumns == 2)
        let after = FigureLayout.data(restored.enumerated().map {
            FigureLayout.Panel(request: $0.element.request, label: labels[$0.offset])
        }, pathExtension: "svg", layout: .init(columns: reopened.layoutColumns ?? 2))

        #expect(before != nil)
        #expect(before == after, "the composed figure changed across a save/reopen")
    }

    /// A staged panel must render the same after a save/load cycle — the point
    /// of storing the drawn figure rather than a recipe (spec D5).
    @Test func restoredPanelRendersIdentically() throws {
        let request = FigureExport.Request.box(
            title: "Box", yLabel: "Value",
            groups: [.init(label: "A", stats: BoxStats.compute([1, 2, 3, 4, 5]))],
            brackets: [])
        let doc = ProjectDocument(
            tableKind: .column, data: "A\n1", hasHeader: true, analysisName: "descriptive",
            panels: [PanelRecord(request: request, title: "Box")])
        let restored = try ProjectDocument.decoded(from: doc.encoded())
        let reloaded = try #require(restored.panels?.first?.request)
        #expect(FigureExport.data(reloaded, pathExtension: "svg")
                == FigureExport.data(request, pathExtension: "svg"))
    }
}
