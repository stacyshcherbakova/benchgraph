import Foundation
import BenchGraphKit

// benchgraph — a thin CLI over BenchGraphKit that demonstrates the MVP promise:
// import data, run a chosen analysis, print provenance, export a figure.

let argv = Array(CommandLine.arguments.dropFirst())

guard let command = argv.first else {
    printUsage()
    exit(0)
}

let rest = Array(argv.dropFirst())
let options = Options(rest)

do {
    switch command {
    case "describe":    try runDescribe(options)
    case "ttest":       try runTTest(options)
    case "anova":       try runANOVA(options)
    case "posthoc":     try runPostHoc(options)
    case "mannwhitney": try runMannWhitney(options)
    case "wilcoxon":    try runWilcoxon(options)
    case "normality":   try runNormality(options)
    case "correlate":   try runCorrelate(options)
    case "regress":     try runRegress(options)
    case "doseresponse": try runDoseResponse(options)
    case "help", "-h", "--help": printUsage()
    case "version", "--version": print("benchgraph \(BenchGraph.version)")
    default:
        FileHandle.standardError.write(Data("Unknown command: \(command)\n\n".utf8))
        printUsage()
        exit(2)
    }
} catch let error as CLIError {
    FileHandle.standardError.write(Data("Error: \(error.message)\n".utf8))
    exit(1)
}

// MARK: - Commands

func runDescribe(_ o: Options) throws {
    let table = try o.loadTable(kind: .column)
    for column in table.columns {
        print(format(Descriptive.analyze(column), header: "Column: \(column.name)"))
    }
    if let path = o.figurePath {
        let req = columnFigure(table, style: o.plotStyle, kind: o.errorBarKind,
                               title: "Distribution by group", brackets: [])
        try renderFigure(req, to: path, theme: try o.resolvedTheme())
    }
}

func runTTest(_ o: Options) throws {
    let table = try o.loadTable(kind: .column)
    guard table.columns.count >= 2 else { throw CLIError("t test needs at least two columns") }
    let a = table.columns[0]
    let b = table.columns[1]
    let result: AnalysisResult
    if o.flag("paired") {
        let pairs = zip(a.values, b.values).compactMap { lhs, rhs -> (Double, Double)? in
            guard let l = lhs, let r = rhs else { return nil }
            return (l, r)
        }
        result = TTest.paired(pairs.map(\.0), pairs.map(\.1))
    } else {
        result = TTest.unpaired(a.present, b.present, welch: !o.flag("student"))
    }
    print(format(result, header: "\(a.name) vs \(b.name)"))

    if let path = o.figurePath {
        var brackets: [BarBracket] = []
        if let p = result.value("p (two-tailed)") {
            let mark = Significance.stars(p)
            if !mark.isEmpty { brackets = [BarBracket(fromIndex: 0, toIndex: 1, label: mark)] }
        }
        let req = columnFigure(table, style: o.plotStyle, kind: o.errorBarKind,
                               title: "\(a.name) vs \(b.name)", brackets: brackets, limit: 2)
        try renderFigure(req, to: path, theme: try o.resolvedTheme())
    }
}

func runANOVA(_ o: Options) throws {
    let table = try o.loadTable(kind: .column)
    guard table.columns.count >= 2 else { throw CLIError("ANOVA needs at least two columns") }
    let groups = table.columns.map { (name: $0.name, values: $0.present) }
    let result = ANOVA.oneWay(groups)
    print(format(result, header: "One-way ANOVA across \(groups.count) groups"))

    if let path = o.figurePath {
        let req = columnFigure(table, style: o.plotStyle, kind: o.errorBarKind,
                               title: "Group means", brackets: [])
        try renderFigure(req, to: path, theme: try o.resolvedTheme())
    }
}

func runPostHoc(_ o: Options) throws {
    let table = try o.loadTable(kind: .column)
    guard table.columns.count >= 2 else { throw CLIError("post-hoc needs at least two columns") }
    let groups = table.columns.map { (name: $0.name, values: $0.present) }
    let result = PostHoc.pairwise(groups)
    print(format(result, header: "Post-hoc pairwise comparisons (\(groups.count) groups)"))

    if let path = o.figurePath {
        let names = table.columns.map(\.name)
        var brackets: [BarBracket] = []
        for i in 0..<names.count {
            for j in (i + 1)..<names.count {
                guard let p = result.value("\(names[i]) vs \(names[j]): p (Holm)") else { continue }
                let mark = Significance.stars(p)
                if !mark.isEmpty { brackets.append(BarBracket(fromIndex: i, toIndex: j, label: mark)) }
            }
        }
        let req = columnFigure(table, style: o.plotStyle, kind: o.errorBarKind,
                               title: "Post-hoc comparisons", brackets: brackets)
        try renderFigure(req, to: path, theme: try o.resolvedTheme())
    }
}

