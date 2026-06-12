import Foundation

// MARK: - Date helpers

extension Date {
    /// A stable yyyy-MM-dd key in the local calendar.
    var dayKey: String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: self)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

func dayKey(for date: Date) -> String { date.dayKey }

func parseDayKey(_ key: String) -> Date? {
    let f = DateFormatter()
    f.calendar = Calendar.current
    f.dateFormat = "yyyy-MM-dd"
    return f.date(from: key)
}

// MARK: - Category

enum Category: String, Codable, CaseIterable, Identifiable, Hashable {
    case work
    case entertainment

    var id: String { rawValue }
    var label: String { self == .work ? "Work" : "Entertainment" }
}

// MARK: - Goal

struct Goal: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var createdDate: Date = Date()
    var targetDate: Date

    /// Whole days from the start of today to the start of the target day.
    var daysRemaining: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let target = cal.startOfDay(for: targetDate)
        return cal.dateComponents([.day], from: today, to: target).day ?? 0
    }
}

// MARK: - Daily activity log

/// Counted time for one day, split by category, with a per-label breakdown.
struct DayLog: Codable {
    var work: Int = 0
    var entertainment: Int = 0
    var apps: [String: Int] = [:]    // label (app name or domain) -> seconds
    var hours: [String: Int] = [:]   // hour "0".."23" -> work seconds

    init() {}

    enum CodingKeys: String, CodingKey { case work, entertainment, apps, hours, seconds }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // `seconds` is the legacy v1 work key; fall back to it for old files.
        work = (try? c.decode(Int.self, forKey: .work))
            ?? (try? c.decode(Int.self, forKey: .seconds)) ?? 0
        entertainment = (try? c.decode(Int.self, forKey: .entertainment)) ?? 0
        apps = (try? c.decode([String: Int].self, forKey: .apps)) ?? [:]
        hours = (try? c.decode([String: Int].self, forKey: .hours)) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(work, forKey: .work)
        try c.encode(entertainment, forKey: .entertainment)
        try c.encode(apps, forKey: .apps)
        try c.encode(hours, forKey: .hours)
    }

    func seconds(for category: Category) -> Int {
        category == .work ? work : entertainment
    }
}

// MARK: - Tracked app

struct TrackedApp: Codable, Identifiable, Hashable {
    var bundleID: String
    var name: String
    var category: Category = .work
    var id: String { bundleID }

    init(bundleID: String, name: String, category: Category = .work) {
        self.bundleID = bundleID
        self.name = name
        self.category = category
    }

    enum CodingKeys: String, CodingKey { case bundleID, name, category }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bundleID = try c.decode(String.self, forKey: .bundleID)
        name = try c.decode(String.self, forKey: .name)
        category = (try? c.decode(Category.self, forKey: .category)) ?? .work
    }
}

// MARK: - Tracked site

struct TrackedSite: Codable, Identifiable, Hashable {
    var host: String
    var category: Category = .work
    var id: String { host }

    init(host: String, category: Category = .work) {
        self.host = host.lowercased()
        self.category = category
    }

    enum CodingKeys: String, CodingKey { case host, category }

    init(from decoder: Decoder) throws {
        // Accept both the legacy bare-string form and the new object form.
        if let s = try? decoder.singleValueContainer().decode(String.self) {
            host = s.lowercased()
            category = .work
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        host = (try c.decode(String.self, forKey: .host)).lowercased()
        category = (try? c.decode(Category.self, forKey: .category)) ?? .work
    }
}

// MARK: - Persisted app data

struct AppData: Codable {
    var goals: [Goal] = []
    var logs: [String: DayLog] = [:]          // dayKey -> DayLog
    var trackedApps: [TrackedApp] = []
    var trackedSites: [TrackedSite] = []
    var idleThreshold: Int = 120              // seconds of no input before pausing
    var autoTrack: Bool = true                // tracking resumes on launch

    enum CodingKeys: String, CodingKey {
        case goals, logs, trackedApps, trackedSites, idleThreshold, autoTrack
    }

    init() {}

    // Tolerant decoding: a missing or malformed field never nukes the rest
    // of the file — new fields just take their defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        goals = (try? c.decode([Goal].self, forKey: .goals)) ?? []
        logs = (try? c.decode([String: DayLog].self, forKey: .logs)) ?? [:]
        trackedApps = (try? c.decode([TrackedApp].self, forKey: .trackedApps)) ?? []
        trackedSites = (try? c.decode([TrackedSite].self, forKey: .trackedSites)) ?? []
        idleThreshold = (try? c.decode(Int.self, forKey: .idleThreshold)) ?? 120
        autoTrack = (try? c.decode(Bool.self, forKey: .autoTrack)) ?? true
    }
}
