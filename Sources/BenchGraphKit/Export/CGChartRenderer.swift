import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

/// Renders charts to raster (PNG/TIFF) and vector (PDF) formats using
/// CoreGraphics, complementing the text-based `SVGRenderer`. It reuses the
/// same `Series` / `BarGroup` inputs so a figure exports identically across
/// formats. CoreGraphics uses a bottom-left origin, so y increases upward here.
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
    private let margin = (top: 30.0, right: 30.0, bottom: 55.0, left: 70.0)
    /// Vertical spacing between stacked significance brackets, in points.
    private let bracketStep: CGFloat = 16
    private let dataColor = CGColor(red: 0.173, green: 0.435, blue: 0.733, alpha: 1)
    private let curveColor = CGColor(red: 0.82, green: 0.286, blue: 0.357, alpha: 1)
    private let axisColor = CGColor(gray: 0.2, alpha: 1)

    public init(width: CGFloat = 520, height: CGFloat = 380) {
        self.width = width
        self.height = height
    }

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
        curve: [(x: Double, y: Double)]? = nil,
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
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }

    // MARK: - Scatter / curve

    private func drawScatter(_ ctx: CGContext, title: String, xLabel: String, yLabel: String,
                             series: [SVGRenderer.Series], curve: [(x: Double, y: Double)]?, logX: Bool) {
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
        // X ticks (t is already in the transformed/log space when logX).
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

        // Fitted curve.
        if let curve, curve.count > 1 {
            ctx.setStrokeColor(curveColor)
            ctx.setLineWidth(2)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: px(curve[0].x), y: py(curve[0].y)))
            for p in curve.dropFirst() { ctx.addLine(to: CGPoint(x: px(p.x), y: py(p.y))) }
            ctx.strokePath()
        }
        // Data points.
        for s in series {
            for p in s.points {
                let r: CGFloat = 4
                let rect = CGRect(x: px(p.x) - r, y: py(p.y) - r, width: 2 * r, height: 2 * r)
                ctx.setFillColor(dataColor)
                ctx.fillEllipse(in: rect)
                ctx.setStrokeColor(CGColor(gray: 1, alpha: 1))
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
        // Reserve a pixel band at the top for significance brackets (y grows up).
        let laid = BracketLayout.assignLevels(brackets)
        let levelCount = (laid.map(\.level).max() ?? -1) + 1
        let band = laid.isEmpty ? 0 : CGFloat(levelCount) * bracketStep + 14
        let usableHeight = plot.height - band
        func py(_ y: Double) -> CGFloat { plot.minY + CGFloat((y - yr.lo) / (yr.hi - yr.lo)) * usableHeight }

        drawTitle(ctx, title)
        stroke(ctx, from: CGPoint(x: plot.minX, y: plot.minY), to: CGPoint(x: plot.maxX, y: plot.minY))
        drawYTicks(ctx, yr: yr, py: py)
        drawYAxisLabel(ctx, yLabel)

        let slot = plot.width / CGFloat(groups.count)
        let barWidth = slot * 0.6
        for (i, g) in groups.enumerated() {
            let cx = plot.minX + slot * (CGFloat(i) + 0.5)
            let top = py(g.value)
            ctx.setFillColor(dataColor)
            ctx.fill(CGRect(x: cx - barWidth / 2, y: plot.minY, width: barWidth, height: top - plot.minY))
            if g.error > 0 {
                ctx.setStrokeColor(axisColor)
                ctx.setLineWidth(1.5)
                stroke(ctx, from: CGPoint(x: cx, y: py(g.value - g.error)), to: CGPoint(x: cx, y: py(g.value + g.error)))
                stroke(ctx, from: CGPoint(x: cx - 6, y: py(g.value + g.error)), to: CGPoint(x: cx + 6, y: py(g.value + g.error)))
            }
            drawText(ctx, g.label, at: CGPoint(x: cx, y: plot.minY - 16), size: 11, align: .center)
        }

        // Significance brackets (larger y is higher on the page).
        ctx.setStrokeColor(axisColor)
        ctx.setLineWidth(1)
        for b in laid where groups.indices.contains(b.lo) && groups.indices.contains(b.hi) {
            let cxA = plot.minX + slot * (CGFloat(b.fromIndex) + 0.5)
            let cxB = plot.minX + slot * (CGFloat(b.toIndex) + 0.5)
            let barTop = max(py(groups[b.fromIndex].value + groups[b.fromIndex].error),
                             py(groups[b.toIndex].value + groups[b.toIndex].error))
            let y = barTop + 10 + CGFloat(b.level) * bracketStep
            let drop: CGFloat = 5
            stroke(ctx, from: CGPoint(x: cxA, y: y), to: CGPoint(x: cxB, y: y))
            stroke(ctx, from: CGPoint(x: cxA, y: y), to: CGPoint(x: cxA, y: y - drop))
            stroke(ctx, from: CGPoint(x: cxB, y: y), to: CGPoint(x: cxB, y: y - drop))
            if !b.label.isEmpty {
                drawText(ctx, b.label, at: CGPoint(x: (cxA + cxB) / 2, y: y + 3), size: 12, align: .center)
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
        drawText(ctx, title, at: CGPoint(x: width / 2, y: height - 22), size: 14, align: .center, bold: true)
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

    private func drawText(_ ctx: CGContext, _ s: String, at p: CGPoint, size: CGFloat, align: Align, bold: Bool = false) {
        let fontName = (bold ? "Helvetica-Bold" : "Helvetica") as CFString
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
        ctx.setFillColor(axisColor)
        ctx.setTextDrawingMode(.fill)
        ctx.textPosition = CGPoint(x: x, y: p.y)
        CTLineDraw(line, ctx)
    }

    // MARK: - Scaling

    private func niceRange(_ lo: Double, _ hi: Double) -> (lo: Double, hi: Double) {
        if lo == hi { let pad = Swift.abs(lo) * 0.1 + 1; return (lo - pad, hi + pad) }
        let pad = (hi - lo) * 0.05
        return (lo - pad, hi + pad)
    }

    private func ticks(_ lo: Double, _ hi: Double, _ count: Int = 5) -> [Double] {
        guard hi > lo else { return [lo] }
        let step = (hi - lo) / Double(count)
        return (0...count).map { lo + Double($0) * step }
    }

    private func fmtTick(_ v: Double) -> String {
        if v == 0 { return "0" }
        let a = Swift.abs(v)
        if a >= 1000 || a < 0.01 { return String(format: "%.2g", v) }
        if v == v.rounded() { return String(format: "%.0f", v) }
        return String(format: "%.2f", v)
    }
}
