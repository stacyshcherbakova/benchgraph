import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

/// Renders charts to raster (PNG/TIFF) and vector (PDF) formats using
/// CoreGraphics, complementing the text-based `SVGRenderer`. It reuses the
/// same `Series` / `BarGroup` / `BoxGroup` / `ViolinGroup` inputs so a figure
/// exports identically across formats. CoreGraphics uses a bottom-left origin,
/// so y increases upward here.
public struct CGChartRenderer {

    public enum Format {
        case pdf, png, tiff

        var utType: UTType {
            switch self {
            case .pdf: return .pdf
            case .png: return .png
            case .tiff: return .tiff
            }
        }
    }

    public let width: CGFloat
    public let height: CGFloat
    public let theme: Theme
    private let margin = (top: 30.0, right: 30.0, bottom: 55.0, left: 70.0)
    /// Vertical spacing between stacked significance brackets, in points.
    /// Matches `SVGRenderer.bracketStep` — see the note there. 16 put a
    /// bracket's label on top of the next level's line.
    private let bracketStep: CGFloat = 22
    private let primaryColor: CGColor
    private let curveColor: CGColor
    private let axisColor: CGColor
    private let textColor: CGColor
    private let backgroundColor: CGColor

    public init(width: CGFloat = 520, height: CGFloat = 380, theme: Theme = .default) {
        self.width = width
        self.height = height
        self.theme = theme
        self.primaryColor = CGChartRenderer.cgColor(theme.primaryColor)
        self.curveColor = CGChartRenderer.cgColor(theme.curveColor)
        self.axisColor = CGChartRenderer.cgColor(theme.axisColor)
        self.textColor = CGChartRenderer.cgColor(theme.textColor)
        self.backgroundColor = CGChartRenderer.cgColor(theme.backgroundColor)
    }

    private func paletteColor(at i: Int) -> CGColor { CGChartRenderer.cgColor(theme.color(at: i)) }

    private var plot: CGRect {
        CGRect(x: margin.left, y: margin.bottom,
               width: width - margin.left - margin.right,
               height: height - margin.top - margin.bottom)
    }

    // MARK: - Public entry points

    public func scatter(
        format: Format,
        title: String, xLabel: String, yLabel: String,
        series: [SVGRenderer.Series],
        curve: [PlotPoint]? = nil,
        logX: Bool = false
    ) -> Data? {
        render(format: format) { ctx in
            drawScatter(ctx, title: title, xLabel: xLabel, yLabel: yLabel,
                        series: series, curve: curve, logX: logX)
        }
    }

    public func barChart(
        format: Format,
        title: String, yLabel: String,
        groups: [SVGRenderer.BarGroup],
        brackets: [BarBracket] = []
    ) -> Data? {
        render(format: format) { ctx in
            drawBars(ctx, title: title, yLabel: yLabel, groups: groups, brackets: brackets)
        }
    }

    public func boxPlot(
        format: Format,
        title: String, yLabel: String,
        groups: [SVGRenderer.BoxGroup],
        brackets: [BarBracket] = []
    ) -> Data? {
        render(format: format) { ctx in
            drawBoxes(ctx, title: title, yLabel: yLabel, groups: groups, brackets: brackets)
        }
    }

    public func violinPlot(
        format: Format,
        title: String, yLabel: String,
        groups: [SVGRenderer.ViolinGroup],
        brackets: [BarBracket] = []
    ) -> Data? {
        render(format: format) { ctx in
            drawViolins(ctx, title: title, yLabel: yLabel, groups: groups, brackets: brackets)
        }
    }

    // MARK: - Dispatch + multi-panel composition

    /// Draw any figure request into an existing context at this renderer's
    /// configured size, without painting a background. The multi-panel
    /// compositor translates the context per cell and calls this.
    public func draw(_ request: FigureExport.Request, in ctx: CGContext) {
        switch request {
        case let .bars(title, yLabel, groups, brackets):
            drawBars(ctx, title: title, yLabel: yLabel, groups: groups, brackets: brackets)
        case let .box(title, yLabel, groups, brackets):
            drawBoxes(ctx, title: title, yLabel: yLabel, groups: groups, brackets: brackets)
        case let .violin(title, yLabel, groups, brackets):
            drawViolins(ctx, title: title, yLabel: yLabel, groups: groups, brackets: brackets)
        case let .scatter(title, xLabel, yLabel, series, curve, logX):
            drawScatter(ctx, title: title, xLabel: xLabel, yLabel: yLabel,
                        series: series, curve: curve, logX: logX)
        }
    }

