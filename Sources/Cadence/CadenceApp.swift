import SwiftUI
import AppKit

@main
struct CadenceApp: App {
    @StateObject private var store: Store
    @StateObject private var tracker: Tracker
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        let s = Store()
        _store = StateObject(wrappedValue: s)
        _tracker = StateObject(wrappedValue: Tracker(store: s))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(tracker)
                .frame(minWidth: 820, minHeight: 540)
        }
        .windowResizability(.contentMinSize)
    }
}

/// Saves on quit and keeps the app as a normal windowed app.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
