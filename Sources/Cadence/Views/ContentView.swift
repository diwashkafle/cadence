import SwiftUI

enum SidebarItem: Hashable {
    case home
    case goal(UUID)
    case tracking
    case settings
}

struct ContentView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var tracker: Tracker
    @State private var selection: SidebarItem? = .home
    @State private var showingNewGoal = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Home", systemImage: "circle.grid.3x3.fill")
                    .tag(SidebarItem.home)

                Section("Goals") {
                    ForEach(store.data.goals) { goal in
                        Label {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(goal.title).lineLimit(1)
                                Text(countdownText(goal))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "target")
                        }
                        .tag(SidebarItem.goal(goal.id))
                        .contextMenu {
                            Button("Delete", role: .destructive) { store.deleteGoal(goal) }
                        }
                    }
                    Button {
                        showingNewGoal = true
                    } label: {
                        Label("New Goal", systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                Section("Work") {
                    Label("Tracking", systemImage: "clock.badge.checkmark")
                        .tag(SidebarItem.tracking)
                    Label("Settings", systemImage: "slider.horizontal.3")
                        .tag(SidebarItem.settings)
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 240)
            .safeAreaInset(edge: .bottom) {
                WorkingToggle().padding(10)
            }
        } detail: {
            switch selection {
            case .home:
                HomeView()
            case .goal(let id):
                if let goal = store.data.goals.first(where: { $0.id == id }) {
                    GoalDetailView(goal: goal)
                } else {
                    placeholder
                }
            case .tracking:
                TrackingView()
            case .settings:
                SettingsView()
            case .none:
                placeholder
            }
        }
        .sheet(isPresented: $showingNewGoal) {
            NewGoalSheet { title, date in
                store.addGoal(title: title, targetDate: date)
            }
        }
    }

    private var placeholder: some View {
        Text("Select a goal or open Tracking")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func countdownText(_ goal: Goal) -> String {
        let d = goal.daysRemaining
        if d > 1 { return "\(d) days left" }
        if d == 1 { return "1 day left" }
        if d == 0 { return "due today" }
        return "\(-d)d overdue"
    }
}

/// Compact toggle pinned at the bottom of the sidebar.
struct WorkingToggle: View {
    @EnvironmentObject var tracker: Tracker

    var body: some View {
        Toggle(isOn: $tracker.isWorking) {
            HStack(spacing: 6) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                Text(tracker.isWorking ? "Working mode" : "Start working")
                    .font(.callout)
            }
        }
        .toggleStyle(.switch)
        .help(tracker.status)
    }

    private var dotColor: Color {
        guard tracker.isWorking else { return .gray }
        if let cat = tracker.activeCategory { return cat.color }
        return .yellow   // armed but nothing counting right now
    }
}

struct NewGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    let onCreate: (String, Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Goal").font(.title2.bold())
            TextField("What do you want to achieve?", text: $title)
                .textFieldStyle(.roundedBorder)
            DatePicker("Target date", selection: $date, displayedComponents: .date)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create") {
                    onCreate(title.trimmingCharacters(in: .whitespaces), date)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
