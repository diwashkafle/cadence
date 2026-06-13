import Foundation

// MARK: - Schedule (weekly split → session type, day type, calories)

enum SessionKey: String, Codable, CaseIterable {
    case legs, pull, legsPull = "legs-pull", mobility, cardio, rest
}

enum DietDayType: String, Codable {
    case low, standard, refeed
    var kcal: Int { self == .low ? 1350 : (self == .standard ? 1700 : 1900) }
    var label: String { rawValue.capitalized }
}

enum BodySchedule {
    /// Calendar weekday: 1=Sun … 7=Sat.
    static func sessionKey(for date: Date) -> SessionKey {
        switch Calendar.current.component(.weekday, from: date) {
        case 2: return .legs       // Mon
        case 3: return .mobility   // Tue
        case 4: return .pull       // Wed
        case 5: return .cardio     // Thu
        case 6: return .legsPull   // Fri
        case 7: return .mobility   // Sat
        default: return .rest      // Sun
        }
    }
    static func dayType(for date: Date) -> DietDayType {
        switch Calendar.current.component(.weekday, from: date) {
        case 2, 4, 6: return .standard
        case 1:       return .refeed
        default:      return .low
        }
    }
}

// MARK: - Editable library types

struct Exercise: Codable, Identifiable, Hashable {
    var id: String          // slug, stable across days
    var name: String
    var setsReps: String
    var notes: String = ""
    var archived: Bool = false
}

struct SessionTemplate: Codable, Identifiable, Hashable {
    var id: String          // SessionKey raw value
    var name: String
    var subtitle: String
    var fasted: Bool
    var warmup: [String]
    var exercises: [Exercise]
    var archived: Bool = false
}

struct Supplement: Codable, Identifiable, Hashable {
    var id: String          // slug
    var name: String
    var dose: String
    var timing: String
    var notes: String = ""
    var weeklyOn: Int? = nil   // Calendar weekday (7 = Sat) if weekly; nil = daily
    var nightly: Bool = false
    var archived: Bool = false

    func showsToday(_ date: Date) -> Bool {
        guard !archived else { return false }
        guard let day = weeklyOn else { return true }
        return Calendar.current.component(.weekday, from: date) == day
    }
}

// MARK: - Daily check-in (logged per day)

struct CheckIn: Codable {
    var weight: Double? = nil
    var sleepHours: Double = 7.5
    var energy: Int = 5
    var mood: Int = 5
    var hunger: Int = 5
    var acidReflux: Bool = false
    var bloating: Bool = false
    var shoulderPain: String = "none"     // none / load / rest

    var floor: Set<String> = []            // floor item ids done
    var meals: Set<Int> = []               // 1, 2, 3
    var supplements: Set<String> = []      // supplement ids done
    var exercises: Set<String> = []        // exercise ids done
    var exerciseLog: [String: String] = [:] // exercise id -> "20kg × 10"
    var warmupDone: Bool = false
    var intensity: String = "standard"     // floor / standard / ceiling
    var sessionDone: Bool = false

    init() {}

    enum CodingKeys: String, CodingKey {
        case weight, sleepHours, energy, mood, hunger, acidReflux, bloating, shoulderPain
        case floor, meals, supplements, exercises, exerciseLog, warmupDone, intensity, sessionDone
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        weight = try? c.decode(Double.self, forKey: .weight)
        sleepHours = (try? c.decode(Double.self, forKey: .sleepHours)) ?? 7.5
        energy = (try? c.decode(Int.self, forKey: .energy)) ?? 5
        mood = (try? c.decode(Int.self, forKey: .mood)) ?? 5
        hunger = (try? c.decode(Int.self, forKey: .hunger)) ?? 5
        acidReflux = (try? c.decode(Bool.self, forKey: .acidReflux)) ?? false
        bloating = (try? c.decode(Bool.self, forKey: .bloating)) ?? false
        shoulderPain = (try? c.decode(String.self, forKey: .shoulderPain)) ?? "none"
        floor = (try? c.decode(Set<String>.self, forKey: .floor)) ?? []
        meals = (try? c.decode(Set<Int>.self, forKey: .meals)) ?? []
        supplements = (try? c.decode(Set<String>.self, forKey: .supplements)) ?? []
        exercises = (try? c.decode(Set<String>.self, forKey: .exercises)) ?? []
        exerciseLog = (try? c.decode([String: String].self, forKey: .exerciseLog)) ?? [:]
        warmupDone = (try? c.decode(Bool.self, forKey: .warmupDone)) ?? false
        intensity = (try? c.decode(String.self, forKey: .intensity)) ?? "standard"
        sessionDone = (try? c.decode(Bool.self, forKey: .sessionDone)) ?? false
    }
}

