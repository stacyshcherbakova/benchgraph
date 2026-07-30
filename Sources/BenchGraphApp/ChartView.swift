import SwiftUI
import BenchGraphKit

/// A native SwiftUI chart that draws the current `ChartSpec` (scatter with an
/// optional fitted curve, bars with error bars, or box / violin distributions),
/// all with significance brackets. This mirrors what the exporters produce, but
/// renders live in the window. The `theme` palette colours the data marks so
/// preset changes are visible immediately; axes/text stay adaptive for legible
/// light/dark display (export uses the theme's full white-canvas styling).
struct ChartView: View {
    let spec: ChartSpec
    var theme: Theme = .default

    private let inset = EdgeInsets(top: 28, leading: 64, bottom: 56, trailing: 32)
    /// Vertical spacing between stacked significance brackets.
    private let bracketStep: CGFloat = 16

    private var dataColor: Color { color(theme.primaryColor) }
    private var curveColor: Color { color(theme.curveColor) }
    private func paletteColor(_ i: Int) -> Color { color(theme.color(at: i)) }

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
                    case let .box(groups, yLabel, brackets):
                        drawBoxes(context, plot: plot, groups: groups, yLabel: yLabel, brackets: brackets)
                    case let .violin(groups, yLabel, brackets):
                        drawViolins(context, plot: plot, groups: groups, yLabel: yLabel, brackets: brackets)
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

        if let curve, curve.count > 1 {
            var path = Path()
            for (i, p) in curve.enumerated() {
                let pt = CGPoint(x: px(p.x), y: py(p.y))
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            context.stroke(path, with: .color(curveColor), lineWidth: 2)
        }

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

        let laid = BracketLayout.assignLevels(brackets)
        let usableHeight = plot.height - bracketBand(laid)
        func py(_ y: Double) -> CGFloat {
            plot.maxY - CGFloat((y - yRange.lo) / (yRange.hi - yRange.lo)) * usableHeight
        }

        drawYAxis(context, plot: plot, yRange: yRange, yLabel: yLabel, height: usableHeight)
        drawBaseline(context, plot: plot)

        let slot = plot.width / CGFloat(groups.count)
        let barWidth = slot * 0.6
        for (i, g) in groups.enumerated() {
            let cx = slotCenter(plot, i, slot)
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
            drawCategoryLabel(context, g.label, cx: cx, plot: plot)
        }

        drawBrackets(context, plot: plot, laid: laid, slot: slot, count: groups.count) { i in
            py(groups[i].value + groups[i].error)
        }
    }

    // MARK: - Box-and-whisker

