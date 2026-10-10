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
- **Security Rules enforce privacy on reads** (full plan §6.2): the identity doc is admin-only; the
  public doc is the 17-field projection. **MVP delta (C3): `private/admin` is readable by every
  signed-in user** (it is admin-only in the full plan), so core's `ComplaintService` can run
  client-side for every role — it needs the real priority inputs, assignment and actor timeline to
  validate and recompute whoever acts. A hand-crafted request from any signed-in token can therefore
  read assignee ids, actor ids and priority inputs; the apps never show them, the public document is
  unchanged, and **`private/identity` stays admin-only** (reporter name / ID / e-mail / phone are not
  exposed). Prod restores admin-only with the server executor.
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
  sender + APNs for iOS). Android in-app feed + badge work. **C3 ships without producing them** (see
  "C3 notes" below): recipient resolution needs a fix first, so C3 swaps in a no-op producer and C4
  adds the real fan-out.

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

## C3 notes (client-side write path)

Implemented in `packages/campusfix_firebase` (`firebase_complaint_repository.dart`,
`complaint_writes.dart`, `firebase_reporter_identity_revealer.dart`,
`deferred_notification_service.dart`) and the two apps' `providers/firebase_overrides.dart`.

- **One transaction per write.** `submit` allocates the next `CF-{year}-{NNNNN}` from
  `counters/complaintIds-{year}` (create at 1 / increment by 1; the service's local ID generator is
  ignored and the draft is re-keyed) and writes the public doc (`version: 1`, `claimed: false`),
  `private/admin`, `private/identity` and `userComplaints/{uid}/items/{id}`. `update` reads the public
  and `private/admin` docs, checks the stored `version` against the one the last `byId` saw, then
  writes `version + 1`, the append-only timeline, the new `updatedAt`, `private/admin` and the
  `staffClaims/{uid}/items/{id}` marker of a changed assignee. A stale version or a `closed` complaint
  throws `ComplaintConflictException` (nothing written).
- **`byId` is the write base.** Every `ComplaintService` action starts with `byId`; it reads
  `private/admin` for every role (the rules delta above) so the service recomputes priorities and
  checks P6/P7 on real data. List / stream reads keep the placeholder assembly for non-admins.
- **Rules.** Only `private/admin` `get` changed (admin-only -> signed-in). The existing
  `legalRoles` mirror already admits every transition for the right role: submit (reporter),
  Review & Route (verifier / admin, T1 or the T1+T2 composite), assign (verifier / admin), start /
  resolve (maintenance / admin), verify and reject (verifier / admin), **close (admin only)**,
  reassign / priority override / safety flag (admin).
- **Identity reveal (D4).** Admin-only. `FirebaseReporterIdentityRevealer.reveal(id, reason:)` is one
  transaction: read `private/identity` + write one `auditLog` entry
  `{ type: 'identityReveal', actorUid, actorRole, complaintId, reason, at, requestId }`; the identity
  is returned only after the commit (fail-closed). A-04's **Reveal reporter identity** asks for a
  required reason (`AppDialog.confirmWithNote`) when the revealer is wired (Firebase entrypoint); the
  offline demo is unchanged.
- **No notifications in C3.** `ComplaintService` builds notifications *before* it persists, and
  `NotificationService.buildFor` lists the user directory (`users/` is admin-only, staff only) and
  addresses the owner audience at `reporter.userId` (`private/identity`, admin-only; the assembled
  complaint carries `''`). That would abort every non-admin write, and for an admin it would address the owner notification to `''` (rejected by the `notifications` rule). C3 overrides
  `notificationServiceProvider` with `DeferredNotificationService` (its `buildFor` returns nothing;
  the feed / mark-read half is unchanged). **C4:** resolve recipients without the directory or the
  identity doc (e.g. a non-PII `reporterId` on `private/admin`, readable by every signed-in user since
  C3, and a staff-id roster), build the notifications **after** `submit` returns (the repository
  replaces the draft's Complaint ID), and delete the override.

## C4 notes (in-app notifications)

Implemented in `packages/campusfix_firebase` (`firebase_notification_service.dart`,
`complaint_writes.dart`), core's `ComplaintService.submit`, `backend/firestore.rules` and
`backend/seed/seed.mjs`. `DeferredNotificationService` (C3) is deleted.

- **Producer.** `FirebaseNotificationService extends NotificationService` is injected through
  `notificationServiceProvider` in both apps' `firebase_overrides.dart`. It keeps core's templates, the
  one-message-per-person rule and the `ntf-<eventId>-<recipientId>` ids; only recipient resolution (and
  re-delivery) changes. It never reads `users/` or `private/identity`.
- **Recipients, all non-PII.** *Owner* = `after.reporter.userId` when set (submit), else
  `complaints/{id}/private/admin.reporterId` (one `get`, cached per complaint). *department / verifiers /
  admins* = `rosters/staff` (read once per service instance):
  `{ maintenance: { <Department.name>: [uid] }, verifiers: [uid], admins: [uid] }`; "verifiers" =
  `verifiers` + `admins`. An audience that cannot be resolved is skipped (never an empty `recipientId`,
  which the rule rejects) and a failed lookup is logged, not thrown, so a notification problem cannot
  fail the complaint write.
- **`reporterId`** is the reporter's opaque uid in `private/admin` (seven keys now). Written at submit,
  carried over on every update from the stored document, and enforced by the rules: required string,
  `== request.auth.uid` on create, immutable on update. Name / ID / e-mail / phone stay in
  `private/identity`. A `private/admin` from before C4 has no `reporterId`: re-run the seed (an update of
  such a document is refused with a `StateError`, and by the rules).
- **Ordering fix.** `ComplaintService.submit` now builds and delivers the submission notifications
  *after* `ComplaintRepository.submit` returns, from the persisted complaint, because the Firebase
  repository replaces the draft's Complaint ID (and the TL-1 event id) with the counter-allocated one.
  Transitions already notify from the re-read complaint; their ids never change.
- **Duplicates.** Re-writing an existing deterministic notification id is `permission-denied` (the
  recipient may only flip `read`) and the writer cannot read it to check, so `deliver` treats that code as
  an idempotent re-delivery and rethrows any other error.
- **Rules.** `rosters/{doc}`: `get, list` for any signed-in user, `write: false` (the seed writes it with
  the Admin SDK). `notifications` rule unchanged. Re-seed and re-deploy the rules together.

## Orchestration
Opus orchestrator plans/decides/verifies; Sonnet agents implement each chunk (own worktree/branch);
orchestrator merges, builds/verifies, checkpoints. Account-free chunks (C0) run now while the Firebase
project is set up in parallel.