// MARK: - Weekly measurements

struct Measurement: Codable {
    var weight: Double? = nil   // weekly average
    var belly: Double? = nil
    var chest: Double? = nil
    var bicep: Double? = nil
    var thigh: Double? = nil
    var compliance: Int = 7

    init() {}

    enum CodingKeys: String, CodingKey { case weight, belly, chest, bicep, thigh, compliance }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        weight = try? c.decode(Double.self, forKey: .weight)
        belly = try? c.decode(Double.self, forKey: .belly)
        chest = try? c.decode(Double.self, forKey: .chest)
        bicep = try? c.decode(Double.self, forKey: .bicep)
        thigh = try? c.decode(Double.self, forKey: .thigh)
        compliance = (try? c.decode(Int.self, forKey: .compliance)) ?? 7
    }
}

// MARK: - Floor items (constant)

struct FloorItem: Identifiable { let id: String; let label: String; let detail: String }

let floorItems: [FloorItem] = [
    .init(id: "ac-rehab", label: "AC rehab sequence", detail: "8 min — runs before everything"),
    .init(id: "protein", label: "Protein at every meal", detail: "The one rule when all else slips"),
    .init(id: "evening-walk", label: "Evening 15 min walk", detail: "Non-negotiable, even on worst days"),
    .init(id: "morning-drink", label: "Lemon + ginger water (AM)", detail: "Keeps the morning anchor alive"),
]

// MARK: - AC rehab sequence (constant)

let acRehab: [Exercise] = [
    .init(id: "cross-body", name: "Cross-body stretch", setsReps: "30 sec × 3", notes: "Pull left arm across chest"),
    .init(id: "pendulum", name: "Pendulum swings", setsReps: "1 min", notes: "Lean forward, small circles"),
    .init(id: "iso-pressout", name: "Isometric press-outs", setsReps: "10 × 5 sec", notes: "Palm into wall, 30-40% effort"),
    .init(id: "band-er-rehab", name: "Band external rotation", setsReps: "15 × 2", notes: "Elbow pinned to side"),
    .init(id: "band-pa-rehab", name: "Band pull-apart", setsReps: "15 × 2", notes: "Chest height"),
    .init(id: "trap-shrug-rehab", name: "Light trap shrugs", setsReps: "15 × 2", notes: "5kg only, hold 2 sec"),
]

// MARK: - Diet reference (constant)

struct MealInfo: Identifiable { let id = UUID(); let name: String; let time: String; let foods: String; let kcal: Int; let protein: Int }
struct DayTypeInfo { let type: DietDayType; let note: String; let protein: Int; let meals: [MealInfo] }

let dietReference: [DayTypeInfo] = [
    .init(type: .low, note: "Tue / Thu / Sat — no rice, minimal carbs", protein: 123, meals: [
        .init(name: "Meal 1", time: "11:00 AM", foods: "4 eggs + 50g soya (air fried) + 100g spinach + veg + 5g ghee + lemon", kcal: 590, protein: 55),
        .init(name: "Meal 2", time: "3:30 PM", foods: "100g dry mung dal + 135g curd + 30g pumpkin seeds + ½ tsp honey", kcal: 627, protein: 38),
        .init(name: "Meal 3", time: "7:30 PM", foods: "50g soya (air fried) + 25g whey in water", kcal: 283, protein: 39),
    ]),
    .init(type: .standard, note: "Mon / Wed / Fri — Low day + rice, banana, milk", protein: 132, meals: [
        .init(name: "Meal 1", time: "11:00 AM", foods: "Low Meal 1 + 100g cooked white rice", kcal: 720, protein: 57),
        .init(name: "Meal 2", time: "3:30 PM", foods: "Low Meal 2 + 1 banana", kcal: 716, protein: 38),
        .init(name: "Meal 3", time: "7:30 PM", foods: "50g soya + 25g whey in 100ml whole milk", kcal: 345, protein: 39),
    ]),
    .init(type: .refeed, note: "Sunday — higher carbs, refeed", protein: 130, meals: [
        .init(name: "Meal 1", time: "11:00 AM", foods: "Low Meal 1 + 150-180g cooked rice", kcal: 800, protein: 57),
        .init(name: "Meal 2", time: "3:30 PM", foods: "150g curd + seasonal fruit + seeds + mung", kcal: 720, protein: 38),
        .init(name: "Meal 3", time: "7:30 PM", foods: "Whey in 150ml milk + optional air-fried potato", kcal: 380, protein: 35),
    ]),
]
