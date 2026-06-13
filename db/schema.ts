import { pgTable, text, integer, doublePrecision, boolean, date, timestamp, jsonb } from "drizzle-orm/pg-core";

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

export const bodyCheckins = pgTable("body_checkins", {
  day: date("day").primaryKey(),
  weight: doublePrecision("weight"),
  sleepHours: doublePrecision("sleep_hours"),
  energy: integer("energy"),
  mood: integer("mood"),
  hunger: integer("hunger"),
  acidReflux: boolean("acid_reflux"),
  bloating: boolean("bloating"),
  shoulderPain: text("shoulder_pain"),   // none | load | rest
  floor: jsonb("floor"),                  // ["ac-rehab", ...]
  meals: jsonb("meals"),                  // [1,2,3]
  supplements: jsonb("supplements"),      // ["creatine", ...]
  exercises: jsonb("exercises"),          // ["goblet-squat", ...]
  exerciseLog: jsonb("exercise_log"),     // { "goblet-squat": "16kg × 10" }
  warmupDone: boolean("warmup_done"),
  intensity: text("intensity"),           // floor | standard | ceiling
  sessionDone: boolean("session_done"),
  updatedAt: timestamp("updated_at", { withTimezone: true }),
});

export const bodyMeasurements = pgTable("body_measurements", {
  week: date("week").primaryKey(),        // Sunday of the week
  weight: doublePrecision("weight"),
  belly: doublePrecision("belly"),
  chest: doublePrecision("chest"),
  bicep: doublePrecision("bicep"),
  thigh: doublePrecision("thigh"),
  compliance: integer("compliance"),
  updatedAt: timestamp("updated_at", { withTimezone: true }),
});