    private func drawBoxes(_ context: GraphicsContext, plot: CGRect,
                           groups: [ChartSpec.Samples], yLabel: String, brackets: [BarBracket]) {
        let stats = groups.map { (label: $0.label, s: BoxStats.compute($0.values)) }
        let los = stats.map { $0.s.displayRange.lo }
        let his = stats.map { $0.s.displayRange.hi }
        guard let lo = los.min(), let hi = his.max(), lo.isFinite, hi.isFinite else {
            drawPlaceholder(context, plot: plot); return
        }
        let yRange = niceRange(lo, hi)
        let laid = BracketLayout.assignLevels(brackets)
        let usableHeight = plot.height - bracketBand(laid)
        func py(_ v: Double) -> CGFloat {
            plot.maxY - CGFloat((v - yRange.lo) / (yRange.hi - yRange.lo)) * usableHeight
        }

        drawYAxis(context, plot: plot, yRange: yRange, yLabel: yLabel, height: usableHeight)
        drawBaseline(context, plot: plot)

        let slot = plot.width / CGFloat(stats.count)
        let boxWidth = slot * 0.5
        for (i, st) in stats.enumerated() {
            let cx = slotCenter(plot, i, slot)
            let s = st.s
            // Whiskers + caps.
            var whisk = Path()
            whisk.move(to: CGPoint(x: cx, y: py(s.lowerWhisker))); whisk.addLine(to: CGPoint(x: cx, y: py(s.q1)))
            whisk.move(to: CGPoint(x: cx, y: py(s.q3))); whisk.addLine(to: CGPoint(x: cx, y: py(s.upperWhisker)))
            whisk.move(to: CGPoint(x: cx - boxWidth / 4, y: py(s.upperWhisker))); whisk.addLine(to: CGPoint(x: cx + boxWidth / 4, y: py(s.upperWhisker)))
            whisk.move(to: CGPoint(x: cx - boxWidth / 4, y: py(s.lowerWhisker))); whisk.addLine(to: CGPoint(x: cx + boxWidth / 4, y: py(s.lowerWhisker)))
            context.stroke(whisk, with: .color(.secondary), lineWidth: 1)
            // Box.
            let box = CGRect(x: cx - boxWidth / 2, y: py(s.q3), width: boxWidth, height: py(s.q1) - py(s.q3))
            context.fill(Path(box), with: .color(paletteColor(i).opacity(0.65)))
            context.stroke(Path(box), with: .color(.primary), lineWidth: 1)
            // Median.
            var med = Path()
            med.move(to: CGPoint(x: cx - boxWidth / 2, y: py(s.median)))
            med.addLine(to: CGPoint(x: cx + boxWidth / 2, y: py(s.median)))
            context.stroke(med, with: .color(.primary), lineWidth: 1.8)
            // Mean cross.
            if s.mean.isFinite {
                let ym = py(s.mean)
                var cross = Path()
                cross.move(to: CGPoint(x: cx - 3, y: ym)); cross.addLine(to: CGPoint(x: cx + 3, y: ym))
                cross.move(to: CGPoint(x: cx, y: ym - 3)); cross.addLine(to: CGPoint(x: cx, y: ym + 3))
                context.stroke(cross, with: .color(.primary), lineWidth: 1)
            }
            // Outliers.
            for o in s.outliers {
                let r: CGFloat = 2.5
                context.stroke(Path(ellipseIn: CGRect(x: cx - r, y: py(o) - r, width: 2 * r, height: 2 * r)),
                               with: .color(.secondary), lineWidth: 1)
            }
            drawCategoryLabel(context, st.label, cx: cx, plot: plot)
        }

        drawBrackets(context, plot: plot, laid: laid, slot: slot, count: stats.count) { i in
            py(stats[i].s.displayRange.hi)
        }
    }

    // MARK: - Violin

    private func drawViolins(_ context: GraphicsContext, plot: CGRect,
                             groups: [ChartSpec.Samples], yLabel: String, brackets: [BarBracket]) {
        let built = groups.map { (label: $0.label,
                                  density: KernelDensity.gaussian($0.values),
                                  s: BoxStats.compute($0.values)) }
        guard built.contains(where: { $0.density.count > 1 }) else {
            // Degenerate samples: fall back to a box plot.
            drawBoxes(context, plot: plot, groups: groups, yLabel: yLabel, brackets: brackets)
            return
        }
        let values = built.flatMap { $0.density.map(\.value) }
        guard let lo = values.min(), let hi = values.max() else { drawPlaceholder(context, plot: plot); return }
        let yRange = niceRange(lo, hi)
        let laid = BracketLayout.assignLevels(brackets)
        let usableHeight = plot.height - bracketBand(laid)
        func py(_ v: Double) -> CGFloat {
            plot.maxY - CGFloat((v - yRange.lo) / (yRange.hi - yRange.lo)) * usableHeight
        }

        drawYAxis(context, plot: plot, yRange: yRange, yLabel: yLabel, height: usableHeight)
        drawBaseline(context, plot: plot)

        let slot = plot.width / CGFloat(built.count)
        let maxHalf = slot * 0.42
        for (i, g) in built.enumerated() {
            let cx = slotCenter(plot, i, slot)
            if g.density.count > 1, let peak = g.density.map(\.density).max(), peak > 0 {
                var path = Path()
                let right = g.density.map { CGPoint(x: cx + CGFloat($0.density / peak) * maxHalf, y: py($0.value)) }
                let left = g.density.reversed().map { CGPoint(x: cx - CGFloat($0.density / peak) * maxHalf, y: py($0.value)) }
                let outline = right + left
                path.move(to: outline[0])
                for p in outline.dropFirst() { path.addLine(to: p) }
                path.closeSubpath()
                context.fill(path, with: .color(paletteColor(i).opacity(0.55)))
                context.stroke(path, with: .color(.secondary), lineWidth: 1)
            }
            // Inner box overlay.
            let s = g.s
            if s.q1.isFinite && s.q3.isFinite {
                var stem = Path()
                stem.move(to: CGPoint(x: cx, y: py(s.lowerWhisker)))
                stem.addLine(to: CGPoint(x: cx, y: py(s.upperWhisker)))
                context.stroke(stem, with: .color(.secondary), lineWidth: 1)
                var iqr = Path()
                iqr.move(to: CGPoint(x: cx, y: py(s.q1)))
                iqr.addLine(to: CGPoint(x: cx, y: py(s.q3)))
                context.stroke(iqr, with: .color(.primary), lineWidth: 4)
                let r: CGFloat = 2.4
                context.fill(Path(ellipseIn: CGRect(x: cx - r, y: py(s.median) - r, width: 2 * r, height: 2 * r)),
                             with: .color(Color(nsColor: .textBackgroundColor)))
            }
            drawCategoryLabel(context, g.label, cx: cx, plot: plot)
        }

        drawBrackets(context, plot: plot, laid: laid, slot: slot, count: built.count) { i in
            py(built[i].density.map(\.value).max() ?? 0)
        }
    }

