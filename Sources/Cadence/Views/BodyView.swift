import SwiftUI

enum BodyTab: String, CaseIterable, Identifiable {
    case today = "Today", week = "Week", reference = "Reference"
    var id: String { rawValue }
}

struct BodyView: View {
    @EnvironmentObject var store: Store
    @State private var tab: BodyTab = .today

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("", selection: $tab) {
                    ForEach(BodyTab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 320)

                switch tab {
                case .today:     BodyTodayView()
                case .week:      BodyWeekView()
                case .reference: BodyReferenceView()
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Today

struct BodyTodayView: View {
    @EnvironmentObject var store: Store

    private var key: String { Date().dayKey }
    private var today: Date { Date() }
    private var sessionKey: SessionKey { BodySchedule.sessionKey(for: today) }
    private var session: SessionTemplate? { store.data.body.session(sessionKey) }
    private var dayType: DietDayType { BodySchedule.dayType(for: today) }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            intensityPicker
            checkInCard
            floorCard
            dietCard
            supplementCard
            sessionCard
        }
    }

    // MARK: header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(longDate(today)).font(.largeTitle.bold())
            HStack(spacing: 8) {
                tag(session?.name ?? "Rest", color: .accentColor)
                if session?.fasted == true { tag("Fasted", color: .purple) }
                tag("\(dayType.label) · \(dayType.kcal) kcal", color: Category.work.color)
            }
            Label("AC rehab runs first — 8 min, before everything", systemImage: "figure.cooldown")
                .font(.caption).foregroundStyle(.orange)
        }
    }

    private var intensityPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Mode").font(.headline)
            Picker("", selection: bind(\.intensity)) {
                Text("Floor").tag("floor")
                Text("Standard").tag("standard")
                Text("Ceiling").tag("ceiling")
            }
            .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 320)
            Text("Floor = minimum that survives a bad day. Ceiling = everything aligned.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: morning check-in

    private var checkInCard: some View {
        card("Morning check-in") {
            HStack {
                Text("Weight (kg)")
                Spacer()
                TextField("—", text: weightString)
                    .frame(width: 80).multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Text("Sleep").frame(width: 70, alignment: .leading)
                Stepper(value: bind(\.sleepHours), in: 0...14, step: 0.5) {
                    Text(String(format: "%.1f h", store.bodyCheckIn(key).sleepHours)).monospacedDigit()
                }
            }
            slider("Energy", \.energy)
            slider("Mood", \.mood)
            slider("Hunger", \.hunger)
            Toggle("Acid reflux", isOn: bind(\.acidReflux))
            Toggle("Bloating", isOn: bind(\.bloating))
            HStack {
                Text("Shoulder pain")
                Spacer()
                Picker("", selection: bind(\.shoulderPain)) {
                    Text("None").tag("none")
                    Text("Under load").tag("load")
                    Text("At rest").tag("rest")
                }.labelsHidden().frame(width: 200)
            }
        }
    }

    // MARK: floor

    private var floorCard: some View {
        card("The Floor — minimum viable day") {
            ForEach(floorItems) { item in
                Toggle(isOn: setBind(\.floor, item.id)) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.label)
                        Text(item.detail).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: diet

    private var dietCard: some View {
        let plan = store.data.body.plan(dayType)
        return card("Diet — \(dayType.label) day · \(dayType.kcal) kcal") {
            if let plan {
                ForEach(Array(plan.meals.enumerated()), id: \.element.id) { i, meal in
                    Toggle(isOn: mealBind(i + 1)) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(meal.name) · \(meal.time)")
                            Text(meal.foods).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                ForEach([1, 2, 3], id: \.self) { n in Toggle("Meal \(n)", isOn: mealBind(n)) }
            }
        }
    }

    private var supplementCard: some View {
        let todays = store.data.body.supplements.filter { $0.showsToday(today) }
        return card("Supplements") {
            ForEach(todays) { s in
                Toggle(isOn: setBind(\.supplements, s.id)) {
                    HStack {
                        Text(s.name)
                        Text("\(s.dose) · \(s.timing)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: session

    @ViewBuilder
    private var sessionCard: some View {
        if let session {
            let warmupReady = session.warmup.isEmpty || bind(\.warmupDone).wrappedValue
            card(session.name + " · " + session.subtitle) {
                if !session.warmup.isEmpty {
                    Text("Warmup (Joint Armor)").font(.subheadline.bold())
                    ForEach(session.warmup, id: \.self) { Text("• \($0)").font(.caption) }
                    Toggle("Warmup complete", isOn: bind(\.warmupDone)).padding(.top, 2)
                    Divider()
                }
                if warmupReady {
                    ForEach(session.exercises) { ex in
                        exerciseRow(ex)
                    }
                    Toggle("Session complete", isOn: bind(\.sessionDone)).padding(.top, 4)
                } else {
                    Text("Check off the warmup to unlock the main work.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func exerciseRow(_ ex: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: setBind(\.exercises, ex.id)) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(ex.name)
                    Text(ex.setsReps + (ex.notes.isEmpty ? "" : " · \(ex.notes)"))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            TextField("log e.g. 16kg × 10", text: logBind(ex.id))
                .textFieldStyle(.roundedBorder).font(.caption)
        }
        .padding(.vertical, 4)
    }

    // MARK: reusable pieces

    private func card<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func slider(_ label: String, _ kp: WritableKeyPath<CheckIn, Int>) -> some View {
        HStack {
            Text(label).frame(width: 70, alignment: .leading)
            Slider(value: intBind(kp), in: 0...10, step: 1)
            Text("\(store.bodyCheckIn(key)[keyPath: kp])").monospacedDigit().frame(width: 24)
        }
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text).font(.caption.bold())
            .padding(.vertical, 3).padding(.horizontal, 8)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
    }

    private func longDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMMM d"
        return f.string(from: d)
    }

    // MARK: bindings

    private func bind<T>(_ kp: WritableKeyPath<CheckIn, T>) -> Binding<T> {
        Binding(
            get: { store.bodyCheckIn(key)[keyPath: kp] },
            set: { v in var ci = store.bodyCheckIn(key); ci[keyPath: kp] = v; store.data.body.checkIns[key] = ci }
        )
    }

    private func intBind(_ kp: WritableKeyPath<CheckIn, Int>) -> Binding<Double> {
        Binding(get: { Double(store.bodyCheckIn(key)[keyPath: kp]) },
                set: { v in var ci = store.bodyCheckIn(key); ci[keyPath: kp] = Int(v); store.data.body.checkIns[key] = ci })
    }

    private var weightString: Binding<String> {
        Binding(
            get: { store.bodyCheckIn(key).weight.map { String(format: "%.1f", $0) } ?? "" },
            set: { v in var ci = store.bodyCheckIn(key); ci.weight = Double(v); store.data.body.checkIns[key] = ci }
        )
    }

    private func setBind(_ kp: WritableKeyPath<CheckIn, Set<String>>, _ id: String) -> Binding<Bool> {
        Binding(
            get: { store.bodyCheckIn(key)[keyPath: kp].contains(id) },
            set: { on in
                var ci = store.bodyCheckIn(key)
                if on { ci[keyPath: kp].insert(id) } else { ci[keyPath: kp].remove(id) }
                store.data.body.checkIns[key] = ci
            }
        )
    }

    private func mealBind(_ n: Int) -> Binding<Bool> {
        Binding(
            get: { store.bodyCheckIn(key).meals.contains(n) },
            set: { on in
                var ci = store.bodyCheckIn(key)
                if on { ci.meals.insert(n) } else { ci.meals.remove(n) }
                store.data.body.checkIns[key] = ci
            }
        )
    }

    private func logBind(_ id: String) -> Binding<String> {
        Binding(
            get: { store.bodyCheckIn(key).exerciseLog[id] ?? "" },
            set: { v in var ci = store.bodyCheckIn(key); ci.exerciseLog[id] = v.isEmpty ? nil : v; store.data.body.checkIns[key] = ci }
        )
    }
}
