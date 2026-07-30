import SwiftUI
import AppKit
import BenchGraphKit

extension Notification.Name {
    /// Posted with a `.benchgraph` file URL when the OS asks the app to open a
    /// project (double-click in Finder, `open` command, drag onto the Dock).
    static let openBenchGraphProject = Notification.Name("openBenchGraphProject")

    /// Posted with a `HelpTopic` slug when a Help menu item is chosen. The open
    /// window observes it and presents the matching card — the same
    /// menu-to-window bridge the project-open path uses.
    static let showBenchGraphHelp = Notification.Name("showBenchGraphHelp")

    /// Posted with a `FileCommand` raw value when a File menu item is chosen.
    /// Only the key window acts on it, so the command lands where the user is
    /// looking rather than in every open window.
    static let benchGraphFileCommand = Notification.Name("benchGraphFileCommand")
}

/// The File-menu actions, bridged from the menu bar to the key window.
enum FileCommand: String {
    case new, open, save, saveAs, importData, exportChart, exportPanels
}

/// App entry point. The `NSApplicationDelegateAdaptor` makes the executable
/// behave as a normal foreground GUI app (Dock icon + focus) even when it is
/// launched directly rather than from a fully signed .app bundle.
@main
struct BenchGraphApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("BenchGraph") {
            ContentView()
                .frame(minWidth: 1040, minHeight: 660)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1360, height: 760)
        .commands {
            // Mac users look in File first. Without these, ⌘S and ⌘O did
            // nothing at all while Open and Save existed only as toolbar icons.
            CommandGroup(replacing: .newItem) {
                fileButton("New", .new, key: "n")
                fileButton("Open…", .open, key: "o")
            }
            CommandGroup(replacing: .saveItem) {
                fileButton("Save", .save, key: "s")
                fileButton("Save As…", .saveAs, key: "s", modifiers: [.command, .shift])
                Divider()
                fileButton("Import Data…", .importData, key: "i")
                Divider()
                fileButton("Export Chart…", .exportChart, key: "e")
                fileButton("Export Panels…", .exportPanels, key: "e",
                           modifiers: [.command, .shift])
            }
            // Replace the stock Help menu: there is no Help Book to search, so
            // its search field would find nothing. These items open the in-app
            // cards and the published guide instead.
            CommandGroup(replacing: .help) {
                Button("BenchGraph Quick Start") {
                    NotificationCenter.default.post(name: .showBenchGraphHelp,
                                                    object: "getting-started")
                }
                .keyboardShortcut("?", modifiers: .command)
                Button("Choosing An Analysis") {
                    NotificationCenter.default.post(name: .showBenchGraphHelp,
                                                    object: "choosing-an-analysis")
                }
                Button("Multi-Panel Figures") {
                    NotificationCenter.default.post(name: .showBenchGraphHelp,
                                                    object: "multi-panel-figures")
                }
                Button("Exporting And Provenance") {
                    NotificationCenter.default.post(name: .showBenchGraphHelp,
                                                    object: "exporting-and-provenance")
                }
                Divider()
                Button("Full Documentation Online") {
                    NSWorkspace.shared.open(BenchGraphDocs.siteURL)
                }
            }
        }
    }
}

/// A File-menu item that posts its command to the key window.
@ViewBuilder
private func fileButton(_ title: String, _ command: FileCommand,
                        key: KeyEquivalent, modifiers: EventModifiers = .command) -> some View {
    Button(title) {
        NotificationCenter.default.post(name: .benchGraphFileCommand,
                                        object: command.rawValue)
    }
    .keyboardShortcut(key, modifiers: modifiers)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Warn before quitting with unsaved work. `isDocumentEdited` is kept in
    /// sync with the model by `ContentView`, so this reads the same state the
    /// close button's dot does.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let edited = sender.windows.filter(\.isDocumentEdited)
        guard !edited.isEmpty else { return .terminateNow }

        let alert = NSAlert()
        alert.messageText = edited.count == 1
            ? "Quit without saving?"
            : "Quit without saving \(edited.count) projects?"
        alert.informativeText = "Your changes will be lost."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit Anyway")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }

    /// Route Finder-opened `.benchgraph` documents to the live window. The open
    /// window observes `.openBenchGraphProject` and loads the project.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.pathExtension == ProjectDocumentExtension {
            NotificationCenter.default.post(name: .openBenchGraphProject, object: url)
        }
    }
}

/// The registered project extension, mirrored here so the delegate does not need
/// to import the engine type just for a string constant.
let ProjectDocumentExtension = "benchgraph"
