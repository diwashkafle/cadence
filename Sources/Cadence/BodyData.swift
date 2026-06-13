import Foundation

// MARK: - Persisted body-module data

struct BodyData: Codable {
    var didSeed: Bool = false
    var checkIns: [String: CheckIn] = [:]        // dayKey -> CheckIn
    var measurements: [String: Measurement] = [:] // weekKey (Sunday dayKey) -> Measurement
    var sessions: [SessionTemplate] = []
    var supplements: [Supplement] = []
    var lastFast: Date? = nil

    init() {}

    enum CodingKeys: String, CodingKey {
        case didSeed, checkIns, measurements, sessions, supplements, lastFast
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        didSeed = (try? c.decode(Bool.self, forKey: .didSeed)) ?? false
        checkIns = (try? c.decode([String: CheckIn].self, forKey: .checkIns)) ?? [:]
        measurements = (try? c.decode([String: Measurement].self, forKey: .measurements)) ?? [:]
        sessions = (try? c.decode([SessionTemplate].self, forKey: .sessions)) ?? []
        supplements = (try? c.decode([Supplement].self, forKey: .supplements)) ?? []
        lastFast = try? c.decode(Date.self, forKey: .lastFast)
    }

    func session(_ key: SessionKey) -> SessionTemplate? {
        sessions.first { $0.id == key.rawValue && !$0.archived }
    }
}

// MARK: - Seeded protocol (Codi's plan)

