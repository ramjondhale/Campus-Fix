# CampusFix AI — Phase 2: Firebase backend plan

**Audience:** the team that builds the real backend. **Status:** plan, not built. **Inputs:** the as-built
prototype ([WALKTHROUGH.md](WALKTHROUGH.md), [RUN-LEDGER.md](RUN-LEDGER.md)) and the specs
([data-model](specs/data-model-spec.md), [privacy](specs/privacy-spec.md),
[status-machine](specs/status-machine-spec.md), [priority](specs/priority-engine-spec.md),
[assignment](specs/assignment-routing-spec.md), [screens](specs/screens-spec.md)). This document fulfils the
promise in [ARCHITECTURE.md](ARCHITECTURE.md) section 9; where it refines that table it says so.

**Contents**
1. [Goal and approach](#1-goal-and-approach)
2. [The seams: interface, mock, Firebase implementation](#2-the-seams-interface-mock-firebase-implementation)
3. [Seam adjustments (where "no UI change" needs a small additive change)](#3-seam-adjustments)
4. [Auth](#4-auth-firebase-auth)
5. [Firestore data model](#5-firestore-data-model)
6. [Security rules: the privacy model, enforced](#6-security-rules-the-privacy-model-enforced)
7. [Storage](#7-storage-cloud-storage)
8. [Push notifications (FCM)](#8-push-notifications-fcm)
9. [Business logic placement](#9-business-logic-placement)
10. [Seeding and migration](#10-seeding-and-migration)
11. [Rollout](#11-rollout)
12. [Risks and open decisions](#12-risks-and-open-decisions)

---

## 1. Goal and approach

**Goal.** Replace the in-memory mocks with Firebase (Auth, Firestore, Cloud Storage, FCM, plus a trusted
server component) **without rewriting the UI or the core logic**, and move the privacy guarantee from
"layering rules proven by tests" ([privacy-spec](specs/privacy-spec.md) prototype honesty clause, RR-3) to
a **server-enforced boundary**.

**Why this is feasible.** Both apps already depend on four **repository interfaces** in
[`packages/campusfix_core/lib/repositories/`](../packages/campusfix_core/lib/repositories) and obtain them
only through Riverpod providers (`apps/*/lib/providers/repositories.dart`). Swapping a provider's value
swaps the backend; widgets, routes, the design system and the pure logic (priority engine, status
machine, assignment router, privacy projections, notification templates) do not change.

**Approach in five rules**

1. **Interfaces stay; implementations change.** One `FirebaseX` class per interface, in a new package
   `packages/campusfix_firebase` (dependency direction `core <- firebase <- apps`; `campusfix_core` and
   `campusfix_design` stay free of Firebase imports). The mock layer stays for unit/widget tests and the
   offline demo.
2. **The server is authoritative for every write.** Clients read through Security Rules; every mutation
   (submit, status transitions, priority, assignment, identity reveal) goes through one trusted executor
   that re-validates with the same rules the pure logic encodes. Clients never write complaint documents.
3. **Document splitting is the privacy mechanism.** Firestore rules are per document, not per field, so
   the aggregate is split into a public document, an admin-only document and a no-client-read identity
   document. This directly encodes `PublicComplaintView` / `AdminComplaintView` / `ReporterIdentity`.
4. **One source of truth for business rules.** Prefer running the same Dart `campusfix_core` on the
   server; otherwise mirror it with golden test vectors exported from core's tests (section 9).
5. **Additive changes only.** Section 3 lists the few seams that need a small, additive change, so the
   scope of "no UI change" is honest.

```
 Flutter apps (mobile, admin web)                         Firebase project (per environment)
 +---------------------------------------+               +--------------------------------------------+
 | widgets -> providers (privacy boundary)|               | Auth: ID-number alias + custom claims      |
 |  AuthRepository ---------------------------------------> role, department                           |
 |  UserRepository ---------------------------------------> Firestore users/{uid}                      |
 |  ComplaintRepository (read) ---------------------------> Firestore complaints/**  (rules: split docs)|
 |  NotificationRepository -------------------------------> Firestore notifications                    |
 |  ComplaintActions (writes) --HTTPS + ID token----------> Executor (Functions / Cloud Run)           |
 |  photo upload -----------------------------------------> Storage uploads/{uid}/**  (staging)        |
 +---------------------------------------+               |   Executor uses the Admin SDK (bypasses rules):|
                                                         |    -> Firestore complaints, private/*, audit |
                                                         |    -> Storage complaints/{id}/** (clean copy)|
                                                         |    -> notifications + FCM push               |
                                                         +--------------------------------------------+
```

**What does not change:** every widget and route; `campusfix_design`; the pure logic and its tests; the
four interfaces' method signatures; the architecture guards (with the small additions in section 11.4).

---

## 2. The seams: interface, mock, Firebase implementation

The four interfaces, their mocks and their replacements:

| Interface ([`repositories/`](../packages/campusfix_core/lib/repositories)) | Mock implementation ([`mock/`](../packages/campusfix_core/lib/mock)) | Phase 2 implementation | Backed by | Role on the client |
|---|---|---|---|---|
| `AuthRepository` (`signIn(idNumber, password)`, `currentUser`, `signOut`) | `MockAuthRepository` | `FirebaseAuthRepository` | Firebase Auth + custom claims + `users/{uid}` | Sign-in, session |
| `ComplaintRepository` (`all`, `byId`, `byReporter`, `byDepartment`, `byStatus`, `submit`, `update`, `watchAll`) | `MockComplaintRepository` | `FirebaseComplaintRepository` | Firestore `complaints/**` + index collections | **Read-only on the client** (`submit`/`update` unused; the server executor implements them with the Admin SDK) |
| `NotificationRepository` (`all`, `byRecipient`, `add`, `markRead`, `markAllRead`, `watchByRecipient`) | `MockNotificationRepository` | `FirebaseNotificationRepository` | Firestore `notifications` | Read, `markRead`, `markAllRead`; `add` is server-only |
| `UserRepository` (`all`, `byId`, `maintenanceByDepartment`) | `MockUserRepository` | `FirebaseUserRepository` | Firestore `users` | Admin-only reads of **staff** profiles (A-04 staff names, assignee picker); the server reads every profile, reporters included, to resolve notification recipients |

**Provider override points.** The wiring is identical in both apps:

- [`apps/mobile/lib/providers/repositories.dart`](../apps/mobile/lib/providers/repositories.dart) and
  [`apps/admin/lib/providers/repositories.dart`](../apps/admin/lib/providers/repositories.dart):
  `authRepositoryProvider`, `complaintRepositoryProvider`, `notificationRepositoryProvider`,
  `userRepositoryProvider` (plus `seedDataProvider` and `mockLatencyProvider`, which Firebase mode ignores).
- [`apps/mobile/lib/providers/services.dart`](../apps/mobile/lib/providers/services.dart) and
  [`apps/admin/lib/providers/services.dart`](../apps/admin/lib/providers/services.dart):
  `complaintServiceProvider`, `notificationServiceProvider`.

Do **not** edit the defaults. Add a second entrypoint per app and override at the `ProviderScope`, so
`lib/main.dart` (mock, offline demo, CI) keeps working:

```dart
// apps/mobile/lib/main_firebase.dart  (new; run with `flutter run -t lib/main_firebase.dart`)
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final fb   = await CampusFixFirebase.init(env: kCfEnv);        // initializeApp, emulators, App Check
  final auth = await FirebaseAuthRepository.restore(fb);          // caches AppUser from claims (S-1)
  runApp(ProviderScope(
    retry: noAutoRetry,
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      userRepositoryProvider.overrideWithValue(FirebaseUserRepository(fb)),
      complaintRepositoryProvider.overrideWithValue(FirebaseComplaintRepository(fb, viewer: auth)),
      notificationRepositoryProvider.overrideWithValue(FirebaseNotificationRepository(fb)),
      complaintServiceProvider.overrideWithValue(RemoteComplaintService(fb)),   // S-2
      notificationServiceProvider.overrideWithValue(ClientNotificationService(fb)),
    ],
    child: const CampusFixApp(),
  ));
}
```

The admin app gets the same with `CampusFixAdminApp`. The login screens read `seedDataProvider` only when
`kShowDemoAccounts` is true, so Firebase builds pass `--dart-define=SHOW_DEMO_ACCOUNTS=false` (the switch
already exists in both `login_screen.dart` files) and never touch the seed.

---

## 3. Seam adjustments

A handful of places in the prototype assume a client-side backend. Each needs a small, additive change;
none touches a widget's layout. IDs are referenced throughout this document.

| ID | Where | Prototype behavior | Phase 2 change | Size |
|---|---|---|---|---|
| **S-1** | `AuthRepository.currentUser` is synchronous; `SessionNotifier.build()` reads it once ([`session.dart`](../apps/mobile/lib/providers/session.dart)) | Mock has the user immediately. | `FirebaseAuthRepository.restore()` is awaited in `main_firebase.dart` and caches the `AppUser` (role and department from the ID-token claims), so `currentUser` stays synchronous. Add an **additive** `Stream<AppUser?> authChanges` (default empty) and have `SessionNotifier` listen, so token revocation or sign-out elsewhere ends the session. | S |
| **S-2** | Four controllers call the **concrete** `ComplaintService` via `complaintServiceProvider`: mobile `work_actions.dart`, `verify_actions.dart`, `report_submit.dart`; admin `complaint_detail_controller.dart` | The L3 executor runs in the client. | Extract an `abstract interface class ComplaintActions` in core with `ComplaintService`'s public action methods (`submit`, `reviewAndRoute`, `assign`, `startWork`, `resolve`, `verify`, `close`, `reject`, `reassign`, `setPriorityOverride`, `setSafetyFlag`) and `ComplaintActionResult`. `ComplaintService implements ComplaintActions`; the provider's type becomes `ComplaintActions`; `RemoteComplaintService` implements it by calling the executor and rebuilding a `ComplaintActionResult` from `{ok, codes, messages}`. Method names are unchanged, so the four controllers need no edit beyond the provider's declared type. | M |
| **S-3** | `ComplaintIdGenerator(initialCounters: seed.lastSequenceByYear)` in `services.dart` | Client allocates `CF-YYYY-NNNNN`. | Server allocates inside the submit transaction from `counters/complaintIds-{year}` (monotonic, capped at 99999 as today). The remote service ignores the client generator. | S |
| **S-4** | `ComplaintRepository` returns the **raw `Complaint` including `reporter`**; `Complaint.reporter` is required | Every client could read identity (RR-3). | Identity and admin data live in other documents (section 5). `FirebaseComplaintRepository` assembles a `Complaint` per viewer with **redacted placeholders** (table in 5.3), so `toPublicView`, `myComplaintsProvider`, `workQueueProvider` and the admin controller keep working unchanged. Tighter end state (optional, after launch): view-returning queries (privacy-spec DM-4's alternative) so non-admin clients never construct a raw `Complaint` at all. | M |
| **S-5** | A-04 reads `view.reporter` and `identity_panel.dart` renders it on click | Identity is already in memory, merely not rendered. | Add `abstract interface class ReporterIdentityRevealer { Future<ReporterIdentity> reveal(String complaintId, {String? reason}); }` (core). `identity_panel.dart` calls it on **Reveal reporter identity** instead of reading the view's reporter; the placeholder in the view is never shown. Optional: a reason field (privacy-spec section 9 lists a free-text reason). Stays inside the already allow-listed file: the provider that exposes the revealer is typed only on `ReporterIdentityRevealer` (not a whole-word `ReporterIdentity`), so the exact admin allow-list (`ReporterIdentity` only in `identity_panel.dart`) still holds. | S |
| **S-6** | `Attachment.ref` is an asset path; after-photos are stamped with the client clock; `ComplaintPhoto` draws placeholders | Mock photos. | `ref` becomes a Storage object path; `createdAt` is set by the server (fresh-evidence rule P1 must not trust a device clock); `ComplaintPhoto` gains an injectable image resolver so `campusfix_design` stays Firebase-free (section 7). | M |
| **S-7** | The state machine's L1 matrix lists the **verifier on T6 (close)**; only the UIs withhold it | Policy is UI-only. | The executor enforces **admin-only close** (product decision, data-model-spec section 7). Also enforce it in the rule mirror (6.3). | S |
| **S-8** | `report_submit.dart` builds `ReporterIdentity` from the session and sends it to `ComplaintService.submit` | Needed because the client wrote the complaint. | The server derives identity from the ID token and `users/{uid}`; the client sends none. The `submit` signature can keep its `reporter` parameter (ignored) and later drop it. **Then `report_submit.dart` leaves core's `mobileReporterAllowList`** (tightening the PR-T14 guard). | S |
| **S-9** | `NotificationService` mixes the client half (`byRecipient`, `watchByRecipient`, `markRead`, `markAllRead`, `unreadCount`) with the producer half (`buildFor`, `deliver`, `emitFor`) that needs the user directory | All in the client. | The producer half runs in the executor. The client gets a thin `ClientNotificationService` over `NotificationRepository` (same method names), so `notificationsProvider` and `markNotificationRead` are untouched. | S |
| **S-10** | `ComplaintService.refreshAging` / `refreshAndPersist` are implemented and tested but **no app calls them**; seed priorities are aged at build time | Aging is not live. | A scheduled function applies `refreshAging` to unresolved complaints (priority-engine-spec section 6 already says "replace the on-read recompute with a scheduled Cloud Function"). | S |
| **S-11** | `watchAll()` / `all()` stream **every** complaint to every client (the board needs them) | Fine in memory. | Bound the Firestore listeners (open complaints plus recent closed; `byId`/`byReporter` on demand) and add the indexes in 5.4. | M |

---

## 4. Auth (Firebase Auth)

**Today.** `MockAuthRepository.signIn(idNumber, password)` matches `AppUser.idNumber` (trimmed,
case-insensitive) and returns `null` for any bad credential, which the login screens render as the
non-enumerating "ID or password is incorrect". Roles are `UserRole` values on `AppUser`; maintenance
users also carry a `Department`.

**Mapping to Firebase Auth (default for the pilot).**

- **Identifier.** Firebase Auth has no username, so each ID number maps deterministically to a **synthetic
  email alias** on a domain the college controls or a reserved one, e.g.
  `<idNumber trimmed and lowercased>@id.campusfix.<college-domain>`. `FirebaseAuthRepository.signIn`
  applies the same normalization as `MockAuthRepository` (trim, lowercase) and calls
  `signInWithEmailAndPassword(alias, password)`. The alias is an identifier only; the real address stays in
  `AppUser.email`.
- **Errors.** Enable Firebase Auth's email-enumeration protection (so unknown-user and wrong-password
  collapse into one error), then map `invalid-credential`, `user-not-found`, `wrong-password` and
  `user-disabled` to `null` (keeps the screen's non-enumerating message). **Rethrow** network and unexpected errors: both login
  screens already catch exceptions and show "Couldn't sign you in. Please try again." with Retry.
- **Stable user IDs.** Create users with `uid = AppUser.id` (`u-rep-01`, `u-adm-01`, ...). Firebase Admin
  `createUser` accepts a custom uid; this keeps `Complaint.reporter.userId`, `Assignment.assigneeId` and
  notification `recipientId` valid and lets mock and Firebase data interleave during the phased cutover.
- **Role and department as custom claims.** The provisioning tool sets
  `{ role: 'reporter'|'maintenance'|'verifier'|'admin', department: 'electrician'|... }` (department only
  for maintenance) with the Admin SDK, and writes the matching `users/{uid}` profile (`displayName`,
  `idNumber`, `email`, `role`, `department`). **The client derives `AppUser.role` from the token claims,
  not from the profile document**, so a profile edit can never grant a role. Claims are small (well under
  the 1000-byte limit) and are read from `getIdTokenResult()`.
- **Claim changes** (promotion, department move) take effect on the next token refresh: the provisioning
  tool also revokes refresh tokens, and the client forces `getIdToken(true)` on resume. Disabling an
  account is `disabled: true` plus token revocation.
- **Provisioning.** Users are created by a roster import (CSV from the college's student/staff system) run
  by an admin-controlled script, never by self-signup (disable client sign-up; the apps have no registration
  screen). The same script is the seeder for demos (section 10).

**How the apps consume claims (no UI change).**

- **Mobile role routing**: `appRedirect` and `RoleGuard` already branch on `AppUser.role`
  ([`app_router.dart`](../apps/mobile/lib/router/app_router.dart)); `role` now comes from claims. The
  admin-on-mobile rule is unchanged: `SessionNotifier.signIn` ends an admin's session and returns
  `adminUsesWeb`.
- **Console A/V gating**: `mayUseConsole(role)` and `kConsoleRoles`
  ([`admin session.dart`](../apps/admin/lib/providers/session.dart)) decide `success` vs `notAuthorized`
  (E-403, AC-45) exactly as today. Rules add a second, data-level gate (section 6) so a reporter or
  maintenance token cannot read admin data even with a hand-made request.
- **Sign-out**: besides `FirebaseAuth.signOut()`, delete this device's FCM token (section 8).

**Open sub-decision (D2, section 12).** The alias email is not a real inbox, so "forgot password" cannot
email the user. For the pilot, resets are admin-issued through the provisioning tool. Alternatives: use
the real college email as the Auth identity (needs an enumeration-guarded ID-to-email lookup), or an
SSO provider (SAML/OIDC through Identity Platform), which would add a sign-in method to `AuthRepository`
(a UI change).

---

## 5. Firestore data model

### 5.1 Collections

```
users/{uid}                                  AppUser profile (self; admins read staff profiles only)
  fcmTokens/{token}                          device tokens, owner-managed
complaints/{complaintId}                     PUBLIC projection  = PublicComplaintView (+ version, claimed)
  private/admin                              ADMIN-ONLY         = the rest of AdminComplaintView, minus identity
  private/identity                           NO CLIENT READ     = ReporterIdentity (released only by the reveal endpoint)
userComplaints/{uid}/items/{complaintId}     ownership index (owner reads: "My complaints" / byReporter)
staffClaims/{uid}/items/{complaintId}        claim index (maintenance reads: "claimed by me" / P7)
notifications/{id}                           AppNotification (recipient reads; id = ntf-<eventId>-<recipientId>)
auditLog/{entryId}                           append-only audit (admin reads; server writes)
counters/complaintIds-{year}                 Complaint ID sequence (server only)
config/campus                                CampusDirectory (buildings -> floors -> rooms), optional
requests/{requestId}                         executor idempotency records (server only)
```

This refines ARCHITECTURE.md section 9, which listed flat `complaints` / `statusEvents` / `users`: the
timeline is embedded (below) and identity gets its own restricted document, as that section and
privacy-spec section 9 both intended. The executor maintains the two index collections in the same
transaction as the change: `userComplaints/{uid}/items/{id}` is written on submit; `staffClaims/{uid}/items/{id}`
whenever an `assigneeId` is set (claim at T3/T4, or named by an admin at T2/T8) and removed when it is
cleared. Server-side code (the executor) reads `users/{uid}` for **every** role, reporters included, with
the Admin SDK; that is how it resolves notification recipients and builds `private/identity`.

### 5.2 Mapping the Dart models

| Dart type | Where it lives | Notes |
|---|---|---|
| `PublicComplaintView` fields (17: `id, category, title, building, floor, room, description, beforePhotos, afterPhotos, effectivePriority, status, safetyFlag, assignedDepartment, resolutionNote, timeline, createdAt, updatedAt`) | `complaints/{id}` document, using `PublicComplaintView.toJson()` key names verbatim | The server writes exactly these keys plus two non-PII helpers: `version` (int, optimistic concurrency, rule P8) and `claimed` (bool, true iff an assignee is named; lets the maintenance queue apply P7 without exposing who). A server test asserts the key set equals the PR-T2 allow-list plus those two. |
| `Attachment` (`id, kind, ref, caption, createdAt`) | embedded in `beforePhotos[]` / `afterPhotos[]` of the public document | `ref` = Storage path; `createdAt` = server time (S-6). |
| `PublicStatusEvent` (`status, actorRole, note, at`) | embedded `timeline[]` of the public document | Append-only; a complaint has a handful of events, far below the 1 MiB document limit. One read per complaint, matching `PublicComplaintView`. |
| `StatusEvent` (`id, status, actorId, actorRole, note, at`) | `private/admin.timeline[]` (same order and length as the public one) | Actor identity (privacy class P2) is admin-only. |
| `Assignment` (`department, assigneeId, assignedBy, assignedAt, isManual`) | `private/admin.assignment`; the public document carries only `assignedDepartment` | `isManual` is derived by the executor (`isManualAssignment`), as `ComplaintService` does today. |
| `priority`, `priorityOverride`, `severity`, `peopleAffected` | `private/admin` | `effectivePriority` (`priorityOverride ?? priority`) is stored in the public document. |
| `ReporterIdentity` | `complaints/{id}/private/identity` | Never readable by a client (6.4). |
| `AppUser` | `users/{uid}` plus claims | `role` and `department` authoritative in claims. |
| `AppNotification` | `notifications/{id}` | Deterministic id keeps writes idempotent. |
| Complaint ID | `counters/complaintIds-{year}` | Replaces `ComplaintIdGenerator`. |
| `CampusDirectory.standard` | optional `config/campus` | Today a compiled constant; moving it lets the college edit buildings without a release. |

### 5.3 How `FirebaseComplaintRepository` assembles a `Complaint` per viewer (S-4)

The interface returns `Complaint`; the repository fills restricted fields with placeholders so the
providers stay untouched. `ReporterIdentity` has a plain const constructor, so empty strings work today
(an additive `ReporterIdentity.redacted` would be tidier).

| `Complaint` field | Admin | Verifier / reporter | Maintenance |
|---|---|---|---|
| `reporter` | placeholder; real identity only through the reveal endpoint (S-5) | placeholder; `userId` = the caller's uid when the complaint is in their `userComplaints` index, else empty (keeps `myComplaintsProvider` working) | placeholder |
| `assignment.assigneeId` | real, from `private/admin` | null | the caller's uid if in `staffClaims`, a fixed opaque sentinel if `claimed` and not theirs, else null (keeps `workQueueProvider`'s "unclaimed or mine" rule) |
| `assignment.assignedBy`, `isManual`, `assignedAt` | real | placeholders (never rendered) | placeholders |
| `timeline[].actorId` | real | empty | empty |
| `priority`, `priorityOverride`, `severity`, `peopleAffected` | real | `priority = effectivePriority`, override null, defaults | same |

`byReporter(uid)` reads `userComplaints/{uid}/items` and fetches those complaints; `byDepartment(d)` is a
query on the public `assignedDepartment` (public by design); `byStatus` queries `status`. `watchAll()` (what
`_rawComplaintsProvider` streams in both apps) joins the caller's own `userComplaints` and `staffClaims`
listeners, so the one `Complaint` list carries the right `reporter.userId` and `assigneeId` placeholders. The
`ComplaintRepository` doc comment already says these query methods exist "so ownership and department
filtering can run inside the data layer, before projection" (privacy-spec section 5.3).

### 5.4 Indexes (`firestore.indexes.json`)

- `notifications`: (`recipientId` asc, `createdAt` desc), for `watchByRecipient` and `byRecipient`.
- `complaints`: (`assignedDepartment` asc, `status` asc), for the maintenance queue; (`status` asc,
  `updatedAt` desc), for the verification queue and bounded board listeners.
- `auditLog`: (`type` asc, `at` desc) and (`complaintId` asc, `at` desc), for access reports.

---

## 6. Security rules: the privacy model, enforced

### 6.1 Principles carried over from privacy-spec

- **PV-4 (identity is admin-only) and PV-5 (never in lists)** become: `private/identity` has **no client
  read at all**; `private/admin` is readable by `role == 'admin'` only; the public document contains no
  P0, P1 or P2 data by construction (its key set is the 17-key allow-list).
- **PV-2 (default deny)**: a final catch-all denies everything not named.
- **Server-authoritative writes**: clients cannot write `complaints/**`.
- Rules are **not filters**: every list query must be constrained to documents the caller may read
  (for example `notifications` by `recipientId`).

### 6.2 `firestore.rules` sketch

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ---- the caller: custom claims set by the Admin SDK (section 4) ----
    function signedIn()       { return request.auth != null; }
    function role()           { return request.auth.token.role; }       // reporter | maintenance | verifier | admin
    function isAdmin()        { return signedIn() && role() == 'admin'; }   // == UserRole.canSeeReporterIdentity
    function isOwnerPath(uid) { return signedIn() && request.auth.uid == uid; }

    // ---- directory ----
    match /users/{uid} {
      // Admins may read STAFF profiles only (A-04 staff names, assignee picker). Reporter profiles are
      // self-readable only: this keeps the prototype's behavior where the admin directory never holds
      // a reporter (`_adminDetails` filters them out), so a reporter's name cannot surface before the
      // audited reveal. The query must constrain `role` with whereIn.
      allow get:   if isOwnerPath(uid)
                   || (isAdmin() && resource.data.role in ['maintenance', 'verifier', 'admin']);
      allow list:  if isAdmin() && resource.data.role in ['maintenance', 'verifier', 'admin'];
      allow write: if false;                     // provisioned by the Admin SDK only
      match /fcmTokens/{token} {
        allow read, write: if isOwnerPath(uid);  // each device manages its own token
      }
    }

    // ---- PUBLIC projection: exactly the PublicComplaintView fields (+ version, claimed) ----
    match /complaints/{complaintId} {
      allow get, list: if signedIn();            // the campus board is visible to every signed-in user (R6)
      allow write: if false;                     // every mutation goes through the executor (section 9)

      // Admin-only half of the aggregate: priority inputs, full assignment, actor-bearing timeline.
      match /private/admin {
        allow get:   if isAdmin();               // verifiers, maintenance and reporters are denied (PR-T4)
        allow write: if false;
      }
      // Reporter identity: NO client may read it, not even an admin. It is released only by the
      // reveal endpoint, which writes the audit entry first (6.4).
      match /private/identity {
        allow read, write: if false;
      }
    }

    // ---- the only links from a person to a complaint ----
    match /userComplaints/{uid}/items/{complaintId} {
      allow get, list: if isOwnerPath(uid);      // owner only: not admins, not verifiers
      allow write:     if false;
    }
    match /staffClaims/{uid}/items/{complaintId} {
      allow get, list: if isOwnerPath(uid);
      allow write:     if false;
    }

    // ---- notifications: recipient reads; may only flip `read` ----
    match /notifications/{id} {
      allow get, list: if signedIn() && resource.data.recipientId == request.auth.uid;
      allow update:    if signedIn() && resource.data.recipientId == request.auth.uid
                       && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['read']);
      allow create, delete: if false;            // created by the executor
    }

    // ---- append-only audit log (privacy-spec section 9) ----
    match /auditLog/{entryId} {
      allow read:  if isAdmin();
      allow write: if false;                     // server-only: "admin-unwritable"
    }

    match /config/{doc}   { allow read: if signedIn(); allow write: if false; }
    match /counters/{doc} { allow read, write: if false; }
    match /requests/{doc} { allow read, write: if false; }

    match /{document=**}  { allow read, write: if false; }   // default deny
  }
}
```

Notes: rules do not cascade to subcollections, which is why `private/*` needs its own `match`.
Reporters and maintenance staff can technically read board data from the web console's Firestore client,
but that is exactly what the board shows them on mobile; the console's E-403 gate is UI, the data gate is
the three-way split above.

### 6.3 Why not rules-only, and what the status-machine mirror would look like

A rules-only backend (clients write `complaints` directly) is **rejected for production**: rules cannot
call the priority engine, enforce the evidence preconditions P1/P2 or recompute priority, fan out
notifications, or write an audit entry on a *read* of identity. The executor exists for those. For
completeness, the L1 matrix is expressible in rules and is useful as an **executable spec** in the rules
unit tests (and as defense in depth should a narrow direct-write path ever be added):

```
function legalRoles(from, to) {
  let edges = {
    'reported>reviewed':   ['verifier', 'admin'],       // T1
    'reviewed>assigned':   ['verifier', 'admin'],       // T2
    'assigned>inProgress': ['maintenance', 'admin'],    // T3
    'inProgress>resolved': ['maintenance', 'admin'],    // T4
    'resolved>verified':   ['verifier', 'admin'],       // T5
    'verified>closed':     ['admin'],                   // T6: product policy (L1 also lists verifier; S-7)
    'resolved>inProgress': ['verifier', 'admin'],       // T7
    'inProgress>assigned': ['admin']                    // T8
  };
  return edges.get(from + '>' + to, []);
}

allow update: if signedIn()
  && resource.data.status != 'closed'                                           // INV-4: closed is immutable
  && request.resource.data.version == resource.data.version + 1                 // P8: stale check
  && (request.resource.data.status == resource.data.status
      || role() in legalRoles(resource.data.status, request.resource.data.status))
  && request.resource.data.timeline.size() == resource.data.timeline.size() + 1 // append-only timeline
  && request.resource.data.timeline[0:resource.data.timeline.size()] == resource.data.timeline;
```

### 6.4 Identity reveal and the audit log (privacy-spec PV-4, PV-5, LK-8, section 9)

Firestore cannot trigger code on a read, so an audit entry per reveal is only trustworthy if the **read
itself goes through the server**. Hence `private/identity` is closed to clients and A-04's **Reveal
reporter identity** calls the `revealReporterIdentity` endpoint (S-5):

1. Verify the ID token; require `role == 'admin'`, else `permission-denied`.
2. Rate-limit per admin (privacy-spec section 9 "reveal controls") and require App Check.
3. In one transaction, write `auditLog/{id}` and read `private/identity`. **Fail closed**: if the audit
   write fails, return nothing.
4. Return `{fullName, idNumber, email, phone}`. The client keeps it only in `identity_panel.dart` state and
   drops it on Hide, navigation and sign-out (existing LK-8 behavior).

**Audit entry** (append-only; `auditLog` is admin-readable, server-writable):

```
{ type: 'identityReveal',            // also: 'priorityOverride', 'manualAssignment', 'reassignment',
  actorUid, actorRole, complaintId,  //       'statusChangeOnBehalf'  (privacy-spec section 9)
  reason: '<free text, optional or required: decision D4>',
  at: <server timestamp>, requestId, appCheck: true }
```

One entry per reveal (not per page view). The executor writes the other entry types as part of the
transaction that makes the change. Audit entries contain no reporter identity themselves.

**Left-over consequence worth noting:** because the public document has no identity, **erasure and
retention** (privacy-spec section 9) become tractable: an erasure job deletes `private/identity`,
`userComplaints/{uid}` and the `users/{uid}` profile while complaints remain as anonymous records.

### 6.5 Rules tests (Firebase Emulator, `@firebase/rules-unit-testing`)

Translate the privacy-spec assertions into rules tests, with a token per role:

| Privacy assertion | Rules / emulator test |
|---|---|
| PR-T4 admin gating over all four roles | `get complaints/x/private/admin`: allowed for `admin`; denied for `reporter`, `maintenance`, `verifier`, unauthenticated |
| PV-4 identity admin-only | `get complaints/x/private/identity` is **denied for every role including admin**; reveal endpoint returns it only for admin and writes an audit entry |
| PV-5 / PR-T2 public key allow-list | After running the executor on the emulator, `Object.keys(publicDoc)` equals the 17 keys plus `version` and `claimed` |
| PR-T9 seed sweep | After seeding the emulator, scan every public document for every seeded reporter's and staff member's strings: none present |
| Writes closed | Any client `set/update/delete` on `complaints/**`, `auditLog`, `counters`, `notifications` (create) is denied; recipient can set `read` only |
| Ownership | `userComplaints/a/items/*` readable by uid `a`, denied for uid `b` and for admin |
| Directory | An admin can list staff profiles but gets nothing for a reporter profile; a reporter reads only their own |
| Default deny | Reads of an unnamed path are denied |

---

## 7. Storage (Cloud Storage)

**Today.** The Report flow and the after-repair form add bundled *sample* photos
(`pickSamplePhoto`, assumption A4); `Attachment.ref` is an asset path; `ComplaintPhoto` draws a
category-tinted placeholder from it.

**Upload flow (two-stage, so metadata is clean and evidence is server-stamped).**

1. **Stage.** The client uploads each photo to `uploads/{uid}/{draftId}/{attachmentId}.<ext>` with a random
   `attachmentId` (no original file names, privacy class P3) and keeps the path in the draft
   `Attachment.ref`. Removing a photo from the draft just drops it; a lifecycle rule expires `uploads/`
   after a day or two.
2. **Submit / resolve.** The executor validates each staged object (exists, owner prefix equals the caller's
   uid, content type and size, count 1 to 5 as `ReportLimits` / `ResolveLimits`), **strips EXIF/GPS and
   re-encodes** (LK-9, privacy-spec section 9 "upload hygiene"), writes the clean copy to
   `complaints/{complaintId}/{before|after}/{attachmentId}.jpg`, and sets `Attachment.ref` to that path and
   `createdAt` to **server time**. Rule P1 (an after-photo must postdate the last rejection) is therefore
   enforced against a trusted clock (S-6).
3. **Render.** Store paths, not download URLs (a tokenized URL is a bearer credential). Resolve with
   `getDownloadURL()` at render time and cache.

**`storage.rules` sketch**

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // staging: the uploader only; images only; size-capped; never updated or deleted from a client
    match /uploads/{uid}/{draftId}/{fileName} {
      allow create: if request.auth != null && request.auth.uid == uid
                    && request.resource.size < 5 * 1024 * 1024
                    && request.resource.contentType.matches('image/(jpeg|png|webp|heic)');
      allow read:   if request.auth != null && request.auth.uid == uid;
      allow update, delete: if false;
    }
    // final evidence: written only by the executor; readable by whoever may read the public complaint
    match /complaints/{complaintId}/{kind}/{fileName} {
      allow read:  if request.auth != null;
      allow write: if false;
    }
  }
}
```

**Design package seam.** Keep `campusfix_design` Firebase-free: give `ComplaintPhoto` an injectable
resolver (an `InheritedWidget` or theme extension holding `ImageProvider? Function(Attachment)`). With no
resolver, or a `ref` that is an asset path, it draws today's placeholder, so the gallery and the tests are
unchanged; `campusfix_firebase` supplies the Storage-backed resolver. `PhotoUploader` and the mocked
camera/gallery sheet (`pickSamplePhoto`) get a real picker (`image_picker`) behind the same callbacks
(`onAdd`).

---

## 8. Push notifications (FCM)

**What exists.** `NotificationTemplates.plan` (pure) produces PII-free drafts per event and audience;
`NotificationService.buildFor` resolves recipients (**owner** = reporter, **department** = maintenance
users of a department, **verifiers** = verifier and admin users, **admins** = admins) and dedupes to one
notification per person per event (the first message wins). `deliver` stores them. The mobile feed and
badge read them through `NotificationRepository`.

**Design.**

| Concern | Decision |
|---|---|
| Source of truth | The in-app `notifications/{id}` document, written by the executor in the same transaction as the status change. Id `ntf-<eventId>-<recipientId>` is deterministic, so retries are idempotent (this id scheme already exists in `buildFor`). |
| Producer | **Server**: `NotificationTemplates.plan` and the recipient rules run in the executor (S-9). Clients never fan out. |
| Delivery | After commit, the server sends FCM to each recipient's tokens (`users/{uid}/fcmTokens`). **Per-recipient sends, not topics**, to preserve the one-per-person dedupe across audiences. Optional topic `dept-<department.name>` only for a broadcast "new work" if recipient lists grow large. |
| Payload | `notification {title, body}` from the stored notification, plus `data {notificationId, complaintId, type}`. Tapping routes with the existing `notificationRoute(role, complaintId)` (reporter to M-10, maintenance to M-14, verifier to M-17). |
| PII on the lock screen | Bodies are PII-free by contract (LK-1) but include location and, for rework, the rejection note (free text, class P3). **Recommended:** omit the note from the push body and show it in-app (decision D3). |
| Tokens (client) | Register after sign-in, update on token refresh, delete on sign-out (extend `SessionNotifier.signOut`). The server prunes tokens FCM reports as unregistered. |
| Permissions | A one-time notification-permission prompt after first sign-in (a small UX addition; the in-app feed works without it). iOS needs an APNs key and push entitlement, so the **iOS build blocker** ([BUILDING.md](BUILDING.md)) must be resolved first. |
| Admins | The spec has no admin notification feed in v1 (the dashboard covers it). Optional later: web push or e-mail for the **admins** audience. |

**Stays client-side:** token registration, permission prompts, foreground display, mark-read
(`markRead` / `markAllRead` are the only notification writes a client keeps, limited to the `read` field
by rules).

---

## 9. Business logic placement

**Decision.** The pure logic in `campusfix_core` is the single source of truth for the rules. Mutations
run **server-side**; the client keeps the pure functions only for UI affordances.

| Logic | Server (executor) | Client | Notes |
|---|---|---|---|
| `computePriority`, aging (`refreshAging`) | **Yes**: on submit, every transition before `resolved`, safety-flag edits, and a scheduled sweep (S-10) | No | Priority freezes at `resolved` and unfreezes on T7 (INV-5), exactly as `ComplaintService` does. |
| `StatusMachine.canTransition` / `nextStatuses` (L1) | **Yes**, authoritative | **Yes**, for affordances (`manageActionsFor`, `WorkJob.canStart`, `VerifyJob.canVerify`) | Server also enforces admin-only close (S-7). |
| `StatusMachine.validateTransition` (L2, P1 to P9) and the service rules (`PO`, `SF`, `P4` directory check, `RA2`) | **Yes** | Optional previews only | Returns the same blocker `code` and `message` to the client. |
| `routeToDepartment`, `isManualAssignment` | **Yes**: `isManual`, `assignedBy`, `assignedAt` are derived, never trusted from the caller | Pre-selection in the A-04 dialogs | Same as `ComplaintService._assignmentFor`. |
| Complaint ID allocation | **Yes** (S-3) | No | |
| `toPublicView` / `toAdminView` | **Yes**: the stored public document **is** the projection, written by one writer | Still applied to assembled `Complaint`s (harmless defense in depth) | |
| `NotificationTemplates.plan`, recipient resolution | **Yes** (S-9) | No | |
| Audit entries | **Yes**, same transaction as the change | No | |

**The executor** is one logical endpoint set (callable functions or HTTPS), each call carrying the caller's
Firebase ID token and a client-generated `requestId` (stored in `requests/` to dedupe double taps):

| Call | Maps to | Returns |
|---|---|---|
| `submitComplaint` | `ComplaintService.submit` | `{complaintId, priority}` (what `SubmittedReport` needs) |
| `applyAction` (`action`, `complaintId`, `expectedStatus`, payload) | `reviewAndRoute`, `assign`, `startWork`, `resolve`, `verify`, `close`, `reject`, `reassign`, `setPriorityOverride`, `setSafetyFlag` | `{ok, codes[], messages[]}` mapped back to `ComplaintActionResult` |
| `revealReporterIdentity` | S-5 | identity, after the audit write |

Each call runs in a **Firestore transaction**: read the public and `private/admin` documents, assemble a
`Complaint`, plan with the core logic (including composite atomicity for Review & Route), then write the
public document (`version + 1`), `private/admin`, the `userComplaints` / `staffClaims` indexes,
notification documents and audit entries in one commit; FCM is sent after commit. The `expectedStatus`
and `version` give the stale check P8 across instances (the in-process per-complaint lock in
`ComplaintService._tails` only serializes within one instance, so concurrency control must be the
transaction).

**Decision D1: how to keep a single source of truth.**

| Option | How | Pros | Cons |
|---|---|---|---|
| **A. Run `campusfix_core` on the server** | A Dart service (for example on Cloud Run) implements the repository interfaces with Admin-SDK Firestore access and runs `ComplaintService` and `NotificationService` unchanged | Zero drift; the existing 651 tests cover the server logic | Server-side Dart Firebase Admin tooling must be evaluated for maturity (ID-token verification, Firestore transactions); callable-function ergonomics differ |
| **B. TypeScript functions + parity vectors** | Port the logic; export golden vectors from core's tests (priority E1 to E22 and the 960-input property grid, the 196-tuple L1 table, preconditions N1 to N15, the 17-key allow-list, notification templates) to JSON, and run them in the server tests | Mature Admin SDK, triggers, scheduler and callable support | Two implementations to keep in sync; vectors are the guard |

**Recommendation:** a short spike (S-0, in M0) to test Option A against the Firestore transaction and
token-verification needs; default to Option B with vectors if the spike finds gaps. Either way the vector
export is worth building: a `packages/campusfix_core/tool/export_vectors.dart` that emits JSON consumed by
the server and rules tests.

---

## 10. Seeding and migration

There is **no production data to migrate**: the prototype is in-memory. Phase 2 needs a **demo and
test seeder** and a **roster importer**.

**Seeder** (`backend/seed/`, runs against the emulators or a dev project; never production):

1. `dart run packages/campusfix_core/tool/export_seed.dart > backend/seed/seed.json` serializes
   `SeedData.build(now: DateTime.now())`: 25 users, 29 complaints, 226 notifications and
   `lastSequenceByYear` (a small new tool; `SeedData` is pure Dart).
2. A loader (Node with the Admin SDK) writes, per complaint: the public document (from the
   `toPublicView(c).toJson()` shape plus `version` and `claimed`), `private/admin`, `private/identity`,
   the `userComplaints` and `staffClaims` indexes; per user: an Auth user with `uid = AppUser.id`, the alias
   email, the claims and `users/{uid}`; the notifications as-is (their ids already match the production
   scheme); `counters/complaintIds-{year}` from `lastSequenceByYear`.
3. The demo password is `seedDemoPassword` (`campusfix-demo`) **in the emulator and dev only**; staging and
   production never receive it, and their builds pass `--dart-define=SHOW_DEMO_ACCOUNTS=false`.
4. Seed photos keep their `assets/seed/...` refs and render as placeholders (no resolver match); optionally
   upload a handful of sample images to the Storage emulator for a richer demo.
5. After loading, run the **PII sweep** (PR-T9) over the emulator's public documents.

**Roster importer** (production onboarding): CSV of ID number, name, email, role, department and an
optional phone to Auth users (alias email, `uid` policy, claims) plus `users/{uid}`; idempotent and
re-runnable; role and department changes use the same tool. The phone is not part of `AppUser`; it is
stored on `users/{uid}` and read only by the executor when it writes `private/identity` (today
`report_submit.dart` builds `ReporterIdentity` without a phone as well). This is a command-line admin
tool, not an app screen.

**Schema evolution:** include `schemaVersion` on each document and ship one-off migration scripts under
`backend/migrations/`; the public key set is guarded by the allow-list test, so adding a field is a
deliberate, reviewed act (PV-2).

---

## 11. Rollout

### 11.1 Firebase Emulator Suite for local development

`firebase.json` runs the **Auth, Firestore, Storage, Functions** (and Pub/Sub for the scheduler)
emulators. The apps connect when `--dart-define=CF_USE_EMULATOR=true` is set
(`useAuthEmulator`, `useFirestoreEmulator`, `useStorageEmulator`, `useFunctionsEmulator`; use the host
alias for the Android emulator). The loop is: start emulators, run the seeder, run
`flutter run -t lib/main_firebase.dart` (mobile) or the admin web with the same define. CI runs the rules,
function and contract tests under `firebase emulators:exec`.

### 11.2 Environments and flavors

- Three Firebase projects: **dev**, **staging**, **prod** (the product is single-tenant, R1, so one
  project per environment, no tenant dimension).
- `--dart-define=CF_ENV=dev|staging|prod` selects options; generate `firebase_options_<env>.dart` with
  `flutterfire configure` per project. Mobile uses Android product flavors and iOS schemes with per-flavor
  `google-services.json` / `GoogleService-Info.plist`; the admin web uses the define plus a Hosting target
  per environment.
- `SHOW_DEMO_ACCOUNTS=false` for staging and prod (existing switch). App Check on in staging and prod.
- Backend code, rules, indexes and the seeder live in a new top-level `backend/` directory (appendix).

### 11.3 Phased cutover (one repository at a time, behind the provider override)

Each milestone is demonstrable and leaves the mock entrypoint working. Sizes are relative (S, M, L).

| Milestone | Scope | Exit criteria |
|---|---|---|
| **M0 Foundations** (M) | Firebase projects, `backend/` skeleton, emulators, `campusfix_firebase` package skeleton, flavors, CI emulator job, **spike S-0** for decision D1, rules test harness | Emulators start in CI; a no-op `main_firebase.dart` boots in both apps; D1 decided |
| **M1 Auth and users** (M) | `FirebaseAuthRepository` (alias sign-in, claims, restore, S-1), `FirebaseUserRepository`, provisioning script and roster importer, role and console gating from claims | All four demo-role logins work on the emulator; admin on mobile gets the web notice; reporter on web gets E-403; bad credentials stay non-enumerating |
| **M2 Complaint read path** (M) | Public/private document split, `FirebaseComplaintRepository` (read, S-4, S-11 bounds), indexes, seeder, rules for complaints and index collections | Board, My Complaints, queues, dashboard and list render from the emulator with seed data; rules tests for PR-T4, ownership and default deny pass; PR-T9 sweep over emulator documents passes |
| **M3 Server executor** (L) | `ComplaintActions` (S-2) and `RemoteComplaintService`, executor calls (`submitComplaint`, `applyAction`), transactions with `version`, ID counter (S-3), priority and aging (S-10), admin-only close (S-7), audit entries for on-behalf and override actions | All three role flows complete end to end on the emulator; golden vectors pass; two concurrent actions yield one success and one stale (P8) |
| **M4 Notifications and FCM** (M) | Executor-side notification fan-out (S-9), `FirebaseNotificationRepository`, `ClientNotificationService`, token lifecycle, push send, deep links | In-app feed matches the prototype's templates and recipients; a device receives a push for T2 and T4; sign-out removes the token |
| **M5 Storage and photos** (M) | Two-stage upload, EXIF strip, `ComplaintPhoto` resolver (S-6), `image_picker`, storage rules | Before and after photos round-trip; server-stamped `createdAt` drives P1; storage rules tests pass |
| **M6 Identity isolation and audit** (M) | `revealReporterIdentity` and `ReporterIdentityRevealer` (S-5), reason prompt if D4 says so, `report_submit.dart` leaves the allow-list (S-8), audit-log reader | Identity doc unreadable from any client token; each reveal writes exactly one audit entry; PR-T14 guard tightened and green |
| **M7 Hardening** (M) | App Check, rate limits, retention and erasure job, monitoring and alerts, load check of listeners and indexes, security review of rules and the executor | Review sign-off; the full privacy-assertion rules matrix is green in CI |
| **M8 Pilot** (S) | Staging soak with real devices, roster import, production cutover, demo accounts off | Checklist signed off; rollback plan for the executor and rules documented |

Cutover is **per repository behind the override**: M1 swaps `authRepositoryProvider` and
`userRepositoryProvider`; M2 swaps `complaintRepositoryProvider`; M3 swaps `complaintServiceProvider`; M4
swaps the notification providers. Because the emulator seed uses the same user IDs as the mock seed,
mixed configurations remain coherent while the work progresses.

### 11.4 Testing strategy

1. **Keep the mocks for unit and widget tests.** The existing suites (core 651, design 224, mobile 199,
   admin 344) never touch Firebase and stay the fast CI gate. Per CLAUDE.md, run mobile and core together.
2. **Repository contract tests.** Extract the behavior tests under `packages/campusfix_core/test/mock/` into
   reusable `runXRepositoryContract(factory)` suites and run them against the mock **and** the Firebase
   implementation on the emulator, so the two cannot diverge.
3. **Rules tests** (`@firebase/rules-unit-testing`): the matrix in 6.5.
4. **Executor tests**: golden vectors (section 9), transaction concurrency, idempotent retry by
   `requestId`, audit entries, notification recipients matching the prototype's templates.
5. **Integration tests**: Flutter `integration_test` driving the three mobile role flows and the admin
   console against the emulators; the lifecycle (report, review, start, resolve, verify, close) is the
   backbone scenario.
6. **Architecture guards extended**: only `campusfix_firebase` may import Firebase plugins; PR-T14 also
   scans the new package for logging of complaints; after S-8, `report_submit.dart` is removed from
   `mobileReporterAllowList`; the exact allow-list rule for `apps/admin` is unchanged.
7. **Staging smoke test and a pilot** with real devices before production.

---

## 12. Risks and open decisions

| ID | Decision or risk | Options / mitigation | Recommendation |
|---|---|---|---|
| **D1** | Server runtime for the executor | Dart on Cloud Run (A) vs TypeScript functions with parity vectors (B), section 9 | Spike in M0; default to B if the spike finds gaps; build the vector export either way |
| **D2** | Auth identifier and password reset | Alias email (admin-issued reset), real college email with guarded lookup, or SSO via Identity Platform | Alias email for the pilot; revisit SSO if the college has an IdP |
| **D3** | Push content on lock screens | Full body, or omit the rework note | Omit the note from push; show in-app |
| **D4** | Reason on identity reveal | Optional, required, or none | Required free-text reason (privacy-spec section 9 lists it); adds one field to the reveal panel |
| **D5** | Verifier closing complaints | State machine L1 allows it; product says admin-only | Enforce admin-only on the server (S-7) |
| **D6** | Separation of duties (resolver must not verify; SM-OI-5) | Deferred in v1 (small-college assumption A2) | Now cheap to enforce server-side; decide with the college |
| **D7** | Admin notification feed | None in v1 | Optional web push or e-mail after launch |
| **R1** | Listener cost: every client streams every complaint (board) | Bounded queries (S-11), indexes, pagination for closed | Load-test in M7 |
| **R2** | The `Complaint` placeholder convention (S-4) hides a leakage risk if a future provider reads placeholder fields | Placeholders are inert (empty or sentinel); tests assert no real identity or staff id ever appears for non-admin viewers; move to view-returning repositories after launch | Accept for launch, schedule the tightening |
| **R3** | Free-text residual PII (description, notes, captions; RR-1) | Helper text exists; add PII-pattern warnings and internal-only admin notes in a later release | Out of scope for the first cut |
| **R4** | Small-population inference from location and time (RR-2) | Accepted by R6 | Revisit with the college |
| **R5** | iOS build is blocked, which also blocks push and device testing | Resolve per [BUILDING.md](BUILDING.md) before M4 | Schedule in M0 |
| **R6** | Data protection obligations (retention, erasure, consent) | Retention schedule, erasure job (6.4), audit-log retention | Agree the schedule with the college before pilot |

---

## Appendix: proposed layout

```
campusfix/
├── backend/
│   ├── firebase.json                  # emulators, hosting targets
│   ├── firestore.rules                # section 6.2
│   ├── firestore.indexes.json         # section 5.4
│   ├── storage.rules                  # section 7
│   ├── server/                        # executor (Dart per D1-A, or functions/ in TypeScript per D1-B)
│   ├── seed/                          # export_seed output, loader, roster importer
│   ├── migrations/
│   └── test/
│       ├── rules/                     # @firebase/rules-unit-testing matrix (6.5)
│       └── vectors/                   # JSON exported from campusfix_core tests
├── packages/
│   ├── campusfix_core/                # + ComplaintActions, ReporterIdentityRevealer, tool/export_*.dart
│   ├── campusfix_design/              # + injectable photo resolver for ComplaintPhoto
│   └── campusfix_firebase/            # FirebaseAuth/User/Complaint/NotificationRepository,
│                                      #   RemoteComplaintService, ClientNotificationService
└── apps/
    ├── mobile/lib/main_firebase.dart  # overrides at the ProviderScope
    └── admin/lib/main_firebase.dart
```
