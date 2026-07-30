import SwiftUI
import AppKit

extension Notification.Name {
    /// Posted with a `.benchgraph` file URL when the OS asks the app to open a
    /// project (double-click in Finder, `open` command, drag onto the Dock).
    static let openBenchGraphProject = Notification.Name("openBenchGraphProject")
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
