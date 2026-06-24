import Foundation

/// The shape of a data table, mirroring the MVP table templates: a value is
/// always organized as named columns of doubles, but the semantics differ.
public enum TableKind: String, Sendable, Codable {
    /// One group per column (e.g. Control, Treatment A, Treatment B).
    case column
    /// First column is X, remaining columns are Y (replicates or series).
    case xy
    /// Like column, but columns are organized into labeled groups.
    case grouped
}

/// A named column of observations. Missing cells are represented as `nil`
/// so analyses can report and exclude them explicitly (provenance).
public struct DataColumn: Sendable, Codable {
    public let name: String
    public let values: [Double?]

    public init(name: String, values: [Double?]) {
        self.name = name
        self.values = values
    }

    /// Non-missing values, in order.
    public var present: [Double] { values.compactMap { $0 } }

    /// Count of missing cells.
    public var missingCount: Int { values.filter { $0 == nil }.count }
}

/// An in-memory data table. This is the document model the analyses read from.
public struct DataTable: Sendable, Codable {
    public let kind: TableKind
    public let columns: [DataColumn]

    public init(kind: TableKind, columns: [DataColumn]) {
        self.kind = kind
        self.columns = columns
    }

    public var columnNames: [String] { columns.map(\.name) }

    public func column(named name: String) -> DataColumn? {
        columns.first { $0.name == name }
    }

    public func column(at index: Int) -> DataColumn? {
        guard columns.indices.contains(index) else { return nil }
        return columns[index]
    }
}
