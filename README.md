# Cadence

A minimal, native macOS app for goal tracking + lightweight work/time tracking. No Electron, no database, zero third-party dependencies — just SwiftUI talking to system frameworks.

## Features

- **Goals** — set a goal with a target date, then open it to see a **GitHub-style contribution heatmap**, a big **days-remaining** countdown, and total/today/streak stats.
- **Work vs. Entertainment tracking** — tag any app or website as **Work** or **Entertainment**. A "working mode" switch samples the frontmost app every few seconds and records time into the right bucket (with idle detection so time away isn't counted).
- **Website tracking without a browser extension** — reads the active tab's **domain only** (never the full URL) via AppleScript. Works with Safari, Chrome, Brave, Arc, Edge, Vivaldi, Opera. (Firefox doesn't expose this.)

## Build & run

Requires the Swift toolchain (Xcode or Command Line Tools). No full Xcode needed.

```sh
./build.sh        # builds Cadence.app
open Cadence.app
```

## Permissions

- **Automation** — the first time tracking reads a browser, macOS asks to allow Cadence to control it. Click OK. (The app is ad-hoc code-signed so this grant persists.)

## Data

Everything is stored locally in:

```
~/Library/Application Support/Cadence/data.json
```

Only domains and categories are recorded — no full URLs, no page content.

## Project layout

| Path | What |
|------|------|
| `Sources/Cadence/Models.swift` | Data model + persistence types (with legacy-format migration) |
| `Sources/Cadence/Store.swift` | Single source of truth + JSON persistence |
| `Sources/Cadence/Tracker.swift` | Frontmost-app sampling, idle detection, browser URL reading |
| `Sources/Cadence/Views/` | SwiftUI views (goals, heatmap, tracking, settings) |
| `build.sh` | Builds and ad-hoc-signs the `.app` bundle |
