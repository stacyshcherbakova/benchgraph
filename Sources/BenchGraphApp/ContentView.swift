import SwiftUI
import AppKit
import BenchGraphKit
import UniformTypeIdentifiers

/// House accent — indigo, matching the docs site theme for brand cohesion.
private let brandAccent = Color.indigo

struct ContentView: View {
    @StateObject private var model = AppModel()
    @State private var confirmingClearPanels = false
    @State private var helpTopic: HelpTopic?
    @State private var window: NSWindow?

    var body: some View {
        HSplitView {
            dataPane
                .frame(minWidth: 360, idealWidth: 420)
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
            ToolbarItemGroup(placement: .principal) {
                Button { model.undo() } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!model.canUndo)
                Button { model.redo() } label: {
                    Label("Redo", systemImage: "arrow.uturn.forward")
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!model.canRedo)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    copyFigureVector()
                } label: {
                    Label("Copy (vector)", systemImage: "doc.on.doc")
                }
                .disabled(model.chart == .none)
                .help("Copy the figure to the clipboard as vector PDF + SVG")
                Button {
                    exportFigure()
                } label: {
                    Label("Export chart…", systemImage: "square.and.arrow.up")
                }
                .disabled(model.chart == .none)
                .help("Export the chart currently on screen. To export the staged "
                      + "panels as one figure, use Export panels… in the Multi-panel section.")
            }
        }
        .tint(brandAccent)
        .background(WindowAccessor { window = $0 })
        .navigationTitle(model.documentName)
        .onReceive(model.$hasUnsavedChanges) { dirty in
            // The close button's dot and the "unsaved changes" behaviour macOS
            // gets for free from a document window; this app is a plain
            // WindowGroup, so it is set explicitly.
            window?.isDocumentEdited = dirty
        }
        .onReceive(NotificationCenter.default.publisher(for: .openBenchGraphProject)) { note in
            // Only the key window loads it. This used to broadcast to every open
            // window, so opening one project replaced the contents of all of
            // them and destroyed unsaved work in each.
            guard isKeyWindow, let url = note.object as? URL else { return }
            guard confirmDiscardingChanges(action: "Open “\(url.lastPathComponent)”") else { return }
            do {
                model.apply(try ProjectDocument.load(from: url), from: url)
            } catch {
                presentError("Could not open that project.", error)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .benchGraphFileCommand)) { note in
            guard isKeyWindow, let raw = note.object as? String,
                  let command = FileCommand(rawValue: raw) else { return }
            switch command {
            case .new:          newProject()
            case .open:         openProject()
            case .save:         saveProject()
            case .saveAs:       saveProjectAs()
            case .importData:   importFile()
            case .exportChart:  if model.chart != .none { exportFigure() }
            case .exportPanels: if model.panelCount > 0 { exportLayout() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showBenchGraphHelp)) { note in
            guard isKeyWindow, let slug = note.object as? String else { return }
            helpTopic = BenchGraphDocs.topic(slug)
        }
        .sheet(item: $helpTopic) { topic in
            HelpSheet(topic: topic)
        }
    }

    /// Whether this view's window is the one the user is working in. Menu
    /// commands and Finder-opened documents act only on that window.
    private var isKeyWindow: Bool {
        guard let window else { return NSApp.keyWindow == nil }
        return window.isKeyWindow
    }

    // MARK: - Left: data entry + editable table

    private var dataPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Data")
                    .font(.title3).bold()
                    .foregroundStyle(brandAccent)

                HStack {
                    Picker("Analysis", selection: analysisBinding) {
                        ForEach(Analysis.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                    Spacer()
                    Toggle("Header row", isOn: hasHeaderBinding)
                        .toggleStyle(.checkbox)
                }

                Text(model.analysis.hint)
                    .font(.caption).foregroundColor(.secondary)

                if model.analysis == .fourPL {
                    HStack(spacing: 6) {
                        Text("Interpolate x at y")
                            .font(.caption).foregroundColor(.secondary)
                        TextField("e.g. 50, 75", text: interpolateBinding,
                                  onEditingChanged: interpolateEditBracket)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.caption, design: .monospaced))
                            .frame(width: 120)
                            .help("Read the concentration back at these response "
                                  + "values — the standard-curve workflow")
                    }
                }

                if model.isColumnChart {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 12) {
                            Picker("Plot", selection: columnPlotBinding) {
                                ForEach(ColumnPlot.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .fixedSize()
                            Spacer()
                            Toggle("Significance", isOn: showSignificanceBinding)
                                .toggleStyle(.checkbox)
                        }
                        if model.isBarChart {
                            Picker("Error bars", selection: errorBarBinding) {
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
                    Picker("Theme", selection: themeBinding) {
                        ForEach(Theme.presets, id: \.name) { Text($0.name).tag($0.name) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    Spacer()
                }
                .controlSize(.small)

                EditableTableView(model: model)

                HStack {
                    Button { model.addRow() } label: { Label("Row", systemImage: "plus") }
                    Button { model.addColumn() } label: { Label("Column", systemImage: "plus") }
                    Button { pasteFromClipboard() } label: { Label("Paste", systemImage: "doc.on.clipboard") }
                    Button { importFile() } label: { Label("Import…", systemImage: "square.and.arrow.down") }
                    Spacer()
                    Button("Sample") { model.loadSample() }
                    Button("Clear") { model.clear() }
                }
                .controlSize(.small)

                Divider().padding(.vertical, 2)
                panelSection
            }
            .padding(14)
        }
    }

    // MARK: - Multi-panel figure staging

    private var panelSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Multi-panel figure")
                .font(.caption).bold().foregroundColor(.secondary)
            Text("Capture the chart on the right as a panel, build up A, B, C…, then export them as one combined journal-style figure. Drag the cards to reorder.")
                .font(.caption2).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { model.addCurrentPanel() }
                } label: {
                    Label("Add current chart", systemImage: "plus.square.on.square")
                }
                .disabled(model.chart == .none)
                .help("Capture the chart shown on the right as the next panel")
                Spacer()
                if model.panelCount > 1 {
                    Stepper("Columns: \(model.layoutColumns)",
                            value: Binding(get: { model.layoutColumns },
                                           set: { model.setLayoutColumns($0) }),
                            in: 1...4)
                        .fixedSize()
                        .help("How many panels per row in the composed figure")
                }
            }

            if model.panelCount == 0 {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundColor(Color.gray.opacity(0.4))
                    .frame(height: 54)
                    .overlay(
                        Text("No panels yet — charts you add appear here")
                            .font(.caption2).foregroundColor(.secondary)
                    )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(Array(model.stagedPanels.enumerated()), id: \.element.id) { i, panel in
                            PanelCard(
                                label: model.panelLabels[i],
                                title: panel.title,
                                image: model.thumbnailImage(for: panel.id),
                                id: panel.id,
                                canMoveLeft: i > 0,
                                canMoveRight: i < model.panelCount - 1,
                                onMoveLeft: { withAnimation { model.movePanel(panel.id, by: -1) } },
                                onMoveRight: { withAnimation { model.movePanel(panel.id, by: 1) } },
                                onRemove: { withAnimation { model.removePanel(panel.id) } },
                                onDropPanel: { draggedID in
                                    guard draggedID != panel.id else { return false }
                                    withAnimation { model.movePanel(draggedID, to: i) }
                                    return true
                                }
                            )
                        }
                    }
                    .padding(2)
                }
                HStack(spacing: 8) {
                    Button { exportLayout() } label: {
                        Label("Export panels…", systemImage: "square.grid.2x2")
                    }
                    .help("Combine the staged panels into one multi-panel figure")
                    Button("Clear") { confirmingClearPanels = true }
                        .help("Remove every staged panel")
                    Spacer()
                    Text(layoutSummary)
                        .font(.caption2).foregroundColor(.secondary)
                }
                .confirmationDialog("Remove all \(model.panelCount) staged panel\(model.panelCount == 1 ? "" : "s")?",
                                    isPresented: $confirmingClearPanels, titleVisibility: .visible) {
                    Button("Clear panels", role: .destructive) {
                        withAnimation { model.clearPanels() }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This can be undone with ⌘Z.")
                }
            }
        }
        .controlSize(.small)
    }

    /// E.g. "3 panels · 2×2 grid" for the current staging and column count.
    private var layoutSummary: String {
        let n = model.panelCount
        let cols = min(model.layoutColumns, n)
        let rows = Int((Double(n) / Double(model.layoutColumns)).rounded(.up))
        return "\(n) panel\(n == 1 ? "" : "s") · \(rows)×\(cols) grid"
    }

    // MARK: - Right: results + chart

    private var resultsPane: some View {
        // A draggable split so the results/metadata and the chart can be resized;
        // the results get a taller default so a typical result shows without scrolling.
        VSplitView {
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
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 220, idealHeight: 430)

            VStack(spacing: 0) {
                if model.supportsResiduals {
                    HStack {
                        ChartModeTabs(showResiduals: showResidualsBinding)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .windowBackgroundColor))
                    Divider()
                }
                ChartView(spec: model.chart, theme: model.theme)
            }
            .frame(minHeight: 260, idealHeight: 360)
        }
    }

    // MARK: - Option bindings (routed through the model for undo)

    private var analysisBinding: Binding<Analysis> {
        Binding(get: { model.analysis }, set: { model.setAnalysis($0) })
    }
    private var hasHeaderBinding: Binding<Bool> {
        Binding(get: { model.hasHeader }, set: { model.setHasHeader($0) })
    }
    private var columnPlotBinding: Binding<ColumnPlot> {
        Binding(get: { model.columnPlot }, set: { model.setColumnPlot($0) })
    }
    private var showSignificanceBinding: Binding<Bool> {
        Binding(get: { model.showSignificance }, set: { model.setShowSignificance($0) })
    }
    private var showResidualsBinding: Binding<Bool> {
        Binding(get: { model.showResiduals }, set: { model.setShowResiduals($0) })
    }
    private var errorBarBinding: Binding<ErrorBarKind> {
        Binding(get: { model.errorBar }, set: { model.setErrorBar($0) })
    }
    private var themeBinding: Binding<String> {
        Binding(get: { model.theme.name }, set: { if let t = Theme.named($0) { model.setTheme(t) } })
    }
    private var interpolateBinding: Binding<String> {
        Binding(get: { model.interpolateText }, set: { model.setInterpolateText($0) })
    }

    /// Collapse a typing session in the interpolation field into one undo step,
    /// the same way grid cells do.
    private func interpolateEditBracket(_ began: Bool) {
        if began { model.beginInteractiveEdit() } else { model.commitInteractiveEdit() }
    }

    // MARK: - Actions

    private func pasteFromClipboard() {
        if let s = NSPasteboard.general.string(forType: .string), !s.isEmpty {
            model.replaceData(with: s)
        }
    }

    /// Import data from an .xlsx workbook or a CSV/TSV file into the grid.
    private func importFile() {
        let panel = NSOpenPanel()
        var types: [UTType] = [.commaSeparatedText, .tabSeparatedText, .plainText]
        if let xlsx = UTType(filenameExtension: "xlsx") { types.insert(xlsx, at: 0) }
        panel.allowedContentTypes = types
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if url.pathExtension.lowercased() == "xlsx" {
            if let data = try? Data(contentsOf: url),
               let csv = try? XLSXImporter().csvText(from: data) {
                model.replaceData(with: csv)
            }
        } else if let text = try? String(contentsOf: url, encoding: .utf8) {
            model.replaceData(with: text)
        }
    }

    /// Copy the current figure to the clipboard as vector data: PDF (widely
    /// pasteable into Illustrator, Keynote, Word) plus SVG for vector editors.
    private func copyFigureVector() {
        guard let pdf = model.figureData(pathExtension: "pdf") else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(pdf, forType: .pdf)
        if let svg = model.figureData(pathExtension: "svg") {
            pb.setData(svg, forType: NSPasteboard.PasteboardType("public.svg-image"))
        }
    }

    private var projectType: UTType {
        UTType(filenameExtension: ProjectDocument.fileExtension) ?? .json
    }

    /// ⌘S: write back to the file this project came from, asking for a location
    /// only the first time.
    private func saveProject() {
        guard let url = model.documentURL else { return saveProjectAs() }
        write(to: url)
    }

    private func saveProjectAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [projectType]
        panel.nameFieldStringValue = model.documentURL?.lastPathComponent
            ?? "untitled.\(ProjectDocument.fileExtension)"
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url { write(to: url) }
    }

    private func write(to url: URL) {
        do {
            try model.makeDocument().save(to: url)
            model.markSaved(to: url)
        } catch {
            presentError("Could not save the project.", error)
        }
    }

    private func openProject() {
        guard confirmDiscardingChanges(action: "Open another project") else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [projectType]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            model.apply(try ProjectDocument.load(from: url), from: url)
        } catch {
            presentError("Could not open that project.", error)
        }
    }

    private func newProject() {
        guard confirmDiscardingChanges(action: "Start a new project") else { return }
        model.newProject()
    }

    /// Ask before throwing away unsaved work. Returns whether to proceed.
    private func confirmDiscardingChanges(action: String) -> Bool {
        guard model.hasUnsavedChanges else { return true }
        let alert = NSAlert()
        alert.messageText = "\(action) without saving?"
        alert.informativeText = "“\(model.documentName)” has unsaved changes that will be lost."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save…")
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            saveProject()
            return !model.hasUnsavedChanges   // cancelled the save sheet → stop
        case .alertSecondButtonReturn:
            return true
        default:
            return false
        }
    }

    private func presentError(_ message: String, _ error: Error) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = String(describing: error)
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func exportFigure() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.svg, .pdf, .png, .tiff]
        panel.nameFieldStringValue = "figure.pdf"
        panel.canCreateDirectories = true
        panel.message = "A .manifest.json recording the data source and analysis options is written alongside the figure."
        if panel.runModal() == .OK, let url = panel.url {
            let ext = url.pathExtension.isEmpty ? "pdf" : url.pathExtension
            if let data = model.figureData(pathExtension: ext) {
                try? data.write(to: url)
                writeManifest(model.exportManifest(), besideFigure: url)
            }
        }
    }

    private func exportLayout() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf, .svg, .png, .tiff]
        panel.nameFieldStringValue = "figure-panels.pdf"
        panel.canCreateDirectories = true
        panel.message = "Exports the staged panels as one multi-panel figure, with a .manifest.json alongside."
        if panel.runModal() == .OK, let url = panel.url {
            let ext = url.pathExtension.isEmpty ? "pdf" : url.pathExtension
            if let data = model.layoutData(pathExtension: ext, columns: model.layoutColumns) {
                try? data.write(to: url)
                writeManifest(model.layoutManifest(), besideFigure: url)
            }
        }
    }

    /// Write a provenance manifest as `<figure-basename>.manifest.json` next to
    /// the exported figure.
    private func writeManifest(_ encode: @autoclosure () -> Data?, besideFigure url: URL) {
        guard let data = encode() else { return }
        let manifestURL = url.deletingLastPathComponent()
            .appendingPathComponent(ExportManifest.filename(forFigure: url.lastPathComponent))
        try? data.write(to: manifestURL)
    }
}

