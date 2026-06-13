import SwiftUI
import AppKit

@main
struct CadenceApp: App {
    @StateObject private var store: Store
    @StateObject private var tracker: Tracker
    @StateObject private var sync: SyncManager
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        let s = Store()
        _store = StateObject(wrappedValue: s)
        _tracker = StateObject(wrappedValue: Tracker(store: s))
        _sync = StateObject(wrappedValue: SyncManager(store: s))
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(store)
                .environmentObject(tracker)
                .environmentObject(sync)
                .frame(minWidth: 820, minHeight: 540)
                .preferredColorScheme(.dark)
        }
        .windowResizability(.contentMinSize)

        // Lives in the menu bar so tracking continues with the window closed.
        MenuBarExtra("Cadence", systemImage: tracker.isWorking ? "record.circle" : "pause.circle") {
            MenuBarContent()
                .environmentObject(store)
                .environmentObject(tracker)
        }
    }
}

struct MenuBarContent: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var tracker: Tracker
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(tracker.status)
        Text("Today: \(hours(store.seconds(on: Date()))) work")
        Divider()
        Toggle("Track activity", isOn: $tracker.isWorking)
        Button("Open Cadence") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Divider()
        Button("Quit Cadence") { NSApp.terminate(nil) }
    }

    private func hours(_ seconds: Int) -> String {
        let h = Double(seconds) / 3600
        if h >= 1 { return String(format: "%.1fh", h) }
        return "\(seconds / 60)m"
    }
}

/// Keeps the app alive when the window closes (tracking continues from the
/// menu bar) and brings the window back when the Dock icon is clicked.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
