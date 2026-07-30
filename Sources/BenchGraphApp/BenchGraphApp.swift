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

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
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