private extension ContentView {
    func writeManifest(_ manifest: ExportManifest, besideFigure url: URL) {
        writeManifest(try? manifest.encoded(), besideFigure: url)
    }
    func writeManifest(_ manifest: LayoutManifest, besideFigure url: URL) {
        writeManifest(try? manifest.encoded(), besideFigure: url)
    }
}

// MARK: - Window access

/// Reaches the `NSWindow` behind a SwiftUI view, so this plain `WindowGroup` can
/// show the edited dot and tell whether it is the key window. A `DocumentGroup`
/// would provide both, but the app is not document-based.
private struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { onResolve(view.window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { onResolve(view.window) }
    }
}

// MARK: - Help

/// One help card: the short, task-shaped form of a published guide page, with a
/// link out to the long form. Content comes from `BenchGraphDocs.topics` so the
/// app and the site cannot drift apart silently (spec D6).
private struct HelpSheet: View {
    let topic: HelpTopic
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(topic.title)
                    .font(.title2.bold())
                Text(topic.summary)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(topic.steps.enumerated()), id: \.offset) { i, step in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(i + 1)")
                                .font(.caption.bold().monospacedDigit())
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(Circle().fill(brandAccent))
                            Text(step)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Button("Read the full guide online") {
                    NSWorkspace.shared.open(BenchGraphDocs.url(forGuide: topic.id))
                }
                .buttonStyle(.link)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 480, height: 460)
    }
}

