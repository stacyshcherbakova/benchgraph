import SwiftUI
import BenchGraphKit

/// A native SwiftUI chart that draws the current `ChartSpec` (scatter with an
/// optional fitted curve, or bars with error bars and significance brackets).
/// This mirrors what the SVG exporter produces, but renders live in the window.
struct ChartView: View {
    let spec: ChartSpec

    private let inset = EdgeInsets(top: 16, leading: 52, bottom: 40, trailing: 16)
    private let dataColor = Color(red: 0.17, green: 0.43, blue: 0.73)
    private let curveColor = Color(red: 0.82, green: 0.29, blue: 0.36)
    /// Vertical spacing between stacked significance brackets.
    private let bracketStep: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            let plot = CGRect(
                x: inset.leading,
                y: inset.top,
                width: max(geo.size.width - inset.leading - inset.trailing, 1),
                height: max(geo.size.height - inset.top - inset.bottom, 1)
            )
            ZStack {
                Canvas { context, _ in
                    switch spec {
                    case .none:
                        drawPlaceholder(context, plot: plot)
                    case let .scatter(points, curve, logX, xLabel, yLabel):
                        drawScatter(context, plot: plot, points: points, curve: curve,
                                    logX: logX, xLabel: xLabel, yLabel: yLabel)
                    case let .bars(groups, yLabel, brackets):
                        drawBars(context, plot: plot, groups: groups, yLabel: yLabel, brackets: brackets)
                    }
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Scatter

    private func drawScatter(_ context: GraphicsContext, plot: CGRect,
                             points: [ChartSpec.Point], curve: [ChartSpec.Point]?,
                             logX: Bool, xLabel: String, yLabel: String) {
        let all = points + (curve ?? [])
        guard !all.isEmpty else { drawPlaceholder(context, plot: plot); return }

        let xs = all.map { logX ? log10(max($0.x, 1e-12)) : $0.x }
        let ys = all.map { $0.y }
        let xRange = niceRange(xs.min()!, xs.max()!)
        let yRange = niceRange(ys.min()!, ys.max()!)

        func px(_ x: Double) -> CGFloat {
            let v = logX ? log10(max(x, 1e-12)) : x
            return plot.minX + CGFloat((v - xRange.lo) / (xRange.hi - xRange.lo)) * plot.width
        }
        func py(_ y: Double) -> CGFloat {
            plot.maxY - CGFloat((y - yRange.lo) / (yRange.hi - yRange.lo)) * plot.height
        }

        drawAxes(context, plot: plot, xRange: xRange, yRange: yRange, logX: logX,
                 xLabel: xLabel, yLabel: yLabel)

        // Fitted curve.
        if let curve, curve.count > 1 {
            var path = Path()
            for (i, p) in curve.enumerated() {
                let pt = CGPoint(x: px(p.x), y: py(p.y))
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            context.stroke(path, with: .color(curveColor), lineWidth: 2)
        }

        // Data points.
        for p in points {
            let r: CGFloat = 4
            let rect = CGRect(x: px(p.x) - r, y: py(p.y) - r, width: 2 * r, height: 2 * r)
            context.fill(Path(ellipseIn: rect), with: .color(dataColor))
            context.stroke(Path(ellipseIn: rect), with: .color(.white), lineWidth: 1)
        }
    }

    // MARK: - Bars

    private func drawBars(_ context: GraphicsContext, plot: CGRect,
                          groups: [ChartSpec.Bar], yLabel: String, brackets: [BarBracket]) {
        guard !groups.isEmpty else { drawPlaceholder(context, plot: plot); return }
        let maxValue = groups.map { $0.value + $0.error }.max() ?? 1
        let yRange = niceRange(0, maxValue > 0 ? maxValue : 1)

        // Reserve a band at the top for significance brackets (smaller y is higher).
        let laid = BracketLayout.assignLevels(brackets)
        let levelCount = (laid.map(\.level).max() ?? -1) + 1
        let band: CGFloat = laid.isEmpty ? 0 : CGFloat(levelCount) * bracketStep + 14
        let usableHeight = plot.height - band

        func py(_ y: Double) -> CGFloat {
            plot.maxY - CGFloat((y - yRange.lo) / (yRange.hi - yRange.lo)) * usableHeight
        }

        drawYAxis(context, plot: plot, yRange: yRange, yLabel: yLabel, height: usableHeight)
        // Baseline.
        var axis = Path()
        axis.move(to: CGPoint(x: plot.minX, y: plot.maxY))
        axis.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
        context.stroke(axis, with: .color(.gray), lineWidth: 1)

        let slot = plot.width / CGFloat(groups.count)
        let barWidth = slot * 0.6
        for (i, g) in groups.enumerated() {
            let cx = plot.minX + slot * (CGFloat(i) + 0.5)
            let top = py(g.value)
            let rect = CGRect(x: cx - barWidth / 2, y: top, width: barWidth, height: plot.maxY - top)
            context.fill(Path(rect), with: .color(dataColor))

            if g.error > 0 {
                var err = Path()
                err.move(to: CGPoint(x: cx, y: py(g.value + g.error)))
                err.addLine(to: CGPoint(x: cx, y: py(g.value - g.error)))
                err.move(to: CGPoint(x: cx - 6, y: py(g.value + g.error)))
                err.addLine(to: CGPoint(x: cx + 6, y: py(g.value + g.error)))
                context.stroke(err, with: .color(.primary), lineWidth: 1.5)
            }

            context.draw(
                Text(g.label).font(.system(size: 11)).foregroundColor(.secondary),
                at: CGPoint(x: cx, y: plot.maxY + 14)
            )
        }

        // Significance brackets (smaller y is higher).
        for b in laid where groups.indices.contains(b.lo) && groups.indices.contains(b.hi) {
            let cxA = plot.minX + slot * (CGFloat(b.fromIndex) + 0.5)
            let cxB = plot.minX + slot * (CGFloat(b.toIndex) + 0.5)
            let barTop = min(py(groups[b.fromIndex].value + groups[b.fromIndex].error),
                             py(groups[b.toIndex].value + groups[b.toIndex].error))
            let y = barTop - 10 - CGFloat(b.level) * bracketStep
            let drop: CGFloat = 5
            var bracket = Path()
            bracket.move(to: CGPoint(x: cxA, y: y + drop))
            bracket.addLine(to: CGPoint(x: cxA, y: y))
            bracket.addLine(to: CGPoint(x: cxB, y: y))
            bracket.addLine(to: CGPoint(x: cxB, y: y + drop))
            context.stroke(bracket, with: .color(.primary), lineWidth: 1)
            if !b.label.isEmpty {
                context.draw(
                    Text(b.label).font(.system(size: 12)).foregroundColor(.primary),
                    at: CGPoint(x: (cxA + cxB) / 2, y: y - 7)
                )
            }
        }
    }

    // MARK: - Axes

    private func drawAxes(_ context: GraphicsContext, plot: CGRect,
                          xRange: (lo: Double, hi: Double), yRange: (lo: Double, hi: Double),
                          logX: Bool, xLabel: String, yLabel: String) {
        var frame = Path()
        frame.move(to: CGPoint(x: plot.minX, y: plot.minY))
        frame.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
        frame.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
        context.stroke(frame, with: .color(.gray), lineWidth: 1)

        // X ticks.
        let xticks = ticks(xRange.lo, xRange.hi, 5)
        for t in xticks {
            let x = plot.minX + CGFloat((t - xRange.lo) / (xRange.hi - xRange.lo)) * plot.width
            var tick = Path()
            tick.move(to: CGPoint(x: x, y: plot.maxY))
            tick.addLine(to: CGPoint(x: x, y: plot.maxY + 4))
            context.stroke(tick, with: .color(.gray), lineWidth: 1)
            let label = logX ? formatTick(pow(10, t)) : formatTick(t)
            context.draw(Text(label).font(.system(size: 10)).foregroundColor(.secondary),
                         at: CGPoint(x: x, y: plot.maxY + 14))
        }
        drawYAxis(context, plot: plot, yRange: yRange, yLabel: yLabel)

        context.draw(Text(xLabel).font(.system(size: 12)).foregroundColor(.primary),
                     at: CGPoint(x: plot.midX, y: plot.maxY + 30))
    }

    private func drawYAxis(_ context: GraphicsContext, plot: CGRect,
                           yRange: (lo: Double, hi: Double), yLabel: String,
                           height: CGFloat? = nil) {
        let mapHeight = height ?? plot.height
        let yticks = ticks(yRange.lo, yRange.hi, 5)
        for t in yticks {
            let y = plot.maxY - CGFloat((t - yRange.lo) / (yRange.hi - yRange.lo)) * mapHeight
            var tick = Path()
            tick.move(to: CGPoint(x: plot.minX - 4, y: y))
            tick.addLine(to: CGPoint(x: plot.minX, y: y))
            context.stroke(tick, with: .color(.gray), lineWidth: 1)
            context.draw(Text(formatTick(t)).font(.system(size: 10)).foregroundColor(.secondary),
                         at: CGPoint(x: plot.minX - 8, y: y), anchor: .trailing)
        }
        context.drawLayer { layer in
            layer.translateBy(x: 14, y: plot.midY)
            layer.rotate(by: .degrees(-90))
            layer.draw(Text(yLabel).font(.system(size: 12)).foregroundColor(.primary),
                       at: .zero)
        }
    }

    private func drawPlaceholder(_ context: GraphicsContext, plot: CGRect) {
        context.draw(
            Text("No figure — paste data and pick an analysis")
                .font(.system(size: 12)).foregroundColor(.secondary),
            at: CGPoint(x: plot.midX, y: plot.midY)
        )
    }

    // MARK: - Scaling helpers

    private func niceRange(_ lo: Double, _ hi: Double) -> (lo: Double, hi: Double) {
        if lo == hi {
            let pad = abs(lo) * 0.1 + 1
            return (lo - pad, hi + pad)
        }
        let pad = (hi - lo) * 0.05
        return (lo - pad, hi + pad)
    }

    private func ticks(_ lo: Double, _ hi: Double, _ count: Int) -> [Double] {
        guard hi > lo else { return [lo] }
        let step = (hi - lo) / Double(count)
        return (0...count).map { lo + Double($0) * step }
    }

    private func formatTick(_ v: Double) -> String {
        if v == 0 { return "0" }
        let a = abs(v)
        if a >= 1000 || a < 0.01 { return String(format: "%.2g", v) }
        if v == v.rounded() { return String(format: "%.0f", v) }
        return String(format: "%.2f", v)
    }
}
