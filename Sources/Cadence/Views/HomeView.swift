import SwiftUI

enum HomeTab: String, CaseIterable, Identifiable {
    case day = "Day"
    case year = "Year"
    var id: String { rawValue }
}

/// Home dashboard with two dot views that share the same colour mechanism:
/// green = worked, brown = elapsed but nothing logged, faint = upcoming, ring = now.
struct HomeView: View {
    @EnvironmentObject var store: Store
    @State private var tab: HomeTab = .day

    private let year = 2026
    private let brown = Color(red: 0.55, green: 0.34, blue: 0.17)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("", selection: $tab) {
                    ForEach(HomeTab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 240)

                switch tab {
                case .day:  daySection
                case .year: yearSection
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Day tab (24 hour-dots)

    private let dayDot: CGFloat = 16

    private var daySection: some View {
        let cal = Calendar.current
        let now = Date()
        let currentHour = cal.component(.hour, from: now)
        let today = cal.startOfDay(for: now)

        let workedSecs = store.seconds(on: now)
        let elapsed = currentHour                 // whole hours gone
        let left = 24 - currentHour               // hours remaining (incl. current)

        return VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(longDate(now)).font(.largeTitle.bold())
                Text("Every dot is an hour of today.")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                stat(hours(workedSecs), "worked", tint: Category.work.color)
                stat("\(elapsed)h", "elapsed", tint: brown)
                stat("\(left)h", "left today", tint: .secondary)
            }

            // 24 dots: two rows of 12 (00–11, 12–23).
            VStack(alignment: .leading, spacing: 8) {
                hourRow(0..<12, currentHour: currentHour, today: today)
                hourRow(12..<24, currentHour: currentHour, today: today)
            }

            dayLegend
        }
    }

    private func hourRow(_ range: Range<Int>, currentHour: Int, today: Date) -> some View {
        HStack(spacing: 6) {
            ForEach(range, id: \.self) { hour in
                VStack(spacing: 3) {
                    Circle()
                        .fill(hourColor(hour, currentHour: currentHour, today: today))
                        .frame(width: dayDot, height: dayDot)
                        .overlay(Circle().stroke(Color.accentColor,
                                                 lineWidth: hour == currentHour ? 2 : 0))
                        .help("\(String(format: "%02d:00", hour)) · \(minutes(store.workSeconds(on: today, hour: hour)))m worked")
                    Text(String(format: "%02d", hour))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func hourColor(_ hour: Int, currentHour: Int, today: Date) -> Color {
        let worked = store.workSeconds(on: today, hour: hour) > 0
        if worked { return Category.work.color }       // green if any work this hour
        if hour < currentHour { return brown }          // elapsed, nothing logged
        return Color.gray.opacity(0.15)                 // current (no work yet) or upcoming
    }

    private var dayLegend: some View {
        HStack(spacing: 14) {
            legendItem(Category.work.color, "Worked")
            legendItem(brown, "Empty hour")
            legendItem(Color.gray.opacity(0.15), "Upcoming")
            ringLegend("This hour")
        }
    }

    // MARK: - Year tab (365 day-dots)

    private let yearDot: CGFloat = 11

    private var yearSection: some View {
        let stats = yearStats()
        return VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "\(year)").font(.largeTitle.bold())
                Text("Every dot is a day. The brown ones already went by.")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                stat("\(stats.dayOfYear)", "of \(stats.total)", tint: .primary)
                stat("\(stats.worked)", "worked", tint: Category.work.color)
                stat("\(stats.off)", "went off", tint: brown)
                stat("\(stats.remaining)", "left in \(year)", tint: .secondary)
            }

            monthGrid
            yearLegend
        }
    }

    private var monthGrid: some View {
        let cal = Calendar.current
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(1...12, id: \.self) { month in
                HStack(alignment: .center, spacing: 4) {
                    Text(monthName(month))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(width: 34, alignment: .leading)
                    ForEach(daysIn(month: month, cal: cal), id: \.self) { day in
                        dayDotView(for: day)
                    }
                }
            }
        }
    }

    private func dayDotView(for date: Date) -> some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let day = cal.startOfDay(for: date)
        let isToday = day == today
        let isPast = day < today
        let worked = store.seconds(on: day) > 0

        let fill: Color
        if worked                 { fill = Category.work.color }
        else if isPast            { fill = brown }
        else                      { fill = Color.gray.opacity(0.15) }

        return Circle()
            .fill(fill)
            .frame(width: yearDot, height: yearDot)
            .overlay(Circle().stroke(Color.accentColor, lineWidth: isToday ? 2 : 0))
            .help("\(humanDate(date))\(worked ? " · worked" : "")")
    }

    private var yearLegend: some View {
        HStack(spacing: 14) {
            legendItem(Category.work.color, "Worked")
            legendItem(brown, "Went off")
            legendItem(Color.gray.opacity(0.15), "Upcoming")
            ringLegend("Today")
        }
    }

    // MARK: - Shared bits

    private func stat(_ value: String, _ label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(tint)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(minWidth: 70, alignment: .leading)
        .padding(.vertical, 8).padding(.horizontal, 12)
        .background(Color.gray.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private func legendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 11, height: 11)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func ringLegend(_ label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(Color.gray.opacity(0.15))
                .frame(width: 11, height: 11)
                .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Data helpers

    private func daysIn(month: Int, cal: Calendar) -> [Date] {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = 1
        guard let first = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: first) else { return [] }
        return range.compactMap { d -> Date? in
            var c = comps; c.day = d
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
        DateFormatter().shortMonthSymbols[month - 1].uppercased()
    }

    private func longDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMMM d"
        return f.string(from: d)
    }

    private func humanDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium
        return f.string(from: d)
    }

    private func hours(_ seconds: Int) -> String {
        let h = Double(seconds) / 3600
        if h >= 1 { return String(format: "%.1fh", h) }
        return "\(seconds / 60)m"
    }

    private func minutes(_ seconds: Int) -> Int { seconds / 60 }
}
