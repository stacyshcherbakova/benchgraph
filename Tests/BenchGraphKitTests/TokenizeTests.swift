import Testing
@testable import BenchGraphKit

/// The editable table grid and the numeric parser share `CSVImporter`'s row/
/// field splitting via `tokenize`; these lock that raw-string behaviour.
@Suite struct TokenizeTests {

    @Test func splitsRowsAndFields() {
        let rows = CSVImporter().tokenize("A,B\n1,2\n3,4\n")
        #expect(rows == [["A", "B"], ["1", "2"], ["3", "4"]])
    }

    @Test func keepsRawStringsWithoutNumericCoercion() {
        let rows = CSVImporter().tokenize("Name,Val\nx,N/A\n")
        #expect(rows == [["Name", "Val"], ["x", "N/A"]])
    }

    @Test func handlesQuotedCommas() {
        let rows = CSVImporter().tokenize("\"a,b\",c\n")
        #expect(rows == [["a,b", "c"]])
    }

    @Test func dropsBlankRows() {
        let rows = CSVImporter().tokenize("1,2\n\n3,4\n")
        #expect(rows == [["1", "2"], ["3", "4"]])
    }

    @Test func defaultColumnNames() {
        let imp = CSVImporter()
        #expect(imp.defaultColumnName(for: 0, kind: .xy) == "X")
        #expect(imp.defaultColumnName(for: 1, kind: .xy) == "A")
        #expect(imp.defaultColumnName(for: 0, kind: .column) == "A")
        #expect(imp.defaultColumnName(for: 1, kind: .column) == "B")
    }
}
