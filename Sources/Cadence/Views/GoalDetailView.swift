import SwiftUI

struct GoalDetailView: View {
    @EnvironmentObject var store: Store
    let goal: Goal

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                countdown
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Work history").font(.headline)
                    Heatmap(logs: store.data.logs,
                            start: goal.createdDate,
                            end: goal.targetDate)
                }
                statsRow
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(goal.title).font(.largeTitle.bold())
            Text("Target: \(formatted(goal.targetDate))")
                .foregroundStyle(.secondary)
        }
    }

    private var countdown: some View {
        let d = goal.daysRemaining
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(abs(d))")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(d < 0 ? .red : .primary)
            VStack(alignment: .leading) {
                Text(d < 0 ? "days overdue" : (d == 1 ? "day remaining" : "days remaining"))
                    .font(.title3)
                if d >= 0 {
                    Text("until \(formatted(goal.targetDate))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            stat(title: "Total", value: hours(store.totalSeconds))
            stat(title: "Today", value: hours(store.seconds(on: Date())))
            stat(title: "Streak", value: "\(store.currentStreak)d")
        }
    }

    private func stat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title2.bold().monospacedDigit())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(minWidth: 80, alignment: .leading)
        .padding(.vertical, 10).padding(.horizontal, 14)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func hours(_ seconds: Int) -> String {
        let h = Double(seconds) / 3600
        if h >= 1 { return String(format: "%.1fh", h) }
        return "\(seconds / 60)m"
    }

    private func formatted(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: d)
    }
}
