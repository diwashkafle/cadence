import SwiftUI

// MARK: - Session editor (warmup + exercises)

struct SessionEditorView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let sessionID: String

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit session").font(.headline)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding()

            if let idx = store.data.body.sessions.firstIndex(where: { $0.id == sessionID }) {
                let session = $store.data.body.sessions[idx]
                Form {
                    Section("Session") {
                        TextField("Name", text: session.name)
                        TextField("Subtitle", text: session.subtitle)
                        Toggle("Fasted", isOn: session.fasted)
                    }

                    Section("Warmup") {
                        ForEach(session.wrappedValue.warmup.indices, id: \.self) { i in
                            TextField("Warmup step", text: session.warmup[i])
                        }
                        .onDelete { offsets in
                            var s = session.wrappedValue; s.warmup.remove(atOffsets: offsets); session.wrappedValue = s
                        }
                        Button {
                            var s = session.wrappedValue; s.warmup.append(""); session.wrappedValue = s
                        } label: { Label("Add warmup step", systemImage: "plus") }
                    }

                    Section("Exercises") {
                        ForEach(session.exercises) { $ex in
                            VStack(alignment: .leading, spacing: 4) {
                                TextField("Name", text: $ex.name).font(.body.bold())
                                TextField("Sets × reps (e.g. 4 × 8-10)", text: $ex.setsReps)
                                TextField("Notes", text: $ex.notes).font(.caption)
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete { offsets in
                            var s = session.wrappedValue; s.exercises.remove(atOffsets: offsets); session.wrappedValue = s
                        }
                        Button {
                            var s = session.wrappedValue
                            s.exercises.append(Exercise(id: UUID().uuidString, name: "New exercise", setsReps: "3 × 10"))
                            session.wrappedValue = s
                        } label: { Label("Add exercise", systemImage: "plus") }
                    }
                }
                .formStyle(.grouped)
            } else {
                Text("Session not found").onAppear { dismiss() }
            }
        }
        .frame(width: 480, height: 580)
    }
}

// MARK: - Supplement editor

struct SupplementEditorView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit supplements").font(.headline)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding()

            Form {
                ForEach($store.data.body.supplements) { $s in
                    Section {
                        TextField("Name", text: $s.name).font(.body.bold())
                        TextField("Dose", text: $s.dose)
                        TextField("Timing", text: $s.timing)
                        TextField("Notes", text: $s.notes).font(.caption)
                        Toggle("Saturday only", isOn: Binding(
                            get: { $s.wrappedValue.weeklyOn == 7 },
                            set: { $s.wrappedValue.weeklyOn = $0 ? 7 : nil }
                        ))
                        Toggle("Nightly", isOn: $s.nightly)
                    }
                }
                .onDelete { offsets in
                    store.data.body.supplements.remove(atOffsets: offsets)
                }
                Button {
                    store.data.body.supplements.append(
                        Supplement(id: UUID().uuidString, name: "New supplement", dose: "", timing: ""))
                } label: { Label("Add supplement", systemImage: "plus") }
            }
            .formStyle(.grouped)
        }
        .frame(width: 480, height: 580)
    }
}
