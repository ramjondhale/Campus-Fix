# CampusFix — Phase 2 MVP (demo) plan

**Status:** plan, in progress. **Supersedes, for the MVP only,** the production design in
[phase-2-firebase-plan.md](phase-2-firebase-plan.md) where this document says so. The full plan remains
the target for production; this is the simplest thing that demos end-to-end on free infrastructure.

## Scope (locked)

- **Demo only.** No real college data — use the existing in-repo `SeedData` (25 users, 29 complaints,
  notifications). No roster import.
- **Environments:** **dev** (now, dummy data) + **prod** (later, when needed). **No staging.**
- **Platforms:** **Android + admin web** for MVP. **iOS and push notifications deferred** (no Apple
  account yet) — the setup is kept easy to add later.
- **Firebase plan:** **Spark (free)** — no billing. (Blaze is only needed later for Cloud Functions and
  real push.)
- **Hosting:** Firebase Hosting (free) for the admin web app.

## Decisions (locked)

| Ref | Decision |
|-----|----------|
| **D2** Auth | Firebase **Email/Password** via **alias emails** derived from the existing demo ID numbers (no login-UI change). **No SSO.** Admin-issued password resets. |
| Roster | None — use existing `SeedData`. |
| **D4** Identity reveal | **Required reason.** Admin-only; an audit entry with the reason is written on reveal. |
| **D6** Separation of duties | **Not enforced** for MVP (simplest; matches the small-college assumption A2). |
| **D5** Close | **Admin-only** close. |
| **D3** Rework note on push | Omit (moot for MVP — in-app notifications only). |
| **D7** Admin notification feed | None. |
| **R6** Retention/erasure | None — data is **permanent** for the demo. |
| **D1** Server runtime | **Deferred.** MVP has **no server executor** (see architecture). Prod will add it. |

## MVP architecture (simplified from the full plan)

The full plan puts every write behind a trusted server executor. **For the MVP demo we skip the server**
and keep everything free and simple:

- **Firestore 3-way document split** — `complaints/{id}` (public), `complaints/{id}/private/admin`,
  `complaints/{id}/private/identity` — exactly as the full plan (§5), so the privacy model is the same.
- **Security Rules enforce privacy on reads** (full plan §6.2): identity/admin docs are role-gated;
  public doc is the 17-field projection. This part is production-grade from day one.
- **Writes run client-side**, reusing the already-tested `campusfix_core` logic (priority engine, status
  machine, assignment, notification templates). Rules enforce the **status-transition matrix** (full plan
  §6.3) and admin-only close. **Honest tradeoff:** the MVP trusts the client for write integrity
  (priority values, etc.); reads and identity privacy are rules-enforced. Prod replaces this with the
  server executor (full plan M3) — no UI/logic change, because of the repository seams.
- **Roles via custom claims**, set by a **local Admin-SDK seed script** (Node + `firebase-admin`, run
  locally with a service-account key — **not** a deployed Function). The app derives `AppUser.role` from
  the token claims. This is the one place we use the Admin SDK, and it stays free (just API calls).
- **Identity reveal (D4):** `private/identity` is admin-readable via rules; the admin client writes the
  audit entry (with the required reason) to `auditLog`. (Prod moves this behind the server endpoint so the
  audit is tamper-proof.)
- **Notifications:** **in-app feed only.** The writing client creates `notifications/{id}` docs using
  core's `NotificationService` recipient logic. **No background FCM push** in MVP (that needs a server
  sender + APNs for iOS). Android in-app feed + badge work.

### Upgrade path to prod (no app rewrite)
Add Cloud Functions (Blaze) as the executor → server-authoritative writes, server-set claims, FCM
fan-out; add APNs for iOS. The four repository interfaces are the seam, so the UI and `campusfix_core`
don't change.

## Firebase access & isolation (how Claude helps without touching the work account)

The machine already has `firebase-tools` logged in for **work** (`~/.config/configstore/...`). To let
Claude do most of the setup **without touching that**:

- **Primary credential: a service-account key for the personal `dev` project.** Referenced only via
  `GOOGLE_APPLICATION_CREDENTIALS` for CampusFix commands. It's a per-project credential (not the Google
  login), so it never touches `firebase login`, `gcloud`, or the work config. Used for: deploying rules &
  indexes, Firestore admin, and the seed script. Revoke anytime by deleting the key in the console.
- **Any `firebase` CLI step that needs user auth** is run with an **isolated config dir**
  (`XDG_CONFIG_HOME=~/.campusfix-firebase`), so it never reads or writes the work login.
- **Owner-only steps (web console, ~5 min):** create the personal Firebase project (free Spark), enable
  **Email/Password** auth, create the **Firestore** database, and **generate the service-account key**.
  Everything after that, Claude can do with the key.

## MVP milestone chunks

| Chunk | Needs account? | Scope |
|-------|----------------|-------|
| **C0 Scaffolding** | No (emulator) | `backend/` (firebase.json emulators [auth/firestore/storage/hosting, **no functions**], `.firebaserc` dev placeholder, `firestore.rules`, `firestore.indexes.json`, `storage.rules`), `packages/campusfix_firebase` skeleton (4 repo impls + init/emulator helper), `apps/*/lib/main_firebase.dart` entrypoints, `campusfix_core/tool/export_seed.dart`, `backend/seed/` Node Admin-SDK script skeleton |
| **C1 Auth + users** | dev project + SA key | `FirebaseAuthRepository` (alias email, claims, restore), `FirebaseUserRepository`, seed script provisions Auth users + claims + `users/{uid}` |
| **C2 Read path** | dev | public/admin/identity split, `FirebaseComplaintRepository` (read), indexes, seed loads complaints + notifications, rules tests |
| **C3 Write path (client)** | dev | wire `ComplaintService` writes through the Firebase repos; rules enforce transitions + admin-only close; identity reveal + audit (reason) |
| **C4 Notifications (in-app)** | dev | `FirebaseNotificationRepository` + client `NotificationService`; feed + badge |
| **C5 Hosting + demo polish** | dev | deploy admin web to Firebase Hosting (dev); Android build; demo accounts on; end-to-end verification |

Each chunk keeps the mock entrypoint (`lib/main.dart`) working, and cuts over one provider at a time
behind the `main_firebase.dart` override — same strategy as the full plan §11.3.

## Orchestration
Opus orchestrator plans/decides/verifies; Sonnet agents implement each chunk (own worktree/branch);
orchestrator merges, builds/verifies, checkpoints. Account-free chunks (C0) run now while the Firebase
project is set up in parallel.
