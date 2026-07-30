import Foundation
import SwiftUI
import AppKit
import BenchGraphKit

/// The analyses the GUI exposes, mapped to the table shape each one needs.
enum Analysis: String, CaseIterable, Identifiable, Sendable {
    // Raw values are STABLE persistence keys written into `.benchgraph` files.
    // They are decoupled from the display label (see `label`) so the UI wording
    // can be re-worded without breaking older saved projects.
    case descriptive   = "descriptive"
    case tTestWelch    = "ttest.welch"
    case tTestStudent  = "ttest.student"
    case tTestPaired   = "ttest.paired"
    case anova         = "anova.oneway"
    case postHoc       = "anova.posthoc"
    case mannWhitney   = "mannwhitney"
    case wilcoxon      = "wilcoxon"
    case normality     = "normality"
    case pearson       = "correlation.pearson"
    case spearman      = "correlation.spearman"
    case linear        = "regression.linear"
    case fourPL        = "doseresponse.4pl"

    var id: String { rawValue }

    /// Human-readable label shown in the picker and used as a chart title.
    /// Safe to re-word freely; it is not what gets persisted.
    var label: String {
        switch self {
        case .descriptive:  return "Descriptive statistics"
        case .tTestWelch:   return "Unpaired t test (Welch)"
        case .tTestStudent: return "Unpaired t test (Student)"
        case .tTestPaired:  return "Paired t test"
        case .anova:        return "One-way ANOVA"
        case .postHoc:      return "ANOVA post-hoc (pairwise)"
        case .mannWhitney:  return "Mann-Whitney U"
        case .wilcoxon:     return "Wilcoxon signed-rank"
        case .normality:    return "Normality (D'Agostino-Pearson)"
        case .pearson:      return "Pearson correlation"
        case .spearman:     return "Spearman correlation"
        case .linear:       return "Linear regression"
        case .fourPL:       return "4PL dose-response"
        }
    }

    /// Resolve a persisted identifier back to an analysis. Falls back to matching
    /// the display label, so projects written by older builds (which stored the
    /// label instead of the stable key) still restore their analysis.
    static func restore(from stored: String) -> Analysis? {
        Analysis(rawValue: stored) ?? allCases.first { $0.label == stored }
    }

    /// Whether this analysis reads a Column table or an XY table.
    var tableKind: TableKind {
        switch self {
        case .pearson, .spearman, .linear, .fourPL: return .xy
        default: return .column
        }
    }

    var hint: String {
        switch self {
        case .wilcoxon, .tTestPaired:
            return "First two columns, paired row by row."
        case .normality:
            return "First column is tested for normality."
        case .pearson, .spearman, .linear, .fourPL:
            return "First column = X, second = Y. One (x, y) pair per row."
        default:
            return "One group per column. Headers name the groups."
        }
    }
}

/// How a column-data analysis is visualised.
enum ColumnPlot: String, CaseIterable, Identifiable, Sendable {
    case bar    = "Bars"
    case box    = "Box"
    case violin = "Violin"
    var id: String { rawValue }
}

/// What the chart view should draw for the current result.
enum ChartSpec: Equatable {
    case none
    case scatter(points: [Point], curve: [Point]?, logX: Bool, xLabel: String, yLabel: String)
    case bars(groups: [Bar], yLabel: String, brackets: [BarBracket])
    case box(groups: [Samples], yLabel: String, brackets: [BarBracket])
    case violin(groups: [Samples], yLabel: String, brackets: [BarBracket])

    struct Point: Equatable { let x: Double; let y: Double }
    struct Bar: Equatable { let label: String; let value: Double; let error: Double }
    /// A named group of raw observations, for box/violin plots.
    struct Samples: Equatable { let label: String; let values: [Double] }
}

/// A full snapshot of the editable session, used for undo/redo. Everything the
/// user can change — the data grid and every presentation option — is captured
/// here so one undo step restores the exact prior state.
struct EditState: Equatable, Sendable {
    var grid: EditGrid
    var hasHeader: Bool
    var analysis: Analysis
    var errorBar: ErrorBarKind
    var columnPlot: ColumnPlot
    var showSignificance: Bool
    var showResiduals: Bool
    var themeName: String
}

