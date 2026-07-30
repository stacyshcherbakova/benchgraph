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

    /// One box-and-whisker group: a label and its precomputed `BoxStats`.
    public struct BoxGroup: Sendable {
        public let label: String
        public let stats: BoxStats
        public init(label: String, stats: BoxStats) {
            self.label = label
            self.stats = stats
        }
    }

    /// One violin group: a kernel-density profile plus box stats for the
    /// median/quartile overlay drawn inside the violin.
    public struct ViolinGroup: Sendable {
        public let label: String
        public let density: [KernelDensity.Sample]
        public let stats: BoxStats
        public init(label: String, density: [KernelDensity.Sample], stats: BoxStats) {
            self.label = label
            self.density = density
            self.stats = stats
        }
    }

    public let width: Double
    public let height: Double
    public let theme: Theme
    private let margin = (top: 30.0, right: 30.0, bottom: 55.0, left: 70.0)
    /// Vertical spacing between stacked significance brackets, in points.
    private let bracketStep = 16.0

    public init(width: Double = 520, height: Double = 380, theme: Theme = .default) {
        self.width = width
        self.height = height
        self.theme = theme
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
            body += "  <path d=\"\(d)\" fill=\"none\" stroke=\"\(theme.curveColor)\" stroke-width=\"2\"/>\n"
        }

        for (si, s) in series.enumerated() {
            let color = s.color == "#2C6FBB" ? theme.color(at: si) : s.color
            for p in s.points {
                let px = xScale.map(logX ? log10(Swift.max(p.x, 1e-12)) : p.x)
                let py = yScale.map(p.y)
                body += "  <circle cx=\"\(fmt(px))\" cy=\"\(fmt(py))\" r=\"4\" fill=\"\(color)\" stroke=\"\(theme.backgroundColor)\" stroke-width=\"1\"/>\n"
            }
        }
        return document(body)
    }

    // MARK: - Bar chart with error bars

    public func barChart(
        title: String,
        yLabel: String,
        groups: [BarGroup],
        brackets: [BarBracket] = []
    ) -> String {
        guard !groups.isEmpty else { return emptyDocument(title: title) }
        let maxValue = groups.map { $0.value + $0.error }.max() ?? 1
        let yMax = maxValue > 0 ? maxValue * 1.1 : 1
        let laid = BracketLayout.assignLevels(brackets)
        let yScale = categoryYScale(domainMin: 0, domainMax: yMax, brackets: laid)

        var body = title.isEmpty ? "" : titleElement(title)
        body += yAxis(label: yLabel, scale: yScale)
        body += "  <line x1=\"\(fmt(margin.left))\" y1=\"\(fmt(margin.top + plotHeight))\" x2=\"\(fmt(margin.left + plotWidth))\" y2=\"\(fmt(margin.top + plotHeight))\" stroke=\"\(theme.axisColor)\" stroke-width=\"1\"/>\n"

        let slot = plotWidth / Double(groups.count)
        let barWidth = slot * 0.6
        for (i, g) in groups.enumerated() {
            let cx = slotCenter(i, slot: slot)
            let barX = cx - barWidth / 2
            let barY = yScale.map(g.value)
            let barH = (margin.top + plotHeight) - barY
            let fill = g.color == "#2C6FBB" ? theme.primaryColor : g.color
            body += "  <rect x=\"\(fmt(barX))\" y=\"\(fmt(barY))\" width=\"\(fmt(barWidth))\" height=\"\(fmt(barH))\" fill=\"\(fill)\"/>\n"
            if g.error > 0 {
                let top = yScale.map(g.value + g.error)
                let bottom = yScale.map(g.value - g.error)
                body += line(cx, top, cx, bottom, width: 1.5)
                body += line(cx - 6, top, cx + 6, top, width: 1.5)
            }
            body += categoryLabel(g.label, cx: cx)
        }

        body += bracketLayer(laid, slot: slot, count: groups.count) { i in
            yScale.map(groups[i].value + groups[i].error)
        }
        return document(body)
    }

    // MARK: - Box-and-whisker

    public func boxPlot(
        title: String,
        yLabel: String,
        groups: [BoxGroup],
        brackets: [BarBracket] = []
    ) -> String {
        guard !groups.isEmpty else { return emptyDocument(title: title) }
        let los = groups.map { $0.stats.displayRange.lo }
        let his = groups.map { $0.stats.displayRange.hi }
        guard let lo = los.min(), let hi = his.max(), lo.isFinite, hi.isFinite else {
            return emptyDocument(title: title)
        }
        let (dMin, dMax) = paddedDomain(lo, hi)
        let laid = BracketLayout.assignLevels(brackets)
        let yScale = categoryYScale(domainMin: dMin, domainMax: dMax, brackets: laid)

        var body = title.isEmpty ? "" : titleElement(title)
        body += yAxis(label: yLabel, scale: yScale)
        body += baseline()

        let slot = plotWidth / Double(groups.count)
        let boxWidth = slot * 0.5
        for (i, g) in groups.enumerated() {
            let cx = slotCenter(i, slot: slot)
            let s = g.stats
            let color = theme.color(at: i)
            let yQ1 = yScale.map(s.q1), yQ3 = yScale.map(s.q3)
            let yMed = yScale.map(s.median)
            let yLow = yScale.map(s.lowerWhisker), yHigh = yScale.map(s.upperWhisker)

            // Whisker stem + caps.
            body += line(cx, yLow, cx, yQ1, width: 1)
            body += line(cx, yQ3, cx, yHigh, width: 1)
            body += line(cx - boxWidth / 4, yHigh, cx + boxWidth / 4, yHigh, width: 1)
            body += line(cx - boxWidth / 4, yLow, cx + boxWidth / 4, yLow, width: 1)
            // Box (IQR).
            body += "  <rect x=\"\(fmt(cx - boxWidth / 2))\" y=\"\(fmt(yQ3))\" width=\"\(fmt(boxWidth))\" height=\"\(fmt(yQ1 - yQ3))\" fill=\"\(color)\" fill-opacity=\"0.65\" stroke=\"\(theme.axisColor)\" stroke-width=\"1\"/>\n"
            // Median line.
            body += line(cx - boxWidth / 2, yMed, cx + boxWidth / 2, yMed, width: 1.8)
            // Mean marker (small "+").
            if s.mean.isFinite {
                let yMean = yScale.map(s.mean)
                body += line(cx - 3, yMean, cx + 3, yMean, width: 1, color: theme.textColor)
                body += line(cx, yMean - 3, cx, yMean + 3, width: 1, color: theme.textColor)
            }
            // Outliers.
            for o in s.outliers {
                body += "  <circle cx=\"\(fmt(cx))\" cy=\"\(fmt(yScale.map(o)))\" r=\"2.5\" fill=\"none\" stroke=\"\(theme.axisColor)\" stroke-width=\"1\"/>\n"
            }
            body += categoryLabel(g.label, cx: cx)
        }

        body += bracketLayer(laid, slot: slot, count: groups.count) { i in
            yScale.map(groups[i].stats.displayRange.hi)
        }
        return document(body)
    }

    // MARK: - Violin

    public func violinPlot(
        title: String,
        yLabel: String,
        groups: [ViolinGroup],
        brackets: [BarBracket] = []
    ) -> String {
        let drawable = groups.filter { $0.density.count > 1 }
        guard !drawable.isEmpty else {
            // No density to draw (tiny/degenerate samples): fall back to a box.
            return boxPlot(title: title, yLabel: yLabel,
                           groups: groups.map { BoxGroup(label: $0.label, stats: $0.stats) },
                           brackets: brackets)
        }
        let values = groups.flatMap { $0.density.map(\.value) }
        guard let lo = values.min(), let hi = values.max() else { return emptyDocument(title: title) }
        let (dMin, dMax) = paddedDomain(lo, hi)
        let laid = BracketLayout.assignLevels(brackets)
        let yScale = categoryYScale(domainMin: dMin, domainMax: dMax, brackets: laid)

        var body = title.isEmpty ? "" : titleElement(title)
        body += yAxis(label: yLabel, scale: yScale)
        body += baseline()

        let slot = plotWidth / Double(groups.count)
        let maxHalf = slot * 0.42
        for (i, g) in groups.enumerated() {
            let cx = slotCenter(i, slot: slot)
            let color = theme.color(at: i)
            guard g.density.count > 1, let peak = g.density.map(\.density).max(), peak > 0 else {
                continue
            }
            // Symmetric outline: up the right edge, back down the left edge.
            let right = g.density.map { (x: cx + ($0.density / peak) * maxHalf, y: yScale.map($0.value)) }
            let left = g.density.reversed().map { (x: cx - ($0.density / peak) * maxHalf, y: yScale.map($0.value)) }
            let path = (right + left).enumerated().map { idx, p in
                "\(idx == 0 ? "M" : "L")\(fmt(p.x)),\(fmt(p.y))"
            }.joined(separator: " ") + " Z"
            body += "  <path d=\"\(path)\" fill=\"\(color)\" fill-opacity=\"0.55\" stroke=\"\(theme.axisColor)\" stroke-width=\"1\"/>\n"

            // Inner box overlay (IQR bar + median dot).
            let s = g.stats
            if s.q1.isFinite && s.q3.isFinite {
                body += line(cx, yScale.map(s.lowerWhisker), cx, yScale.map(s.upperWhisker), width: 1)
                body += line(cx, yScale.map(s.q1), cx, yScale.map(s.q3), width: 4, color: theme.textColor)
                body += "  <circle cx=\"\(fmt(cx))\" cy=\"\(fmt(yScale.map(s.median)))\" r=\"2.4\" fill=\"\(theme.backgroundColor)\"/>\n"
            }
            body += categoryLabel(g.label, cx: cx)
        }

        body += bracketLayer(laid, slot: slot, count: groups.count) { i in
            yScale.map(groups[i].density.map(\.value).max() ?? 0)
        }
        return document(body)
    }

    // MARK: - Dispatch

    /// Render any figure request to a standalone SVG document. Used by the
    /// multi-panel compositor so every panel goes through the same code paths as
    /// a single-figure export.
    public func render(_ request: FigureExport.Request) -> String {
        switch request {
        case let .bars(title, yLabel, groups, brackets):
            return barChart(title: title, yLabel: yLabel, groups: groups, brackets: brackets)
        case let .box(title, yLabel, groups, brackets):
            return boxPlot(title: title, yLabel: yLabel, groups: groups, brackets: brackets)
        case let .violin(title, yLabel, groups, brackets):
            return violinPlot(title: title, yLabel: yLabel, groups: groups, brackets: brackets)
        case let .scatter(title, xLabel, yLabel, series, curve, logX):
            return scatter(title: title, xLabel: xLabel, yLabel: yLabel, series: series, curve: curve, logX: logX)
        }
    }

    // MARK: - Shared category-plot helpers

    /// A y scale that reserves a band at the top for significance brackets so
    /// they never collide with the tallest element.
    private func categoryYScale(domainMin: Double, domainMax: Double, brackets: [BarBracket]) -> Scale {
        let levelCount = (brackets.map(\.level).max() ?? -1) + 1
        let band = brackets.isEmpty ? 0 : Double(levelCount) * bracketStep + 14
        return Scale(domainMin: domainMin, domainMax: domainMax,
                     rangeMin: margin.top + plotHeight, rangeMax: margin.top + band)
    }

    private func slotCenter(_ i: Int, slot: Double) -> Double { margin.left + slot * (Double(i) + 0.5) }

    private func baseline() -> String {
        line(margin.left, margin.top + plotHeight, margin.left + plotWidth, margin.top + plotHeight, width: 1)
    }

    private func categoryLabel(_ label: String, cx: Double) -> String {
        "  <text x=\"\(fmt(cx))\" y=\"\(fmt(margin.top + plotHeight + 18))\" font-size=\"12\" text-anchor=\"middle\" fill=\"\(theme.axisColor)\">\(escape(label))</text>\n"
    }

    /// Significance brackets above the elements. `topY(i)` returns the y (px) of
    /// the top of element i; smaller y is higher on the page.
    private func bracketLayer(_ laid: [BarBracket], slot: Double, count: Int, topY: (Int) -> Double) -> String {
        var body = ""
        for b in laid where (0..<count).contains(b.lo) && (0..<count).contains(b.hi) {
            let cxA = slotCenter(b.fromIndex, slot: slot)
            let cxB = slotCenter(b.toIndex, slot: slot)
            let y = Swift.min(topY(b.fromIndex), topY(b.toIndex)) - 10 - Double(b.level) * bracketStep
            let drop = 5.0
            body += line(cxA, y, cxB, y, width: 1)
            body += line(cxA, y, cxA, y + drop, width: 1)
            body += line(cxB, y, cxB, y + drop, width: 1)
            if !b.label.isEmpty {
                body += "  <text x=\"\(fmt((cxA + cxB) / 2))\" y=\"\(fmt(y - 3))\" font-size=\"13\" text-anchor=\"middle\" fill=\"\(theme.textColor)\">\(escape(b.label))</text>\n"
            }
        }
        return body
    }

    private func line(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double,
                      width: Double, color: String? = nil) -> String {
        "  <line x1=\"\(fmt(x1))\" y1=\"\(fmt(y1))\" x2=\"\(fmt(x2))\" y2=\"\(fmt(y2))\" stroke=\"\(color ?? theme.axisColor)\" stroke-width=\"\(fmt(width))\"/>\n"
    }

    /// A modest symmetric pad around a data range so glyphs aren't clipped.
    private func paddedDomain(_ lo: Double, _ hi: Double) -> (Double, Double) {
        if lo == hi { let pad = Swift.abs(lo) * 0.1 + 1; return (lo - pad, hi + pad) }
        let pad = (hi - lo) * 0.08
        return (lo - pad, hi + pad)
    }

    // MARK: - Shared scaffolding

    private struct Scale {
        let domainMin, domainMax, rangeMin, rangeMax: Double
        func map(_ v: Double) -> Double {
            if domainMax == domainMin { return (rangeMin + rangeMax) / 2 }
            let t = (v - domainMin) / (domainMax - domainMin)
            return rangeMin + t * (rangeMax - rangeMin)
        }
        /// "Nice" round tick values within the domain (see `AxisTicks`).
        func ticks(_ count: Int = 5) -> [Double] {
            AxisTicks.nice(domainMin, domainMax, count: count)
        }
    }

    private func axes(xLabel: String, yLabel: String, title: String, xScale: Scale, yScale: Scale, logX: Bool) -> String {
        var s = title.isEmpty ? "" : titleElement(title)
        let x0 = margin.left, x1 = margin.left + plotWidth
        let yBottom = margin.top + plotHeight
        s += line(x0, yBottom, x1, yBottom, width: 1)
        s += line(x0, margin.top, x0, yBottom, width: 1)
        for t in xScale.ticks() {
            let px = xScale.map(t)
            let label = logX ? fmtTick(pow(10, t)) : fmtTick(t)
            s += "  <line x1=\"\(fmt(px))\" y1=\"\(fmt(yBottom))\" x2=\"\(fmt(px))\" y2=\"\(fmt(yBottom + 5))\" stroke=\"\(theme.axisColor)\"/>\n"
            s += "  <text x=\"\(fmt(px))\" y=\"\(fmt(yBottom + 18))\" font-size=\"11\" text-anchor=\"middle\" fill=\"\(theme.axisColor)\">\(label)</text>\n"
        }
        s += yAxis(label: yLabel, scale: yScale)
        s += "  <text x=\"\(fmt(margin.left + plotWidth / 2))\" y=\"\(fmt(height - 12))\" font-size=\"13\" text-anchor=\"middle\" fill=\"\(theme.axisColor)\">\(escape(xLabel))</text>\n"
        return s
    }

    private func yAxis(label: String, scale: Scale) -> String {
        var s = ""
        let x0 = margin.left
        for t in scale.ticks() {
            let py = scale.map(t)
            s += "  <line x1=\"\(fmt(x0 - 5))\" y1=\"\(fmt(py))\" x2=\"\(fmt(x0))\" y2=\"\(fmt(py))\" stroke=\"\(theme.axisColor)\"/>\n"
            s += "  <text x=\"\(fmt(x0 - 9))\" y=\"\(fmt(py + 4))\" font-size=\"11\" text-anchor=\"end\" fill=\"\(theme.axisColor)\">\(fmtTick(t))</text>\n"
        }
        let cy = margin.top + plotHeight / 2
        s += "  <text x=\"18\" y=\"\(fmt(cy))\" font-size=\"13\" text-anchor=\"middle\" fill=\"\(theme.axisColor)\" transform=\"rotate(-90 18 \(fmt(cy)))\">\(escape(label))</text>\n"
        return s
    }

    private func titleElement(_ title: String) -> String {
        "  <text x=\"\(fmt(width / 2))\" y=\"20\" font-size=\"15\" font-weight=\"bold\" text-anchor=\"middle\" fill=\"\(theme.textColor)\">\(escape(title))</text>\n"
    }

    private func document(_ body: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="\(fmt(width))" height="\(fmt(height))" viewBox="0 0 \(fmt(width)) \(fmt(height))" font-family="\(theme.fontFamily)">
          <rect width="\(fmt(width))" height="\(fmt(height))" fill="\(theme.backgroundColor)"/>
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
