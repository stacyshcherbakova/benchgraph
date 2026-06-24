import SwiftUI
import AppKit

/// App entry point. The `NSApplicationDelegateAdaptor` makes the executable
/// behave as a normal foreground GUI app (Dock icon + focus) even when it is
/// launched directly rather than from a fully signed .app bundle.
@main
struct BenchGraphApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("BenchGraph") {
            ContentView()
                .frame(minWidth: 960, minHeight: 620)
        }
        .windowStyle(.titleBar)
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
}
