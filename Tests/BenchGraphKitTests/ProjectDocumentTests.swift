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
        #expect(restored.version == 2)
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
    }
}
