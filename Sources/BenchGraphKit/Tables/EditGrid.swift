import Foundation

/// The editable, string-typed table the user types into directly.
///
/// It is the canonical data surface for the app: the CSV text handed to the
/// analysis parser and written into the project file is *derived* from this
/// grid (`csv(includeHeader:)`), so there is a single source of truth for the
/// data. Cells stay as raw strings — numeric interpretation happens later, in
/// `CSVImporter`, exactly as it does for pasted or imported data. It lives in
/// the engine (not the UI) so its serialization and header logic are testable.
public struct EditGrid: Equatable, Sendable {
    /// Column header names. When the table has no header row these are display
    /// placeholders (X, A, B …) and are not serialized.
    public private(set) var columnNames: [String]
    /// Data rows; every row is kept padded to `columnNames.count` cells.
    public private(set) var rows: [[String]]
    /// How the columns are interpreted, which also drives placeholder names.
    public let kind: TableKind

    public var columnCount: Int { columnNames.count }
    public var rowCount: Int { rows.count }

    public init(kind: TableKind, columnNames: [String], rows: [[String]]) {
        self.kind = kind
        self.columnNames = columnNames
        self.rows = rows
        normalize()
    }

    /// An empty starter grid with `columns` placeholder columns and `rows` blank
    /// rows, so a new/cleared table is immediately typeable.
    public static func empty(kind: TableKind, columns: Int = 2, rows: Int = 4) -> EditGrid {
        let importer = CSVImporter()
        let names = (0..<max(columns, 1)).map { importer.defaultColumnName(for: $0, kind: kind) }
        let blank = Array(repeating: Array(repeating: "", count: names.count), count: max(rows, 1))
        return EditGrid(kind: kind, columnNames: names, rows: blank)
    }

    /// Parse CSV/TSV text into a grid, mirroring how `CSVImporter` splits data.
    public static func parse(_ text: String, kind: TableKind, hasHeader: Bool) -> EditGrid {
        let importer = CSVImporter()
        let tokens = importer.tokenize(text)
        guard !tokens.isEmpty else { return .empty(kind: kind) }
        let width = tokens.map(\.count).max() ?? 0
        var names: [String]
        var body: [[String]]
        if hasHeader, let header = tokens.first {
            names = (0..<width).map { i in
                let raw = i < header.count ? header[i].trimmingCharacters(in: .whitespaces) : ""
                return raw.isEmpty ? importer.defaultColumnName(for: i, kind: kind) : raw
            }
            body = Array(tokens.dropFirst())
        } else {
            names = (0..<width).map { importer.defaultColumnName(for: $0, kind: kind) }
            body = tokens
        }
        return EditGrid(kind: kind, columnNames: names, rows: body)
    }

    // MARK: - Serialization

    /// Render the grid back to CSV text. `includeHeader` writes the column names
    /// as a first line; the output re-parses to an equivalent grid.
    public func csv(includeHeader: Bool) -> String {
        var lines: [String] = []
        if includeHeader { lines.append(columnNames.map(Self.encodeField).joined(separator: ",")) }
        for row in rows { lines.append(row.map(Self.encodeField).joined(separator: ",")) }
        return lines.joined(separator: "\n")
    }

    /// Quote a field only when it contains a comma, quote, or newline, matching
    /// the reader in `CSVImporter`.
    public static func encodeField(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: - Editing

    public func cell(_ row: Int, _ col: Int) -> String {
        guard rows.indices.contains(row), rows[row].indices.contains(col) else { return "" }
        return rows[row][col]
    }

    public mutating func setCell(_ row: Int, _ col: Int, _ value: String) {
        guard rows.indices.contains(row), columnNames.indices.contains(col) else { return }
        rows[row][col] = value
    }

    public mutating func renameColumn(_ col: Int, to name: String) {
        guard columnNames.indices.contains(col) else { return }
        columnNames[col] = name
    }

    public mutating func addRow() { rows.append(Array(repeating: "", count: columnNames.count)) }

    public mutating func removeRow(_ row: Int) {
        guard rows.indices.contains(row), rows.count > 1 else { return }
        rows.remove(at: row)
    }

    public mutating func addColumn() {
        let name = CSVImporter().defaultColumnName(for: columnNames.count, kind: kind)
        columnNames.append(name)
        for i in rows.indices { rows[i].append("") }
    }

    public mutating func removeColumn(_ col: Int) {
        guard columnNames.indices.contains(col), columnNames.count > 1 else { return }
        columnNames.remove(at: col)
        for i in rows.indices where rows[i].indices.contains(col) { rows[i].remove(at: col) }
    }

    /// Reinterpret the grid when the header toggle flips, keeping all data:
    /// turning a header off pushes the names down into a data row; turning it on
    /// promotes the first data row to names.
    public mutating func applyHeaderChange(nowHasHeader: Bool) {
        let importer = CSVImporter()
        if nowHasHeader {
            guard let first = rows.first else { return }
            columnNames = (0..<columnNames.count).map { i in
                let raw = i < first.count ? first[i].trimmingCharacters(in: .whitespaces) : ""
                return raw.isEmpty ? importer.defaultColumnName(for: i, kind: kind) : raw
            }
            rows.removeFirst()
            if rows.isEmpty { rows = [Array(repeating: "", count: columnNames.count)] }
        } else {
            rows.insert(columnNames, at: 0)
            columnNames = (0..<columnNames.count).map { importer.defaultColumnName(for: $0, kind: kind) }
        }
        normalize()
    }

    /// Keep every row the same width as the header, and guarantee at least one
    /// column and one row so the editor always has something to show.
    private mutating func normalize() {
        if columnNames.isEmpty { columnNames = [CSVImporter().defaultColumnName(for: 0, kind: kind)] }
        let width = columnNames.count
        rows = rows.map { row in
            if row.count == width { return row }
            if row.count > width { return Array(row.prefix(width)) }
            return row + Array(repeating: "", count: width - row.count)
        }
        if rows.isEmpty { rows = [Array(repeating: "", count: width)] }
    }
}
