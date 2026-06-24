import Foundation
import SwiftUI
import BenchGraphKit

/// The analyses the GUI exposes, mapped to the table shape each one needs.
enum Analysis: String, CaseIterable, Identifiable {
    case descriptive   = "Descriptive statistics"
    case tTestWelch    = "Unpaired t test (Welch)"
    case tTestStudent  = "Unpaired t test (Student)"
    case tTestPaired   = "Paired t test"
    case anova         = "One-way ANOVA"
    case postHoc       = "ANOVA post-hoc (pairwise)"
    case mannWhitney   = "Mann-Whitney U"
    case wilcoxon      = "Wilcoxon signed-rank"
    case normality     = "Normality (D'Agostino-Pearson)"
    case pearson       = "Pearson correlation"
    case spearman      = "Spearman correlation"
    case linear        = "Linear regression"
    case fourPL        = "4PL dose-response"

    var id: String { rawValue }

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

/// What the chart view should draw for the current result.
enum ChartSpec: Equatable {
    case none
    case scatter(points: [Point], curve: [Point]?, logX: Bool, xLabel: String, yLabel: String)
    case bars(groups: [Bar], yLabel: String, brackets: [BarBracket])

    struct Point: Equatable { let x: Double; let y: Double }
    struct Bar: Equatable { let label: String; let value: Double; let error: Double }
}

/// Drives the whole window: raw data + chosen analysis → live result + chart.
@MainActor
final class AppModel: ObservableObject {
    @Published var rawText: String {
        didSet { recompute() }
    }
    @Published var analysis: Analysis {
        didSet { recompute() }
    }
    @Published var hasHeader: Bool {
        didSet { recompute() }
    }
    /// Which spread statistic the bar error bars show (SD / SEM / 95% CI).
    @Published var errorBar: ErrorBarKind = .sem {
        didSet { recompute() }
    }
    /// Whether to draw significance brackets linking compared groups.
    @Published var showSignificance: Bool = true {
        didSet { recompute() }
    }

    @Published private(set) var table: DataTable?
    @Published private(set) var result: AnalysisResult?
    @Published private(set) var chart: ChartSpec = .none
    @Published private(set) var errorMessage: String?

    /// Whether the current figure is a column chart (error-bar/significance
    /// controls only apply to these).
    var isBarChart: Bool { if case .bars = chart { return true }; return false }

