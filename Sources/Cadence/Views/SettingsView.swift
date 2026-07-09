import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var sync: SyncManager
    @State private var newSite = ""
    @State private var newSiteCategory: Category = .work
    @State private var runningApps: [TrackedApp] = []
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var neonURL = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Settings").font(.largeTitle.bold())

                // MARK: Cloud sync
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Cloud sync (Neon)").font(.headline)
                        Spacer()
                        statusBadge
                    }
                    Text("Your data auto-saves locally and pushes to your Neon database. Paste the connection string from your Neon dashboard — it's stored in the macOS Keychain, never in a file or git.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

                    SecureField("postgresql://user:password@…neon.tech/dbname?sslmode=require", text: $neonURL)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Save connection") {
                            sync.setConnectionString(neonURL)
                            neonURL = ""
                        }
                        .disabled(neonURL.isEmpty)
                        Button("Sync now") {
                            Task { await sync.sync() }
                        }
                        .disabled(sync.syncing || !sync.isConfigured)
                        if sync.syncing { ProgressView().controlSize(.small) }
                        Spacer()
                    }
                    Toggle("Sync automatically in the background", isOn: Binding(
                        get: { store.data.cloudAutoSync },
                        set: { store.data.cloudAutoSync = $0 }
                    ))
                    Text("Goals and settings sync instantly. Work tracking syncs every 30 minutes.")
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if let last = store.data.lastSyncedAt {
                        Text("Last synced: \(last.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if let err = sync.lastError {
                        Text(err).font(.caption2).foregroundStyle(.red)
                            .textSelection(.enabled).lineLimit(3)
                    }
                }

                Divider()

                // MARK: Apps
                VStack(alignment: .leading, spacing: 10) {
                    Text("Apps").font(.headline)
                    Text("Mark each app as Work or Entertainment. Time in it is recorded to that bucket; leave it Off to ignore it.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(combinedApps()) { app in
                        HStack(spacing: 10) {
                            if let icon = iconFor(app.bundleID) {
                                Image(nsImage: icon).resizable().frame(width: 18, height: 18)
                            }
                            VStack(alignment: .leading, spacing: 0) {
                                Text(app.name)
                                Text(app.bundleID).font(.caption2).foregroundStyle(.tertiary)
                            }
                            Spacer()
                            categoryPicker(
                                selection: store.trackedApp(bundleID: app.bundleID)?.category,
                                onChange: { store.setApp(app, category: $0) }
                            )
                        }
                        .padding(.vertical, 3)
                    }

                    Button {
                        runningApps = currentRunningApps()
                    } label: {
                        Label("Refresh running apps", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.link)
                }

                Divider()

                // MARK: Sites
                VStack(alignment: .leading, spacing: 10) {
                    Text("Websites").font(.headline)
                    Text("When a browser is in front, the active tab's domain is matched here and recorded to its bucket. Only the domain is read — never the full URL. The browser will ask for Automation permission once.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

                    HStack {
                        TextField("e.g. github.com", text: $newSite)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(addSite)
                        Picker("", selection: $newSiteCategory) {
                            ForEach(Category.allCases) { Text($0.label).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                        Button("Add", action: addSite).disabled(newSite.isEmpty)
                    }

                    ForEach(store.data.trackedSites) { site in
                        HStack {
                            Image(systemName: "globe").foregroundStyle(site.category.color)
                            Text(site.host)
                            Spacer()
                            Picker("", selection: Binding(
                                get: { site.category },
                                set: { store.setSiteCategory(site, category: $0) }
                            )) {
                                ForEach(Category.allCases) { Text($0.label).tag($0) }
                            }
                            .labelsHidden()
                            .frame(width: 150)
                            Button {
                                store.removeSite(site)
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4).padding(.horizontal, 10)
                        .background(Color.gray.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    }
                }

                Divider()

                // MARK: Startup
                VStack(alignment: .leading, spacing: 6) {
                    Text("Startup").font(.headline)
                    Toggle("Start Cadence at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, on in
                            do {
                                if on { try SMAppService.mainApp.register() }
                                else { try SMAppService.mainApp.unregister() }
                                loginError = nil
                            } catch {
                                loginError = error.localizedDescription
                                launchAtLogin = SMAppService.mainApp.status == .enabled
                            }
                        }
                    if let loginError {
                        Text(loginError).font(.caption).foregroundStyle(.red)
                    }
                    Text("Tracking itself starts automatically whenever Cadence launches (turn it off from the menu bar icon).")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                // MARK: Idle
                VStack(alignment: .leading, spacing: 6) {
                    Text("Idle threshold").font(.headline)
                    Text("Pause counting after \(store.data.idleThreshold)s of no keyboard or mouse activity.")
                        .font(.caption).foregroundStyle(.secondary)
                    Slider(
                        value: Binding(
                            get: { Double(store.data.idleThreshold) },
                            set: { store.data.idleThreshold = Int($0) }
                        ),
                        in: 30...600, step: 30
                    )
                    .frame(maxWidth: 320)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            runningApps = currentRunningApps()
        }
    }

    private var statusBadge: some View {
        let color: Color = sync.syncing ? .yellow
            : (sync.lastError != nil ? .red
            : (sync.isConfigured ? Category.work.color : .gray))
        return HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(sync.status).font(.caption).foregroundStyle(.secondary)
        }
    }

    /// Three-way Off / Work / Entertainment control.
    private func categoryPicker(selection: Category?, onChange: @escaping (Category?) -> Void) -> some View {
        Picker("", selection: Binding(
            get: { selection },
            set: { onChange($0) }
        )) {
            Text("Off").tag(Category?.none)
            Text("Work").tag(Category?.some(.work))
            Text("Fun").tag(Category?.some(.entertainment))
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 200)
    }

    private func addSite() {
        store.addSite(newSite, category: newSiteCategory)
        newSite = ""
    }

    /// Tracked apps unioned with currently-running regular apps, deduped.
    private func combinedApps() -> [TrackedApp] {
        var seen = Set<String>()
        var result: [TrackedApp] = []
        for app in store.data.trackedApps + runningApps {
            if seen.insert(app.bundleID).inserted {
                result.append(app)
            }
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func currentRunningApps() -> [TrackedApp] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let id = app.bundleIdentifier else { return nil }
                return TrackedApp(bundleID: id, name: app.localizedName ?? id)
            }
    }

    private func iconFor(_ bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