/// Drives the whole window: an editable data grid + chosen analysis → live
/// result + chart, with undo/redo across every edit.
@MainActor
final class AppModel: ObservableObject {
    /// The editable table the user types into — the single source of truth for
    /// the data. The CSV handed to the parser is derived from it (`csvText`).
    @Published private(set) var grid: EditGrid
    @Published var hasHeader: Bool
    @Published var analysis: Analysis
    /// Which spread statistic the bar error bars show (SD / SEM / 95% CI).
    @Published var errorBar: ErrorBarKind = .sem
    /// How column data is drawn (bars / box / violin).
    @Published var columnPlot: ColumnPlot = .bar
    /// Whether to draw significance brackets linking compared groups.
    @Published var showSignificance: Bool = true
    /// For regression / dose-response: draw a residual plot instead of the fit.
    @Published var showResiduals: Bool = false
    /// Journal theme used for the live chart and figure export.
    @Published var theme: Theme = .default

    @Published private(set) var table: DataTable?
    @Published private(set) var result: AnalysisResult?
    @Published private(set) var chart: ChartSpec = .none
    @Published private(set) var errorMessage: String?

    /// One chart staged for the multi-panel figure, with a rendered thumbnail
    /// so the tray shows exactly what was captured.
    struct StagedPanel: Identifiable {
        let id: UUID
        let request: FigureExport.Request
        let title: String
        let thumbnail: NSImage?
    }

    /// Figures staged for a multi-panel publication layout (A, B, C …).
    @Published private(set) var stagedPanels: [StagedPanel] = []
    var panelCount: Int { stagedPanels.count }

    /// One undo manager for the whole session. Cmd-Z/Cmd-Shift-Z and the toolbar
    /// buttons drive it; each edit registers a full-state restore.
    let undoManager = UndoManager()
    private var interactiveSnapshot: EditState?

    /// The current data as CSV text, derived from the grid and header flag. This
    /// is what the analysis parser and the project file consume.
    var csvText: String { grid.csv(includeHeader: hasHeader) }

    /// Whether the current figure is a bar chart (the error-bar picker only
    /// applies to these).
    var isBarChart: Bool { if case .bars = chart { return true }; return false }

    /// Whether the current figure draws grouped column data (bars / box /
    /// violin) — the plot-style and significance controls apply to these.
    var isColumnChart: Bool {
        switch chart {
        case .bars, .box, .violin: return true
        default: return false
        }
    }

    init() {
        // Prefill with the bundled dose-response sample so the window is alive
        // on first launch.
        let sample = """
        Concentration,Response
        1,9.1
        3,23.0
        10,49.5
        30,75.2
        100,90.9
        300,96.8
        """
        analysis = .fourPL
        hasHeader = true
        grid = EditGrid.parse(sample, kind: .xy, hasHeader: true)
        recompute()
    }

    // MARK: - Editing entry points (grid)

    /// Live cell edit: update one cell and recompute. Undo granularity is per
    /// editing session, bracketed by `beginInteractiveEdit`/`commitInteractiveEdit`.
    func updateCell(_ row: Int, _ col: Int, _ value: String) {
        grid.setCell(row, col, value)
        recompute()
    }

    func renameColumn(_ col: Int, to name: String) {
        grid.renameColumn(col, to: name)
        recompute()
    }

    /// Snapshot before an interactive (typing) edit begins, so the whole session
    /// collapses to a single undo step registered on commit.
    func beginInteractiveEdit() {
        if interactiveSnapshot == nil { interactiveSnapshot = snapshot() }
    }

    func commitInteractiveEdit() {
        guard let previous = interactiveSnapshot else { return }
        interactiveSnapshot = nil
        if previous != snapshot() { registerUndo(previous) }
    }

