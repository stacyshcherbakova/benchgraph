import Foundation

/// A minimal, deterministic vector renderer that emits publication-style SVG.
///
/// SVG is chosen for the MVP because it is text, so it can be diffed and
/// snapshot-tested (the roadmap's validation plan asks for "snapshot test
/// exported SVG structure"), and it converts cleanly to PDF/TIFF downstream.
public struct SVGRenderer {

    public struct Series: Sendable {
        public let name: String
        public let points: [(x: Double, y: Double)]
        public let color: String
        public init(name: String, points: [(x: Double, y: Double)], color: String = "#2C6FBB") {
            self.name = name
            self.points = points
            self.color = color
        }
    }

    public struct BarGroup: Sendable {
        public let label: String
        public let value: Double
        public let error: Double      // half-length of the error bar (e.g. SEM)
        public let color: String
        public init(label: String, value: Double, error: Double, color: String = "#2C6FBB") {
            self.label = label
            self.value = value
            self.error = error
            self.color = color
        }
    }

    public let width: Double
    public let height: Double
    private let margin = (top: 30.0, right: 30.0, bottom: 55.0, left: 70.0)

    public init(width: Double = 520, height: Double = 380) {
        self.width = width
        self.height = height
    }

    private var plotWidth: Double { width - margin.left - margin.right }
    private var plotHeight: Double { height - margin.top - margin.bottom }

    // MARK: - Scatter / XY with optional fitted curve

    /// Render an XY scatter, optionally overlaying a fitted curve (e.g. 4PL or
    /// a regression line) and using a log10 X axis for dose-response.
    public func scatter(
        title: String,
        xLabel: String,
        yLabel: String,
        series: [Series],
        curve: [(x: Double, y: Double)]? = nil,
        logX: Bool = false
    ) -> String {
        let allPoints = series.flatMap { $0.points } + (curve ?? [])
        guard !allPoints.isEmpty else { return emptyDocument(title: title) }

        let xs = allPoints.map { logX ? log10(Swift.max($0.x, 1e-12)) : $0.x }
        let ys = allPoints.map { $0.y }
        let xScale = Scale(domainMin: xs.min()!, domainMax: xs.max()!, rangeMin: margin.left, rangeMax: margin.left + plotWidth)
        let yScale = Scale(domainMin: ys.min()!, domainMax: ys.max()!, rangeMin: margin.top + plotHeight, rangeMax: margin.top)

        var body = axes(xLabel: xLabel, yLabel: yLabel, title: title, xScale: xScale, yScale: yScale, logX: logX)

        if let curve, curve.count > 1 {
            let d = curve.enumerated().map { i, p -> String in
                let px = xScale.map(logX ? log10(Swift.max(p.x, 1e-12)) : p.x)
                let py = yScale.map(p.y)
                return "\(i == 0 ? "M" : "L")\(fmt(px)),\(fmt(py))"
            }.joined(separator: " ")
            body += "  <path d=\"\(d)\" fill=\"none\" stroke=\"#D1495B\" stroke-width=\"2\"/>\n"
        }

        for s in series {
            for p in s.points {
                let px = xScale.map(logX ? log10(Swift.max(p.x, 1e-12)) : p.x)
                let py = yScale.map(p.y)
                body += "  <circle cx=\"\(fmt(px))\" cy=\"\(fmt(py))\" r=\"4\" fill=\"\(s.color)\" stroke=\"#ffffff\" stroke-width=\"1\"/>\n"
            }
        }
        return document(body)
    }

    // MARK: - Bar chart with error bars

    public func barChart(
        title: String,
        yLabel: String,
        groups: [BarGroup]
    ) -> String {
        guard !groups.isEmpty else { return emptyDocument(title: title) }
        let maxValue = groups.map { $0.value + $0.error }.max() ?? 1
        let yMax = maxValue > 0 ? maxValue * 1.1 : 1
        let yScale = Scale(domainMin: 0, domainMax: yMax, rangeMin: margin.top + plotHeight, rangeMax: margin.top)

        var body = title.isEmpty ? "" : titleElement(title)
        body += yAxis(label: yLabel, scale: yScale)
        body += "  <line x1=\"\(fmt(margin.left))\" y1=\"\(fmt(margin.top + plotHeight))\" x2=\"\(fmt(margin.left + plotWidth))\" y2=\"\(fmt(margin.top + plotHeight))\" stroke=\"#333\" stroke-width=\"1\"/>\n"

        let slot = plotWidth / Double(groups.count)
        let barWidth = slot * 0.6
        for (i, g) in groups.enumerated() {
            let cx = margin.left + slot * (Double(i) + 0.5)
            let barX = cx - barWidth / 2
            let barY = yScale.map(g.value)
            let barH = (margin.top + plotHeight) - barY
            body += "  <rect x=\"\(fmt(barX))\" y=\"\(fmt(barY))\" width=\"\(fmt(barWidth))\" height=\"\(fmt(barH))\" fill=\"\(g.color)\"/>\n"
            // Error bar.
            if g.error > 0 {
                let top = yScale.map(g.value + g.error)
                let bottom = yScale.map(g.value - g.error)
                body += "  <line x1=\"\(fmt(cx))\" y1=\"\(fmt(top))\" x2=\"\(fmt(cx))\" y2=\"\(fmt(bottom))\" stroke=\"#333\" stroke-width=\"1.5\"/>\n"
                body += "  <line x1=\"\(fmt(cx - 6))\" y1=\"\(fmt(top))\" x2=\"\(fmt(cx + 6))\" y2=\"\(fmt(top))\" stroke=\"#333\" stroke-width=\"1.5\"/>\n"
            }
            // Category label.
            body += "  <text x=\"\(fmt(cx))\" y=\"\(fmt(margin.top + plotHeight + 18))\" font-size=\"12\" text-anchor=\"middle\" fill=\"#333\">\(escape(g.label))</text>\n"
        }
        return document(body)
    }

