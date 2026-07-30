import Foundation

/// Composes several figures into one multi-panel publication figure with
/// A/B/C… panel labels, exported as a single SVG / PDF / PNG / TIFF.
///
/// Each panel is rendered through the same `SVGRenderer` / `CGChartRenderer`
/// code paths as a standalone figure, then placed into a grid cell. This is the
/// roadmap's "simple multi-panel layout with labels A/B/C" and completes the
/// multi-panel publication-figure workflow.
public enum FigureLayout {

    /// One panel: a figure request plus its label (e.g. "A").
    public struct Panel: Sendable {
        public let request: FigureExport.Request
        public let label: String
        public init(request: FigureExport.Request, label: String) {
            self.request = request
            self.label = label
        }
    }

    /// Grid geometry for the composed figure. Sizes are in points; the CG
    /// renderer rasterizes at @2x, and the SVG scales cleanly to any size.
    public struct Spec: Sendable {
        public var columns: Int
        public var panelWidth: Double
        public var panelHeight: Double
        public var gap: Double
        public var padding: Double
        /// Vertical space reserved above each panel for its label.
        public var labelBand: Double

        public init(columns: Int = 2, panelWidth: Double = 460, panelHeight: Double = 340,
                    gap: Double = 26, padding: Double = 26, labelBand: Double = 24) {
            self.columns = max(1, columns)
            self.panelWidth = panelWidth
            self.panelHeight = panelHeight
            self.gap = gap
            self.padding = padding
            self.labelBand = labelBand
        }

        var cellHeight: Double { labelBand + panelHeight }

        public func rows(panelCount: Int) -> Int {
            max(1, Int((Double(panelCount) / Double(columns)).rounded(.up)))
        }

        /// Total canvas size for `panelCount` panels.
        public func totalSize(panelCount: Int) -> (w: Double, h: Double) {
            let cols = Double(min(columns, max(panelCount, 1)))
            let rws = Double(rows(panelCount: panelCount))
            let w = padding * 2 + cols * panelWidth + (cols - 1) * gap
            let h = padding * 2 + rws * cellHeight + (rws - 1) * gap
            return (w, h)
        }

        /// Top-left cell rectangle (SVG coordinate convention) for panel `index`.
        public func cellRect(index: Int) -> CGRect {
            let col = index % columns
            let row = index / columns
            let x = padding + Double(col) * (panelWidth + gap)
            let y = padding + Double(row) * (cellHeight + gap)
            return CGRect(x: x, y: y, width: panelWidth, height: cellHeight)
        }
    }

    /// Default A, B, C … Z, AA, AB … labels for `count` panels.
    public static func defaultLabels(count: Int) -> [String] {
        (0..<count).map { i in
            var n = i, s = ""
            repeat {
                s = String(UnicodeScalar(UInt8(65 + n % 26))) + s
                n = n / 26 - 1
            } while n >= 0
            return s
        }
    }

    /// Render the composed multi-panel figure to bytes for the given file
    /// extension (svg / pdf / png / tiff), or nil if the extension is
    /// unsupported or there are no panels.
    public static func data(_ panels: [Panel], pathExtension rawExt: String,
                            theme: Theme = .default, layout: Spec = Spec()) -> Data? {
        guard !panels.isEmpty else { return nil }
        let ext = rawExt.lowercased()
        switch ext {
        case "svg":
            return svg(panels, theme: theme, layout: layout).data(using: .utf8)
        case "pdf", "png", "tiff":
            let fmt: CGChartRenderer.Format = ext == "pdf" ? .pdf : (ext == "png" ? .png : .tiff)
            let total = layout.totalSize(panelCount: panels.count)
            return CGChartRenderer(width: total.w, height: total.h, theme: theme)
                .composite(format: fmt, panels: panels, layout: layout)
        default:
            return nil
        }
    }

    // MARK: - SVG composition

    private static func svg(_ panels: [Panel], theme: Theme, layout: Spec) -> String {
        let total = layout.totalSize(panelCount: panels.count)
        func f(_ v: Double) -> String { String(format: "%.2f", v) }

        var body = "  <rect width=\"\(f(total.w))\" height=\"\(f(total.h))\" fill=\"\(theme.backgroundColor)\"/>\n"
        let renderer = SVGRenderer(width: layout.panelWidth, height: layout.panelHeight, theme: theme)

        for (i, panel) in panels.enumerated() {
            let cell = layout.cellRect(index: i)
            let panelX = cell.minX
            let panelY = cell.minY + layout.labelBand

            // Nest the panel's standalone SVG as a positioned sub-viewport.
            var inner = renderer.render(panel.request)
            if let svgStart = inner.range(of: "<svg ") {
                inner = String(inner[svgStart.lowerBound...])
            }
            if let opening = inner.range(of: "<svg ") {
                inner.replaceSubrange(opening, with: "<svg x=\"\(f(panelX))\" y=\"\(f(panelY))\" ")
            }
            body += inner
            body += "\n"

            if !panel.label.isEmpty {
                let lx = cell.minX + 2
                let ly = cell.minY + layout.labelBand - 7
                body += "  <text x=\"\(f(lx))\" y=\"\(f(ly))\" font-size=\"16\" font-weight=\"bold\" text-anchor=\"start\" fill=\"\(theme.textColor)\">\(escape(panel.label))</text>\n"
            }
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="\(f(total.w))" height="\(f(total.h))" viewBox="0 0 \(f(total.w)) \(f(total.h))" font-family="\(theme.fontFamily)">
        \(body)</svg>
        """
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }
}