    func addRow() { edit { grid.addRow() } }
    func removeRow(_ row: Int) { edit { grid.removeRow(row) } }
    func addColumn() { edit { grid.addColumn() } }
    func removeColumn(_ col: Int) { edit { grid.removeColumn(col) } }

    /// Replace the grid with freshly pasted/imported CSV or TSV text.
    func replaceData(with text: String) {
        edit { grid = EditGrid.parse(text, kind: analysis.tableKind, hasHeader: hasHeader) }
    }

    /// Load the analysis-appropriate bundled sample.
    func loadSample() {
        let text: String
        switch analysis.tableKind {
        case .xy:
            text = "Concentration,Response\n1,9.1\n3,23.0\n10,49.5\n30,75.2\n100,90.9\n300,96.8"
        default:
            text = "Control,Treated\n5.1,7.2\n4.8,6.9\n5.5,7.8\n5.0,7.1\n4.9,6.5\n5.3,7.6"
        }
        edit {
            hasHeader = true
            grid = EditGrid.parse(text, kind: analysis.tableKind, hasHeader: true)
        }
    }

    /// Clear to an empty, still-typeable grid.
    func clear() {
        edit { grid = EditGrid.empty(kind: analysis.tableKind) }
    }

    // MARK: - Editing entry points (options)

    func setHasHeader(_ value: Bool) {
        guard value != hasHeader else { return }
        edit {
            grid.applyHeaderChange(nowHasHeader: value)
            hasHeader = value
        }
    }

    func setAnalysis(_ value: Analysis) {
        guard value != analysis else { return }
        edit {
            let newKind = value.tableKind
            if newKind != grid.kind {
                // Reinterpret the same data under the new table shape.
                grid = EditGrid.parse(csvText, kind: newKind, hasHeader: hasHeader)
            }
            analysis = value
        }
    }

    func setErrorBar(_ value: ErrorBarKind) { guard value != errorBar else { return }; edit { errorBar = value } }
    func setColumnPlot(_ value: ColumnPlot) { guard value != columnPlot else { return }; edit { columnPlot = value } }
    func setShowSignificance(_ value: Bool) { guard value != showSignificance else { return }; edit { showSignificance = value } }
    func setShowResiduals(_ value: Bool) { guard value != showResiduals else { return }; edit { showResiduals = value } }
    func setTheme(_ value: Theme) { guard value != theme else { return }; edit { theme = value } }

    /// Whether the current analysis has a fit whose residuals can be plotted.
    var supportsResiduals: Bool { analysis == .linear || analysis == .fourPL }

    // MARK: - Undo / redo

    var canUndo: Bool { undoManager.canUndo }
    var canRedo: Bool { undoManager.canRedo }
    func undo() { if undoManager.canUndo { undoManager.undo() } }
    func redo() { if undoManager.canRedo { undoManager.redo() } }

    /// Run a discrete user change as one undoable step.
    private func edit(_ mutate: () -> Void) {
        let previous = snapshot()
        mutate()
        recompute()
        registerUndo(previous)
    }

    private func snapshot() -> EditState {
        EditState(grid: grid, hasHeader: hasHeader, analysis: analysis, errorBar: errorBar,
                  columnPlot: columnPlot, showSignificance: showSignificance,
                  showResiduals: showResiduals, themeName: theme.name)
    }

    private func apply(state: EditState) {
        grid = state.grid
        hasHeader = state.hasHeader
        analysis = state.analysis
        errorBar = state.errorBar
        columnPlot = state.columnPlot
        showSignificance = state.showSignificance
        showResiduals = state.showResiduals
        theme = Theme.named(state.themeName) ?? .default
        recompute()
    }

