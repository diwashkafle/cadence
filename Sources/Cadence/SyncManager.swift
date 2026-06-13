import Foundation
import Combine

/// Pushes the local working copy up to Neon via the Data API (managed PostgREST).
/// Offline-first: local JSON stays the instant working copy; this syncs it to the
/// cloud over HTTPS with a bearer token. Last-write-wins (bulk upsert per table).
@MainActor
final class SyncManager: ObservableObject {
    @Published var status = "Not configured"
    @Published var syncing = false
    @Published var lastError: String?

    private let store: Store
    private var cancellable: AnyCancellable?
    private var periodicTimer: Timer?
    private var lastManualSig: Data?
    private let tokenAccount = "neon-token"
    private let periodInterval: TimeInterval = 30 * 60   // work tracking cadence

    init(store: Store) {
        self.store = store
        refreshStatus()
        lastManualSig = Self.manualSig(store.data)

        // INSTANT path — routine/manual edits (everything except the per-5s work
        // logs) push almost immediately. We diff a signature so the constant
        // work-tracking writes don't trip this.
        cancellable = store.$data
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] data in
                guard let self, self.store.data.cloudAutoSync, self.isConfigured else { return }
                let sig = Self.manualSig(data)
                guard sig != self.lastManualSig else { return }
                self.lastManualSig = sig
                Task { await self.sync() }
            }

        // PERIODIC path — work tracking (and everything else) pushes every 30 min.
        let timer = Timer(timeInterval: periodInterval, repeats: true) { [weak self] _ in
            guard let self, self.store.data.cloudAutoSync, self.isConfigured else { return }
            Task { await self.sync() }
        }
        RunLoop.main.add(timer, forMode: .common)
        periodicTimer = timer

        // Initial push shortly after launch.
        if isConfigured && store.data.cloudAutoSync {
            Task { try? await Task.sleep(nanoseconds: 3_000_000_000); await sync() }
        }
    }

    /// Signature of the "routine" data (all of it except the work-tracking `logs`
    /// and the sync bookkeeping). Changes here trigger an instant sync.
    private static func manualSig(_ d: AppData) -> Data? {
        struct Snap: Encodable {
            let goals: [Goal]
            let trackedApps: [TrackedApp]
            let trackedSites: [TrackedSite]
            let body: BodyData
            let idleThreshold: Int
            let dataApiURL: String
            let cloudAutoSync: Bool
        }
        let snap = Snap(goals: d.goals, trackedApps: d.trackedApps, trackedSites: d.trackedSites,
                        body: d.body, idleThreshold: d.idleThreshold,
                        dataApiURL: d.dataApiURL, cloudAutoSync: d.cloudAutoSync)
        let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
        return try? enc.encode(snap)
    }

    // MARK: Configuration

    /// Public REST endpoint (not a secret). Stored in AppData.
    var baseURL: String { store.data.dataApiURL.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Bearer token: Keychain first, then ~/Library/Application Support/Cadence/neon.token.
    var token: String? {
        if let t = Keychain.get(account: tokenAccount), !t.isEmpty { return t }
        let fileURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Cadence/neon.token")
        if let s = try? String(contentsOf: fileURL, encoding: .utf8) {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        return nil
    }

    var isConfigured: Bool { !baseURL.isEmpty && token != nil }

    func setToken(_ value: String) {
        Keychain.set(value.trimmingCharacters(in: .whitespacesAndNewlines), account: tokenAccount)
        refreshStatus()
    }

    func setBaseURL(_ value: String) {
        store.data.dataApiURL = value.trimmingCharacters(in: .whitespacesAndNewlines)
        refreshStatus()
    }

    private func refreshStatus() {
        status = isConfigured ? "Ready" : "Not configured"
    }

    // MARK: Sync

    func sync() async {
        guard !syncing, isConfigured, let token else { return }
        guard let root = URL(string: baseURL) else {
            status = "Bad URL"; lastError = "Could not parse the Data API URL."; return
        }
        syncing = true; status = "Syncing…"; lastError = nil
        let data = store.data

        do {
            try await upsert("goals", rows: data.goals.map(Self.goalRow), root: root, token: token)
            try await upsert("day_logs", rows: data.logs.map { Self.dayLogRow(day: $0.key, log: $0.value) }, root: root, token: token)
            try await upsert("tracked_apps", rows: data.trackedApps.map(Self.appRow), root: root, token: token)
            try await upsert("tracked_sites", rows: data.trackedSites.map(Self.siteRow), root: root, token: token)
            try await upsert("body_checkins", rows: data.body.checkIns.map { Self.checkInRow(day: $0.key, c: $0.value) }, root: root, token: token)
            try await upsert("body_measurements", rows: data.body.measurements.map { Self.measurementRow(week: $0.key, m: $0.value) }, root: root, token: token)
            store.data.lastSyncedAt = Date()
            status = "Synced"
        } catch {
            lastError = String(describing: error)
            status = "Error"
        }
        syncing = false
    }

    /// Bulk upsert one table via PostgREST (POST array + merge-duplicates on the PK).
    private func upsert(_ table: String, rows: [[String: Any]], root: URL, token: String) async throws {
        guard !rows.isEmpty else { return }
        var req = URLRequest(url: root.appendingPathComponent(table))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(token, forHTTPHeaderField: "apikey")   // harmless if the endpoint ignores it
        req.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try JSONSerialization.data(withJSONObject: rows)

        let (body, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw SyncError.message("No HTTP response") }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: body, encoding: .utf8) ?? ""
            throw SyncError.message("\(table): HTTP \(http.statusCode) — \(text)")
        }
    }

    enum SyncError: Error, CustomStringConvertible {
        case message(String)
        var description: String { switch self { case .message(let m): return m } }
    }

    // MARK: Row builders (Date/strings PostgREST understands)

    private static let iso = ISO8601DateFormatter()

    private static func goalRow(_ g: Goal) -> [String: Any] {
        ["id": g.id.uuidString, "title": g.title,
         "created_date": iso.string(from: g.createdDate),
         "target_date": iso.string(from: g.targetDate),
         "updated_at": iso.string(from: Date())]
    }
    private static func dayLogRow(day: String, log: DayLog) -> [String: Any] {
        ["day": day, "work": log.work, "entertainment": log.entertainment,
         "apps": log.apps, "hours": log.hours, "updated_at": iso.string(from: Date())]
    }
    private static func appRow(_ a: TrackedApp) -> [String: Any] {
        ["bundle_id": a.bundleID, "name": a.name, "category": a.category.rawValue,
         "updated_at": iso.string(from: Date())]
    }
    private static func siteRow(_ s: TrackedSite) -> [String: Any] {
        ["host": s.host, "category": s.category.rawValue, "updated_at": iso.string(from: Date())]
    }
    private static func checkInRow(day: String, c: CheckIn) -> [String: Any] {
        ["day": day,
         "weight": c.weight ?? NSNull(), "sleep": c.sleep, "energy": c.energy,
         "mood": c.mood, "hunger": c.hunger, "acid_reflux": c.acidReflux, "bloating": c.bloating,
         "shoulder_pain": c.shoulderPain, "floor": Array(c.floor), "meals": Array(c.meals),
         "supplements": Array(c.supplements), "exercises": Array(c.exercises),
         "exercise_log": c.exerciseLog, "warmup_done": c.warmupDone,
         "intensity": c.intensity, "session_done": c.sessionDone,
         "updated_at": iso.string(from: Date())]
    }
    private static func measurementRow(week: String, m: Measurement) -> [String: Any] {
        ["week": week,
         "weight": m.weight ?? NSNull(), "belly": m.belly ?? NSNull(),
         "chest": m.chest ?? NSNull(), "bicep": m.bicep ?? NSNull(), "thigh": m.thigh ?? NSNull(),
         "compliance": m.compliance, "updated_at": iso.string(from: Date())]
    }
}