extension BodyData {
    static func seededLibrary() -> (sessions: [SessionTemplate], supplements: [Supplement]) {
        let legs = SessionTemplate(
            id: SessionKey.legs.rawValue, name: "Legs + Core", subtitle: "Weights · 50 min",
            fasted: false,
            warmup: ["Terminal knee extensions (band) — 15/leg", "Wall sit — 30 sec",
                     "Single-leg balance — 20 sec/side", "Ankle circles — 10/dir"],
            exercises: [
                .init(id: "goblet-squat", name: "Goblet Squat", setsReps: "4 × 8-10", notes: "Deep, DB at chest"),
                .init(id: "db-rdl", name: "DB Romanian Deadlift", setsReps: "4 × 8-10", notes: "Feel hamstring stretch"),
                .init(id: "bulgarian", name: "Bulgarian Split Squat", setsReps: "3 × 8/leg", notes: "Rear foot on chair"),
                .init(id: "reverse-lunge", name: "Reverse Lunges", setsReps: "3 × 10/leg", notes: "Control descent"),
                .init(id: "calf-raise", name: "Calf Raise", setsReps: "4 × 15-20", notes: "Slow negatives"),
                .init(id: "plank", name: "Plank", setsReps: "3 × 45-60 sec", notes: "Full tension"),
                .init(id: "dead-bug", name: "Dead Bug", setsReps: "3 × 12", notes: "Opposite arm + leg"),
                .init(id: "leg-raise", name: "Lying Leg Raise", setsReps: "3 × 12", notes: "Press low back to floor"),
            ])

        let pull = SessionTemplate(
            id: SessionKey.pull.rawValue, name: "Pull + Core", subtitle: "Weights · 50 min",
            fasted: false,
            warmup: ["Band pull-aparts — 15", "Band external rotation — 12/arm",
                     "Wall slides — 10 slow", "Wrist circles — 10/dir"],
            exercises: [
                .init(id: "db-row", name: "1-Arm DB Row", setsReps: "4 × 8/arm", notes: "Full stretch at bottom"),
                .init(id: "bent-row", name: "Bent Over Row", setsReps: "4 × 8-10", notes: "45° torso"),
                .init(id: "pullover", name: "DB Pullover", setsReps: "3 × 10-12", notes: "Deep lat stretch"),
                .init(id: "shrugs", name: "DB Shrugs", setsReps: "3 × 12-15", notes: "Hold 2 sec at top"),
                .init(id: "hammer-curl", name: "Hammer Curl", setsReps: "3 × 10", notes: "No swing"),
                .init(id: "bicep-curl", name: "Bicep Curl", setsReps: "3 × 10-12", notes: "Supinate at top"),
                .init(id: "face-pull", name: "Band Face Pull", setsReps: "3 × 15", notes: "External rotation at end"),
                .init(id: "russian-twist", name: "Russian Twist", setsReps: "3 × 20", notes: "With DB"),
            ])

        let legsPull = SessionTemplate(
            id: SessionKey.legsPull.rawValue, name: "Legs + Pull Hybrid", subtitle: "Weights · 50 min",
            fasted: false,
            warmup: ["Terminal knee extensions (band) — 15/leg", "Band pull-aparts — 15",
                     "Wall sit — 30 sec", "Ankle + wrist circles — 10/dir"],
            exercises: [
                .init(id: "goblet-squat", name: "Goblet Squat", setsReps: "4 × 8-10", notes: "Deep, DB at chest"),
                .init(id: "db-rdl", name: "DB Romanian Deadlift", setsReps: "4 × 8-10", notes: "Feel hamstring stretch"),
                .init(id: "bulgarian", name: "Bulgarian Split Squat", setsReps: "3 × 8/leg", notes: "Rear foot on chair"),
                .init(id: "calf-raise", name: "Calf Raise", setsReps: "4 × 15-20", notes: "Slow negatives"),
                .init(id: "db-row", name: "1-Arm DB Row", setsReps: "4 × 8/arm", notes: "Friday pull swap"),
                .init(id: "hammer-curl", name: "Hammer Curl", setsReps: "3 × 10", notes: "Friday pull swap"),
                .init(id: "plank", name: "Plank", setsReps: "3 × 45-60 sec", notes: "Full tension"),
                .init(id: "russian-twist", name: "Russian Twist", setsReps: "3 × 20", notes: "With DB"),
            ])

        let mobility = SessionTemplate(
            id: SessionKey.mobility.rawValue, name: "Mobility + Isometric", subtitle: "50 min · NOT a rest day",
            fasted: true,
            warmup: ["Neck circles + chin tucks — 60 sec", "Shoulder circles — 10 each way",
                     "Band pull-aparts — 20", "Band external rotation — 15/arm",
                     "Hip circles — 10/dir", "Ankle + wrist circles — 10/dir"],
            exercises: [
                .init(id: "wall-sit", name: "Wall sit", setsReps: "45-60 sec × 3", notes: "Rest 45 sec"),
                .init(id: "iso-squat", name: "Isometric squat hold", setsReps: "30-45 sec × 3", notes: "Parallel"),
                .init(id: "sl-balance", name: "Single-leg balance", setsReps: "45 sec/side × 2", notes: ""),
                .init(id: "glute-bridge", name: "Glute bridge hold", setsReps: "45 sec × 3", notes: ""),
                .init(id: "dead-hang", name: "Dead hang", setsReps: "20-30 sec × 2", notes: "Only if shoulder allows"),
                .init(id: "plank-mob", name: "Plank", setsReps: "45-60 sec × 3", notes: ""),
                .init(id: "side-plank", name: "Side plank", setsReps: "30 sec/side × 2", notes: ""),
                .init(id: "iso-bicep", name: "Isometric bicep hold", setsReps: "30 sec/side × 2", notes: "Midpoint"),
                .init(id: "flow-9090", name: "Mobility flow", setsReps: "15 min", notes: "90/90, WGS, cat-cow, couch, pigeon, deep squat"),
                .init(id: "breath-478", name: "4-7-8 breathwork", setsReps: "8 rounds", notes: "Inhale 4 · hold 7 · exhale 8"),
            ])

        let cardio = SessionTemplate(
            id: SessionKey.cardio.rawValue, name: "Stair Intervals", subtitle: "Cardio · 55 min · hard",
            fasted: true,
            warmup: ["Lemon + ginger water before", "Walk to location — 10 min easy", "ORS after session"],
            exercises: [
                .init(id: "stair-intervals", name: "Stair intervals", setsReps: "35-40 min", notes: "3 min hard climb / 1 min slow down · Month1 3:1 → Month3 5:1"),
                .init(id: "jog-finish", name: "Jogging in place", setsReps: "10 min", notes: "Moderate finish"),
            ])

        let rest = SessionTemplate(
            id: SessionKey.rest.rawValue, name: "Walk + Refeed", subtitle: "Sunday · no training",
            fasted: true,
            warmup: [],
            exercises: [
                .init(id: "morning-walk", name: "Morning walk", setsReps: "60 min", notes: "Sunlight exposure — important"),
                .init(id: "evening-walk-sun", name: "Evening walk", setsReps: "15 min", notes: ""),
            ])

        let supplements: [Supplement] = [
            .init(id: "creatine", name: "Creatine Monohydrate", dose: "5g", timing: "Morning with water", notes: "Never skip — LBM preservation"),
            .init(id: "finasteride", name: "Finasteride 1mg", dose: "1 tab", timing: "With Meal 1", notes: "Needs fat"),
            .init(id: "calcium", name: "Calcium 500mg", dose: "1 tab", timing: "With Meal 1", notes: "Bone support"),
            .init(id: "fish-oil", name: "Fish Oil", dose: "2 caps", timing: "With Meal 1", notes: "Anti-inflammatory"),
            .init(id: "vitd3", name: "Vitamin D3 60k IU", dose: "1 cap", timing: "Sat mid-Meal 1", notes: "Needs fat · never after 4 PM", weeklyOn: 7),
            .init(id: "magnesium", name: "Magnesium Glycinate", dose: "400mg", timing: "Before bed", notes: "Sleep + recovery", nightly: true),
            .init(id: "whey", name: "Whey Protein", dose: "25g", timing: "Meal 3", notes: "~12.6g protein/scoop"),
            .init(id: "minox-am", name: "Minoxidil (AM)", dose: "0.5ml", timing: "Morning", notes: "Skip on derma-stamp day"),
            .init(id: "minox-pm", name: "Minoxidil (PM)", dose: "0.5ml", timing: "Night before bed", notes: "Skip on derma-stamp day", nightly: true),
        ]

        return ([legs, pull, legsPull, mobility, cardio, rest], supplements)
    }
}

// MARK: - Store helpers

extension Store {
    func bodyCheckIn(_ key: String) -> CheckIn {
        data.body.checkIns[key] ?? CheckIn()
    }

    func seedBodyIfNeeded() {
        guard !data.body.didSeed else { return }
        let lib = BodyData.seededLibrary()
        data.body.sessions = lib.sessions
        data.body.supplements = lib.supplements
        data.body.didSeed = true
    }

    /// Compliance proxy: fraction of floor + session + meals done today (0…10).
    func bodyComplianceToday() -> Int {
        let c = bodyCheckIn(Date().dayKey)
        let floorScore = Double(c.floor.count) / Double(max(1, floorItems.count))
        let mealScore = Double(c.meals.count) / 3.0
        let sessionScore = c.sessionDone ? 1.0 : 0.0
        return Int(((floorScore + mealScore + sessionScore) / 3.0 * 10).rounded())
    }
}

/// Sunday (week-start) key for a date, used to bucket weekly measurements.
func weekKey(for date: Date) -> String {
    let cal = Calendar.current
    let weekday = cal.component(.weekday, from: date) // 1 = Sunday
    let sunday = cal.date(byAdding: .day, value: -(weekday - 1), to: cal.startOfDay(for: date)) ?? date
    return sunday.dayKey
}