    /// Compose several panels into one figure. `self` must be sized to the whole
    /// canvas (see `FigureLayout.Spec.totalSize`); each panel is drawn into its
    /// cell with a bold label (A, B, C …) above it.
    public func composite(format: Format, panels: [FigureLayout.Panel], layout: FigureLayout.Spec) -> Data? {
        render(format: format) { ctx in
            let total = layout.totalSize(panelCount: panels.count)
            for (i, panel) in panels.enumerated() {
                let cell = layout.cellRect(index: i)              // top-left origin
                let panelBottomCG = total.h - (cell.minY + layout.labelBand + layout.panelHeight)
                ctx.saveGState()
                ctx.translateBy(x: cell.minX, y: panelBottomCG)
                CGChartRenderer(width: layout.panelWidth, height: layout.panelHeight, theme: theme)
                    .draw(panel.request, in: ctx)
                ctx.restoreGState()
                if !panel.label.isEmpty {
                    let labelYCG = panelBottomCG + layout.panelHeight + 4
                    drawText(ctx, panel.label, at: CGPoint(x: cell.minX + 2, y: labelYCG),
                             size: 15, align: .left, bold: true, color: textColor)
                }
            }
        }
    }

    // MARK: - Backends

    private func render(format: Format, draw: (CGContext) -> Void) -> Data? {
        switch format {
        case .pdf: return renderPDF(draw: draw)
        case .png, .tiff: return renderBitmap(type: format.utType, draw: draw)
        }
    }