    // MARK: - Shared scaffolding

    private struct Scale {
        let domainMin, domainMax, rangeMin, rangeMax: Double
        func map(_ v: Double) -> Double {
            if domainMax == domainMin { return (rangeMin + rangeMax) / 2 }
            let t = (v - domainMin) / (domainMax - domainMin)
            return rangeMin + t * (rangeMax - rangeMin)
        }
        /// "Nice" tick values across the domain.
        func ticks(_ count: Int = 5) -> [Double] {
            guard domainMax > domainMin else { return [domainMin] }
            let step = (domainMax - domainMin) / Double(count)
            return (0...count).map { domainMin + Double($0) * step }
        }
    }

    private func axes(xLabel: String, yLabel: String, title: String, xScale: Scale, yScale: Scale, logX: Bool) -> String {
        var s = title.isEmpty ? "" : titleElement(title)
        // Axes lines.
        let x0 = margin.left, x1 = margin.left + plotWidth
        let yBottom = margin.top + plotHeight
        s += "  <line x1=\"\(fmt(x0))\" y1=\"\(fmt(yBottom))\" x2=\"\(fmt(x1))\" y2=\"\(fmt(yBottom))\" stroke=\"#333\" stroke-width=\"1\"/>\n"
        s += "  <line x1=\"\(fmt(x0))\" y1=\"\(fmt(margin.top))\" x2=\"\(fmt(x0))\" y2=\"\(fmt(yBottom))\" stroke=\"#333\" stroke-width=\"1\"/>\n"
        // X ticks.
        for t in xScale.ticks() {
            let px = xScale.map(t)
            let label = logX ? fmtTick(pow(10, t)) : fmtTick(t)
            s += "  <line x1=\"\(fmt(px))\" y1=\"\(fmt(yBottom))\" x2=\"\(fmt(px))\" y2=\"\(fmt(yBottom + 5))\" stroke=\"#333\"/>\n"
            s += "  <text x=\"\(fmt(px))\" y=\"\(fmt(yBottom + 18))\" font-size=\"11\" text-anchor=\"middle\" fill=\"#333\">\(label)</text>\n"
        }
        s += yAxis(label: yLabel, scale: yScale)
        // X axis label.
        s += "  <text x=\"\(fmt(margin.left + plotWidth / 2))\" y=\"\(fmt(height - 12))\" font-size=\"13\" text-anchor=\"middle\" fill=\"#333\">\(escape(xLabel))</text>\n"
        return s
    }

    private func yAxis(label: String, scale: Scale) -> String {
        var s = ""
        let x0 = margin.left
        for t in scale.ticks() {
            let py = scale.map(t)
            s += "  <line x1=\"\(fmt(x0 - 5))\" y1=\"\(fmt(py))\" x2=\"\(fmt(x0))\" y2=\"\(fmt(py))\" stroke=\"#333\"/>\n"
            s += "  <text x=\"\(fmt(x0 - 9))\" y=\"\(fmt(py + 4))\" font-size=\"11\" text-anchor=\"end\" fill=\"#333\">\(fmtTick(t))</text>\n"
        }
        let cy = margin.top + plotHeight / 2
        s += "  <text x=\"18\" y=\"\(fmt(cy))\" font-size=\"13\" text-anchor=\"middle\" fill=\"#333\" transform=\"rotate(-90 18 \(fmt(cy)))\">\(escape(label))</text>\n"
        return s
    }

    private func titleElement(_ title: String) -> String {
        "  <text x=\"\(fmt(width / 2))\" y=\"20\" font-size=\"15\" font-weight=\"bold\" text-anchor=\"middle\" fill=\"#222\">\(escape(title))</text>\n"
    }

    private func document(_ body: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="\(fmt(width))" height="\(fmt(height))" viewBox="0 0 \(fmt(width)) \(fmt(height))" font-family="Helvetica, Arial, sans-serif">
          <rect width="\(fmt(width))" height="\(fmt(height))" fill="#ffffff"/>
        \(body)</svg>
        """
    }

    private func emptyDocument(title: String) -> String {
        document(titleElement(title) + "  <text x=\"\(fmt(width / 2))\" y=\"\(fmt(height / 2))\" font-size=\"12\" text-anchor=\"middle\" fill=\"#999\">No data</text>\n")
    }

    // MARK: - Formatting

    /// Fixed-precision coordinate formatting keeps output byte-stable for tests.
    private func fmt(_ v: Double) -> String { String(format: "%.2f", v) }

    private func fmtTick(_ v: Double) -> String {
        if v == 0 { return "0" }
        let a = Swift.abs(v)
        if a >= 1000 || a < 0.01 { return String(format: "%.2g", v) }
        if v == v.rounded() { return String(format: "%.0f", v) }
        return String(format: "%.2f", v)
    }

    private func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }
}
