import Foundation

/// One place that turns a renderer-agnostic figure description into bytes for a
/// chosen file format. Both the CLI and the GUI use this so a figure exports
/// identically regardless of entry point. The format is selected by file
/// extension: svg (vector text), pdf (vector), png/tiff (raster).
public enum FigureExport {

    public enum Request {
        case bars(title: String, yLabel: String, groups: [SVGRenderer.BarGroup], brackets: [BarBracket])
        case scatter(title: String, xLabel: String, yLabel: String,
                     series: [SVGRenderer.Series], curve: [(x: Double, y: Double)]?, logX: Bool)
    }

    /// File extensions this exporter understands.
    public static let supportedExtensions = ["svg", "pdf", "png", "tiff"]

    /// Render `request` to data for the given file extension, or nil if the
    /// extension is unsupported or rendering fails.
    public static func data(_ request: Request, pathExtension rawExt: String) -> Data? {
        let ext = rawExt.lowercased()
        switch ext {
        case "svg":
            let svg: String
            switch request {
            case let .bars(title, yLabel, groups, brackets):
                svg = SVGRenderer().barChart(title: title, yLabel: yLabel, groups: groups, brackets: brackets)
            case let .scatter(title, xLabel, yLabel, series, curve, logX):
                svg = SVGRenderer().scatter(title: title, xLabel: xLabel, yLabel: yLabel,
                                            series: series, curve: curve, logX: logX)
            }
            return svg.data(using: .utf8)
        case "pdf", "png", "tiff":
            let fmt: CGChartRenderer.Format = ext == "pdf" ? .pdf : (ext == "png" ? .png : .tiff)
            switch request {
            case let .bars(title, yLabel, groups, brackets):
                return CGChartRenderer().barChart(format: fmt, title: title, yLabel: yLabel, groups: groups, brackets: brackets)
            case let .scatter(title, xLabel, yLabel, series, curve, logX):
                return CGChartRenderer().scatter(format: fmt, title: title, xLabel: xLabel, yLabel: yLabel,
                                                 series: series, curve: curve, logX: logX)
            }
        default:
            return nil
        }
    }
}