// MARK: - Panel drag payload

extension UTType {
    /// Private drag type for reordering staged panels. Declaring our own type
    /// (rather than dragging plain text) means a card only accepts another card
    /// — text dragged in from another app is not a valid drop.
    static let benchGraphPanel = UTType(exportedAs: "com.benchgraph.panel")
}

/// The identity of a panel being dragged within the tray.
private struct PanelDragItem: Codable, Transferable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .benchGraphPanel)
    }
}

// MARK: - Staged panel card

/// A staged panel in the multi-panel tray: a thumbnail of the captured chart,
/// its A/B/C badge, the title, and remove/reorder controls.
///
/// Reordering has two paths that share one model call: dragging a card onto
/// another, and the right-click Move left / Move right menu. The menu is kept
/// because drag-and-drop is not keyboard-accessible.
private struct PanelCard: View {
    let label: String
    let title: String
    let image: NSImage?
    let id: UUID
    let canMoveLeft: Bool
    let canMoveRight: Bool
    let onMoveLeft: () -> Void
    let onMoveRight: () -> Void
    let onRemove: () -> Void
    /// Handle another card being dropped here. Returns whether it was accepted.
    let onDropPanel: (UUID) -> Bool

    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .topLeading) {
                thumbnail
                Text(label)
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(brandAccent))
                    .padding(4)
            }
            .overlay(alignment: .topTrailing) {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.gray.opacity(0.85))
                }
                .buttonStyle(.plain)
                .padding(2)
                .help("Remove panel")
            }
            Text(title)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(.secondary)
                .frame(width: 108)
        }
        .overlay(alignment: .leading) {
            // Insertion indicator. Drawn as an overlay on fixed-size geometry so
            // nothing reflows while a drag is in flight.
            if isTargeted {
                Capsule()
                    .fill(brandAccent)
                    .frame(width: 3)
                    .padding(.vertical, 2)
                    .offset(x: -5)
            }
        }
        .contextMenu {
            Button("Move left", action: onMoveLeft).disabled(!canMoveLeft)
            Button("Move right", action: onMoveRight).disabled(!canMoveRight)
            Divider()
            Button("Remove", role: .destructive, action: onRemove)
        }
        .draggable(PanelDragItem(id: id))
        .dropDestination(for: PanelDragItem.self) { items, _ in
            guard let dragged = items.first else { return false }
            return onDropPanel(dragged.id)
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }

    private var thumbnail: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "chart.bar")
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 108, height: 79)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.gray.opacity(0.3)))
    }
}

