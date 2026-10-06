# Spec: Privacy & Hidden Reporter Identity (`campusfix_core/lib/logic/privacy.dart`)

**Chunk:** S2.5 implements the projections; S4/S5 consume them. **Traceability:** R5 (hidden reporter
identity), R6 (anonymous campus board), R10, R12 (admin).
**Authority:** subordinate to `data-model-spec.md` (§2.1 `ReporterIdentity`, §3 views, §5 `UserRole.canSeeReporterIdentity`).
**This is the load-bearing spec of the product:** a defect here is a product-level defect.

> **Prototype honesty clause.** In the prototype everything runs client-side on in-memory data, so
> privacy is enforced **structurally by types and by layering rules** (this spec), proven by tests.
> It is *not* a security boundary against a malicious device. The real boundary is Phase-2 Firestore
> Security Rules + a separately-stored identity document (ARCHITECTURE §9).

## 1. Principles
| ID | Principle |
|----|-----------|
| PV-1 | **Privacy by construction.** Screens that must not show identity accept a type that *cannot hold it* (`PublicComplaintView`). Forgetting to hide a field is impossible, not merely unlikely. |
| PV-2 | **Default deny.** A new field is invisible to all views until it is explicitly added to a view *and* to the allow-list test (§8, PR-T2). |
| PV-3 | **Single choke point.** Raw `Complaint` -> view conversion happens only in `logic/privacy.dart` (`toPublicView`, `toAdminView`). |
| PV-4 | **Identity is admin-only.** `UserRole.canSeeReporterIdentity` is `true` only for `admin`. Verifier/management and maintenance never see it — not on the board, lists, maintenance, verifier, or notification surfaces, and not behind any "audit" flow. |
| PV-5 | **No identity in lists, ever** — not even in the admin list (R5: "never on normal lists/boards/maintenance screens"). Admin sees identity only inside the single-complaint detail, behind an explicit reveal. |
| PV-6 | **Complaint screens never render the complaint's `reporter` block — not even for its owner** (no need; reduces leakage via screenshots/shared devices). A session header/greeting may show the signed-in user's own display name; that is session UI, not complaint data. |

## 2. PII classification (exact fields)

