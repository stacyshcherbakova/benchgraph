import SwiftUI
import AppKit
import BenchGraphKit
import UniformTypeIdentifiers

/// House accent — indigo, matching the docs site theme for brand cohesion.
private let brandAccent = Color.indigo

struct ContentView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        HSplitView {
            dataPane
                .frame(minWidth: 320, idealWidth: 380)
            resultsPane
                .frame(minWidth: 420)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button { openProject() } label: {
                    Label("Open", systemImage: "folder")
                }
                Button { saveProject() } label: {
                    Label("Save", systemImage: "tray.and.arrow.down")
                }
            }
            ToolbarItem(placement: .principal) {
                Text("BenchGraph").font(.headline)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    exportFigure()
                } label: {
                    Label("Export figure…", systemImage: "square.and.arrow.up")
                }
                .disabled(model.chart == .none)
            }
        }
        .tint(brandAccent)
    }

    // MARK: - Left: data entry + preview

    private var dataPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Data")
                .font(.title3).bold()
                .foregroundStyle(brandAccent)

            HStack {
                Picker("Analysis", selection: $model.analysis) {
                    ForEach(Analysis.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden()
                Spacer()
                Toggle("Header row", isOn: $model.hasHeader)
                    .toggleStyle(.checkbox)
            }

            Text(model.analysis.hint)
                .font(.caption).foregroundColor(.secondary)

            if model.isColumnChart {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        Picker("Plot", selection: $model.columnPlot) {
                            ForEach(ColumnPlot.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                        Spacer()
                        Toggle("Significance", isOn: $model.showSignificance)
                            .toggleStyle(.checkbox)
                    }
                    if model.isBarChart {
                        Picker("Error bars", selection: $model.errorBar) {
                            ForEach(ErrorBarKind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                }
                .controlSize(.small)
            }

            HStack(spacing: 8) {
                Text("Theme").font(.caption).foregroundColor(.secondary)
                Picker("Theme", selection: Binding(
                    get: { model.theme.name },
                    set: { if let t = Theme.named($0) { model.theme = t } }
                )) {
                    ForEach(Theme.presets, id: \.name) { Text($0.name).tag($0.name) }
                }
                .labelsHidden()
                .fixedSize()
                Spacer()
            }
            .controlSize(.small)

            Text("Paste CSV / TSV (from Excel or Numbers)")
                .font(.caption).foregroundColor(.secondary)
            TextEditor(text: $model.rawText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 160)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))

            HStack {
                Button("Load sample") { loadSample() }
                Button("Clear") { model.rawText = "" }
                Spacer()
            }
            .controlSize(.small)

            if let table = model.table, !table.columns.isEmpty {
                Text("Parsed preview")
                    .font(.caption).foregroundColor(.secondary)
                DataPreview(table: table)
            }
            Spacer()
        }
        .padding(14)
    }

    // MARK: - Right: results + chart

    private var resultsPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let message = model.errorMessage {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .padding(.top, 4)
                    }
                    if let result = model.result {
                        ResultCard(result: result)
                    }
                }
                .padding(14)
            }
            Divider()
            ChartView(spec: model.chart, theme: model.theme)
                .frame(minHeight: 260)
        }
    }

    // MARK: - Actions

    private func loadSample() {
        switch model.analysis.tableKind {
        case .xy:
            model.rawText = "Concentration,Response\n1,9.1\n3,23.0\n10,49.5\n30,75.2\n100,90.9\n300,96.8"
        default:
            model.rawText = "Control,Treated\n5.1,7.2\n4.8,6.9\n5.5,7.8\n5.0,7.1\n4.9,6.5\n5.3,7.6"
        }
    }

    private var projectType: UTType {
        UTType(filenameExtension: ProjectDocument.fileExtension) ?? .json
    }

    private func saveProject() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [projectType]
        panel.nameFieldStringValue = "untitled.\(ProjectDocument.fileExtension)"
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            try? model.makeDocument().save(to: url)
        }
    }

    private func openProject() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [projectType]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url,
           let doc = try? ProjectDocument.load(from: url) {
            model.apply(doc)
        }
    }

    private func exportFigure() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.svg, .pdf, .png, .tiff]
        panel.nameFieldStringValue = "figure.pdf"
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            let ext = url.pathExtension.isEmpty ? "pdf" : url.pathExtension
            if let data = model.figureData(pathExtension: ext) {
                try? data.write(to: url)
            }
        }
    }
}

