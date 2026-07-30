import Foundation

/// One staged panel of a multi-panel figure, as stored in a project file.
///
/// The panel is persisted as the **rendered figure** — the exact
/// `FigureExport.Request` that was drawn — not as a recipe to re-run on load.
/// A staged panel is a snapshot of a past chart, and a figure that may already
/// be in a submitted manuscript must not silently redraw because a fit
/// tolerance or a bandwidth changed in a later build. See the spec's D5.
///
/// The manifest and source data ride along as provenance: they record how the
/// panel was produced, so it can be traced and, on request, re-derived — but
/// the drawn figure remains the source of truth.
public struct PanelRecord: Codable, Equatable, Sendable {

    /// The figure exactly as it was rendered when staged.
    public var request: FigureExport.Request
    /// Display title shown under the panel's thumbnail in the tray.
    public var title: String
    /// How this panel was produced: analysis, options, engine version, and the
    /// full result envelope. Optional so a panel is still valid without it.
    public var manifest: ExportManifest?
    /// The panel's source data (CSV text) at staging time. Panels in one figure
    /// commonly come from different datasets, so this cannot be recovered from
    /// the project's own `data` field.
    public var sourceData: String?

    public init(request: FigureExport.Request,
                title: String,
                manifest: ExportManifest? = nil,
                sourceData: String? = nil) {
        self.request = request
        self.title = title
        self.manifest = manifest
        self.sourceData = sourceData
    }
}