| Class | Meaning | Fields |
|-------|---------|--------|
| **P0 — direct reporter PII** | Identifies the reporter. **Never** in a public view. | `ReporterIdentity.fullName`, `.idNumber`, `.email`, `.phone` |
| **P1 — reporter-linkable identifier** | Pseudonymous, but joins to P0. Treated as PII. | `ReporterIdentity.userId`; `Complaint.reporter` (the whole object); `StatusEvent.actorId` **when `actorRole == reporter`** (the creation event's `actorId == reporter.userId`) |
| **P2 — staff / actor identity** | Identifies handling staff. Restricted to **admin** views (consistent with the data-model note on `StatusEvent`). | `StatusEvent.actorId` (all roles); `Assignment.assigneeId`; `Assignment.assignedBy`; any display name/ID/email resolved from those (`AppUser.displayName`, `.idNumber`, `.email`) |
| **P3 — residual / free-text / media** | Not structured identity, but can self-identify. **Cannot be proven absent by tests**; mitigated by UX + Phase 2. | `Complaint.description`, `StatusEvent.note`, `Complaint.resolutionNote`, `Attachment.caption`, photo pixels, photo EXIF/GPS, `Attachment.ref` filenames |
| **Non-PII** | Safe for every authenticated role. | `Complaint.id`, `category`, `building`, `floor`, `room`, `priority`/`priorityOverride`/`effectivePriority`, `status`, `createdAt`, `updatedAt`, `Attachment.id/kind/createdAt`, `assignment.department`, `assignment.isManual`, `assignment.assignedAt`, `StatusEvent.status/actorRole/at`, `severity`, `peopleAffected`, `safetyFlag` |

`Complaint.title`: optional reporter free-text (P3 residual, same class as `description`). Per the
final data-model §3.2 it **is** carried on both views (the report UI may leave it null/derived).

## 3. View projections

### 3.1 `PublicComplaintView` — **no PII** (data-model §3.1, as amended)
Used by: board, My Complaints, maintenance, verifier, notifications (derivation), admin list/dashboard.

| Field | Source | Notes |
|-------|--------|-------|
| `id` | `Complaint.id` | |
| `category` | `.category` | |
| `building`, `floor`, `room` | same | |
| `description` | same | P3 residual |
| `beforePhotos`, `afterPhotos` | same | `Attachment` list (P3 residual: media) |
| `effectivePriority` | `priorityOverride ?? priority` | raw `priority`/override not exposed |
| `status` | same | |
| `createdAt`, `updatedAt` | same | |
| `timeline` **[DM-1]** | `List<PublicStatusEvent>` | projection of `StatusEvent`: **only** `status`, `actorRole`, `note`, `at` |
| `resolutionNote` **[DM-2]** | same | needed by verifier/owner; P3 residual |
| `assignedDepartment` **[DM-2]** | `assignment?.department` | label only; no `assigneeId`/`assignedBy` |

`PublicStatusEvent` **[DM-1]** = `{ status: ComplaintStatus, actorRole: UserRole, note: String?, at: DateTime }`.
It has **no `actorId` and no `id`**.

### 3.2 `AdminComplaintView` — only for `admin`
`PublicComplaintView` fields **plus**: `reporter: ReporterIdentity` (P0/P1), `assignment: Assignment?`
(P2: assignee, assignedBy), full `timeline: List<StatusEvent>` **with** `actorId` (P2; overrides the
public timeline field), and **[DM-3]** `title`, `priority` (raw computed), `priorityOverride`,
`safetyFlag`, `severity`, `peopleAffected` (the admin must see the inputs behind a priority).
Materializes **only** when `requester.role == UserRole.admin`.

### 3.3 Functions (data-model §3.3, unchanged signatures)
```dart
PublicComplaintView toPublicView(Complaint c);
AdminComplaintView? toAdminView(Complaint c, AppUser requester); // null unless requester.role == admin
```
* `toPublicView` is total, pure, role-independent: **the same output for every caller**.
* `toAdminView` returns `null` for `reporter`, `maintenance`, `verifier` — including a reporter
  requesting **their own** complaint (they get the public view, PV-6).
* Neither function logs, caches, or mutates.

### 3.4 Data-model amendments these specs assume (orchestrator to approve; data-model-spec is **not** edited by this chunk)
| ID | Amendment | Why |
|----|-----------|-----|
| **DM-1** | Add `PublicStatusEvent` and `PublicComplaintView.timeline`. | data-model §2.4 says public/maintenance timelines show role + time + note, but §3.1 has **no timeline field** in `PublicComplaintView`, and §3.2 puts the timeline only in the admin-only view. Without DM-1 no non-admin screen can show status history (R9 tracking). |
| **DM-2** | Add `PublicComplaintView.resolutionNote` and `.assignedDepartment`. | §3.1 has neither; §3.2 gives `resolutionNote` only to admin, yet the **verifier** must read it to verify (R10) and the reporter/maintenance need the department. |
| **DM-3** | Add `title`, `priority`, `priorityOverride`, `safetyFlag`, `severity`, `peopleAffected` to `AdminComplaintView`. | Admin must see and edit priority inputs (R12); §3.2 omits them. |
| **DM-4** | View-returning repository queries (e.g. `board()`, `mine(userId)`, `workQueue(department)`) *or* the provider-boundary rule of §5.2. | `ComplaintRepository.all()` returns raw PII-bearing `Complaint`s to every client, and there is no way to ask "my complaints" without loading everyone's. |

*If DM-1/DM-2 are rejected:* timeline, resolution note and department disappear from non-admin screens;
every `[DM-n]` tag in these specs marks what to strike.

## 4. Role x surface visibility

`Y` = shown, `—` = never shown, `ID` = identifier only (no PII). "Public view" = §3.1.

| Data element | Board (M-11) | My Complaints / own details (M-09, M-10) | Maintenance (M-13..15) | Verifier (M-16, M-17) | Notifications (M-12) | Admin dashboard (A-02) | Admin list (A-03) | Admin detail (A-04), role **admin** | Admin detail (A-04), role **verifier** |
|--------------|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|
| Complaint ID | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| category, building/floor/room | Y | Y | Y | Y | Y (text only) | Y (aggregates; top lists) | Y | Y | Y |
| description | Y | Y | Y | Y | — | — | — (search only) | Y | Y |
| before / after photos | Y | Y | Y | Y | — | — | — (thumb optional) | Y | Y |
| effective priority | Y | Y | Y | Y | Y (text) | Y | Y | Y | Y |
| status, createdAt, updatedAt | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| public timeline (role + time + note) [DM-1] | — | Y | Y | Y | — | — | — | Y (admin form) | Y (public form) |
| resolution note [DM-2] | — | Y | Y | Y | — | — | — | Y | Y |
| assigned department (label) [DM-2] | — | Y | Y | Y | Y (text) | Y (aggregates) | Y | Y | Y |
| raw priority / override / safetyFlag / severity / people [DM-3] | — | — | — | — | — | — | — | Y | — |
| assignee, assignedBy, isManual, assignedAt | — | — | — | — | — | — | — | Y | — |
| **timeline actor identity (name/ID)** | — | — | — | — | — | — | — | **Y** | — |
| **reporter identity (P0/P1)** | — | — | — | — | — | — | — | **Y (reveal-gated)** | — |

Notes:
* **Board** shows exactly the R6 field set (ID, category, location, photo, description, priority,
  date/time, status) — it deliberately omits timeline/notes (they are free text; minimise exposure).
* Verifier/management on the admin web gets **the same data as the verifier on mobile**: no identity,
  ever (PV-4). `ARCHITECTURE.md` §4 ("audit-gated in admin") conflicts with `canSeeReporterIdentity`;
  this spec follows the data model (PV-OI-1).
* "Admin list" has **no reporter column and no reporter-based search/sort/filter** (PV-5).
* No surface exposes P0/P1 in a URL, route parameter, query string, page title, tooltip, or
  clipboard-by-default.

## 5. Layering rules (where raw `Complaint` may exist)

### 5.1 Allowed locations
| Layer / path | May import/handle `Complaint`, `ReporterIdentity`, `.reporter` | May import `AdminComplaintView` |
|--------------|:--:|:--:|
| `campusfix_core/lib/models`, `logic/privacy.dart`, `repositories`, `mock` | Y | Y |
| `apps/admin` — **only** the identity panel widget of A-04 (proposed `features/complaint_detail/identity_panel.dart`) and the A-04 controller that calls `toAdminView` | **identity panel only** | Y (A-04 + its controller) |
| every other file in `apps/admin` | — | — |
| `apps/mobile` (all features) | — (except the *report-submit* controller building the draft `Complaint` from the signed-in user) | — |
| `campusfix_design` (widgets) | — | — |

### 5.2 Provider-boundary rule (until DM-4)
State/providers that feed board, lists, notifications, maintenance, verifier and admin list/dashboard
**must map to `PublicComplaintView` at the provider boundary** and expose only views. Raw `Complaint`s
must not be placed in widget state, route extras, or logs. The submit flow builds a `Complaint` from the
signed-in `AppUser` (`ReporterIdentity` from the session) and hands it straight to
`ComplaintRepository.submit`.

### 5.3 Ownership ("my complaints") and department filters
These require reading `Complaint.reporter.userId` / `assignment.department|assigneeId` on the raw
aggregate. They must run **inside the repository/provider layer** (before projection) and return views;
widgets receive no ownership or assignee data. Consequently the board does **not** show a "mine" badge.

## 6. Timeline actor-identity display rule

| Timeline element | Public forms (own, maintenance, verifier, admin-as-verifier) | Admin detail (role `admin`) |
|------------------|-------------------------------------------------|------------------------------|
| status entered | label (e.g. "In Progress") | same |
| time (`at`) | yes | yes |
| actor **role** | yes ("Reporter", "Maintenance", "Verifier", "Admin") | yes |
| note | yes | yes |
| actor **name / ID** (`actorId` resolved) | **never** | yes, with role |
| `StatusEvent.id` | not exposed | yes |

* The **creation** event shows "Reporter · Reported · <time>" publicly (role only) — never the reporter's name.
* Auto-routed events show "Verifier/Admin · Assigned · Auto-routed to Electrician" (department is non-PII).
* Notes are **public text** to everyone who can open that complaint's timeline. Every note input must
  show the helper text: *"Visible to people involved in this complaint. Don't include names or contact details."*

## 7. Other leak channels (rules)

| ID | Rule |
|----|------|
| LK-1 | **Notifications** (R11, derived from `StatusEvent`s, status-machine §5.1): message text uses only complaint ID, category/department/status labels, location, priority, and (for rework) the rejection note. No P0/P1/P2. |
| LK-2 | **Search/filter** on board, my list, admin list, and notifications indexes only public fields (ID, category, location, description, status, priority, department). No reporter search in v1. |
| LK-3 | **Logging/debug:** `ReporterIdentity.toString()` returns a redacted constant (e.g. `ReporterIdentity(redacted)`); `Complaint.toString()` omits `reporter`; no `print`/`debugPrint`/`dart:developer.log` of a `Complaint`, `AdminComplaintView`, or `toJson()` of either. |
| LK-4 | **Serialization:** `Complaint.toJson()` (includes `reporter`) is for **repositories only**. UI/state/export code serializes `PublicComplaintView.toJson()` only. |
| LK-5 | **Route/deep links** carry only the Complaint ID (`/complaints/:id`), never names/emails/IDs. |
| LK-6 | **Seed/mock data:** seed `description`, `note`, `caption`, `ref` strings must not contain any seeded reporter's name, ID number, email, phone, or userId (verified by PR-T9). Seed reporters use clearly fictional identities. |
| LK-7 | **Export/print/CSV of complaints is out of scope for v1.** If added, it follows `PublicComplaintView` unless a future audited admin export is specified. |
| LK-8 | **Identity reveal UX (A-04):** identity panel is collapsed by default; "Reveal reporter identity" is an explicit click with a one-line reminder; it re-collapses on navigation/sign-out; identity is never put into the page title, URL, or screenshots' metadata. |
| LK-9 | **Photos** (P3): in the prototype use bundled sample images only (A4). The photo-picker shows a hint: "Avoid including people's faces or documents." Phase 2 strips EXIF/GPS on upload. |

## 8. Concrete unit-test assertions (S2.5; part also run by S2.6 over seed data)

### 8.1 Fixtures
```dart
// A complaint whose PII values are unique sentinels (cannot collide with ordinary words).
const piiName  = 'Zelda Quillfeather';
const piiId    = 'STU-2026-31337';
const piiEmail = 'zelda.quillfeather@college.test';
const piiPhone = '+91 98765 43210';
const piiUid   = 'u-9f3a-sentinel';
const staffId  = 'staff-electrician-sentinel';     // used as actorId / assigneeId / assignedBy
// Fragments to scan for (case-insensitive): 'Zelda', 'Quillfeather', '31337', '98765', 'u-9f3a', 'staff-electrician-sentinel'
```
`fixtureComplaint` is a fully-populated complaint: both photo lists, a `resolutionNote`, an `Assignment`
with `assigneeId = staffId`, a **full lifecycle timeline** whose first event has `actorId = piiUid` and
whose later events have `actorId = staffId`, and a `priorityOverride`. Also build per-category / per-status
variants (parametrise over all `ProblemCategory` x `ComplaintStatus`).

### 8.2 Assertions

| ID | Assertion |
|----|-----------|
| **PR-T1** | **No-PII serialization:** `final s = jsonEncode(toPublicView(fixtureComplaint).toJson()).toLowerCase();` contains **none** of the sentinel fragments (`piiName`, `piiId`, `piiEmail`, `piiPhone`, `piiUid` and each fragment above, lower-cased). |
| **PR-T2** | **Key allow-list (default deny):** `toPublicView(c).toJson().keys.toSet()` **equals exactly** the 17 keys of the final data-model §3.2: `{id, category, title, building, floor, room, description, beforePhotos, afterPhotos, effectivePriority, status, safetyFlag, assignedDepartment, resolutionNote, timeline, createdAt, updatedAt}`. Adding any field fails the test until a reviewer updates the allow-list. |
| **PR-T3** | **Nested allow-lists:** each `Attachment` JSON in the public view has keys exactly `{id, kind, ref, caption, createdAt}`; each public timeline entry has keys exactly `{status, actorRole, note, at}` (no `id`, no `actorId`). |
| **PR-T4** | **Admin gating (exhaustive over `UserRole.values`):** `toAdminView(c, requester)` is `null` for `reporter`, `maintenance`, `verifier`; non-null for `admin`. Includes the case `requester.id == c.reporter.userId` with `role == reporter` => `null`. Also `UserRole.canSeeReporterIdentity` is `true` for `admin` only. |
| **PR-T5** | **Positive control (anti-vacuity):** for `admin`, `jsonEncode(toAdminView(c, admin).toJson())` **does** contain `piiName`, `piiEmail`, `piiUid`, `staffId`; and `adminView.reporter == c.reporter`. (Proves PR-T1's scanner can actually detect these strings.) |
| **PR-T6** | **Public timeline has no actor identity:** for every public timeline entry, serialized text contains neither `piiUid` (creation event) nor `staffId` nor any `AppUser.displayName` of staff in the fixture; `actorRole` is present. The admin view's timeline **does** contain `actorId` for every event (PR-T5 covers positive). |
| **PR-T7** | **Superset:** every key of the public view appears in the admin view with an equal value (except `timeline`, which is `StatusEvent` in admin form with the same length/order). |
| **PR-T8** | **Priority exposure:** public `effectivePriority == c.priorityOverride ?? c.priority`; the keys `priority` and `priorityOverride` are absent from the public JSON. |
| **PR-T9** | **Seed sweep (S2.6):** for **every** seed complaint (>= 24) run PR-T1 using *that complaint's own* reporter strings (name, idNumber, email, phone, userId) **and** every other seed reporter's strings, against its public view JSON. Also run against derived notification messages (LK-1) for all timeline events. Catches PII pasted into seed free text. |
| **PR-T10** | **Matrix sweep:** PR-T1 parametrised over all 8 categories x 7 statuses x {with/without override, with/without assignment, with/without after-photos}. |
| **PR-T11** | **Redaction:** `piiName`, `piiId`, `piiEmail`, `piiPhone`, `piiUid` do not appear in `ReporterIdentity.toString()` nor `Complaint.toString()` nor `toPublicView(c).toString()` (LK-3). |
| **PR-T12** | **Purity/stability:** `toPublicView(c)` called twice (and for two different "viewers") returns equal values; it does not mutate `c` (deep-equal before/after). |
| **PR-T13** | **Round-trip:** `PublicComplaintView.fromJson(v.toJson()) == v` and the round-tripped JSON still passes PR-T1. |
| **PR-T14** | **Architecture guard (static, runs in `dart test`):** scan source text — (a) no file under `apps/mobile/lib/**` or `campusfix_design/lib/**` references `ReporterIdentity`, `AdminComplaintView`, or `.reporter` (allowed exception: the report-submit controller, by explicit allow-list entry); (b) under `apps/admin/lib/**`, `ReporterIdentity`/`.reporter` appear only in the identity-panel file and `AdminComplaintView` only in A-04's files; (c) no `print(`/`debugPrint(`/`log(` call takes a `Complaint`/`AdminComplaintView`. |
| **PR-T15** | **Notification derivation (S4.4):** for every `StatusEvent` of every seed complaint, the generated message contains none of the strings in PR-T9 and matches the §5.1 templates. |
| **PR-T16** | **Screen-level (later, widget tests):** board, My Complaints, maintenance, verifier and admin-list widgets are constructed only with `PublicComplaintView` (compile-time) and the rendered text of each, for the fixture, contains none of the sentinel fragments (admin list included: no reporter column header). |

## 9. Phase 2 (future) — audit logging & hardening
Not built in the prototype. Designed so the interfaces here do not change:
* **Audit log** (append-only, admin-unwritable): one entry per **identity reveal** (`toAdminView` materialization / reveal click): who, which complaint, when, free-text reason; plus priority overrides, manual assignments/reassignments, and every status change by an admin acting on behalf. ARCHITECTURE §5 already notes `toAdminView` will "write an audit entry".
* **Storage separation:** identity in a restricted document/subcollection (e.g. `complaints/{id}/private/identity`) readable only by `admin` custom claim; public document carries `PublicComplaintView` fields only. Firestore Rules + emulator tests assert: non-admin read of the identity doc is denied; non-admin read of the public doc contains no PII fields.
* **Upload hygiene:** strip EXIF/GPS, optional face-blur, malware/size checks.
* **Free-text hygiene:** warn/mask on obvious PII patterns (phones, emails, ID formats) in description/notes; separate *internal* (admin-only) notes from public timeline notes.
* **Reveal controls:** rate limits, reason capture, access reports for the college.
* **Retention & deletion:** retention schedule for identity and photos; right-to-erasure handling.

## 10. Residual risks (accepted in v1)
| ID | Risk | Mitigation now | Later |
|----|------|----------------|-------|
| RR-1 | Reporter self-identifies in `description`/notes/captions/photos (P3) | Helper text (§6, LK-9); seed sweep PR-T9 | PII-pattern masking, internal notes (Phase 2) |
| RR-2 | Small-population inference: location + timestamp on the board may single out a reporter | Accepted (R6 mandates location/time) | Coarsen time/location for sensitive categories |
| RR-3 | Prototype loads raw `Complaint`s client-side (no server boundary) | Layering rules §5, PR-T14 | Firestore Rules + separate identity doc |
| RR-4 | Admin over-access | Reveal-gated UI (LK-8) | Audit log, reason capture, rate limits |
| RR-5 | Screenshots/shared devices | PV-6 (no `reporter` block on any complaint screen except the admin reveal panel) | Screen-capture protections on identity panel |

## 11. Open issues for the orchestrator
| ID | Issue |
|----|-------|
| PV-OI-1 | `ARCHITECTURE.md` §4 lists the verifier as "audit-gated in admin" for identity, but data-model §1.4 makes `canSeeReporterIdentity` true only for `admin`. This spec follows the data model (verifier never sees identity). Fix ARCHITECTURE §4. |
| PV-OI-2 | **DM-1..DM-4** above require orchestrator decisions; downstream specs (`screens-spec.md`) are written assuming DM-1..DM-3 and tag them `[DM-n]`. |
| PV-OI-3 | `StatusEvent.actorId` for the creation event equals `ReporterIdentity.userId`; this is why public timelines drop `actorId` entirely (PR-T6). Consider a distinct opaque `actorRef` in Phase 2. |
