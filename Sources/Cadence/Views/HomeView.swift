import SwiftUI

/// Year-in-dots overview for 2026: one dot per day.
/// - green  = a past day with work logged
/// - brown  = a past day that went off with nothing logged
/// - faint  = a day still to come
/// - ring   = today
struct HomeView: View {
    @EnvironmentObject var store: Store

    private let year = 2026
    private let dot: CGFloat = 11
    private let spacing: CGFloat = 4
    private let brown = Color(red: 0.55, green: 0.34, blue: 0.17)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                summary
                monthGrid
                legend
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(year, format: .number.grouping(.never))").font(.largeTitle.bold())
            Text("Every dot is a day. The brown ones already went by.")
                .foregroundStyle(.secondary)
        }
    }

    private var summary: some View {
        let stats = yearStats()
        return HStack(spacing: 16) {
            stat("\(stats.dayOfYear)", "of \(stats.total)", tint: .primary)
            stat("\(stats.worked)", "worked", tint: Category.work.color)
            stat("\(stats.off)", "went off", tint: brown)
            stat("\(stats.remaining)", "left in \(year)", tint: .secondary)
        }
    }

    private func stat(_ value: String, _ label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(tint)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(minWidth: 70, alignment: .leading)
        .padding(.vertical, 8).padding(.horizontal, 12)
        .background(Color.gray.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private var monthGrid: some View {
        let cal = Calendar.current
        return VStack(alignment: .leading, spacing: spacing) {
            ForEach(1...12, id: \.self) { month in
                HStack(alignment: .center, spacing: spacing) {
                    Text(monthName(month))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(width: 34, alignment: .leading)
                    ForEach(daysIn(month: month, cal: cal), id: \.self) { day in
                        dotView(for: day)
                    }
                }
            }
        }
    }

    private func dotView(for date: Date) -> some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let day = cal.startOfDay(for: date)
        let isToday = day == today
        let isPast = day < today
        let worked = store.seconds(on: day) > 0

        let fill: Color
        if isPast && worked      { fill = Category.work.color }
        else if isPast           { fill = brown }
        else if isToday && worked { fill = Category.work.color }
        else                     { fill = Color.gray.opacity(0.15) }

        return Circle()
            .fill(fill)
            .frame(width: dot, height: dot)
            .overlay(
                Circle().stroke(Color.accentColor, lineWidth: isToday ? 2 : 0)
            )
            .help("\(humanDate(date))\(worked ? " · worked" : "")")
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(Category.work.color, "Worked")
            legendItem(brown, "Went off")
            legendItem(Color.gray.opacity(0.15), "Upcoming")
            HStack(spacing: 5) {
                Circle().fill(Color.gray.opacity(0.15))
                    .frame(width: dot, height: dot)
                    .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                Text("Today").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func legendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: dot, height: dot)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: Data

    private func daysIn(month: Int, cal: Calendar) -> [Date] {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let first = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: first) else { return [] }
        return range.compactMap { d -> Date? in
            var c = comps
            c.day = d
            return cal.date(from: c)
        }
    }

    private func yearStats() -> (dayOfYear: Int, total: Int, worked: Int, off: Int, remaining: Int) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var total = 0, worked = 0, off = 0, dayOfYear = 0
        for month in 1...12 {
            for date in daysIn(month: month, cal: cal) {
                total += 1
                let day = cal.startOfDay(for: date)
                if day <= today { dayOfYear += 1 }
                if day < today {
                    if store.seconds(on: day) > 0 { worked += 1 } else { off += 1 }
                }
            }
        }
        return (dayOfYear, total, worked, off, max(0, total - dayOfYear))
    }

    private func monthName(_ month: Int) -> String {
        let f = DateFormatter()
        return f.shortMonthSymbols[month - 1].uppercased()
    }

    private func humanDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: d)
    }
}
