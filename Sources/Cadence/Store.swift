import Foundation
import Combine

/// Single source of truth. Holds all persisted data and writes it to
/// ~/Library/Application Support/Cadence/data.json
final class Store: ObservableObject {
    @Published var data: AppData {
        didSet { scheduleSave() }
    }

    private let fileURL: URL
    private var saveWorkItem: DispatchWorkItem?

    init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Cadence", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("data.json")

        if let raw = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder.cadence.decode(AppData.self, from: raw) {
            data = decoded
        } else {
            data = AppData()
        }
    }

    // MARK: Goals

    func addGoal(title: String, targetDate: Date) {
        data.goals.append(Goal(title: title, targetDate: targetDate))
    }

    func deleteGoal(_ goal: Goal) {
        data.goals.removeAll { $0.id == goal.id }
    }

    // MARK: Logs

    /// Add counted seconds to a given day, into the right category bucket.
    func addWork(seconds: Int, label: String, category: Category, on date: Date = Date()) {
        let key = date.dayKey
        var log = data.logs[key] ?? DayLog()
        if category == .work {
            log.work += seconds
            let hour = Calendar.current.component(.hour, from: date)
            log.hours[String(hour), default: 0] += seconds
        } else {
            log.entertainment += seconds
        }
        log.apps[label, default: 0] += seconds
        data.logs[key] = log
    }

    /// Work seconds logged in a specific hour (0–23) of a day.
    func workSeconds(on date: Date, hour: Int) -> Int {
        data.logs[date.dayKey]?.hours[String(hour)] ?? 0
    }

    /// Work seconds for a day (drives the heatmap and goal stats).
    func seconds(on date: Date) -> Int {
        data.logs[date.dayKey]?.work ?? 0
    }

    func entertainmentSeconds(on date: Date) -> Int {
        data.logs[date.dayKey]?.entertainment ?? 0
    }

    var totalSeconds: Int {
        data.logs.values.reduce(0) { $0 + $1.work }
    }

    /// Consecutive days (ending today or yesterday) with any counted work.
    var currentStreak: Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: Date())
        if (data.logs[day.dayKey]?.work ?? 0) == 0 {
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        var streak = 0
        while (data.logs[day.dayKey]?.work ?? 0) > 0 {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    // MARK: Tracked apps

    func trackedApp(bundleID: String) -> TrackedApp? {
        data.trackedApps.first { $0.bundleID == bundleID }
    }

    /// Set an app's category, or pass nil to stop tracking it.
    func setApp(_ app: TrackedApp, category: Category?) {
        data.trackedApps.removeAll { $0.bundleID == app.bundleID }
        if let category {
            data.trackedApps.append(TrackedApp(bundleID: app.bundleID, name: app.name, category: category))
        }
    }

    // MARK: Tracked sites

    func trackedSite(matching host: String) -> TrackedSite? {
        data.trackedSites.first { host.contains($0.host) }
    }

    func addSite(_ raw: String, category: Category) {
        let host = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .lowercased()
        guard !host.isEmpty else { return }
        data.trackedSites.removeAll { $0.host == host }
        data.trackedSites.append(TrackedSite(host: host, category: category))
    }

    func setSiteCategory(_ site: TrackedSite, category: Category) {
        guard let idx = data.trackedSites.firstIndex(where: { $0.host == site.host }) else { return }
        data.trackedSites[idx].category = category
    }

    func removeSite(_ site: TrackedSite) {
        data.trackedSites.removeAll { $0.host == site.host }
    }

    // MARK: Persistence

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: item)
    }

    func saveNow() {
        guard let raw = try? JSONEncoder.cadence.encode(data) else { return }
        try? raw.write(to: fileURL, options: .atomic)
    }
}

extension JSONEncoder {
    static var cadence: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }
}

extension JSONDecoder {
    static var cadence: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