    // MARK: - Shared category helpers

    private func bracketBand(_ laid: [BarBracket]) -> CGFloat {
        let levelCount = (laid.map(\.level).max() ?? -1) + 1
        return laid.isEmpty ? 0 : CGFloat(levelCount) * bracketStep + 14
    }

    private func slotCenter(_ plot: CGRect, _ i: Int, _ slot: CGFloat) -> CGFloat {
        plot.minX + slot * (CGFloat(i) + 0.5)
    }

    private func drawBaseline(_ context: GraphicsContext, plot: CGRect) {
        var axis = Path()
        axis.move(to: CGPoint(x: plot.minX, y: plot.maxY))
        axis.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
        context.stroke(axis, with: .color(.gray), lineWidth: 1)
    }

    private func drawCategoryLabel(_ context: GraphicsContext, _ label: String, cx: CGFloat, plot: CGRect) {
        context.draw(
            Text(label).font(.system(size: 11)).foregroundColor(.secondary),
            at: CGPoint(x: cx, y: plot.maxY + 14)
        )
    }

    /// Significance brackets above the elements (smaller y is higher). `topY(i)`
    /// returns the y of the top of element i.
    private func drawBrackets(_ context: GraphicsContext, plot: CGRect, laid: [BarBracket],
                              slot: CGFloat, count: Int, topY: (Int) -> CGFloat) {
        for b in laid where (0..<count).contains(b.lo) && (0..<count).contains(b.hi) {
            let cxA = slotCenter(plot, b.fromIndex, slot)
            let cxB = slotCenter(plot, b.toIndex, slot)
            let y = min(topY(b.fromIndex), topY(b.toIndex)) - 10 - CGFloat(b.level) * bracketStep
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
        AxisTicks.nice(lo, hi, count: count)
    }

    private func formatTick(_ v: Double) -> String {
        if v == 0 { return "0" }
        let a = abs(v)
        if a >= 1000 || a < 0.01 { return String(format: "%.2g", v) }
        if v == v.rounded() { return String(format: "%.0f", v) }
        return String(format: "%.2f", v)
    }

    /// Parse a `#RRGGBB` hex string into a SwiftUI `Color`.
    private func color(_ hex: String) -> Color {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return .gray }
        return Color(red: Double((v >> 16) & 0xFF) / 255,
                     green: Double((v >> 8) & 0xFF) / 255,
                     blue: Double(v & 0xFF) / 255)
    }
}
