# CampusFix backend (Phase 2 MVP)

Firebase **Spark (free)** backend for the demo: Auth + Firestore + Storage + Hosting.
**No Cloud Functions** (no Blaze billing), **Android + admin web only** (iOS and push deferred).
Plan and decisions: [`docs/phase-2-mvp.md`](../docs/phase-2-mvp.md) (MVP deltas) on top of
[`docs/phase-2-firebase-plan.md`](../docs/phase-2-firebase-plan.md) (production design).

```
backend/
  firebase.json            emulators (auth 9099, firestore 8080, storage 9199, hosting 5000, ui 4000),
                           hosting -> ../apps/admin/build/web (SPA rewrite), rules + indexes. No "functions".
  .firebaserc              project aliases (REPLACE_WITH_DEV_PROJECT_ID until the dev project exists)
  firestore.rules          3-way document split; reads production-grade; MVP client writes gated by the
                           status-transition mirror. Header comment lists every MVP-vs-prod delta.
  firestore.indexes.json   plan section 5.4
  storage.rules            plan section 7 (MVP: authenticated create for final evidence)
  seed/                    Node + firebase-admin seeder (local script, not a Function)
```

## How the MVP differs from production (summary)

| Area | MVP (this folder) | Production |
|------|-------------------|------------|
| Writes | Client-side, reusing `campusfix_core` logic; **rules enforce** legal transitions, `version + 1`, append-only timeline, closed-is-immutable, admin-only close | Server executor (Cloud Functions / Cloud Run), clients cannot write `complaints/**` |
| Identity | `private/identity` admin-**readable**; admin client writes the reveal audit entry (required reason) | No client read; reveal endpoint writes the audit first |
| Notifications | Writing client creates `notifications/*`; in-app feed only | Server fan-out + FCM push |
| Complaint IDs | Client allocates in a transaction on `counters/complaintIds-{year}` | Server |
| Roles | Custom claims set by `seed/seed.mjs` (Admin SDK, run locally) | Roster importer / server |

Reads and identity privacy are rules-enforced from day one; the MVP trusts the client for write
*integrity* (e.g. the priority value). Do not point real college data at this configuration.

## Prerequisites

- `firebase-tools` (`npm i -g firebase-tools`), Node >= 18, Flutter/Dart (repo toolchain).
- For the emulators you need no Firebase account. For the **dev** project you need a personal Spark
  project and a service-account key (see "Dev project" below).
- **Do not use your work Firebase login.** Run any `firebase` CLI step that needs auth with an isolated
  config dir: `XDG_CONFIG_HOME=~/.campusfix-firebase firebase ...`. The service-account key is referenced
  only via `GOOGLE_APPLICATION_CREDENTIALS` for CampusFix commands.

## 1. Start the emulators

```bash
cd backend
firebase emulators:start --project demo-campusfix     # demo-* ids never touch a real project
# Emulator UI: http://localhost:4000   Auth 9099  Firestore 8080  Storage 9199  Hosting 5000
```

## 2. Generate `seed.json`

The seed is the in-repo `SeedData` (25 users, 29 complaints, notifications) serialized by a small Dart CLI:

```bash
cd packages/campusfix_core
dart run tool/export_seed.dart > ../../backend/seed/seed.json
# options: --deterministic (fixed reference time instead of "now"), --pretty, --out <file>
```

## 3. Run the seed script

```bash
cd backend/seed
npm install
node seed.mjs --dry-run          # validate seed.json + print the plan; no Firebase, no install needed

# against the running emulators (no credentials)
FIRESTORE_EMULATOR_HOST=localhost:8080 FIREBASE_AUTH_EMULATOR_HOST=localhost:9099 \
FIREBASE_PROJECT_ID=demo-campusfix ALIAS_DOMAIN=id.campusfix.test node seed.mjs

# against the personal dev project (service-account key; --yes confirms a real project)
GOOGLE_APPLICATION_CREDENTIALS=$HOME/.campusfix/dev-sa-key.json \
ALIAS_DOMAIN=id.campusfix.test node seed.mjs --yes
```

For each user it creates an Auth user with `uid = AppUser.id`, the alias email
`<idNumber trimmed + lowercased>@$ALIAS_DOMAIN`, the password `$SEED_PASSWORD` (default `campusfix-demo`),
and custom claims `{ role, department? }`; it writes `users/{uid}`, every complaint's public document +
`private/admin` + `private/identity` + the `userComplaints` / `staffClaims` indexes, the notifications and
the `counters/complaintIds-{year}` documents. It is idempotent and refuses to run with `CF_ENV=prod`.

`ALIAS_DOMAIN` must equal the apps' `--dart-define=CF_ALIAS_DOMAIN=...` (both default to
`id.campusfix.test`). The demo password is for emulator/dev only.

## 4. Run the apps against the emulators

```bash
# mobile (Android emulator reaches the host as 10.0.2.2; the package picks it automatically)
cd apps/mobile && flutter run -t lib/main_firebase.dart --dart-define=CF_USE_EMULATOR=true
# admin web
cd apps/admin && flutter run -d chrome -t lib/main_firebase.dart --dart-define=CF_USE_EMULATOR=true
```

Useful defines: `CF_ENV=dev|prod`, `CF_USE_EMULATOR=true`, `CF_EMULATOR_HOST=<host>` (physical device),
`CF_ALIAS_DOMAIN=<domain>`, `SHOW_DEMO_ACCOUNTS=false` (hide the demo quick-fill; keep it on for the dev demo,
the quick-fill ids/password match the seed).

## Dev project (personal Spark project)

Owner-only console steps (~5 min): create the project, enable **Email/Password** sign-in, create the
**Firestore** database, and generate a **service-account key**. Then set the project id in `.firebaserc`
(`default` and `dev`) and deploy:

```bash
export GOOGLE_APPLICATION_CREDENTIALS=$HOME/.campusfix/dev-sa-key.json
export XDG_CONFIG_HOME=$HOME/.campusfix-firebase           # isolate from the work login

# rules + indexes (+ storage rules once the Storage bucket exists)
cd backend && firebase deploy --only firestore:rules,firestore:indexes --project dev

# admin web -> Firebase Hosting (free)
cd apps/admin && flutter build web -t lib/main_firebase.dart --dart-define=CF_ENV=dev
cd ../../backend && firebase deploy --only hosting --project dev
```

Enable email-enumeration protection in Auth settings (plan section 4) so unknown-user and wrong-password
collapse into one error; password resets are admin-issued (alias emails are not real inboxes).

## Notes

- `firebase.json` has **no `functions` block**; there is nothing to deploy beyond rules, indexes and hosting.
- The Firebase packages are imported only by `packages/campusfix_firebase` (and the two `main_firebase.dart`
  entrypoints); `campusfix_core` and `campusfix_design` stay Firebase-free.
- Rules unit tests (`@firebase/rules-unit-testing`, plan section 6.5) belong in `backend/test/rules/` (C2).
