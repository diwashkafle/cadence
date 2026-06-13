import SwiftUI

// MARK: - Week

struct BodyWeekView: View {
    @EnvironmentObject var store: Store

    private var wKey: String { weekKey(for: Date()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            weekGrid
            measurementsCard
            weightTrend
            if Calendar.current.component(.weekday, from: Date()) == 1 {
                Label("Sunday — log front + side photos (same spot, light, time).",
                      systemImage: "camera")
                    .font(.callout).foregroundStyle(.orange)
                    .padding(12)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var weekGrid: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let sunday = cal.date(byAdding: .day, value: -(weekday - 1), to: today) ?? today
        return VStack(alignment: .leading, spacing: 10) {
            Text("This week").font(.headline)
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    let day = cal.date(byAdding: .day, value: i, to: sunday) ?? sunday
                    let done = store.data.body.checkIns[day.dayKey]?.sessionDone ?? false
                    let isToday = cal.isDate(day, inSameDayAs: today)
                    VStack(spacing: 4) {
                        Text(weekdayShort(day)).font(.caption2).foregroundStyle(.secondary)
                        Circle()
                            .fill(done ? Category.work.color : Color.gray.opacity(0.15))
                            .frame(width: 26, height: 26)
                            .overlay(Circle().stroke(Color.accentColor, lineWidth: isToday ? 2 : 0))
                        Text(BodySchedule.sessionKey(for: day).rawValue.prefix(4))
                            .font(.system(size: 8)).foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var measurementsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly measurements").font(.headline)
            Text("Use the weekly average, not a single weigh-in. Baseline: 80kg · belly 40\" · chest 39\" · bicep 14\" · thigh 23\"")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            measureField("Weight avg (kg)", \.weight)
            measureField("Belly (in)", \.belly)
            measureField("Chest (in)", \.chest)
            measureField("Bicep flexed (in)", \.bicep)
            measureField("Thigh (in)", \.thigh)
            HStack {
                Text("Compliance").frame(width: 110, alignment: .leading)
                Slider(value: complianceBind, in: 0...10, step: 1)
                Text("\(measurement.compliance)").monospacedDigit().frame(width: 24)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var weightTrend: some View {
        let points = recentWeeklyWeights()
        return VStack(alignment: .leading, spacing: 10) {
            Text("Weight trend (weekly avg)").font(.headline)
            if points.count < 2 {
                Text("Log weekly weight for a couple of weeks to see the trend.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                SparkLine(values: points.map { $0.1 })
                    .frame(height: 80)
                HStack {
                    Text("\(points.first!.1, specifier: "%.1f")kg").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(points.last!.1, specifier: "%.1f")kg").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: helpers

    private var measurement: Measurement { store.data.body.measurements[wKey] ?? Measurement() }

    private func measureField(_ label: String, _ kp: WritableKeyPath<Measurement, Double?>) -> some View {
        HStack {
            Text(label).frame(width: 130, alignment: .leading)
            Spacer()
            TextField("—", text: measureBind(kp))
                .frame(width: 80).multilineTextAlignment(.trailing).textFieldStyle(.roundedBorder)
        }
    }

    private func measureBind(_ kp: WritableKeyPath<Measurement, Double?>) -> Binding<String> {
        Binding(
            get: { measurement[keyPath: kp].map { String(format: "%g", $0) } ?? "" },
            set: { v in var m = measurement; m[keyPath: kp] = Double(v); store.data.body.measurements[wKey] = m }
        )
    }

    private var complianceBind: Binding<Double> {
        Binding(get: { Double(measurement.compliance) },
                set: { v in var m = measurement; m.compliance = Int(v); store.data.body.measurements[wKey] = m })
    }

    private func recentWeeklyWeights() -> [(String, Double)] {
        store.data.body.measurements
            .compactMap { (k, m) in m.weight.map { (k, $0) } }
            .sorted { $0.0 < $1.0 }
    }

    private func weekdayShort(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE"
        return f.string(from: d)
    }
}

/// Minimal line chart for the weight trend.
struct SparkLine: View {
    let values: [Double]
    var body: some View {
        GeometryReader { geo in
            let lo = values.min() ?? 0, hi = values.max() ?? 1
            let span = max(0.001, hi - lo)
            Path { p in
                for (i, v) in values.enumerated() {
                    let x = values.count == 1 ? 0 : geo.size.width * CGFloat(i) / CGFloat(values.count - 1)
                    let y = geo.size.height * (1 - CGFloat((v - lo) / span))
                    i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(Category.work.color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Reference

struct SessionEditTarget: Identifiable { let id: String }

struct BodyReferenceView: View {
    @EnvironmentObject var store: Store
    @State private var editSession: SessionEditTarget?
    @State private var editingSupplements = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Tap the pencil on a session — or Edit on supplements — to tweak your routine. Changes save instantly and sync.")
                .font(.caption).foregroundStyle(.secondary)
            section("AC Joint Rehab — every morning, 8 min") {
                ForEach(acRehab) { exerciseLine($0) }
                Text("Banned for good: overhead swinging, behind-the-neck, deep dips.")
                    .font(.caption).foregroundStyle(.red)
            }

            section("The Floor — minimum viable day") {
                ForEach(floorItems) { item in
                    VStack(alignment: .leading, spacing: 1) {
                        Text("• " + item.label)
                        Text("   " + item.detail).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

            ForEach(store.data.body.sessions.filter { !$0.archived }) { s in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(s.name) · \(s.subtitle)").font(.headline)
                        Spacer()
                        Button { editSession = SessionEditTarget(id: s.id) } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                        .help("Edit this session")
                    }
                    if !s.warmup.isEmpty {
                        Text("Warmup").font(.caption.bold()).foregroundStyle(.secondary)
                        ForEach(s.warmup, id: \.self) { Text("• \($0)").font(.caption) }
                        Divider().padding(.vertical, 2)
                    }
                    ForEach(s.exercises) { exerciseLine($0) }
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }

            section("Diet by day type") {
                ForEach(dietReference, id: \.type.rawValue) { info in
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(info.type.label) · \(info.type.kcal) kcal · ~\(info.protein)g protein")
                            .font(.subheadline.bold())
                        Text(info.note).font(.caption2).foregroundStyle(.secondary)
                        ForEach(info.meals) { m in
                            Text("• \(m.name) (\(m.time)) — \(m.foods) · \(m.kcal) kcal / \(m.protein)g")
                                .font(.caption)
                        }
                    }
                    .padding(.bottom, 6)
                }
                Text("Weekly avg ~1,570 kcal. Protein every meal is the floor rule. Stop eating by 7:30–8 PM → 15-16h daily fast.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Supplements").font(.headline)
                    Spacer()
                    Button("Edit") { editingSupplements = true }.buttonStyle(.borderless)
                }
                ForEach(store.data.body.supplements.filter { !$0.archived }) { s in
                    VStack(alignment: .leading, spacing: 1) {
                        Text("• \(s.name) — \(s.dose), \(s.timing)")
                        if !s.notes.isEmpty {
                            Text("   \(s.notes)").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

            section("Monthly 36-48h fast") {
                Text("Wednesday dinner → Friday morning. Water, black coffee, plain ginger tea, electrolytes only. Never exceed 48h.")
                    .font(.caption)
                if let last = store.data.body.lastFast {
                    Text("Last fast: \(last.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .sheet(item: $editSession) { target in
            SessionEditorView(sessionID: target.id).environmentObject(store)
        }
        .sheet(isPresented: $editingSupplements) {
            SupplementEditorView().environmentObject(store)
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func exerciseLine(_ ex: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("• \(ex.name) — \(ex.setsReps)")
            if !ex.notes.isEmpty {
                Text("   \(ex.notes)").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