func runMannWhitney(_ o: Options) throws {
    let table = try o.loadTable(kind: .column)
    guard table.columns.count >= 2 else { throw CLIError("Mann-Whitney needs two columns") }
    let result = MannWhitney.test(table.columns[0].present, table.columns[1].present)
    print(format(result, header: "\(table.columns[0].name) vs \(table.columns[1].name)"))
}

func runWilcoxon(_ o: Options) throws {
    let table = try o.loadTable(kind: .column)
    guard table.columns.count >= 2 else { throw CLIError("Wilcoxon needs two paired columns") }
    let a = table.columns[0]
    let b = table.columns[1]
    let pairs = zip(a.values, b.values).compactMap { l, r -> (Double, Double)? in
        guard let l, let r else { return nil }
        return (l, r)
    }
    guard !pairs.isEmpty else { throw CLIError("no complete pairs to compare") }
    let result = Wilcoxon.signedRank(pairs.map(\.0), pairs.map(\.1))
    print(format(result, header: "\(a.name) vs \(b.name) (paired)"))
}

func runNormality(_ o: Options) throws {
    let table = try o.loadTable(kind: .column)
    for column in table.columns {
        print(format(Normality.dagostinoPearson(column.present), header: "Column: \(column.name)"))
    }
}

func runCorrelate(_ o: Options) throws {
    let (x, y) = try o.loadXY()
    let result = o.flag("spearman") ? Correlation.spearman(x, y) : Correlation.pearson(x, y)
    print(format(result, header: "Correlation"))
}

func runRegress(_ o: Options) throws {
    let (x, y) = try o.loadXY()
    let result = LinearRegression.analyze(x, y)
    print(format(result, header: "Linear regression"))

    if let path = o.figurePath {
        let fit = LinearRegression.fit(x, y)
        let req: FigureExport.Request
        if o.flag("residuals") {
            req = residualFigure(x: x, y: y, predict: fit.predict, logX: false,
                                 title: "Linear regression — residuals")
        } else {
            let xMin = x.min()!, xMax = x.max()!
            let line = [(x: xMin, y: fit.predict(xMin)), (x: xMax, y: fit.predict(xMax))]
            req = .scatter(
                title: "Linear regression", xLabel: "X", yLabel: "Y",
                series: [.init(name: "data", points: zip(x, y).map { (x: $0, y: $1) })],
                curve: line, logX: false)
        }
        try renderFigure(req, to: path, theme: try o.resolvedTheme())
    }
}

func runDoseResponse(_ o: Options) throws {
    let (x, y) = try o.loadXY()
    let interpolate = (o.value("interpolate") ?? "").split(separator: ",").compactMap { Double($0) }
    let result = FourPL.analyze(x: x, y: y, interpolateY: interpolate)
    print(format(result, header: "Dose-response (4PL)"))

    if let path = o.figurePath {
        let fit = FourPL.fit(x: x, y: y)
        let req: FigureExport.Request
        if o.flag("residuals") {
            req = residualFigure(x: x, y: y, predict: fit.predict, logX: true,
                                 title: "Dose-response (4PL) — residuals")
        } else {
            let positiveX = x.filter { $0 > 0 }
            let lo = log10(positiveX.min() ?? 1)
            let hi = log10(positiveX.max() ?? 10)
            let curve = stride(from: lo, through: hi, by: (hi - lo) / 80).map { exp -> (x: Double, y: Double) in
                let xv = pow(10, exp)
                return (x: xv, y: fit.predict(xv))
            }
            req = .scatter(
                title: "Dose-response (4PL)",
                xLabel: "Concentration (log scale)", yLabel: "Response",
                series: [.init(name: "data", points: zip(x, y).map { (x: $0, y: $1) })],
                curve: curve, logX: true)
        }
        try renderFigure(req, to: path, theme: try o.resolvedTheme())
    }
}

/// A residual figure (observed − predicted vs X) with a zero reference line,
/// shared by the regression and dose-response commands.
func residualFigure(x: [Double], y: [Double], predict: (Double) -> Double,
                    logX: Bool, title: String) -> FigureExport.Request {
    let points = zip(x, y).map { (x: $0, y: $1 - predict($0)) }
    let xs = logX ? x.filter { $0 > 0 } : x
    let lo = xs.min() ?? 0, hi = xs.max() ?? 1
    return .scatter(title: title, xLabel: logX ? "Concentration (log scale)" : "X",
                    yLabel: "Residual",
                    series: [.init(name: "resid", points: points)],
                    curve: [(x: lo, y: 0), (x: hi, y: 0)], logX: logX)
}

