import Foundation

/// A BenchGraph project file: an explicit, versioned, human-inspectable JSON
/// document holding the data and analysis specification, so a project reopens
/// exactly as it was saved. The roadmap insists analysis options not be hidden
/// in opaque blobs — this is plain JSON with named fields.
public struct ProjectDocument: Codable, Equatable {

    /// Current on-disk schema version. Bump when the shape changes.
    public static let currentVersion = 1

    /// Conventional file extension for project files.
    public static let fileExtension = "benchgraph"

    public var version: Int
    /// How the data columns should be interpreted.
    public var tableKind: TableKind
    /// The source data exactly as entered/pasted (CSV/TSV text).
    public var data: String
    /// Whether the first row is a header.
    public var hasHeader: Bool
    /// The selected analysis, stored by a stable identifier (not its display
    /// label), so re-wording the UI label does not break older project files.
    public var analysisName: String
    /// Engine version that wrote the file, for provenance.
    public var savedWithEngine: String

    public init(
        tableKind: TableKind,
        data: String,
        hasHeader: Bool,
        analysisName: String,
        version: Int = ProjectDocument.currentVersion,
        savedWithEngine: String = BenchGraph.version
    ) {
        self.version = version
        self.tableKind = tableKind
        self.data = data
        self.hasHeader = hasHeader
        self.analysisName = analysisName
        self.savedWithEngine = savedWithEngine
    }

    public enum LoadError: Error, Equatable {
        case unreadable
        case malformed(String)
        case unsupportedVersion(Int)
    }

    /// Encode to pretty, key-sorted JSON (stable output for diffing).
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public func save(to url: URL) throws {
        try encoded().write(to: url, options: .atomic)
    }

    /// Decode from JSON, rejecting versions newer than this build understands.
    public static func decoded(from data: Data) throws -> ProjectDocument {
        let doc: ProjectDocument
        do {
            doc = try JSONDecoder().decode(ProjectDocument.self, from: data)
        } catch {
            throw LoadError.malformed(error.localizedDescription)
        }
        guard doc.version <= currentVersion else {
            throw LoadError.unsupportedVersion(doc.version)
        }
        return doc
    }

    public static func load(from url: URL) throws -> ProjectDocument {
        guard let data = try? Data(contentsOf: url) else { throw LoadError.unreadable }
        return try decoded(from: data)
    }
}
