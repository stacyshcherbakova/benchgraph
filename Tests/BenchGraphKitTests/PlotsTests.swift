import Testing
import Foundation
@testable import BenchGraphKit

/// Covers the box/violin layer: Tukey box statistics, the kernel-density
/// estimate behind violins, journal theme presets, and that both renderers
/// actually emit box/violin geometry honouring the selected theme.
@Suite struct PlotsTests {

    // MARK: - Box statistics

    @Test func boxStatsWithOutlier() {
        // 100 sits far beyond the upper fence; 1…9 form a clean quartile spread.
        let s = BoxStats.compute([1, 2, 3, 4, 5, 6, 7, 8, 9, 100])
        #expect(abs(s.q1 - 3.25) < 1e-9)
        #expect(abs(s.median - 5.5) < 1e-9)
        #expect(abs(s.q3 - 7.75) < 1e-9)
        #expect(abs(s.iqr - 4.5) < 1e-9)
        // Whiskers stop at the most extreme in-fence points.
        #expect(s.lowerWhisker == 1)
        #expect(s.upperWhisker == 9)
        #expect(s.outliers == [100])
        #expect(abs(s.mean - 14.5) < 1e-9)
        // The display range must include the outlier so it isn't clipped.
        #expect(s.displayRange.hi == 100)
    }

    @Test func boxStatsNoOutliers() {
        let s = BoxStats.compute([10, 12, 14, 16, 18])
        #expect(s.q1 == 12)
        #expect(s.median == 14)
        #expect(s.q3 == 16)
        #expect(s.lowerWhisker == 10)
        #expect(s.upperWhisker == 18)
        #expect(s.outliers.isEmpty)
    }

    @Test func boxStatsDegenerate() {
        #expect(BoxStats.compute([]).median.isNaN)
        let one = BoxStats.compute([7])
        #expect(one.median == 7 && one.q1 == 7 && one.q3 == 7)
        #expect(one.outliers.isEmpty)
    }

    // MARK: - Kernel density

    @Test func kdeIntegratesToOne() {
        let x = [2.0, 3, 3, 4, 5, 5, 5, 6, 7, 8]
        let profile = KernelDensity.gaussian(x)
        #expect(profile.count == 64)
        #expect(profile.allSatisfy { $0.density >= 0 })
        #expect(profile.contains { $0.density > 0 })
        // Riemann sum over the grid should integrate to ~1 (it's a density).
        let step = profile[1].value - profile[0].value
        let area = profile.reduce(0) { $0 + $1.density } * step
        #expect(abs(area - 1) < 0.06)
        // The mode should land inside the data span.
        let peak = profile.max { $0.density < $1.density }!
        #expect(peak.value >= x.min()! && peak.value <= x.max()!)
    }

    @Test func kdeNeedsSpread() {
        #expect(KernelDensity.gaussian([5]).isEmpty)        // too few points
        #expect(KernelDensity.gaussian([3, 3, 3]).isEmpty)  // no spread
    }

    // MARK: - Themes

    @Test func themeLookupAndPalette() {
        #expect(Theme.named("nature") == .nature)
        #expect(Theme.named("GRAYSCALE") == .grayscale)     // case-insensitive
        #expect(Theme.named("does-not-exist") == nil)
        // The palette cycles once exhausted.
        let t = Theme.default
        #expect(t.color(at: 0) == t.palette[0])
        #expect(t.color(at: t.palette.count) == t.palette[0])
        // Preset names are distinct.
        #expect(Set(Theme.presets.map(\.name)).count == Theme.presets.count)
    }

    // MARK: - SVG rendering

    private func boxGroups() -> [SVGRenderer.BoxGroup] {
        [
            SVGRenderer.BoxGroup(label: "A", stats: BoxStats.compute([1, 2, 3, 4, 5, 6, 7, 8, 9, 100])),
            SVGRenderer.BoxGroup(label: "B", stats: BoxStats.compute([4, 5, 6, 5, 4, 6, 5, 7]))
        ]
    }

    @Test func svgBoxPlotDrawsGeometryAndTheme() {
        let svg = SVGRenderer(theme: .grayscale).boxPlot(
            title: "Dist", yLabel: "V", groups: boxGroups(),
            brackets: [BarBracket(fromIndex: 0, toIndex: 1, label: "*")]
        )
        #expect(svg.contains("<rect"))          // the IQR boxes
        #expect(svg.contains("<circle"))        // the 100 outlier
        #expect(svg.contains(">A<") && svg.contains(">B<"))
        #expect(svg.contains(">*<"))            // significance bracket
        // Grayscale palette must reach the output (box fill).
        #expect(svg.contains(Theme.grayscale.color(at: 0)))
    }

    @Test func svgViolinPlotDrawsFilledPaths() {
        let groups = [
            SVGRenderer.ViolinGroup(label: "A",
                                    density: KernelDensity.gaussian([1, 2, 2, 3, 3, 3, 4, 4, 5]),
                                    stats: BoxStats.compute([1, 2, 2, 3, 3, 3, 4, 4, 5]))
        ]
        let svg = SVGRenderer().violinPlot(title: "V", yLabel: "Value", groups: groups)
        #expect(svg.contains("<path"))
        #expect(svg.contains("fill-opacity=\"0.55\""))
        #expect(svg.contains(">A<"))
    }

    @Test func defaultThemeKeepsOriginalColors() {
        // The default preset must reproduce the original blue bars / red curve so
        // earlier figures are unchanged.
        let bars = [SVGRenderer.BarGroup(label: "A", value: 10, error: 2)]
        #expect(SVGRenderer().barChart(title: "T", yLabel: "V", groups: bars).contains("#2C6FBB"))
        #expect(SVGRenderer(theme: .grayscale).barChart(title: "T", yLabel: "V", groups: bars)
            .contains(Theme.grayscale.primaryColor))
    }

    // MARK: - CoreGraphics rendering

    @Test func cgBoxAndViolinRenderValidPDF() {
        let box = CGChartRenderer().boxPlot(format: .pdf, title: "Dist", yLabel: "V", groups: boxGroups())
        #expect(box != nil)
        #expect(Array(box!.prefix(4)) == [0x25, 0x50, 0x44, 0x46])  // "%PDF"

        let violinGroups = [
            SVGRenderer.ViolinGroup(label: "A",
                                    density: KernelDensity.gaussian([1, 2, 2, 3, 3, 3, 4, 5]),
                                    stats: BoxStats.compute([1, 2, 2, 3, 3, 3, 4, 5]))
        ]
        let violin = CGChartRenderer(theme: .nature).violinPlot(format: .png, title: "V", yLabel: "Value", groups: violinGroups)
        #expect(violin != nil)
        #expect(Array(violin!.prefix(4)) == [0x89, 0x50, 0x4E, 0x47])  // PNG signature
    }
}