    init() {
        // Prefill with the bundled dose-response sample so the window is alive
        // on first launch.
        rawText = """
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
        recompute()
    }

    /// Re-parse the data and re-run the selected analysis. Linked data →
    /// analysis → graph update, the way the roadmap's core workflow describes.
    func recompute() {
        errorMessage = nil
        result = nil
        chart = .none

        let parsed = CSVImporter().parse(rawText, kind: analysis.tableKind, hasHeader: hasHeader)
        table = parsed
        guard !parsed.columns.isEmpty else {
            errorMessage = "No columns parsed. Paste CSV/TSV data above."
            return
        }

        do {
            switch analysis {
            case .descriptive:
                result = Descriptive.analyze(parsed.columns[0])
                chart = columnBars(parsed)
            case .tTestWelch:
                let (a, b) = try twoColumns(parsed)
                result = TTest.unpaired(a.present, b.present, welch: true)
                chart = columnBars(parsed, limit: 2)
            case .tTestStudent:
                let (a, b) = try twoColumns(parsed)
                result = TTest.unpaired(a.present, b.present, welch: false)
                chart = columnBars(parsed, limit: 2)
            case .tTestPaired:
                let (a, b) = try twoColumns(parsed)
                let pairs = zip(a.values, b.values).compactMap { l, r -> (Double, Double)? in
                    guard let l, let r else { return nil }
                    return (l, r)
                }
                guard !pairs.isEmpty else { throw AppError("No complete pairs to compare.") }
                result = TTest.paired(pairs.map(\.0), pairs.map(\.1))
                chart = columnBars(parsed, limit: 2)
            case .anova:
                guard parsed.columns.count >= 2 else { throw AppError("ANOVA needs at least two columns.") }
                let groups = parsed.columns.map { (name: $0.name, values: $0.present) }
                result = ANOVA.oneWay(groups)
                chart = columnBars(parsed)
            case .postHoc:
                guard parsed.columns.count >= 2 else { throw AppError("Post-hoc comparisons need at least two columns.") }
                let groups = parsed.columns.map { (name: $0.name, values: $0.present) }
                result = PostHoc.pairwise(groups)
                chart = columnBars(parsed)
            case .mannWhitney:
                let (a, b) = try twoColumns(parsed)
                result = MannWhitney.test(a.present, b.present)
                chart = columnBars(parsed, limit: 2)
            case .wilcoxon:
                let (a, b) = try twoColumns(parsed)
                let pairs = zip(a.values, b.values).compactMap { l, r -> (Double, Double)? in
                    guard let l, let r else { return nil }
                    return (l, r)
                }
                guard !pairs.isEmpty else { throw AppError("No complete pairs to compare.") }
                result = Wilcoxon.signedRank(pairs.map(\.0), pairs.map(\.1))
                chart = columnBars(parsed, limit: 2)
            case .normality:
                result = Normality.dagostinoPearson(parsed.columns[0].present)
                chart = columnBars(parsed, limit: 1)
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
                let xMin = x.min()!, xMax = x.max()!
                let line = [ChartSpec.Point(x: xMin, y: fit.predict(xMin)),
                            ChartSpec.Point(x: xMax, y: fit.predict(xMax))]
                chart = .scatter(points: zip(x, y).map { .init(x: $0, y: $1) }, curve: line,
                                 logX: false, xLabel: xName(parsed), yLabel: yName(parsed))
            case .fourPL:
                let (x, y) = try xyPairs(parsed)
                result = FourPL.analyze(x: x, y: y)
                let fit = FourPL.fit(x: x, y: y)
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
        } catch let e as AppError {
            errorMessage = e.message
        } catch {
            errorMessage = error.localizedDescription
        }

        // Link analysis p-values to the bar chart as significance brackets.
        if showSignificance, let result, case let .bars(groups, yLabel, _) = chart {
            let brackets = significanceBrackets(analysis: analysis, result: result,
                                                barCount: groups.count, table: parsed)
            if !brackets.isEmpty {
                chart = .bars(groups: groups, yLabel: yLabel, brackets: brackets)
            }
        }
    }

    // MARK: - Project documents

    /// Capture the current session as a saveable project document.
    func makeDocument() -> ProjectDocument {
        ProjectDocument(
            tableKind: analysis.tableKind,
            data: rawText,
            hasHeader: hasHeader,
            analysisName: analysis.rawValue
        )
    }

    /// Restore a loaded project, recomputing the result and chart.
    func apply(_ doc: ProjectDocument) {
        if let restored = Analysis(rawValue: doc.analysisName) { analysis = restored }
        hasHeader = doc.hasHeader
        rawText = doc.data   // didSet triggers recompute with the final state
    }

    /// Describe the current chart for the shared exporter.
    func figureRequest() -> FigureExport.Request? {
        switch chart {
        case .none:
            return nil
        case let .scatter(points, curve, logX, xLabel, yLabel):
            return .scatter(
                title: analysis.rawValue, xLabel: xLabel, yLabel: yLabel,
                series: [.init(name: "data", points: points.map { (x: $0.x, y: $0.y) })],
                curve: curve?.map { (x: $0.x, y: $0.y) },
                logX: logX
            )
        case let .bars(groups, yLabel, brackets):
            return .bars(
                title: analysis.rawValue, yLabel: yLabel,
                groups: groups.map { .init(label: $0.label, value: $0.value, error: $0.error) },
                brackets: brackets
            )
        }
    }

    /// Render the current figure to bytes for the given file extension
    /// (svg / pdf / png / tiff), matching the on-screen chart.
    func figureData(pathExtension ext: String) -> Data? {
        guard let req = figureRequest() else { return nil }
        return FigureExport.data(req, pathExtension: ext)
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

    private func columnBars(_ t: DataTable, limit: Int? = nil) -> ChartSpec {
        let cols = limit.map { Array(t.columns.prefix($0)) } ?? t.columns
        let bars = cols.compactMap { col -> ChartSpec.Bar? in
            let s = Descriptive.summary(col.present)
            guard s.mean.isFinite else { return nil }
            let half = errorBar.halfLength(s)
            return .init(label: col.name, value: s.mean, error: half.isFinite ? half : 0)
        }
        return bars.isEmpty ? .none : .bars(groups: bars, yLabel: errorBar.caption, brackets: [])
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
}
