import Foundation
import Compression

/// Reads the first worksheet of an `.xlsx` workbook into rows of string cells,
/// with **zero external dependencies**: an `.xlsx` is a ZIP of XML, so this
/// unzips the parts it needs with the OS `Compression` framework (raw DEFLATE)
/// and parses the XML with Foundation's `XMLParser`.
///
/// Scope is deliberately small — matching the roadmap's "basic XLSX import if
/// feasible without large dependency risk": a single sheet, shared strings,
/// inline strings, and numbers. Formulas resolve to their cached value; styles,
/// dates-as-numbers, and multiple sheets beyond the first are not interpreted.
public struct XLSXImporter {

    public enum XLSXError: Error, Equatable {
        case notAZipArchive
        case noWorksheet
    }

    public init() {}

    /// Parse the first worksheet into rows of string cells (sparse cells filled
    /// with empty strings so every row is rectangular).
    public func rows(from data: Data) throws -> [[String]] {
        let bytes = [UInt8](data)
        guard let archive = Zip.read(bytes) else { throw XLSXError.notAZipArchive }

        let shared = archive["xl/sharedStrings.xml"].map { SharedStrings.parse($0) } ?? []

        let sheetName = archive.keys
            .filter { $0.hasPrefix("xl/worksheets/") && $0.hasSuffix(".xml") }
            .sorted()
            .first
        guard let sheetName, let sheetData = archive[sheetName] else { throw XLSXError.noWorksheet }

        return Worksheet.parse(sheetData, sharedStrings: shared)
    }

    /// Convert the first worksheet to CSV text, reusing the same encoding rules
    /// as the editable grid so it flows through the normal import path.
    public func csvText(from data: Data) throws -> String {
        try rows(from: data)
            .map { row in row.map(Self.encodeField).joined(separator: ",") }
            .joined(separator: "\n")
    }

    /// Parse straight into a `DataTable` for the CLI / engine.
    public func parse(_ data: Data, kind: TableKind, hasHeader: Bool = true) throws -> DataTable {
        CSVImporter().parse(try csvText(from: data), kind: kind, hasHeader: hasHeader)
    }

