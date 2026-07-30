import Testing
import Foundation
@testable import BenchGraphKit

/// XLSX import: a real (deflate-compressed) workbook fixture exercises the ZIP
/// reader, shared strings, inline strings, numbers, and sparse cells.
@Suite struct XLSXTests {

    /// A minimal but genuine `.xlsx` (ZIP + XML) built with Python's zipfile.
    /// Header row uses shared strings; data has a sparse cell (missing A4) and
    /// an inline string (A5).
    private static let workbookBase64 = """
    UEsDBBQAAAAIALdY41y1JUDXewAAAIwAAAATAAAAW0NvbnRlbnRfVHlwZXNdLnhtbB2MQQ7CIBAA776C7L0FPRhjoL31BfUBhK60sSyE3Rj7e9HjZDJjx0/a1Rsrb5kcnHsDCinkZaPo4DFP3Q0Ui6fF75nQwYEM43Cy81GQVYuJHawi5a41hxWT5z4XpGaeuSYvDWvUxYeXj6gvxlx1yCRI0snvAYPV/9nwBVBLAwQUAAAACAC3WONc3Vpdk58AAADPAAAAFAAAAHhsL3NoYXJlZFN0cmluZ3MueG1sPY3BCsIwEETvfkXYu031ICJJeij4BfoBoVltoNnU7Fb0700RvQzMG2bGdK80qScWjpks7JoWFNKQQ6S7hevlvD2CYvEU/JQJLbyRoXMbwyyqVoktjCLzSWseRkyemzwj1eSWS/JSbblrngv6wCOipEnv2/agk48EasgLiYU9qIXiY8H+59eH6Iy4PpOUPBktzugVffGlDgqGP95UZXEfUEsDBBQAAAAIALdY41wG2jhl+gAAAPsBAAAYAAAAeGwvd29ya3NoZWV0cy9zaGVldDEueG1sdZFRboMwDIbfd4rI74uBQsemkKrVtAtsO0AEaYkGCUoi2t1+KWVphcSb/f/2Zzthu0vfkVFap4yuIKUJEKlr0yh9quD76+O5BOK80I3ojJYV/EoHO/7Ezsb+uFZKTwJAuwpa74c3RFe3sheOmkHq4ByN7YUPqT2hG6wUzdTUd5glyRZ7oTQE2iS+Cy9CbM2Z2LAKcFZfg30KxFfgQj7yhOHIGdazd3j00uhhYNxJWSRlU11B0wXlpr/QbIWwiYTNVJnTckG46Vv6ukLI/wmHfJ5VrlQWcVYx3aZ0p7T89DboynHmeasY+tB2ze4bFPMGxZKLj4+L8d/4H1BLAQIUAxQAAAAIALdY41y1JUDXewAAAIwAAAATAAAAAAAAAAAAAACAAQAAAABbQ29udGVudF9UeXBlc10ueG1sUEsBAhQDFAAAAAgAt1jjXN1aXZOfAAAAzwAAABQAAAAAAAAAAAAAAIABrAAAAHhsL3NoYXJlZFN0cmluZ3MueG1sUEsBAhQDFAAAAAgAt1jjXAbaOGX6AAAA+wEAABgAAAAAAAAAAAAAAIABfQEAAHhsL3dvcmtzaGVldHMvc2hlZXQxLnhtbFBLBQYAAAAAAwADAMkAAACtAgAAAAA=
    """

    private func workbook() -> Data {
        Data(base64Encoded: Self.workbookBase64.filter { !$0.isWhitespace })!
    }

    @Test func readsRowsResolvingStringsAndSparseCells() throws {
        let rows = try XLSXImporter().rows(from: workbook())
        #expect(rows.count == 5)
        #expect(rows[0] == ["Control", "Treated"])   // shared strings
        #expect(rows[1] == ["5.1", "7.2"])
        #expect(rows[2] == ["4.8", "6.9"])
        #expect(rows[3] == ["", "7.8"])               // A4 missing → empty
        #expect(rows[4] == ["hi", "6.5"])             // inline string
    }

    @Test func parsesIntoDataTable() throws {
        let table = try XLSXImporter().parse(workbook(), kind: .column, hasHeader: true)
        #expect(table.columnNames == ["Control", "Treated"])
        #expect(table.columns[0].present == [5.1, 4.8])          // "" and "hi" excluded
        #expect(table.columns[1].present == [7.2, 6.9, 7.8, 6.5])
    }

    @Test func csvTextRoundTrips() throws {
        let csv = try XLSXImporter().csvText(from: workbook())
        #expect(csv.hasPrefix("Control,Treated"))
        #expect(csv.contains("5.1,7.2"))
    }

    @Test func rejectsNonZipData() {
        #expect(throws: XLSXImporter.XLSXError.notAZipArchive) {
            try XLSXImporter().rows(from: Data("not a zip".utf8))
        }
    }
}
