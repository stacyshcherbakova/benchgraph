import Testing
@testable import BenchGraphKit

@Suite struct ImportExportTests {

    // MARK: - CSV import

    @Test func parseColumnTableWithHeader() {
        let csv = "Control,Treated\n1,4\n2,5\n3,6\n"
        let table = CSVImporter().parse(csv, kind: .column)
        #expect(table.columnNames == ["Control", "Treated"])
        #expect(table.columns[0].present == [1, 2, 3])
        #expect(table.columns[1].present == [4, 5, 6])
    }

    @Test func missingAndNonNumericBecomeNil() {
        let csv = "A,B\n1,\n2,N/A\nx,4\n"
        let table = CSVImporter().parse(csv, kind: .column)
        #expect(table.columns[0].present == [1, 2])     // "x" dropped
        #expect(table.columns[0].missingCount == 1)
        #expect(table.columns[1].present == [4])         // "" and "N/A" dropped
        #expect(table.columns[1].missingCount == 2)
    }

    @Test func tabDelimiterAutoDetect() {
        let tsv = "X\tY\n1\t10\n2\t20\n"
        let table = CSVImporter().parse(tsv, kind: .xy)
        #expect(table.columns[0].present == [1, 2])
        #expect(table.columns[1].present == [10, 20])
    }

    @Test func quotedFieldsAndThousands() {
        let csv = "\"Big Values\"\n\"1,000\"\n2000\n"
        let table = CSVImporter().parse(csv, kind: .column)
        #expect(table.columns[0].name == "Big Values")
        #expect(table.columns[0].present == [1000, 2000])
    }

    @Test func defaultColumnNamesForXY() {
        let csv = "1,2,3\n4,5,6\n"
        let table = CSVImporter().parse(csv, kind: .xy, hasHeader: false)
        #expect(table.columnNames == ["X", "A", "B"])
    }

    // MARK: - SVG export

    @Test func scatterSVGIsWellFormed() {
        let svg = SVGRenderer().scatter(
            title: "Test",
            xLabel: "X", yLabel: "Y",
            series: [.init(name: "d", points: [.init(x: 1, y: 2), .init(x: 2, y: 4), .init(x: 3, y: 6)])]
        )
        #expect(svg.hasPrefix("<?xml"))
        #expect(svg.contains("<svg"))
        #expect(svg.contains("</svg>"))
        #expect(svg.contains("<circle"))   // data points rendered
    }

    @Test func barChartRendersErrorBars() {
        let svg = SVGRenderer().barChart(
            title: "Means",
            yLabel: "Value",
            groups: [
                .init(label: "A", value: 10, error: 2),
                .init(label: "B", value: 14, error: 3)
            ]
        )
        #expect(svg.contains("<rect"))
        #expect(svg.contains("<line"))     // error bars + axes
        #expect(svg.contains(">A<"))
        #expect(svg.contains(">B<"))
    }

    @Test func deterministicOutput() {
        let r = SVGRenderer()
        let pts: [PlotPoint] = [.init(x: 1, y: 1), .init(x: 2, y: 2)]
        let a = r.scatter(title: "T", xLabel: "X", yLabel: "Y", series: [.init(name: "d", points: pts)])
        let b = r.scatter(title: "T", xLabel: "X", yLabel: "Y", series: [.init(name: "d", points: pts)])
        #expect(a == b)   // byte-stable for snapshot testing
    }
}
