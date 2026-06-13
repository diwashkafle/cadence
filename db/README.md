# Cadence DB (Drizzle + Neon)

Schema and migrations for the Cadence cloud database. This is the **source of truth**
for the table structure that the macOS app syncs into and the future mobile app reads from.

## One-time setup

```sh
cd db
npm install
cp .env.example .env        # then paste your Neon connection string into .env
npm run push                # create/update the tables in Neon
```

- `npm run push` — apply the schema directly to Neon (fast, good for solo dev).
- `npm run generate` — generate SQL migration files into `./migrations`.
- `npm run studio` — open Drizzle Studio to browse the data.

## Notes

- `.env` is gitignored. Never commit your connection string.
- The macOS app (`Sources/Cadence/SyncManager.swift`) also creates these tables
  with `CREATE TABLE IF NOT EXISTS`, so the app works even before you run `push` —
  but this file remains the canonical schema. Keep the two in sync when you change a table.