// MARK: - Output formatting

func format(_ r: AnalysisResult, header: String) -> String {
    var lines: [String] = []
    lines.append("── \(header) ──")
    lines.append("Analysis: \(r.analysis)")
    lines.append("Formula:  \(r.formula)")
    lines.append("Results:")
    let width = r.values.map { $0.label.count }.max() ?? 0
    for v in r.values {
        let pad = String(repeating: " ", count: width - v.label.count)
        lines.append("  \(v.label)\(pad)  \(formatNumber(v.value))")
    }
    if !r.assumptions.isEmpty {
        lines.append("Assumptions:")
        r.assumptions.forEach { lines.append("  • \($0)") }
    }
    if !r.warnings.isEmpty {
        lines.append("Warnings:")
        r.warnings.forEach { lines.append("  ⚠ \($0)") }
    }
    if r.excludedCount > 0 {
        lines.append("Excluded cells (missing/non-numeric): \(r.excludedCount)")
    }
    lines.append("Engine: BenchGraph \(r.engineVersion)")
    lines.append("")
    return lines.joined(separator: "\n")
}

func formatNumber(_ v: Double) -> String {
    if v.isNaN { return "n/a" }
    if v == v.rounded() && abs(v) < 1e6 { return String(format: "%.0f", v) }
    let a = abs(v)
    if a != 0 && (a < 1e-4 || a >= 1e6) { return String(format: "%.4g", v) }
    return String(format: "%.5g", v)
}

/// How the column-based commands visualise their groups.
enum PlotStyle { case bar, box, violin }

/// Build a column figure (bars, box, or violin) for the chosen columns. Bars
/// show mean ± the selected error statistic; box/violin show the distribution.
func columnFigure(_ table: DataTable, style: PlotStyle, kind: ErrorBarKind,
                  title: String, brackets: [BarBracket], limit: Int? = nil) -> FigureExport.Request {
    let cols = limit.map { Array(table.columns.prefix($0)) } ?? table.columns
    switch style {
    case .bar:
        let groups = cols.map { col -> SVGRenderer.BarGroup in
            let s = Descriptive.summary(col.present)
            return SVGRenderer.BarGroup(label: col.name, value: s.mean, error: kind.halfLength(s))
        }
        return .bars(title: title, yLabel: kind.caption, groups: groups, brackets: brackets)
    case .box:
        let groups = cols.map { SVGRenderer.BoxGroup(label: $0.name, stats: BoxStats.compute($0.present)) }
        return .box(title: title, yLabel: "Value", groups: groups, brackets: brackets)
    case .violin:
        let groups = cols.map { col in
            SVGRenderer.ViolinGroup(label: col.name,
                                    density: KernelDensity.gaussian(col.present),
                                    stats: BoxStats.compute(col.present))
        }
        return .violin(title: title, yLabel: "Value", groups: groups, brackets: brackets)
    }
}

/// Render a figure to `path`, choosing SVG / PDF / PNG / TIFF from the file
/// extension (shared with the GUI via `FigureExport`).
func renderFigure(_ req: FigureExport.Request, to path: String, theme: Theme = .default) throws {
    let ext = (path as NSString).pathExtension.lowercased()
    guard FigureExport.supportedExtensions.contains(ext) else {
        throw CLIError("unsupported figure format '.\(ext)'. Use .svg, .pdf, .png, or .tiff")
    }
    guard let bytes = FigureExport.data(req, pathExtension: ext, theme: theme) else {
        throw CLIError("failed to render figure")
    }
    do {
        try bytes.write(to: URL(fileURLWithPath: path))
        print("Figure written to \(path)")
    } catch {
        throw CLIError("could not write figure to \(path): \(error.localizedDescription)")
    }
}

// MARK: - Option parsing

struct CLIError: Error { let message: String; init(_ m: String) { message = m } }

struct Options {
    private var positionals: [String] = []
    private var flags: Set<String> = []
    private var named: [String: String] = [:]

    init(_ args: [String]) {
        var i = 0
        while i < args.count {
            let arg = args[i]
            if arg.hasPrefix("--") {
                let key = String(arg.dropFirst(2))
                if i + 1 < args.count && !args[i + 1].hasPrefix("--") {
                    named[key] = args[i + 1]
                    i += 1
                } else {
                    flags.insert(key)
                }
            } else {
                positionals.append(arg)
            }
            i += 1
        }
    }

    func flag(_ name: String) -> Bool { flags.contains(name) }
    func value(_ name: String) -> String? { named[name] }

    /// Figure output path: `--out <path.ext>` (format by extension) or the
    /// legacy `--svg <path>`.
    var figurePath: String? { named["out"] ?? named["svg"] }

