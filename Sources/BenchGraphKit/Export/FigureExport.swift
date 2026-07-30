import Foundation

/// One place that turns a renderer-agnostic figure description into bytes for a
/// chosen file format. Both the CLI and the GUI use this so a figure exports
/// identically regardless of entry point. The format is selected by file
/// extension: svg (vector text), pdf (vector), png/tiff (raster). A `Theme`
/// chooses the palette and fonts and is shared across all formats.
public enum FigureExport {

    public enum Request: Sendable {
        case bars(title: String, yLabel: String, groups: [SVGRenderer.BarGroup], brackets: [BarBracket])
        case box(title: String, yLabel: String, groups: [SVGRenderer.BoxGroup], brackets: [BarBracket])
        case violin(title: String, yLabel: String, groups: [SVGRenderer.ViolinGroup], brackets: [BarBracket])
        case scatter(title: String, xLabel: String, yLabel: String,
                     series: [SVGRenderer.Series], curve: [(x: Double, y: Double)]?, logX: Bool)

        /// The figure's title, regardless of chart type.
        public var title: String {
            switch self {
            case let .bars(t, _, _, _), let .box(t, _, _, _), let .violin(t, _, _, _):
                return t
            case let .scatter(t, _, _, _, _, _):
                return t
            }
        }
    }

    /// File extensions this exporter understands.
    public static let supportedExtensions = ["svg", "pdf", "png", "tiff"]

    /// Render `request` to data for the given file extension, or nil if the
    /// extension is unsupported or rendering fails.
    public static func data(_ request: Request, pathExtension rawExt: String, theme: Theme = .default) -> Data? {
        let ext = rawExt.lowercased()
        switch ext {
        case "svg":
            let r = SVGRenderer(theme: theme)
            let svg: String
            switch request {
            case let .bars(title, yLabel, groups, brackets):
                svg = r.barChart(title: title, yLabel: yLabel, groups: groups, brackets: brackets)
            case let .box(title, yLabel, groups, brackets):
                svg = r.boxPlot(title: title, yLabel: yLabel, groups: groups, brackets: brackets)
            case let .violin(title, yLabel, groups, brackets):
                svg = r.violinPlot(title: title, yLabel: yLabel, groups: groups, brackets: brackets)
            case let .scatter(title, xLabel, yLabel, series, curve, logX):
                svg = r.scatter(title: title, xLabel: xLabel, yLabel: yLabel,
                                series: series, curve: curve, logX: logX)
            }
            return svg.data(using: .utf8)
        case "pdf", "png", "tiff":
            let fmt: CGChartRenderer.Format = ext == "pdf" ? .pdf : (ext == "png" ? .png : .tiff)
            let r = CGChartRenderer(theme: theme)
            switch request {
            case let .bars(title, yLabel, groups, brackets):
                return r.barChart(format: fmt, title: title, yLabel: yLabel, groups: groups, brackets: brackets)
            case let .box(title, yLabel, groups, brackets):
                return r.boxPlot(format: fmt, title: title, yLabel: yLabel, groups: groups, brackets: brackets)
            case let .violin(title, yLabel, groups, brackets):
                return r.violinPlot(format: fmt, title: title, yLabel: yLabel, groups: groups, brackets: brackets)
            case let .scatter(title, xLabel, yLabel, series, curve, logX):
                return r.scatter(format: fmt, title: title, xLabel: xLabel, yLabel: yLabel,
                                 series: series, curve: curve, logX: logX)
            }
        default:
            return nil
        }
    }
}
