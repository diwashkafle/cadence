import Foundation
import AppKit
import Combine

/// Drives work tracking. Every `interval` seconds it samples the frontmost
/// app, checks idle time, and (when "working mode" is on) credits time to the
/// store if the active app — or the active browser tab's website — is tracked.
final class Tracker: ObservableObject {
    @Published var isWorking = false {
        didSet { isWorking ? start() : stop() }
    }
    /// Human-readable description of what's happening right now.
    @Published var status = "Idle"
    /// Whether the current sample is being counted at all.
    @Published var counting = false
    /// Which bucket the current sample is counting toward (nil when not counting).
    @Published var activeCategory: Category? = nil

    private let store: Store
    private let interval: TimeInterval = 5
    private var timer: Timer?

    /// Bundle IDs that support the Chrome AppleScript dialect.
    private let chromeFamily: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.canary",
        "com.brave.Browser", "com.brave.Browser.beta",
        "com.microsoft.edgemac", "com.vivaldi.Vivaldi",
        "company.thebrowser.Browser",      // Arc
        "com.operasoftware.Opera"
    ]
    private let safariFamily: Set<String> = ["com.apple.Safari", "com.apple.SafariTechnologyPreview"]

    init(store: Store) {
        self.store = store
    }

    private func start() {
        status = "Tracking…"
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        tick()
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        counting = false
        activeCategory = nil
        status = "Paused"
        store.saveNow()
    }

    // MARK: Sampling

    private func tick() {
        // 1. Idle check — don't count time when the user is away.
        let idle = Int(idleSeconds())
        if idle >= store.data.idleThreshold {
            counting = false
            activeCategory = nil
            status = "Away (idle \(idle)s)"
            return
        }

        // 2. Who's in front?
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier else {
            counting = false
            activeCategory = nil
            status = "No active app"
            return
        }
        let appName = app.localizedName ?? bundleID

        // 3. Is the app itself categorised?
        if let tracked = store.trackedApp(bundleID: bundleID) {
            credit(seconds: Int(interval), bucket: appName, label: appName, category: tracked.category)
            return
        }

        // 4. Otherwise, if it's a browser, classify by the active tab's domain.
        if let url = browserURL(for: bundleID), let host = host(from: url) {
            if let site = store.trackedSite(matching: host) {
                credit(seconds: Int(interval), bucket: site.host,
                       label: "\(site.host) — \(appName)", category: site.category)
                return
            }
            counting = false
            activeCategory = nil
            status = "\(appName): \(host) (not categorised)"
            return
        }

        // 5. Not categorised.
        counting = false
        activeCategory = nil
        status = "\(appName) (not categorised)"
    }

    private func credit(seconds: Int, bucket: String, label: String, category: Category) {
        store.addWork(seconds: seconds, label: bucket, category: category)
        counting = true
        activeCategory = category
        status = "\(category.label) — \(label)"
    }

    // MARK: System queries

    /// Seconds since the last keyboard/mouse input, system-wide.
    private func idleSeconds() -> CFTimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState,
                                                eventType: .null)
    }

    private func host(from urlString: String) -> String? {
        guard let url = URL(string: urlString), let host = url.host else { return nil }
        return host.lowercased()
    }

    /// Reads the front tab's URL from a supported browser via AppleScript.
    /// Returns nil for unsupported browsers (e.g. Firefox) or if permission
    /// hasn't been granted yet.
    private func browserURL(for bundleID: String) -> String? {
        let source: String
        if safariFamily.contains(bundleID) {
            source = "tell application id \"\(bundleID)\" to return URL of front document"
        } else if chromeFamily.contains(bundleID) {
            source = "tell application id \"\(bundleID)\" to return URL of active tab of front window"
        } else {
            return nil
        }
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let result = script.executeAndReturnError(&error)
        if error != nil { return nil }
        return result.stringValue
    }
}
