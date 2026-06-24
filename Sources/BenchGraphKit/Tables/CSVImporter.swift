import Foundation

/// Parses pasted spreadsheet data or CSV/TSV files into a `DataTable`.
///
/// Handles the messy realities the roadmap calls out: empty cells, mixed
/// delimiters, quoted fields, a header row, and non-numeric tokens (which
/// become missing values rather than crashing the import).
public struct CSVImporter {

    public enum Delimiter {
        case comma
        case tab
        case auto

        func character(for text: String) -> Character {
            switch self {
            case .comma: return ","
            case .tab: return "\t"
            case .auto:
                // Pick whichever appears more often in the first line.
                let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
                let tabs = firstLine.filter { $0 == "\t" }.count
                let commas = firstLine.filter { $0 == "," }.count
                return tabs > commas ? "\t" : ","
            }
        }
    }

    public init() {}

    /// Parse text into a table.
    ///
    /// - Parameters:
    ///   - text: raw CSV/TSV/pasted content.
    ///   - kind: how to interpret the columns.
    ///   - hasHeader: whether the first row holds column names.
    ///   - delimiter: field separator, or `.auto` to detect.
    public func parse(
        _ text: String,
        kind: TableKind,
        hasHeader: Bool = true,
        delimiter: Delimiter = .auto
    ) -> DataTable {
        let sep = delimiter.character(for: text)
        let rows = splitRows(text).map { parseLine($0, separator: sep) }
        guard !rows.isEmpty else { return DataTable(kind: kind, columns: []) }

        let width = rows.map(\.count).max() ?? 0
        var headerNames: [String]
        var dataRows: [[String]]

        if hasHeader, let header = rows.first {
            headerNames = (0..<width).map { i in
                let raw = i < header.count ? header[i].trimmingCharacters(in: .whitespaces) : ""
                return raw.isEmpty ? defaultName(for: i, kind: kind) : raw
            }
            dataRows = Array(rows.dropFirst())
        } else {
            headerNames = (0..<width).map { defaultName(for: $0, kind: kind) }
            dataRows = rows
        }

        var columns: [DataColumn] = []
        for col in 0..<width {
            var values: [Double?] = []
            for row in dataRows {
                let cell = col < row.count ? row[col] : ""
                values.append(parseNumber(cell))
            }
            columns.append(DataColumn(name: headerNames[col], values: values))
        }
        return DataTable(kind: kind, columns: columns)
    }

    // MARK: - Helpers

    private func defaultName(for index: Int, kind: TableKind) -> String {
        if kind == .xy && index == 0 { return "X" }
        // A, B, C ... then A1, B1 ...
        let letterIndex = kind == .xy ? index - 1 : index
        let letter = String(UnicodeScalar(UInt8(65 + (letterIndex % 26))))
        let suffix = letterIndex / 26
        return suffix == 0 ? letter : "\(letter)\(suffix)"
    }

    /// Split on newlines, dropping a trailing empty line but keeping interior
    /// blank rows out (a fully blank row carries no observations).
    private func splitRows(_ text: String) -> [String] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Minimal RFC-4180-style field splitter supporting double-quoted fields.
    private func parseLine(_ line: String, separator: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = line.makeIterator()
        var pending: Character? = iterator.next()

        while let ch = pending {
            pending = iterator.next()
            if inQuotes {
                if ch == "\"" {
                    if pending == "\"" {          // escaped quote
                        current.append("\"")
                        pending = iterator.next()
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(ch)
                }
            } else if ch == "\"" {
                inQuotes = true
            } else if ch == separator {
                fields.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        fields.append(current)
        return fields
    }

    /// Parse a cell into a number, tolerating thousands separators and
    /// common "missing" tokens. Returns nil for anything non-numeric.
    private func parseNumber(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        let lowered = trimmed.lowercased()
        let missingTokens: Set<String> = ["na", "n/a", "nan", "null", "nd", "-", "."]
        if missingTokens.contains(lowered) { return nil }
        // Strip thousands separators but keep the decimal point.
        let cleaned = trimmed.replacingOccurrences(of: ",", with: "")
        return Double(cleaned)
    }
}