// MARK: - Chart mode tabs

/// A small accent-pill segmented control for switching the chart between the
/// fitted graph and the residual plot. Reads as two tabs; the active one is
/// filled with the brand accent.
private struct ChartModeTabs: View {
    @Binding var showResiduals: Bool

    var body: some View {
        HStack(spacing: 3) {
            tab("Graph", icon: "chart.xyaxis.line", selected: !showResiduals) { showResiduals = false }
            tab("Residuals", icon: "chart.dots.scatter", selected: showResiduals) { showResiduals = true }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.4))
        )
    }

    private func tab(_ title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.callout.weight(selected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .foregroundStyle(selected ? Color.white : Color.secondary)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(selected ? brandAccent : Color.clear)
                        .shadow(color: selected ? brandAccent.opacity(0.35) : .clear, radius: 3, y: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: selected)
    }
}

// MARK: - Editable table

/// A spreadsheet-like editable grid. Cells and headers are plain text fields;
/// edits flow straight into the model (live recompute) and coalesce into a
/// single undo step per editing session via `begin/commitInteractiveEdit`.
private struct EditableTableView: View {
    @ObservedObject var model: AppModel
    private let cellWidth: CGFloat = 92
    private let gutter: CGFloat = 26

    var body: some View {
        let grid = model.grid
        VStack(alignment: .leading, spacing: 4) {
            Text("Table — type to edit, ⌘Z to undo")
                .font(.caption).foregroundColor(.secondary)
            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 3) {
                    headerRow(grid)
                    ForEach(0..<grid.rowCount, id: \.self) { r in
                        dataRow(grid, r)
                    }
                }
                .padding(6)
            }
            .frame(minHeight: 150, maxHeight: 240)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.25)))
        }
    }

    private func headerRow(_ grid: EditGrid) -> some View {
        HStack(spacing: 3) {
            Color.clear.frame(width: gutter, height: 1)
            ForEach(0..<grid.columnCount, id: \.self) { c in
                HStack(spacing: 2) {
                    if model.hasHeader {
                        TextField("", text: columnNameBinding(c), onEditingChanged: editBracket)
                            .textFieldStyle(.plain)
                            .font(.system(.caption, design: .default).bold())
                            .frame(width: cellWidth - 16)
                    } else {
                        Text(grid.columnNames[c])
                            .font(.caption).bold().foregroundColor(.secondary)
                            .frame(width: cellWidth - 16, alignment: .leading)
                    }
                    Button { model.removeColumn(c) } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 9))
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                    .help("Delete column")
                    .disabled(grid.columnCount <= 1)
                }
                .frame(width: cellWidth)
            }
        }
    }

    private func dataRow(_ grid: EditGrid, _ r: Int) -> some View {
        HStack(spacing: 3) {
            Button { model.removeRow(r) } label: {
                Image(systemName: "minus.circle").font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)
            .frame(width: gutter)
            .help("Delete row")
            .disabled(grid.rowCount <= 1)

            ForEach(0..<grid.columnCount, id: \.self) { c in
                TextField("", text: cellBinding(r, c), onEditingChanged: editBracket)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: cellWidth)
            }
        }
    }

    // Undo bracketing for a typing session.
    private func editBracket(_ began: Bool) {
        if began { model.beginInteractiveEdit() } else { model.commitInteractiveEdit() }
    }

    private func cellBinding(_ r: Int, _ c: Int) -> Binding<String> {
        Binding(get: { model.grid.cell(r, c) }, set: { model.updateCell(r, c, $0) })
    }

    private func columnNameBinding(_ c: Int) -> Binding<String> {
        Binding(
            get: { model.grid.columnNames.indices.contains(c) ? model.grid.columnNames[c] : "" },
            set: { model.renameColumn(c, to: $0) }
        )
    }
}

// MARK: - Result display

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