    private func registerUndo(_ previous: EditState) {
        undoManager.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated {
                let current = model.snapshot()
                model.apply(state: previous)
                model.registerUndo(current)
            }
        }
    }

    // MARK: - Recompute

    /// Re-parse the data and re-run the selected analysis. Linked data →
    /// analysis → graph update, the way the roadmap's core workflow describes.
    func recompute() {
        errorMessage = nil
        result = nil
        chart = .none

        let parsed = CSVImporter().parse(csvText, kind: analysis.tableKind, hasHeader: hasHeader)
        table = parsed
        guard !parsed.columns.isEmpty else {
            errorMessage = "No columns parsed. Type or paste CSV/TSV data."
            return
        }

        do {
            switch analysis {
            case .descriptive:
                result = Descriptive.analyze(parsed.columns[0])
                chart = columnChart(parsed)
            case .tTestWelch:
                let (a, b) = try twoColumns(parsed)
                result = TTest.unpaired(a.present, b.present, welch: true)
                chart = columnChart(parsed, limit: 2)
            case .tTestStudent:
                let (a, b) = try twoColumns(parsed)
                result = TTest.unpaired(a.present, b.present, welch: false)
                chart = columnChart(parsed, limit: 2)
            case .tTestPaired:
                let (a, b) = try twoColumns(parsed)
                let pairs = zip(a.values, b.values).compactMap { l, r -> (Double, Double)? in
                    guard let l, let r else { return nil }
                    return (l, r)
                }
                guard !pairs.isEmpty else { throw AppError("No complete pairs to compare.") }
                result = TTest.paired(pairs.map(\.0), pairs.map(\.1))
                chart = columnChart(parsed, limit: 2)
            case .anova:
                guard parsed.columns.count >= 2 else { throw AppError("ANOVA needs at least two columns.") }
                let groups = parsed.columns.map { (name: $0.name, values: $0.present) }
                result = ANOVA.oneWay(groups)
                chart = columnChart(parsed)
            case .postHoc:
                guard parsed.columns.count >= 2 else { throw AppError("Post-hoc comparisons need at least two columns.") }
                let groups = parsed.columns.map { (name: $0.name, values: $0.present) }
                result = PostHoc.pairwise(groups)
                chart = columnChart(parsed)
            case .mannWhitney:
                let (a, b) = try twoColumns(parsed)
                result = MannWhitney.test(a.present, b.present)
                chart = columnChart(parsed, limit: 2)
            case .wilcoxon:
                let (a, b) = try twoColumns(parsed)
                let pairs = zip(a.values, b.values).compactMap { l, r -> (Double, Double)? in
                    guard let l, let r else { return nil }
                    return (l, r)
                }
                guard !pairs.isEmpty else { throw AppError("No complete pairs to compare.") }
                result = Wilcoxon.signedRank(pairs.map(\.0), pairs.map(\.1))
                chart = columnChart(parsed, limit: 2)
            case .normality:
                result = Normality.dagostinoPearson(parsed.columns[0].present)
                chart = columnChart(parsed, limit: 1)
            case .pearson:
                let (x, y) = try xyPairs(parsed)
                result = Correlation.pearson(x, y)
                chart = .scatter(points: zip(x, y).map { .init(x: $0, y: $1) }, curve: nil,
                                 logX: false, xLabel: xName(parsed), yLabel: yName(parsed))
            case .spearman:
                let (x, y) = try xyPairs(parsed)
                result = Correlation.spearman(x, y)
                chart = .scatter(points: zip(x, y).map { .init(x: $0, y: $1) }, curve: nil,
                                 logX: false, xLabel: xName(parsed), yLabel: yName(parsed))
            case .linear:
                let (x, y) = try xyPairs(parsed)
                result = LinearRegression.analyze(x, y)
                let fit = LinearRegression.fit(x, y)
                if showResiduals {
                    chart = residualScatter(x: x, y: y, predict: fit.predict, logX: false, xLabel: xName(parsed))
                } else {
                    let xMin = x.min()!, xMax = x.max()!
                    let line = [ChartSpec.Point(x: xMin, y: fit.predict(xMin)),
                                ChartSpec.Point(x: xMax, y: fit.predict(xMax))]
                    chart = .scatter(points: zip(x, y).map { .init(x: $0, y: $1) }, curve: line,
                                     logX: false, xLabel: xName(parsed), yLabel: yName(parsed))
                }
            case .fourPL:
                let (x, y) = try xyPairs(parsed)
                result = FourPL.analyze(x: x, y: y)
                let fit = FourPL.fit(x: x, y: y)
                if showResiduals {
                    chart = residualScatter(x: x, y: y, predict: fit.predict, logX: true, xLabel: xName(parsed))
                } else {
                    let positive = x.filter { $0 > 0 }
                    let lo = log10(positive.min() ?? 1), hi = log10(positive.max() ?? 10)
                    let step = (hi - lo) / 80
                    let curve = stride(from: lo, through: hi, by: max(step, 1e-6)).map { e -> ChartSpec.Point in
                        let xv = pow(10, e)
                        return .init(x: xv, y: fit.predict(xv))
                    }
                    chart = .scatter(points: zip(x, y).map { .init(x: $0, y: $1) }, curve: curve,
                                     logX: true, xLabel: xName(parsed), yLabel: yName(parsed))
                }
            }
        } catch let e as AppError {
            errorMessage = e.message
        } catch {
            errorMessage = error.localizedDescription
        }

        // Link analysis p-values to the column chart as significance brackets.
        if showSignificance, let result {
            func marks(_ count: Int) -> [BarBracket] {
                significanceBrackets(analysis: analysis, result: result, barCount: count, table: parsed)
            }
            switch chart {
            case let .bars(groups, yLabel, _):
                let b = marks(groups.count)
                if !b.isEmpty { chart = .bars(groups: groups, yLabel: yLabel, brackets: b) }
            case let .box(groups, yLabel, _):
                let b = marks(groups.count)
                if !b.isEmpty { chart = .box(groups: groups, yLabel: yLabel, brackets: b) }
            case let .violin(groups, yLabel, _):
                let b = marks(groups.count)
                if !b.isEmpty { chart = .violin(groups: groups, yLabel: yLabel, brackets: b) }
            default:
                break
            }
        }
    }

    // MARK: - Project documents

    /// Capture the current session as a saveable project document, including the
    /// presentation options so it reopens exactly as configured.
    func makeDocument() -> ProjectDocument {
        ProjectDocument(
            tableKind: analysis.tableKind,
            data: csvText,
            hasHeader: hasHeader,
            analysisName: analysis.rawValue,
            errorBar: errorBar,
            plotStyle: columnPlot.rawValue,
            showSignificance: showSignificance,
            themeName: theme.name,
            showResiduals: showResiduals
        )
    }

    /// Restore a loaded project: data, analysis, and (when present) the saved
    /// presentation options. Registered as one undo step.
    func apply(_ doc: ProjectDocument) {
        let previous = snapshot()
        if let restored = Analysis.restore(from: doc.analysisName) { analysis = restored }
        hasHeader = doc.hasHeader
        grid = EditGrid.parse(doc.data, kind: analysis.tableKind, hasHeader: doc.hasHeader)
        if let e = doc.errorBar { errorBar = e }
        if let style = doc.plotStyle, let plot = ColumnPlot(rawValue: style) { columnPlot = plot }
        if let sig = doc.showSignificance { showSignificance = sig }
        if let name = doc.themeName, let t = Theme.named(name) { theme = t }
        if let res = doc.showResiduals { showResiduals = res }
        recompute()
        registerUndo(previous)
    }

    /// Describe the current chart for the shared exporter.
    func figureRequest() -> FigureExport.Request? {
        switch chart {
        case .none:
            return nil
        case let .scatter(points, curve, logX, xLabel, yLabel):
            return .scatter(
                title: chartTitle, xLabel: xLabel, yLabel: yLabel,
                series: [.init(name: "data", points: points.map { (x: $0.x, y: $0.y) })],
                curve: curve?.map { (x: $0.x, y: $0.y) },
                logX: logX
            )
        case let .bars(groups, yLabel, brackets):
            return .bars(
                title: analysis.label, yLabel: yLabel,
                groups: groups.map { .init(label: $0.label, value: $0.value, error: $0.error) },
                brackets: brackets
            )
        case let .box(groups, yLabel, brackets):
            return .box(
                title: analysis.label, yLabel: yLabel,
                groups: groups.map { .init(label: $0.label, stats: BoxStats.compute($0.values)) },
                brackets: brackets
            )
        case let .violin(groups, yLabel, brackets):
            return .violin(
                title: analysis.label, yLabel: yLabel,
                groups: groups.map {
                    .init(label: $0.label,
                          density: KernelDensity.gaussian($0.values),
                          stats: BoxStats.compute($0.values))
                },
                brackets: brackets
            )
        }
    }

    /// Render the current figure to bytes for the given file extension
    /// (svg / pdf / png / tiff), matching the on-screen chart.
    func figureData(pathExtension ext: String) -> Data? {
        guard let req = figureRequest() else { return nil }
        return FigureExport.data(req, pathExtension: ext, theme: theme)
    }

    // MARK: - Multi-panel layout

    /// Stage the current figure as a panel in the multi-panel layout, rendering
    /// a thumbnail of exactly what was captured so the tray shows it.
    func addCurrentPanel() {
        guard let req = figureRequest() else { return }
        let thumbnail = FigureExport.data(req, pathExtension: "png", theme: theme)
            .flatMap { NSImage(data: $0) }
        stagedPanels.append(StagedPanel(id: UUID(), request: req, title: req.title, thumbnail: thumbnail))
    }

    func removePanel(_ id: UUID) {
        stagedPanels.removeAll { $0.id == id }
    }

    /// Move a staged panel one place left (-1) or right (+1) in the A/B/C order.
    func movePanel(_ id: UUID, by offset: Int) {
        guard let i = stagedPanels.firstIndex(where: { $0.id == id }) else { return }
        let j = i + offset
        guard stagedPanels.indices.contains(j) else { return }
        stagedPanels.swapAt(i, j)
    }

    func clearPanels() { stagedPanels.removeAll() }

    /// The A, B, C … label of each staged panel, by position.
    var panelLabels: [String] { FigureLayout.defaultLabels(count: stagedPanels.count) }

    /// Render the staged panels to a composed multi-panel figure. Panels are
    /// labelled A, B, C… by position so labels stay in order.
    func layoutData(pathExtension ext: String, columns: Int) -> Data? {
        guard !stagedPanels.isEmpty else { return nil }
        let labels = panelLabels
        let ordered = stagedPanels.enumerated().map {
            FigureLayout.Panel(request: $0.element.request, label: labels[$0.offset])
        }
        return FigureLayout.data(ordered, pathExtension: ext, theme: theme,
                                 layout: .init(columns: max(1, columns)))
    }

    /// A manifest describing a multi-panel export: app/engine/theme plus the
    /// ordered panel labels and titles.
    func layoutManifest() -> LayoutManifest {
        let labels = panelLabels
        let entries = stagedPanels.enumerated().map {
            LayoutManifest.PanelEntry(label: labels[$0.offset], title: $0.element.title)
        }
        return LayoutManifest(theme: theme.name, panels: entries)
    }

    /// A provenance manifest describing how the current figure was produced,
    /// suitable for writing alongside an export.
    func exportManifest() -> ExportManifest {
        ExportManifest(
            analysis: analysis.label,
            analysisKey: analysis.rawValue,
            tableKind: analysis.tableKind.rawValue,
            hasHeader: hasHeader,
            rowCount: grid.rowCount,
            columnNames: grid.columnNames,
            errorBar: isBarChart ? errorBar.rawValue : nil,
            plotStyle: isColumnChart ? columnPlot.rawValue : nil,
            showSignificance: isColumnChart ? showSignificance : nil,
            theme: theme.name,
            result: result
        )
    }

    // MARK: - Helpers

    private struct AppError: Error { let message: String; init(_ m: String) { message = m } }

    private func twoColumns(_ t: DataTable) throws -> (DataColumn, DataColumn) {
        guard t.columns.count >= 2 else { throw AppError("This test needs at least two columns.") }
        return (t.columns[0], t.columns[1])
    }

    private func xyPairs(_ t: DataTable) throws -> ([Double], [Double]) {
        guard t.columns.count >= 2 else { throw AppError("Need an X column and a Y column.") }
        let pairs = zip(t.columns[0].values, t.columns[1].values).compactMap { xv, yv -> (Double, Double)? in
            guard let x = xv, let y = yv else { return nil }
            return (x, y)
        }
        guard pairs.count >= 2 else { throw AppError("Need at least two complete (x, y) rows.") }
        if analysis == .fourPL && pairs.count < 4 { throw AppError("4PL needs at least 4 points.") }
        return (pairs.map(\.0), pairs.map(\.1))
    }

    private func columnChart(_ t: DataTable, limit: Int? = nil) -> ChartSpec {
        let cols = limit.map { Array(t.columns.prefix($0)) } ?? t.columns
        switch columnPlot {
        case .bar:
            let bars = cols.compactMap { col -> ChartSpec.Bar? in
                let s = Descriptive.summary(col.present)
                guard s.mean.isFinite else { return nil }
                let half = errorBar.halfLength(s)
                return .init(label: col.name, value: s.mean, error: half.isFinite ? half : 0)
            }
            return bars.isEmpty ? .none : .bars(groups: bars, yLabel: errorBar.caption, brackets: [])
        case .box, .violin:
            let groups = cols.compactMap { col -> ChartSpec.Samples? in
                let v = col.present
                return v.isEmpty ? nil : .init(label: col.name, values: v)
            }
            guard !groups.isEmpty else { return .none }
            return columnPlot == .box
                ? .box(groups: groups, yLabel: "Value", brackets: [])
                : .violin(groups: groups, yLabel: "Value", brackets: [])
        }
    }

    /// Build significance brackets that link the bars to the analysis p-values.
    /// Only pairwise tests produce them; the omnibus ANOVA and single-sample
    /// analyses have no pair to bracket.
    private func significanceBrackets(analysis: Analysis, result: AnalysisResult,
                                      barCount: Int, table: DataTable) -> [BarBracket] {
        func bracket(_ i: Int, _ j: Int, _ p: Double) -> BarBracket? {
            let mark = Significance.stars(p)
            guard !mark.isEmpty, i < barCount, j < barCount else { return nil }
            return BarBracket(fromIndex: i, toIndex: j, label: mark)
        }
        switch analysis {
        case .tTestWelch, .tTestStudent, .tTestPaired, .mannWhitney, .wilcoxon:
            guard let p = result.value("p (two-tailed)"), let b = bracket(0, 1, p) else { return [] }
            return [b]
        case .postHoc:
            let names = table.columns.map(\.name)
            var out: [BarBracket] = []
            for i in 0..<names.count {
                for j in (i + 1)..<names.count {
                    if let p = result.value("\(names[i]) vs \(names[j]): p (Holm)"),
                       let b = bracket(i, j, p) {
                        out.append(b)
                    }
                }
            }
            return out
        default:
            return []
        }
    }

    private func xName(_ t: DataTable) -> String { t.columns.first?.name ?? "X" }
    private func yName(_ t: DataTable) -> String { t.columns.count > 1 ? t.columns[1].name : "Y" }

    /// A residual plot for a fitted model: observed − predicted against X, with a
    /// zero reference line. Reuses the scatter renderer so it exports identically.
    private func residualScatter(x: [Double], y: [Double], predict: (Double) -> Double,
                                 logX: Bool, xLabel: String) -> ChartSpec {
        let points = zip(x, y).map { ChartSpec.Point(x: $0, y: $1 - predict($0)) }
        let xs = logX ? x.filter { $0 > 0 } : x
        let xMin = xs.min() ?? 0, xMax = xs.max() ?? 1
        let zero = [ChartSpec.Point(x: xMin, y: 0), ChartSpec.Point(x: xMax, y: 0)]
        return .scatter(points: points, curve: zero, logX: logX, xLabel: xLabel, yLabel: "Residual")
    }

    /// Chart title, marking residual plots so exports are self-describing.
    private var chartTitle: String {
        (showResiduals && supportsResiduals) ? "\(analysis.label) — residuals" : analysis.label
    }
}
