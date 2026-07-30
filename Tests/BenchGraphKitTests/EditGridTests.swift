import Testing
@testable import BenchGraphKit

/// The editable grid backs the app's data table; these lock its parse/serialize
/// round-trip and structural edits so the on-screen table stays consistent with
/// the CSV the analyses actually run on.
@Suite struct EditGridTests {

    @Test func parseWithHeaderSplitsNamesAndRows() {
        let g = EditGrid.parse("Control,Treated\n5.1,7.2\n4.8,6.9", kind: .column, hasHeader: true)
        #expect(g.columnNames == ["Control", "Treated"])
        #expect(g.rowCount == 2)
        #expect(g.cell(0, 0) == "5.1")
        #expect(g.cell(1, 1) == "6.9")
    }

    @Test func csvRoundTripsThroughParse() {
        let g = EditGrid.parse("A,B\n1,2\n3,4", kind: .column, hasHeader: true)
        let csv = g.csv(includeHeader: true)
        let again = EditGrid.parse(csv, kind: .column, hasHeader: true)
        #expect(again == g)
    }

    @Test func rowsArePaddedToHeaderWidth() {
        let g = EditGrid.parse("A,B,C\n1\n2,3", kind: .column, hasHeader: true)
        #expect(g.columnCount == 3)
        #expect(g.rows[0] == ["1", "", ""])
        #expect(g.rows[1] == ["2", "3", ""])
    }

    @Test func editingCellsAndStructure() {
        var g = EditGrid.empty(kind: .column, columns: 2, rows: 2)
        g.setCell(0, 0, "9")
        #expect(g.cell(0, 0) == "9")
        g.addRow()
        #expect(g.rowCount == 3)
        g.addColumn()
        #expect(g.columnCount == 3)
        #expect(g.rows[0].count == 3)   // new column padded across rows
        g.removeColumn(2)
        #expect(g.columnCount == 2)
    }

    @Test func keepsAtLeastOneRowAndColumn() {
        var g = EditGrid.empty(kind: .column, columns: 1, rows: 1)
        g.removeRow(0)              // refused: would empty the grid
        #expect(g.rowCount == 1)
        g.removeColumn(0)           // refused: would empty the grid
        #expect(g.columnCount == 1)
    }

    @Test func headerToggleOffPromotesNamesToData() {
        var g = EditGrid.parse("Control,Treated\n5.1,7.2", kind: .column, hasHeader: true)
        g.applyHeaderChange(nowHasHeader: false)
        #expect(g.columnNames == ["A", "B"])       // placeholder names
        #expect(g.rows.first == ["Control", "Treated"])  // former header now data
    }

    @Test func headerToggleOnPromotesFirstRowToNames() {
        var g = EditGrid.parse("Control,Treated\n5.1,7.2", kind: .column, hasHeader: false)
        g.applyHeaderChange(nowHasHeader: true)
        #expect(g.columnNames == ["Control", "Treated"])
        #expect(g.rows == [["5.1", "7.2"]])
    }

    @Test func xyPlaceholderNames() {
        let g = EditGrid.empty(kind: .xy, columns: 2, rows: 1)
        #expect(g.columnNames == ["X", "A"])
    }

    @Test func serializationQuotesFieldsWithCommas() {
        var g = EditGrid.empty(kind: .column, columns: 1, rows: 1)
        g.setCell(0, 0, "a,b")
        let csv = g.csv(includeHeader: false)
        #expect(csv == "\"a,b\"")
        // And it re-parses back to the same single cell.
        #expect(EditGrid.parse(csv, kind: .column, hasHeader: false).cell(0, 0) == "a,b")
    }
}
