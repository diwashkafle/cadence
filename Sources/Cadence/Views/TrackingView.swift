import SwiftUI

struct TrackingView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var tracker: Tracker

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tracking").font(.largeTitle.bold())
                    HStack(spacing: 6) {
                        if let cat = tracker.activeCategory {
                            Circle().fill(cat.color).frame(width: 8, height: 8)
                        }
                        Text(tracker.status).foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 16) {
                    bigStat(title: "Work today", value: hours(store.seconds(on: Date())),
                            tint: Category.work.color,
                            active: tracker.activeCategory == .work)
                    bigStat(title: "Entertainment today", value: hours(store.entertainmentSeconds(on: Date())),
                            tint: Category.entertainment.color,
                            active: tracker.activeCategory == .entertainment)
                    bigStat(title: "Work this week", value: hours(weekWorkSeconds()),
                            tint: .secondary, active: false)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Today by app / site").font(.headline)
                    let breakdown = todayBreakdown()
                    if breakdown.isEmpty {
                        Text("Nothing counted yet today. Turn on working mode and use an app or site you've categorised.")
                            .font(.callout).foregroundStyle(.secondary)
                    } else {
                        ForEach(breakdown, id: \.0) { name, secs in
                            HStack(spacing: 8) {
                                Circle().fill(categoryColor(for: name)).frame(width: 8, height: 8)
                                Text(name)
                                Spacer()
                                Text(hours(secs)).monospacedDigit().foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6).padding(.horizontal, 12)
                            .background(Color.gray.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                if store.data.trackedApps.isEmpty && store.data.trackedSites.isEmpty {
                    Label("You haven't categorised any apps or sites yet — open Settings.",
                          systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func bigStat(title: String, value: String, tint: Color, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
            Text(title).font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(tint, lineWidth: active ? 2 : 0)
                )
        )
    }

    private func todayBreakdown() -> [(String, Int)] {
        let apps = store.data.logs[Date().dayKey]?.apps ?? [:]
        return apps.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    /// Infer a breakdown row's colour from the matching tracked app or site.
    private func categoryColor(for label: String) -> Color {
        if let app = store.data.trackedApps.first(where: { $0.name == label }) {
            return app.category.color
        }
        if let site = store.data.trackedSites.first(where: { $0.host == label }) {
            return site.category.color
        }
        return .secondary
    }

    private func weekWorkSeconds() -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var total = 0
        for offset in 0..<7 {
            if let d = cal.date(byAdding: .day, value: -offset, to: today) {
                total += store.seconds(on: d)
            }
        }
        return total
    }

    private func hours(_ seconds: Int) -> String {
        let h = Double(seconds) / 3600
        if h >= 1 { return String(format: "%.1fh", h) }
        return "\(seconds / 60)m"
    }
}