    /// Error-bar statistic for bar figures: `--error sd|sem|ci` (default SEM).
    var errorBarKind: ErrorBarKind {
        switch (named["error"] ?? "sem").lowercased() {
        case "sd": return .sd
        case "ci", "ci95", "95ci": return .ci95
        default: return .sem
        }
    }

    /// Figure style for column commands: `--plot bar|box|violin` (default bar).
    var plotStyle: PlotStyle {
        switch (named["plot"] ?? "bar").lowercased() {
        case "box": return .box
        case "violin": return .violin
        default: return .bar
        }
    }

    /// Journal theme for figures: `--theme <name>` (default Default).
    func resolvedTheme() throws -> Theme {
        guard let name = named["theme"] else { return .default }
        guard let theme = Theme.named(name) else {
            throw CLIError("unknown theme '\(name)'. Options: \(Theme.presets.map(\.name).joined(separator: ", "))")
        }
        return theme
    }

    var inputPath: String? { positionals.first }

    func loadTable(kind: TableKind) throws -> DataTable {
        guard let path = inputPath else { throw CLIError("no input file given") }
        let hasHeader = !flag("no-header")
        let table: DataTable
        if (path as NSString).pathExtension.lowercased() == "xlsx" {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
                throw CLIError("could not read file: \(path)")
            }
            do { table = try XLSXImporter().parse(data, kind: kind, hasHeader: hasHeader) }
            catch { throw CLIError("could not read xlsx \(path): \(error)") }
        } else {
            guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
                throw CLIError("could not read file: \(path)")
            }
            table = CSVImporter().parse(text, kind: kind, hasHeader: hasHeader)
        }
        guard !table.columns.isEmpty else { throw CLIError("no columns parsed from \(path)") }
        return table
    }

    /// Load an XY table and return aligned (x, y) pairs from columns 0 and 1,
    /// dropping rows where either is missing.
    func loadXY() throws -> (x: [Double], y: [Double]) {
        let table = try loadTable(kind: .xy)
        guard table.columns.count >= 2 else { throw CLIError("need an X column and at least one Y column") }
        let pairs = zip(table.columns[0].values, table.columns[1].values).compactMap { xv, yv -> (Double, Double)? in
            guard let x = xv, let y = yv else { return nil }
            return (x, y)
        }
        guard !pairs.isEmpty else { throw CLIError("no complete (x, y) rows") }
        return (pairs.map(\.0), pairs.map(\.1))
    }
}

func printUsage() {
    print("""
    benchgraph \(BenchGraph.version) — fast path from data to trustworthy stats and figures.

    USAGE:
      benchgraph <command> <file.csv|file.tsv|file.xlsx> [options]

    COMMANDS:
      describe      Descriptive statistics for every column
      ttest         Two-group t test on the first two columns
                      --paired      paired t test
                      --student     pooled-variance (default is Welch)
      anova         One-way ANOVA across all columns
      posthoc       ANOVA post-hoc pairwise comparisons (Bonferroni & Holm)
      mannwhitney   Nonparametric two-group comparison (first two columns)
      wilcoxon      Wilcoxon signed-rank test (first two columns, paired)
      normality     D'Agostino-Pearson normality test (per column)
      correlate     Correlation of columns 1 (X) and 2 (Y)
                      --spearman    rank correlation (default is Pearson)
      regress       Simple linear regression (X = col 1, Y = col 2)
                      --residuals   plot residuals instead of the fitted line
      doseresponse  4PL dose-response fit (X = concentration, Y = response)
                      --interpolate 50,75   read x at these y values
                      --residuals   plot residuals instead of the fitted curve

    GLOBAL OPTIONS:
      --no-header   treat the first row as data, not column names
      --out <path>  also export a figure; format from extension:
                      .svg .pdf .png .tiff
                      (describe, ttest, anova, posthoc, regress, doseresponse)
      --svg <path>  alias for --out with an .svg file
      --error <k>   bar error bars: sd | sem | ci  (default sem)
      --plot <k>    column figure style: bar | box | violin  (default bar)
      --theme <k>   journal theme: Default | Nature | Grayscale | Vibrant

    Column figures (describe, ttest, anova, posthoc) annotate comparisons with
    significance brackets (****<0.0001, ***<0.001, **<0.01, *<0.05, ns).

    EXAMPLES:
      benchgraph describe data.csv --out dist.svg --plot violin
      benchgraph ttest groups.csv --student --out fig.pdf --error ci
      benchgraph posthoc groups.csv --out posthoc.svg --plot box --theme Nature
      benchgraph doseresponse curve.csv --interpolate 50 --svg curve.svg
    """)
}