    private func renderPDF(draw: (CGContext) -> Void) -> Data? {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return nil }
        var mediaBox = CGRect(x: 0, y: 0, width: width, height: height)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }
        ctx.beginPDFPage(nil)
        fillBackground(ctx)
        draw(ctx)
        ctx.endPDFPage()
        ctx.closePDF()
        return data as Data
    }

    private func renderBitmap(type: UTType, draw: (CGContext) -> Void) -> Data? {
        let scale = 2  // @2x for crisp raster output
        let pxW = Int(width) * scale
        let pxH = Int(height) * scale
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: pxW, height: pxH, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
        fillBackground(ctx)
        draw(ctx)
        guard let image = ctx.makeImage() else { return nil }

        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, type.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }

    private func fillBackground(_ ctx: CGContext) {
        ctx.setFillColor(backgroundColor)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }

    // MARK: - Scatter / curve

    private func drawScatter(_ ctx: CGContext, title: String, xLabel: String, yLabel: String,
                             series: [SVGRenderer.Series], curve: [PlotPoint]?, logX: Bool) {
        let all = series.flatMap { $0.points } + (curve ?? [])
        guard !all.isEmpty else { return }
        let xs = all.map { logX ? log10(Swift.max($0.x, 1e-12)) : $0.x }
        let ys = all.map { $0.y }
        let xr = niceRange(xs.min()!, xs.max()!)
        let yr = niceRange(ys.min()!, ys.max()!)

        func px(_ x: Double) -> CGFloat {
            let v = logX ? log10(Swift.max(x, 1e-12)) : x
            return plot.minX + CGFloat((v - xr.lo) / (xr.hi - xr.lo)) * plot.width
        }
        func py(_ y: Double) -> CGFloat {
            plot.minY + CGFloat((y - yr.lo) / (yr.hi - yr.lo)) * plot.height
        }

        drawTitle(ctx, title)
        drawAxesFrame(ctx)
        ctx.setStrokeColor(axisColor)
        ctx.setLineWidth(1)
        for t in ticks(xr.lo, xr.hi) {
            let xv = plot.minX + CGFloat((t - xr.lo) / (xr.hi - xr.lo)) * plot.width
            stroke(ctx, from: CGPoint(x: xv, y: plot.minY), to: CGPoint(x: xv, y: plot.minY - 4))
            drawText(ctx, logX ? fmtTick(pow(10, t)) : fmtTick(t), at: CGPoint(x: xv, y: plot.minY - 16), size: 10, align: .center)
        }
        drawYTicks(ctx, yr: yr, py: py)
        drawText(ctx, xLabel, at: CGPoint(x: plot.midX, y: 14), size: 12, align: .center)
        drawYAxisLabel(ctx, yLabel)

        if let curve, curve.count > 1 {
            ctx.setStrokeColor(curveColor)
            ctx.setLineWidth(2)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: px(curve[0].x), y: py(curve[0].y)))
            for p in curve.dropFirst() { ctx.addLine(to: CGPoint(x: px(p.x), y: py(p.y))) }
            ctx.strokePath()
        }
        for (si, s) in series.enumerated() {
            let color = s.color == "#2C6FBB" ? paletteColor(at: si) : CGChartRenderer.cgColor(s.color)
            for p in s.points {
                let r: CGFloat = 4
                let rect = CGRect(x: px(p.x) - r, y: py(p.y) - r, width: 2 * r, height: 2 * r)
                ctx.setFillColor(color)
                ctx.fillEllipse(in: rect)
                ctx.setStrokeColor(backgroundColor)
                ctx.setLineWidth(1)
                ctx.strokeEllipse(in: rect)
            }
        }
    }

    // MARK: - Bars

    private func drawBars(_ ctx: CGContext, title: String, yLabel: String,
                          groups: [SVGRenderer.BarGroup], brackets: [BarBracket]) {
        guard !groups.isEmpty else { return }
        let maxValue = groups.map { $0.value + $0.error }.max() ?? 1
        let yr = niceRange(0, maxValue > 0 ? maxValue : 1)
        let laid = BracketLayout.assignLevels(brackets)
        let usableHeight = plot.height - bracketBand(laid)
        func py(_ y: Double) -> CGFloat { plot.minY + CGFloat((y - yr.lo) / (yr.hi - yr.lo)) * usableHeight }

        drawTitle(ctx, title)
        stroke(ctx, from: CGPoint(x: plot.minX, y: plot.minY), to: CGPoint(x: plot.maxX, y: plot.minY))
        drawYTicks(ctx, yr: yr, py: py)
        drawYAxisLabel(ctx, yLabel)

        let slot = plot.width / CGFloat(groups.count)
        let barWidth = slot * 0.6
        for (i, g) in groups.enumerated() {
            let cx = slotCenter(i, slot: slot)
            let top = py(g.value)
            let fill = g.color == "#2C6FBB" ? primaryColor : CGChartRenderer.cgColor(g.color)
            ctx.setFillColor(fill)
            ctx.fill(CGRect(x: cx - barWidth / 2, y: plot.minY, width: barWidth, height: top - plot.minY))
            if g.error > 0 {
                ctx.setStrokeColor(axisColor)
                ctx.setLineWidth(1.5)
                stroke(ctx, from: CGPoint(x: cx, y: py(g.value - g.error)), to: CGPoint(x: cx, y: py(g.value + g.error)))
                stroke(ctx, from: CGPoint(x: cx - 6, y: py(g.value + g.error)), to: CGPoint(x: cx + 6, y: py(g.value + g.error)))
            }
            drawText(ctx, g.label, at: CGPoint(x: cx, y: plot.minY - 16), size: 11, align: .center)
        }

        drawBrackets(ctx, laid, slot: slot, count: groups.count) { i in py(groups[i].value + groups[i].error) }
    }

    // MARK: - Boxes

    private func drawBoxes(_ ctx: CGContext, title: String, yLabel: String,
                           groups: [SVGRenderer.BoxGroup], brackets: [BarBracket]) {
        guard !groups.isEmpty else { return }
        let lo = groups.map { $0.stats.displayRange.lo }.min() ?? 0
        let hi = groups.map { $0.stats.displayRange.hi }.max() ?? 1
        guard lo.isFinite, hi.isFinite else { return }
        let yr = niceRange(lo, hi)
        let laid = BracketLayout.assignLevels(brackets)
        let usableHeight = plot.height - bracketBand(laid)
        func py(_ y: Double) -> CGFloat { plot.minY + CGFloat((y - yr.lo) / (yr.hi - yr.lo)) * usableHeight }

        drawTitle(ctx, title)
        stroke(ctx, from: CGPoint(x: plot.minX, y: plot.minY), to: CGPoint(x: plot.maxX, y: plot.minY))
        drawYTicks(ctx, yr: yr, py: py)
        drawYAxisLabel(ctx, yLabel)

        let slot = plot.width / CGFloat(groups.count)
        let boxWidth = slot * 0.5
        for (i, g) in groups.enumerated() {
            let cx = slotCenter(i, slot: slot)
            let s = g.stats
            ctx.setStrokeColor(axisColor)
            ctx.setLineWidth(1)
            // Whiskers + caps.
            stroke(ctx, from: CGPoint(x: cx, y: py(s.lowerWhisker)), to: CGPoint(x: cx, y: py(s.q1)))
            stroke(ctx, from: CGPoint(x: cx, y: py(s.q3)), to: CGPoint(x: cx, y: py(s.upperWhisker)))
            stroke(ctx, from: CGPoint(x: cx - boxWidth / 4, y: py(s.upperWhisker)), to: CGPoint(x: cx + boxWidth / 4, y: py(s.upperWhisker)))
            stroke(ctx, from: CGPoint(x: cx - boxWidth / 4, y: py(s.lowerWhisker)), to: CGPoint(x: cx + boxWidth / 4, y: py(s.lowerWhisker)))
            // Box.
            let boxRect = CGRect(x: cx - boxWidth / 2, y: py(s.q1), width: boxWidth, height: py(s.q3) - py(s.q1))
            ctx.setFillColor(paletteColor(at: i).copy(alpha: 0.65) ?? paletteColor(at: i))
            ctx.fill(boxRect)
            ctx.setStrokeColor(axisColor)
            ctx.stroke(boxRect)
            // Median.
            ctx.setLineWidth(1.8)
            stroke(ctx, from: CGPoint(x: cx - boxWidth / 2, y: py(s.median)), to: CGPoint(x: cx + boxWidth / 2, y: py(s.median)))
            // Mean cross.
            if s.mean.isFinite {
                ctx.setStrokeColor(textColor)
                ctx.setLineWidth(1)
                let ym = py(s.mean)
                stroke(ctx, from: CGPoint(x: cx - 3, y: ym), to: CGPoint(x: cx + 3, y: ym))
                stroke(ctx, from: CGPoint(x: cx, y: ym - 3), to: CGPoint(x: cx, y: ym + 3))
            }
            // Outliers.
            ctx.setStrokeColor(axisColor)
            ctx.setLineWidth(1)
            for o in s.outliers {
                let r: CGFloat = 2.5
                ctx.strokeEllipse(in: CGRect(x: cx - r, y: py(o) - r, width: 2 * r, height: 2 * r))
            }
            drawText(ctx, g.label, at: CGPoint(x: cx, y: plot.minY - 16), size: 11, align: .center)
        }

        drawBrackets(ctx, laid, slot: slot, count: groups.count) { i in py(groups[i].stats.displayRange.hi) }
    }

    // MARK: - Violins

    private func drawViolins(_ ctx: CGContext, title: String, yLabel: String,
                             groups: [SVGRenderer.ViolinGroup], brackets: [BarBracket]) {
        guard groups.contains(where: { $0.density.count > 1 }) else {
            drawBoxes(ctx, title: title, yLabel: yLabel,
                      groups: groups.map { SVGRenderer.BoxGroup(label: $0.label, stats: $0.stats) },
                      brackets: brackets)
            return
        }
        let values = groups.flatMap { $0.density.map(\.value) }
        guard let lo = values.min(), let hi = values.max() else { return }
        let yr = niceRange(lo, hi)
        let laid = BracketLayout.assignLevels(brackets)
        let usableHeight = plot.height - bracketBand(laid)
        func py(_ y: Double) -> CGFloat { plot.minY + CGFloat((y - yr.lo) / (yr.hi - yr.lo)) * usableHeight }

        drawTitle(ctx, title)
        stroke(ctx, from: CGPoint(x: plot.minX, y: plot.minY), to: CGPoint(x: plot.maxX, y: plot.minY))
        drawYTicks(ctx, yr: yr, py: py)
        drawYAxisLabel(ctx, yLabel)

        let slot = plot.width / CGFloat(groups.count)
        let maxHalf = slot * 0.42
        for (i, g) in groups.enumerated() {
            let cx = slotCenter(i, slot: slot)
            guard g.density.count > 1, let peak = g.density.map(\.density).max(), peak > 0 else { continue }
            ctx.beginPath()
            let right = g.density.map { CGPoint(x: cx + CGFloat($0.density / peak) * maxHalf, y: py($0.value)) }
            let left = g.density.reversed().map { CGPoint(x: cx - CGFloat($0.density / peak) * maxHalf, y: py($0.value)) }
            let outline = right + left
            ctx.move(to: outline[0])
            for p in outline.dropFirst() { ctx.addLine(to: p) }
            ctx.closePath()
            ctx.setFillColor(paletteColor(at: i).copy(alpha: 0.55) ?? paletteColor(at: i))
            ctx.drawPath(using: .fill)
            // Re-stroke the outline.
            ctx.beginPath()
            ctx.move(to: outline[0])
            for p in outline.dropFirst() { ctx.addLine(to: p) }
            ctx.closePath()
            ctx.setStrokeColor(axisColor)
            ctx.setLineWidth(1)
            ctx.strokePath()

            // Inner box overlay.
            let s = g.stats
            if s.q1.isFinite && s.q3.isFinite {
                ctx.setStrokeColor(axisColor)
                ctx.setLineWidth(1)
                stroke(ctx, from: CGPoint(x: cx, y: py(s.lowerWhisker)), to: CGPoint(x: cx, y: py(s.upperWhisker)))
                ctx.setStrokeColor(textColor)
                ctx.setLineWidth(4)
                stroke(ctx, from: CGPoint(x: cx, y: py(s.q1)), to: CGPoint(x: cx, y: py(s.q3)))
                let r: CGFloat = 2.4
                ctx.setFillColor(backgroundColor)
                ctx.fillEllipse(in: CGRect(x: cx - r, y: py(s.median) - r, width: 2 * r, height: 2 * r))
            }
            drawText(ctx, g.label, at: CGPoint(x: cx, y: plot.minY - 16), size: 11, align: .center)
        }

        drawBrackets(ctx, laid, slot: slot, count: groups.count) { i in py(groups[i].density.map(\.value).max() ?? 0) }
    }

    // MARK: - Shared category helpers

    private func bracketBand(_ laid: [BarBracket]) -> CGFloat {
        let levelCount = (laid.map(\.level).max() ?? -1) + 1
        return laid.isEmpty ? 0 : CGFloat(levelCount) * bracketStep + 14
    }

    private func slotCenter(_ i: Int, slot: CGFloat) -> CGFloat { plot.minX + slot * (CGFloat(i) + 0.5) }

    /// Significance brackets (larger y is higher on the page). `topY(i)` returns
    /// the y of the top of element i.
    private func drawBrackets(_ ctx: CGContext, _ laid: [BarBracket], slot: CGFloat, count: Int, topY: (Int) -> CGFloat) {
        ctx.setStrokeColor(axisColor)
        ctx.setLineWidth(1)
        for b in laid where (0..<count).contains(b.lo) && (0..<count).contains(b.hi) {
            let cxA = slotCenter(b.fromIndex, slot: slot)
            let cxB = slotCenter(b.toIndex, slot: slot)
            let y = max(topY(b.fromIndex), topY(b.toIndex)) + 10 + CGFloat(b.level) * bracketStep
            let drop: CGFloat = 5
            stroke(ctx, from: CGPoint(x: cxA, y: y), to: CGPoint(x: cxB, y: y))
            stroke(ctx, from: CGPoint(x: cxA, y: y), to: CGPoint(x: cxA, y: y - drop))
            stroke(ctx, from: CGPoint(x: cxB, y: y), to: CGPoint(x: cxB, y: y - drop))
            if !b.label.isEmpty {
                drawText(ctx, b.label, at: CGPoint(x: (cxA + cxB) / 2, y: y + 3), size: 12, align: .center, color: textColor)
            }
        }
    }

    // MARK: - Drawing helpers

    private func drawAxesFrame(_ ctx: CGContext) {
        ctx.setStrokeColor(axisColor)
        ctx.setLineWidth(1)
        stroke(ctx, from: CGPoint(x: plot.minX, y: plot.maxY), to: CGPoint(x: plot.minX, y: plot.minY))
        stroke(ctx, from: CGPoint(x: plot.minX, y: plot.minY), to: CGPoint(x: plot.maxX, y: plot.minY))
    }

    private func drawYTicks(_ ctx: CGContext, yr: (lo: Double, hi: Double), py: (Double) -> CGFloat) {
        ctx.setStrokeColor(axisColor)
        ctx.setLineWidth(1)
        for t in ticks(yr.lo, yr.hi) {
            let y = py(t)
            stroke(ctx, from: CGPoint(x: plot.minX - 4, y: y), to: CGPoint(x: plot.minX, y: y))
            drawText(ctx, fmtTick(t), at: CGPoint(x: plot.minX - 8, y: y - 4), size: 10, align: .right)
        }
    }

    private func drawTitle(_ ctx: CGContext, _ title: String) {
        guard !title.isEmpty else { return }
        drawText(ctx, title, at: CGPoint(x: width / 2, y: height - 22), size: 14, align: .center, bold: true, color: textColor)
    }

    private func drawYAxisLabel(_ ctx: CGContext, _ label: String) {
        ctx.saveGState()
        ctx.translateBy(x: 16, y: plot.midY)
        ctx.rotate(by: .pi / 2)
        drawText(ctx, label, at: .zero, size: 12, align: .center)
        ctx.restoreGState()
    }

    private func stroke(_ ctx: CGContext, from a: CGPoint, to b: CGPoint) {
        ctx.beginPath()
        ctx.move(to: a)
        ctx.addLine(to: b)
        ctx.strokePath()
    }

    private enum Align { case left, center, right }

    private func drawText(_ ctx: CGContext, _ s: String, at p: CGPoint, size: CGFloat, align: Align,
                          bold: Bool = false, color: CGColor? = nil) {
        let fontName = (bold ? theme.boldFontName : theme.fontName) as CFString
        let font = CTFontCreateWithName(fontName, size, nil)
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: attrs))
        let bounds = CTLineGetBoundsWithOptions(line, [])
        var x = p.x
        switch align {
        case .center: x -= bounds.width / 2
        case .right:  x -= bounds.width
        case .left:   break
        }
        ctx.setFillColor(color ?? axisColor)
        ctx.setTextDrawingMode(.fill)
        ctx.textPosition = CGPoint(x: x, y: p.y)
        CTLineDraw(line, ctx)
    }

    // MARK: - Color

    /// Parse a `#RRGGBB` hex string into a device-RGB `CGColor`, falling back to
    /// mid-gray for malformed input.
    static func cgColor(_ hex: String) -> CGColor {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return CGColor(gray: 0.5, alpha: 1) }
        let r = CGFloat((v >> 16) & 0xFF) / 255
        let g = CGFloat((v >> 8) & 0xFF) / 255
        let b = CGFloat(v & 0xFF) / 255
        return CGColor(red: r, green: g, blue: b, alpha: 1)
    }

    // MARK: - Scaling

    private func niceRange(_ lo: Double, _ hi: Double) -> (lo: Double, hi: Double) {
        if lo == hi { let pad = Swift.abs(lo) * 0.1 + 1; return (lo - pad, hi + pad) }
        let pad = (hi - lo) * 0.05
        return (lo - pad, hi + pad)
    }

    private func ticks(_ lo: Double, _ hi: Double, _ count: Int = 5) -> [Double] {
        AxisTicks.nice(lo, hi, count: count)
    }

    private func fmtTick(_ v: Double) -> String {
        if v == 0 { return "0" }
        let a = Swift.abs(v)
        if a >= 1000 || a < 0.01 { return String(format: "%.2g", v) }
        if v == v.rounded() { return String(format: "%.0f", v) }
        return String(format: "%.2f", v)
    }
}
