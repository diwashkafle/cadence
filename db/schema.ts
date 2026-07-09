import { pgTable, text, integer, date, timestamp, jsonb } from "drizzle-orm/pg-core";

// Source of truth for the Cadence cloud database.
// The macOS app's SyncManager upserts into exactly these tables; the future
// mobile app reads from them directly. Keep this file and SyncManager in sync.

export const goals = pgTable("goals", {
  id: text("id").primaryKey(),
  title: text("title"),
  createdDate: timestamp("created_date", { withTimezone: true }),
  targetDate: timestamp("target_date", { withTimezone: true }),
  updatedAt: timestamp("updated_at", { withTimezone: true }),
});

export const dayLogs = pgTable("day_logs", {
  day: date("day").primaryKey(),
  work: integer("work"),
  entertainment: integer("entertainment"),
  apps: jsonb("apps"),     // { "App name": seconds }
  hours: jsonb("hours"),   // { "0".."23": seconds }
  updatedAt: timestamp("updated_at", { withTimezone: true }),
});

export const trackedApps = pgTable("tracked_apps", {
  bundleId: text("bundle_id").primaryKey(),
  name: text("name"),
  category: text("category"),   // work | entertainment
  updatedAt: timestamp("updated_at", { withTimezone: true }),
});

export const trackedSites = pgTable("tracked_sites", {
  host: text("host").primaryKey(),
  category: text("category"),
  updatedAt: timestamp("updated_at", { withTimezone: true }),
});
