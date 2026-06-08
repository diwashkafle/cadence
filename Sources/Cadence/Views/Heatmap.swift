import SwiftUI

/// GitHub-style contribution grid: one column per week, 7 rows (Sun…Sat).
/// Cell colour scales with counted work minutes that day.
struct Heatmap: View {
    let logs: [String: DayLog]
    let start: Date          // first day to show
    let end: Date            // last day to show

    private let cell: CGFloat = 12
    private let gap: CGFloat = 3

    var body: some View {
        let weeks = buildWeeks()
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: gap) {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: gap) {
                            ForEach(0..<7, id: \.self) { row in
                                cellView(week[row])
                            }
                        }
                    }
                }
            }
            legend
        }
    }

    @ViewBuilder
    private func cellView(_ day: Date?) -> some View {
        if let day, day <= Calendar.current.startOfDay(for: Date()) {
            let secs = logs[day.dayKey]?.work ?? 0
            RoundedRectangle(cornerRadius: 2)
                .fill(color(for: secs))
                .frame(width: cell, height: cell)
                .help("\(humanDate(day)) · \(minutes(secs)) min")
        } else {
            // Future day or padding — keep the grid aligned but invisible.
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.clear)
                .frame(width: cell, height: cell)
        }
    }

    private var legend: some View {
        HStack(spacing: 4) {
            Text("Less").font(.caption2).foregroundStyle(.secondary)
            ForEach([0, 20, 45, 90, 150], id: \.self) { m in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color(for: m * 60))
                    .frame(width: cell, height: cell)
            }
            Text("More").font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: Grid construction

    /// Each element is a 7-slot week, Sunday→Saturday, with nil for padding.
    private func buildWeeks() -> [[Date?]] {
        let cal = Calendar.current
        let firstDay = cal.startOfDay(for: start)
        let lastDay = cal.startOfDay(for: end)

        // Back up to the Sunday on or before the start.
        let weekday = cal.component(.weekday, from: firstDay) // 1 = Sunday
        let gridStart = cal.date(byAdding: .day, value: -(weekday - 1), to: firstDay) ?? firstDay

        var weeks: [[Date?]] = []
        var current = gridStart
        while current <= lastDay {
            var week: [Date?] = []
            for _ in 0..<7 {
                if current >= firstDay && current <= lastDay {
                    week.append(current)
                } else {
                    week.append(nil)
                }
                current = cal.date(byAdding: .day, value: 1, to: current) ?? current
            }
            weeks.append(week)
        }
        return weeks
    }

    // MARK: Styling

    private func color(for seconds: Int) -> Color {
        let m = seconds / 60
        let green = Color(red: 0.13, green: 0.77, blue: 0.37)
        switch m {
        case 0:        return Color.gray.opacity(0.15)
        case 1..<30:   return green.opacity(0.30)
        case 30..<60:  return green.opacity(0.50)
        case 60..<120: return green.opacity(0.75)
        default:       return green
        }
    }

    private func minutes(_ seconds: Int) -> Int { seconds / 60 }

    private func humanDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: d)
    }
}
