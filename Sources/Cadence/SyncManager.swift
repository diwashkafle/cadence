import Foundation
import Combine
import NIOCore
import NIOPosix
import NIOSSL
import PostgresNIO
import Logging

/// Pushes the local working copy up to Neon Postgres. Local stays the instant
/// auto-save; this syncs it to the cloud (offline-first). Last-write-wins:
/// each sync overwrites the cloud rows with the current local values.
@MainActor
final class SyncManager: ObservableObject {
    @Published var status = "Not configured"
    @Published var syncing = false
    @Published var lastError: String?

    private let store: Store
    private var cancellable: AnyCancellable?
    private let logger = Logger(label: "cadence.sync")

    init(store: Store) {
        self.store = store
        refreshStatus()

        // Auto-sync: debounce data changes, push when online.
        cancellable = store.$data
            .debounce(for: .seconds(15), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.store.data.cloudAutoSync, self.connectionString != nil else { return }
                Task { await self.sync() }
            }

        // Initial push shortly after launch.
        if connectionString != nil && store.data.cloudAutoSync {
            Task { try? await Task.sleep(nanoseconds: 3_000_000_000); await sync() }
        }
    }

    // MARK: Configuration

    /// Keychain first; falls back to ~/Library/Application Support/Cadence/neon.url
    /// so the URL never has to be pasted into a chat or committed.
    var connectionString: String? {
        if let k = Keychain.get(), !k.isEmpty { return k }
        let fileURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Cadence/neon.url")
        if let s = try? String(contentsOf: fileURL, encoding: .utf8) {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    func setConnectionString(_ value: String) {
        Keychain.set(value.trimmingCharacters(in: .whitespacesAndNewlines))
        refreshStatus()
    }

    private func refreshStatus() {
        status = connectionString == nil ? "Not configured" : "Ready"
    }

    // MARK: Sync

    func sync() async {
        guard !syncing, let urlString = connectionString else { return }
        guard let cfg = Self.config(from: urlString) else {
            lastError = "Could not parse the Neon connection string."
            status = "Bad URL"
            return
        }
        syncing = true
        status = "Syncing…"
        lastError = nil

        let snapshot = store.data   // capture on main actor

        do {
            try await Self.push(snapshot, config: cfg, logger: logger)
            store.data.lastSyncedAt = Date()
            status = "Synced"
        } catch {
            lastError = String(describing: error)
            status = "Error"
        }
        syncing = false
    }

    // MARK: Connection config

    private static func config(from urlString: String) -> PostgresConnection.Configuration? {
        guard let comps = URLComponents(string: urlString),
              let host = comps.host,
              let user = comps.user else { return nil }
        let db = comps.path.hasPrefix("/") ? String(comps.path.dropFirst()) : comps.path
        var tls = PostgresConnection.Configuration.TLS.disable
        if let ctx = try? NIOSSLContext(configuration: .makeClientConfiguration()) {
            tls = .require(ctx)
        }
        return PostgresConnection.Configuration(
            host: host,
            port: comps.port ?? 5432,
            username: user,
            password: comps.password,
            database: db.isEmpty ? nil : db,
            tls: tls
        )
    }

    // MARK: Push (runs off the main actor)

    nonisolated private static func push(_ data: AppData,
                                         config: PostgresConnection.Configuration,
                                         logger: Logger) async throws {
        let elg = MultiThreadedEventLoopGroup.singleton
        let conn = try await PostgresConnection.connect(
            on: elg.next(), configuration: config, id: 1, logger: logger)
        defer { try? conn.close().wait() }

        try await ensureSchema(conn, logger: logger)

        // Goals
        for g in data.goals {
            try await conn.query("""
                INSERT INTO goals (id, title, created_date, target_date, updated_at)
                VALUES (\(g.id.uuidString), \(g.title), \(g.createdDate), \(g.targetDate), now())
                ON CONFLICT (id) DO UPDATE SET
                  title = EXCLUDED.title, created_date = EXCLUDED.created_date,
                  target_date = EXCLUDED.target_date, updated_at = now()
                """, logger: logger)
        }

        // Work logs (per day)
        for (day, log) in data.logs {
            let apps = jsonString(log.apps)
            let hours = jsonString(log.hours)
            try await conn.query("""
                INSERT INTO day_logs (day, work, entertainment, apps, hours, updated_at)
                VALUES (\(day)::date, \(log.work), \(log.entertainment), \(apps)::jsonb, \(hours)::jsonb, now())
                ON CONFLICT (day) DO UPDATE SET
                  work = EXCLUDED.work, entertainment = EXCLUDED.entertainment,
                  apps = EXCLUDED.apps, hours = EXCLUDED.hours, updated_at = now()
                """, logger: logger)
        }

        // Tracked apps / sites
        for a in data.trackedApps {
            try await conn.query("""
                INSERT INTO tracked_apps (bundle_id, name, category, updated_at)
                VALUES (\(a.bundleID), \(a.name), \(a.category.rawValue), now())
                ON CONFLICT (bundle_id) DO UPDATE SET
                  name = EXCLUDED.name, category = EXCLUDED.category, updated_at = now()
                """, logger: logger)
        }
        for s in data.trackedSites {
            try await conn.query("""
                INSERT INTO tracked_sites (host, category, updated_at)
                VALUES (\(s.host), \(s.category.rawValue), now())
                ON CONFLICT (host) DO UPDATE SET
                  category = EXCLUDED.category, updated_at = now()
                """, logger: logger)
        }

        // Body check-ins (per day)
        for (day, c) in data.body.checkIns {
            try await conn.query("""
                INSERT INTO body_checkins
                  (day, weight, sleep, energy, mood, hunger, acid_reflux, bloating, shoulder_pain,
                   floor, meals, supplements, exercises, exercise_log, warmup_done, intensity, session_done, updated_at)
                VALUES
                  (\(day)::date, \(c.weight), \(c.sleep), \(c.energy), \(c.mood), \(c.hunger),
                   \(c.acidReflux), \(c.bloating), \(c.shoulderPain),
                   \(jsonArray(c.floor))::jsonb, \(jsonIntArray(c.meals))::jsonb, \(jsonArray(c.supplements))::jsonb,
                   \(jsonArray(c.exercises))::jsonb, \(jsonString(c.exerciseLog))::jsonb,
                   \(c.warmupDone), \(c.intensity), \(c.sessionDone), now())
                ON CONFLICT (day) DO UPDATE SET
                  weight = EXCLUDED.weight, sleep = EXCLUDED.sleep, energy = EXCLUDED.energy,
                  mood = EXCLUDED.mood, hunger = EXCLUDED.hunger, acid_reflux = EXCLUDED.acid_reflux,
                  bloating = EXCLUDED.bloating, shoulder_pain = EXCLUDED.shoulder_pain,
                  floor = EXCLUDED.floor, meals = EXCLUDED.meals, supplements = EXCLUDED.supplements,
                  exercises = EXCLUDED.exercises, exercise_log = EXCLUDED.exercise_log,
                  warmup_done = EXCLUDED.warmup_done, intensity = EXCLUDED.intensity,
                  session_done = EXCLUDED.session_done, updated_at = now()
                """, logger: logger)
        }

        // Weekly measurements
        for (week, m) in data.body.measurements {
            try await conn.query("""
                INSERT INTO body_measurements (week, weight, belly, chest, bicep, thigh, compliance, updated_at)
                VALUES (\(week)::date, \(m.weight), \(m.belly), \(m.chest), \(m.bicep), \(m.thigh), \(m.compliance), now())
                ON CONFLICT (week) DO UPDATE SET
                  weight = EXCLUDED.weight, belly = EXCLUDED.belly, chest = EXCLUDED.chest,
                  bicep = EXCLUDED.bicep, thigh = EXCLUDED.thigh, compliance = EXCLUDED.compliance,
                  updated_at = now()
                """, logger: logger)
        }
    }

    nonisolated private static func ensureSchema(_ conn: PostgresConnection, logger: Logger) async throws {
        let statements = [
            "CREATE TABLE IF NOT EXISTS goals (id text PRIMARY KEY, title text, created_date timestamptz, target_date timestamptz, updated_at timestamptz)",
            "CREATE TABLE IF NOT EXISTS day_logs (day date PRIMARY KEY, work integer, entertainment integer, apps jsonb, hours jsonb, updated_at timestamptz)",
            "CREATE TABLE IF NOT EXISTS tracked_apps (bundle_id text PRIMARY KEY, name text, category text, updated_at timestamptz)",
            "CREATE TABLE IF NOT EXISTS tracked_sites (host text PRIMARY KEY, category text, updated_at timestamptz)",
            "CREATE TABLE IF NOT EXISTS body_checkins (day date PRIMARY KEY, weight double precision, sleep integer, energy integer, mood integer, hunger integer, acid_reflux boolean, bloating boolean, shoulder_pain text, floor jsonb, meals jsonb, supplements jsonb, exercises jsonb, exercise_log jsonb, warmup_done boolean, intensity text, session_done boolean, updated_at timestamptz)",
            "CREATE TABLE IF NOT EXISTS body_measurements (week date PRIMARY KEY, weight double precision, belly double precision, chest double precision, bicep double precision, thigh double precision, compliance integer, updated_at timestamptz)",
        ]
        for sql in statements {
            try await conn.query(PostgresQuery(unsafeSQL: sql), logger: logger)
        }
    }

    // MARK: JSON helpers

    nonisolated private static func jsonString(_ dict: [String: Int]) -> String {
        guard let d = try? JSONSerialization.data(withJSONObject: dict), let s = String(data: d, encoding: .utf8) else { return "{}" }
        return s
    }
    nonisolated private static func jsonString(_ dict: [String: String]) -> String {
        guard let d = try? JSONSerialization.data(withJSONObject: dict), let s = String(data: d, encoding: .utf8) else { return "{}" }
        return s
    }
    nonisolated private static func jsonArray(_ set: Set<String>) -> String {
        guard let d = try? JSONSerialization.data(withJSONObject: Array(set)), let s = String(data: d, encoding: .utf8) else { return "[]" }
        return s
    }
    nonisolated private static func jsonIntArray(_ set: Set<Int>) -> String {
        guard let d = try? JSONSerialization.data(withJSONObject: Array(set)), let s = String(data: d, encoding: .utf8) else { return "[]" }
        return s
    }
}
