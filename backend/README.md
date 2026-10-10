# CampusFix backend (Phase 2 MVP)

Firebase **Spark (free)** backend for the demo: Auth + Firestore + Storage + Hosting.
**No Cloud Functions** (no Blaze billing), **Android + admin web only** (iOS and push deferred).
Plan and decisions: [`docs/phase-2-mvp.md`](../docs/phase-2-mvp.md) (MVP deltas) on top of
[`docs/phase-2-firebase-plan.md`](../docs/phase-2-firebase-plan.md) (production design).

```
backend/
  firebase.json            emulators (auth 9099, firestore 8080, storage 9199, hosting 5000, ui 4000),
                           hosting -> public/ (gitignored staging copy of ../apps/admin/build/web; SPA
                           rewrite — Firebase forbids a public dir outside backend/), rules + indexes.
                           No "functions".
  .firebaserc              project aliases (REPLACE_WITH_DEV_PROJECT_ID until the dev project exists)
  firestore.rules          3-way document split; reads production-grade except `private/admin` (any
                           signed-in user may read it, MVP delta (f)); MVP client writes gated by the
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
| Admin half | `private/admin` readable by **every signed-in user** (so `ComplaintService` runs client-side for every role; `private/identity` stays admin-only) | Admin only; server executor |
| Notifications | Writing client creates `notifications/*`; in-app feed only | Server fan-out + FCM push |
| Complaint IDs | Client allocates in the submit transaction on `counters/complaintIds-{year}` (create at 1 / +1) | Server |
| Roles | Custom claims set by `seed/seed.mjs` (Admin SDK, run locally) | Roster importer / server |

Reads and identity privacy are rules-enforced from day one (the one read relaxation is `private/admin`, see
above); the MVP trusts the client for write *integrity* (e.g. the priority value). In-app notifications are
produced client-side (C4: `FirebaseNotificationService` addresses them from the non-PII
`private/admin.reporterId` and `rosters/staff`; no push). Do not point real college data at
this configuration.

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

Live dev project: **`campus-fix-a8e09`** — Hosting **https://campus-fix-a8e09.web.app**.

Owner-only console steps (~5 min): create the project, enable **Email/Password** sign-in, create the
**Firestore** database, generate a **service-account key** (saved at `~/.campusfix-firebase/dev-sa.json`,
`chmod 600`), and grant that service account the **Editor** role in Google Cloud IAM. The default
"Firebase Admin SDK" SA can do runtime data + Auth + (via Admin SDK) rules, but **not** CLI deploys, index
creation, app registration, or Hosting without a management role.

All CLI/SDK steps use the key + an isolated CLI config so the work Firebase login is untouched:

```bash
export GOOGLE_APPLICATION_CREDENTIALS=$HOME/.campusfix-firebase/dev-sa.json
export XDG_CONFIG_HOME=$HOME/.campusfix-firebase/fbconfig     # isolate from the work login
PROJECT=campus-fix-a8e09
```

**Seed** (Auth users + claims + Firestore data — Admin SDK, bypasses rules):
```bash
cd packages/campusfix_core && dart run tool/export_seed.dart --deterministic > ../../backend/seed/seed.json
cd ../../backend/seed && npm install && ALIAS_DOMAIN=id.campusfix.test node seed.mjs --yes
```

**Rules** — the CLI's rules *test* step needs a permission the SA lacks (`firebaserules:test` 403), so
deploy rules via the Admin SDK (this also validates syntax):
```bash
cd backend/seed && node --input-type=module -e "import admin from 'firebase-admin';import {readFile} from 'node:fs/promises';admin.initializeApp({credential:admin.credential.applicationDefault()});await admin.securityRules().releaseFirestoreRulesetFromSource(await readFile('../firestore.rules','utf8'));console.log('rules released');"
```

**Indexes** (CLI, needs the Editor role):
```bash
cd backend && firebase deploy --only firestore:indexes --project $PROJECT
```

**Admin web → Firebase Hosting** (free). The web build needs the Firebase config as dart-defines (from
`firebase apps:sdkconfig WEB <appId>`), and the Hosting public dir must live inside `backend/`, so stage the
build into `backend/public/` first:
```bash
cd apps/admin && flutter build web -t lib/main_firebase.dart \
  --dart-define=CF_ENV=dev --dart-define=CF_ALIAS_DOMAIN=id.campusfix.test \
  --dart-define=CF_API_KEY=<apiKey> --dart-define=CF_APP_ID=<appId> --dart-define=CF_PROJECT_ID=$PROJECT \
  --dart-define=CF_MESSAGING_SENDER_ID=<senderId> \
  --dart-define=CF_AUTH_DOMAIN=$PROJECT.firebaseapp.com \
  --dart-define=CF_STORAGE_BUCKET=$PROJECT.firebasestorage.app
cd ../../backend && rsync -a --delete ../apps/admin/build/web/ public/ \
  && firebase deploy --only hosting --project $PROJECT
```

Enable email-enumeration protection in Auth settings (plan section 4) so unknown-user and wrong-password
collapse into one error; password resets are admin-issued (alias emails are not real inboxes).

## Notes

- `firebase.json` has **no `functions` block**; there is nothing to deploy beyond rules, indexes and hosting.
- The Firebase packages are imported only by `packages/campusfix_firebase` (and the two `main_firebase.dart`
  entrypoints); `campusfix_core` and `campusfix_design` stay Firebase-free.
- Rules unit tests (`@firebase/rules-unit-testing`, plan section 6.5) belong in `backend/test/rules/` (C2).