// MARK: - Components

/// Read-only grid preview of the parsed table (first rows).
private struct DataPreview: View {
    let table: DataTable
    private let maxRows = 10

    private var rowCount: Int { table.columns.map { $0.values.count }.max() ?? 0 }

    var body: some View {
        let shown = min(rowCount, maxRows)
        ScrollView(.horizontal, showsIndicators: true) {
            Grid(alignment: .trailing, horizontalSpacing: 14, verticalSpacing: 3) {
                GridRow {
                    ForEach(Array(table.columns.enumerated()), id: \.offset) { _, col in
                        Text(col.name).font(.caption).bold()
                    }
                }
                Divider()
                ForEach(0..<shown, id: \.self) { row in
                    GridRow {
                        ForEach(Array(table.columns.enumerated()), id: \.offset) { _, col in
                            Text(cell(col, row))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(col.values.indices.contains(row) && col.values[row] == nil ? .secondary : .primary)
                        }
                    }
                }
            }
            .padding(8)
        }
        .frame(maxHeight: 170)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
        .overlay(alignment: .bottom) {
            if rowCount > maxRows {
                Text("… \(rowCount - maxRows) more rows")
                    .font(.caption2).foregroundColor(.secondary)
                    .padding(2)
            }
        }
    }

    private func cell(_ col: DataColumn, _ row: Int) -> String {
        guard col.values.indices.contains(row) else { return "" }
        guard let v = col.values[row] else { return "—" }
        return v == v.rounded() ? String(format: "%.0f", v) : String(format: "%g", v)
    }
}

/// Provenance-rich result display: numbers, then assumptions/warnings.
private struct ResultCard: View {
    let result: AnalysisResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(result.analysis).font(.title3).bold().foregroundStyle(brandAccent)
            Text(result.formula)
                .font(.caption).foregroundColor(.secondary)
                .textSelection(.enabled)

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 4) {
                ForEach(Array(result.values.enumerated()), id: \.offset) { _, v in
                    GridRow {
                        Text(v.label).foregroundColor(.secondary)
                        Text(format(v.value))
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .gridColumnAlignment(.trailing)
                    }
                }
            }

            if !result.assumptions.isEmpty {
                section(title: "Assumptions", systemImage: "checkmark.seal", color: .secondary,
                        items: result.assumptions)
            }
            if !result.warnings.isEmpty {
                section(title: "Warnings", systemImage: "exclamationmark.triangle", color: .orange,
                        items: result.warnings)
            }
            if result.excludedCount > 0 {
                Text("Excluded cells (missing / non-numeric): \(result.excludedCount)")
                    .font(.caption).foregroundColor(.secondary)
            }
            Text("Engine: BenchGraph \(result.engineVersion)")
                .font(.caption2).foregroundColor(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(brandAccent.opacity(0.15), lineWidth: 1)
        )
    }

    private func section(title: String, systemImage: String, color: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: systemImage).font(.subheadline).foregroundColor(color)
            ForEach(items, id: \.self) { item in
                Text("• \(item)").font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(.top, 4)
    }

    private func format(_ v: Double) -> String {
        if v.isNaN { return "n/a" }
        if v == v.rounded() && abs(v) < 1e6 { return String(format: "%.0f", v) }
        let a = abs(v)
        if a != 0 && (a < 1e-4 || a >= 1e6) { return String(format: "%.4g", v) }
        return String(format: "%.5g", v)
    }
}