    /// Quote a field only when it contains a comma, quote, or newline.
    static func encodeField(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

// MARK: - Minimal ZIP reader

/// Just enough of the ZIP format to pull named entries out of an `.xlsx`.
/// Reads the central directory, then inflates each entry's DEFLATE payload
/// (method 8) or copies stored data (method 0).
private enum Zip {

    static func read(_ bytes: [UInt8]) -> [String: Data]? {
        guard let eocd = findEOCD(bytes) else { return nil }
        let count = u16(bytes, eocd + 10)
        var p = u32(bytes, eocd + 16)   // central directory offset

        var out: [String: Data] = [:]
        for _ in 0..<count {
            guard p + 46 <= bytes.count, u32(bytes, p) == 0x0201_4b50 else { break }
            let method   = u16(bytes, p + 10)
            let compSize = u32(bytes, p + 20)
            let uncompSz = u32(bytes, p + 24)
            let nameLen  = u16(bytes, p + 28)
            let extraLen = u16(bytes, p + 30)
            let cmntLen  = u16(bytes, p + 32)
            let localOff = u32(bytes, p + 42)
            let name = string(bytes, p + 46, nameLen)

            if let payload = extract(bytes, localOffset: localOff, method: method,
                                     compSize: compSize, uncompSize: uncompSz) {
                out[name] = payload
            }
            p += 46 + nameLen + extraLen + cmntLen
        }
        return out.isEmpty ? nil : out
    }

    /// Read and (if needed) inflate one entry's data from its local header.
    private static func extract(_ bytes: [UInt8], localOffset: Int, method: Int,
                                compSize: Int, uncompSize: Int) -> Data? {
        guard localOffset + 30 <= bytes.count, u32(bytes, localOffset) == 0x0403_4b50 else { return nil }
        let nameLen = u16(bytes, localOffset + 26)
        let extraLen = u16(bytes, localOffset + 28)
        let start = localOffset + 30 + nameLen + extraLen
        guard start + compSize <= bytes.count else { return nil }
        let comp = Array(bytes[start ..< start + compSize])

        switch method {
        case 0:  return Data(comp)                       // stored
        case 8:  return inflate(comp, expected: uncompSize)  // DEFLATE
        default: return nil
        }
    }

    private static func inflate(_ src: [UInt8], expected: Int) -> Data? {
        guard !src.isEmpty else { return Data() }
        let capacity = max(expected, src.count * 4, 1)
        var dst = [UInt8](repeating: 0, count: capacity)
        let written = src.withUnsafeBufferPointer { sp in
            dst.withUnsafeMutableBufferPointer { dp in
                compression_decode_buffer(dp.baseAddress!, dp.count,
                                          sp.baseAddress!, sp.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard written > 0 else { return nil }
        return Data(dst[0 ..< written])
    }

    /// Scan backward for the End Of Central Directory signature (0x06054b50).
    private static func findEOCD(_ bytes: [UInt8]) -> Int? {
        guard bytes.count >= 22 else { return nil }
        var i = bytes.count - 22
        let lowest = max(0, bytes.count - 22 - 0xFFFF)
        while i >= lowest {
            if u32(bytes, i) == 0x0605_4b50 { return i }
            i -= 1
        }
        return nil
    }

    // Little-endian readers (bounds-checked; out-of-range reads return 0).
    private static func u16(_ b: [UInt8], _ o: Int) -> Int {
        guard o + 1 < b.count else { return 0 }
        return Int(b[o]) | Int(b[o + 1]) << 8
    }
    private static func u32(_ b: [UInt8], _ o: Int) -> Int {
        guard o + 3 < b.count else { return 0 }
        return Int(b[o]) | Int(b[o + 1]) << 8 | Int(b[o + 2]) << 16 | Int(b[o + 3]) << 24
    }
    private static func string(_ b: [UInt8], _ o: Int, _ len: Int) -> String {
        guard o + len <= b.count else { return "" }
        return String(decoding: b[o ..< o + len], as: UTF8.self)
    }
}

// MARK: - XML parsing

/// Parses `sharedStrings.xml` into an ordered list of strings. Each `<si>` may
/// hold several `<t>` runs, which are concatenated.
private final class SharedStrings: NSObject, XMLParserDelegate {
    private var strings: [String] = []
    private var current = ""
    private var inString = false
    private var inText = false

    static func parse(_ data: Data) -> [String] {
        let d = SharedStrings()
        let parser = XMLParser(data: data)
        parser.delegate = d
        parser.parse()
        return d.strings
    }

    func parser(_ parser: XMLParser, didStartElement el: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        switch el {
        case "si": inString = true; current = ""
        case "t" where inString: inText = true
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters s: String) {
        if inText { current += s }
    }

    func parser(_ parser: XMLParser, didEndElement el: String, namespaceURI: String?,
                qualifiedName: String?) {
        switch el {
        case "t": inText = false
        case "si": strings.append(current); inString = false
        default: break
        }
    }
}

/// Parses a worksheet's `sheetData` into dense rows, resolving shared-string and
/// inline-string cells to their text and keeping numbers as their literal text.
private final class Worksheet: NSObject, XMLParserDelegate {
    private let shared: [String]
    private var rows: [[String]] = []

    // Per-row / per-cell parsing state.
    private var rowCells: [(col: Int, value: String)] = []
    private var cellType = ""
    private var cellCol = 0
    private var value = ""
    private var inValue = false
    private var inInlineText = false

    init(shared: [String]) { self.shared = shared }

    static func parse(_ data: Data, sharedStrings: [String]) -> [[String]] {
        let d = Worksheet(shared: sharedStrings)
        let parser = XMLParser(data: data)
        parser.delegate = d
        parser.parse()
        return d.rows
    }

    func parser(_ parser: XMLParser, didStartElement el: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        switch el {
        case "row":
            rowCells = []
        case "c":
            cellType = attributes["t"] ?? ""
            cellCol = Worksheet.columnIndex(fromRef: attributes["r"] ?? "")
            value = ""
        case "v":
            inValue = true; value = ""
        case "t" where cellType == "inlineStr":
            inInlineText = true; value = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters s: String) {
        if inValue || inInlineText { value += s }
    }

    func parser(_ parser: XMLParser, didEndElement el: String, namespaceURI: String?,
                qualifiedName: String?) {
        switch el {
        case "v":
            inValue = false
        case "t" where inInlineText:
            inInlineText = false
        case "c":
            let resolved: String
            if cellType == "s", let i = Int(value), shared.indices.contains(i) {
                resolved = shared[i]
            } else {
                resolved = value
            }
            rowCells.append((cellCol, resolved))
        case "row":
            rows.append(densify(rowCells))
        default:
            break
        }
    }

    /// Build a rectangular row: place each cell at its column index, filling any
    /// gaps (sparse cells) with empty strings.
    private func densify(_ cells: [(col: Int, value: String)]) -> [String] {
        guard let maxCol = cells.map(\.col).max() else { return [] }
        var row = [String](repeating: "", count: maxCol + 1)
        for c in cells where c.col >= 0 && c.col <= maxCol { row[c.col] = c.value }
        return row
    }

    /// Column letters from a cell reference ("B7" → 1, "AA1" → 26).
    static func columnIndex(fromRef ref: String) -> Int {
        var n = 0
        for ch in ref {
            guard let a = ch.asciiValue, a >= 65, a <= 90 else { break }
            n = n * 26 + Int(a - 64)
        }
        return max(0, n - 1)
    }
}
