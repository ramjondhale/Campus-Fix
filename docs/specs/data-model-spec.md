# Spec: Data Model & Core Contracts (`campusfix_core`)

**Authority:** This is the canonical contract for enums, models, view projections, and logic
signatures. All other specs and all code must match these names exactly. Owner: orchestrator.
Traceability: R3–R10, R12.

> Dart conventions: immutable classes (`@immutable`, `final` fields, `const` ctor where possible),
> `copyWith`, value equality (use `package:collection` for lists), `toJson`/`fromJson` (prep for
> Firebase). Enums are rich (fields + helpers) via enhanced enums.

## 1. Enums

### 1.1 `ProblemCategory` (R3)
Values + metadata (`label`, `defaultDepartment`, `autoRoutable`):
| value | label | defaultDepartment | autoRoutable |
|-------|-------|-------------------|--------------|
| `electrical` | Electrical | `electrician` | yes |
| `plumbing` | Plumbing / Water / Washroom | `plumber` | yes |
| `civil` | Civil / Building | `civilMaintenance` | yes |
| `furniture` | Furniture | `carpenter` | yes |
| `cleanliness` | Cleanliness / Sanitation | `housekeeping` | yes |
| `it` | IT / Network / Projector / Computer | `itTeam` | yes |
| `safety` | Safety | `null` (manual triage) | no |
| `other` | Other | `null` (manual triage) | no |

### 1.2 `Priority` (R7)
`critical`, `high`, `medium`, `low`. Fields: `label`, `weight` (critical=4…low=1), `rank` for sorting.

### 1.3 `ComplaintStatus` (R9)
Ordered: `reported`, `reviewed`, `assigned`, `inProgress`, `resolved`, `verified`, `closed`.
Fields: `label`, `order` (0–6). Helper `isTerminal` (true for `closed`).

### 1.4 `UserRole`
`reporter`, `maintenance`, `verifier`, `admin`. Helper `canSeeReporterIdentity` → true only for `admin`.

### 1.5 `Department` (R8)
`electrician`, `plumber`, `carpenter`, `civilMaintenance`, `itTeam`, `housekeeping`. Field: `label`.
(Safety/Other have no default department → manual triage; see routing spec.)

### 1.6 `Severity` (reporter-rated input to priority)
`minor`, `moderate`, `severe`. Field: `weight` (1/2/3).

### 1.7 `PeopleAffected`
`individual`, `small` (a few), `many` (a class/lab/floor), `campusWide`. Field: `weight` (1–4).

### 1.8 `AttachmentKind`
`beforePhoto`, `afterPhoto`, `other`.

## 2. Models

### 2.1 `ReporterIdentity` — **PII, never in a public view (R5)**
`userId: String`, `fullName: String`, `idNumber: String` (student/staff ID), `email: String`,
`phone: String?`.

### 2.2 `AppUser`
`id: String`, `idNumber: String`, `displayName: String`, `role: UserRole`, `email: String`,
`department: Department?` (set for `maintenance` staff).

### 2.3 `Attachment`
`id: String`, `kind: AttachmentKind`, `ref: String` (asset path / mock URL), `caption: String?`,
`createdAt: DateTime`.

### 2.4 `StatusEvent` (timeline entry; R9/R10)
`id: String`, `status: ComplaintStatus` (the status entered), `actorId: String`,
`actorRole: UserRole`, `note: String?`, `at: DateTime`.
> Display rule: actor identity is shown in admin views only; public/maintenance timelines show role +
> timestamp + note, never the actor's name/ID.

### 2.5 `Assignment` (R8)
`department: Department`, `assigneeId: String?`, `assignedBy: String`, `assignedAt: DateTime`,
`isManual: bool`.

### 2.6 `Complaint` (R4) — aggregate root
| field | type | notes |
|-------|------|-------|
| `id` | `String` | Complaint ID, format `CF-YYYY-NNNNN` (see §4). |
| `category` | `ProblemCategory` | |
| `title` | `String?` | optional short title; else derived from category. |
| `description` | `String` | |
| `building` | `String` | |
| `floor` | `String` | |
| `room` | `String` | room / location detail. |
| `reporter` | `ReporterIdentity` | PII — gated. |
| `beforePhotos` | `List<Attachment>` | reporter-uploaded. |
| `afterPhotos` | `List<Attachment>` | maintenance-uploaded (R10). |
| `priority` | `Priority` | computed; may be overridden. |
| `priorityOverride` | `Priority?` | admin manual override; if set, wins. |
| `status` | `ComplaintStatus` | current. |
| `assignment` | `Assignment?` | null until assigned. |
| `timeline` | `List<StatusEvent>` | append-only history. |
| `resolutionNote` | `String?` | maintenance note at resolution (R10). |
| `safetyFlag` | `bool` | reporter/triage flag → priority override. |
| `severity` | `Severity` | reporter-rated. |
| `peopleAffected` | `PeopleAffected` | reporter-rated. |
| `createdAt` | `DateTime` | |
| `updatedAt` | `DateTime` | |

Helpers: `effectivePriority` (`priorityOverride ?? priority`), `Duration waitingTime(DateTime now)`
(clamped to `Duration.zero`), `copyWith`, value equality, `toJson/fromJson`.

> **As-built notes (S2.1 — authoritative for downstream chunks):**
> - `copyWith` treats a `null` arg as "keep current". To *clear* a nullable field use the matching
>   `clearX: true` flag: `clearPhone`, `clearDepartment`, `clearCaption`, `clearNote`,
>   `clearAssigneeId`, `clearTitle`, `clearPriorityOverride`, `clearAssignment`, `clearResolutionNote`.
> - `Complaint(...)` is a factory that stores the three lists as **unmodifiable**; append to the
>   timeline with `copyWith(timeline: [...c.timeline, event])`.
> - `Priority.rank`: `critical=0 … low=3` (ascending sort = most urgent first). `weight` is 4…1.
> - `ProblemCategory.autoRoutable` is a getter (`defaultDepartment != null`).
> - JSON: enums by `.name`, dates as ISO-8601; `fromJson` tolerates missing optional keys (missing
>   list → empty, missing `safetyFlag` → false). `ReporterIdentity.toString()` / `Complaint.toString()`
>   are PII-redacted.
> - Complaint ID generator lives at `lib/mock/id_generator.dart`
>   (`nextComplaintId(DateTime)`, year-scoped counter, caps at 99999 → throws).

## 3. View projections (R5/R6) — privacy is structural
> Resolves gaps DM-1/DM-2/DM-3 raised during S0.3. PII = reporter name/email/idNumber/phone **and**
> any actor's name/id in the timeline. Everything below is non-PII and safe for authenticated users.

### 3.1 `PublicStatusEvent` — timeline entry without actor identity
Fields: `status: ComplaintStatus`, `actorRole: UserRole`, `note: String?`, `at: DateTime`.
(Projection of `StatusEvent` dropping `id` and `actorId`.)

### 3.2 `PublicComplaintView` — **no PII** (board, lists, maintenance & verifier screens)
Fields: `id`, `category`, `title`, `building`, `floor`, `room`, `description`, `beforePhotos`,
`afterPhotos`, `effectivePriority`, `status`, `safetyFlag`, `assignedDepartment: Department?`,
`resolutionNote: String?`, `timeline: List<PublicStatusEvent>`, `createdAt`, `updatedAt`.
> The **Board** (R6) renders only a subset (id, category, location, a photo, description, priority,
> date/time, status) — it does not show the timeline, resolution note, or assigned department. That is
> a screen-level choice; the fields are safe to carry on the view either way.

### 3.3 `AdminComplaintView` — full, admin-gated
All of `PublicComplaintView` **plus** `reporter` (PII), `severity`, `peopleAffected`, `priority`,
`priorityOverride`, `assignment` (full: `assigneeId`, `assignedBy`, `isManual`…), and the full
`timeline: List<StatusEvent>` (with actor id/role). Only materializes when `requester.role == admin`.

### 3.4 Projection functions (in `logic/privacy.dart`)
```dart
PublicComplaintView toPublicView(Complaint c);
List<PublicComplaintView> toPublicViews(Iterable<Complaint> cs);
AdminComplaintView? toAdminView(Complaint c, AppUser requester); // null unless requester.role == admin
```
**Invariant (unit-tested):** `PublicComplaintView` (and its serialized form) can carry no reporter
PII and no actor identity. Tests use sentinel PII values and assert they never appear in any public
projection (see `privacy-spec.md` PR-T1…PR-T16).

### 3.5 Privacy boundary rule (resolves DM-4)
`ComplaintRepository` is the data layer and returns raw `Complaint` (with PII) — it is the "backend".
**Raw `Complaint` must never reach a widget.** A Riverpod provider layer (built in S4.1/S5.1) maps repo
output → `PublicComplaintView` / `AdminComplaintView` based on the current user, and UI consumes only
views. In Phase 2, Firestore Security Rules enforce the same server-side.

## 4. Complaint ID generation
Format `CF-<year>-<5-digit zero-padded sequence>`, e.g. `CF-2026-00042`. In the mock layer a
monotonic counter per year produces the sequence. Interface: `String nextComplaintId(DateTime now)`.

## 5. Logic signatures (implemented in later chunks; stubs/contracts here)
```dart
// S2.2 priority-engine
Priority computePriority(PriorityInputs inputs);
class PriorityInputs { ProblemCategory category; bool safetyFlag; Severity severity;
  PeopleAffected peopleAffected; Duration waitingTime; /* locationSensitivity optional */ }

// S2.3 status-machine — L1 (pure edge+role legality)
abstract class StatusMachine {
  static bool canTransition(ComplaintStatus from, ComplaintStatus to, UserRole role);
  static List<ComplaintStatus> nextStatuses(ComplaintStatus from, UserRole role);
  // L2 (preconditions P1–P9 over the actual complaint) — resolves SM-OI-1.
  // Pure; calls canTransition internally. Returns ok + the unmet blockers (never throws).
  static ValidationResult validateTransition(
      Complaint c, ComplaintStatus to, AppUser actor, TransitionRequest req);
}
class TransitionRequest {            // what the caller supplies for a transition attempt
  ComplaintStatus expectedFrom;      // stale-guard (P8)
  String? note;                      // reject/reassign reason, etc.
  String? resolutionNote;            // T4
  List<Attachment> afterPhotos;      // T4 (kind == afterPhoto)
  Assignment? assignment;            // T2/T8
  Priority? priorityOverride;        // admin at review (set) / clear handled separately
}
class ValidationResult { bool get ok; List<TransitionBlocker> blockers; }
class TransitionBlocker { String code; /* e.g. "P1" */ String message; }
// Note: the atomic *executor* (apply transition → append StatusEvent → recompute/freeze priority →
// persist) lives in ComplaintService (chunk S2.7), not in StatusMachine.

// S2.4 assignment-router
Department? routeToDepartment(ProblemCategory category); // null => manual triage

// S2.6 repositories (interfaces)
abstract class ComplaintRepository {
  Future<List<Complaint>> all();
  Future<Complaint?> byId(String id);
  Future<Complaint> submit(Complaint draft);
  Future<Complaint> update(Complaint c);
  Stream<List<Complaint>> watchAll();
}
abstract class AuthRepository {
  Future<AppUser?> signIn(String idNumber, String password);
  AppUser? get currentUser;
  Future<void> signOut();
}
```

## 6. Package layout
```
campusfix_core/lib/
  campusfix_core.dart        # barrel export
  enums/…                    # one file per enum (or grouped)
  models/…                   # one file per model
  logic/priority_engine.dart status_machine.dart assignment_router.dart privacy.dart
  repositories/…             # abstract interfaces
  mock/mock_complaint_repository.dart mock_auth_repository.dart seed_data.dart id_generator.dart
campusfix_core/test/…        # mirrors lib/ ; every enum/model/logic file has a test
```

## 7. Resolved decisions (orchestrator verdicts on S0.3 open issues)
These are binding. Agents implement to these.

| Ref | Decision |
|-----|----------|
| DM-1 | **Accepted.** `PublicComplaintView` carries a `timeline` of `PublicStatusEvent` (no actor identity). §3.1/§3.2. |
| DM-2 | **Accepted.** `resolutionNote` + `assignedDepartment` added to `PublicComplaintView` (verifier/maintenance/reporter need them; neither is PII). |
| DM-3 | **Accepted.** `AdminComplaintView` adds `title`, `severity`, `peopleAffected`, `priority`, `priorityOverride`, full `assignment`, and actor-bearing `timeline`. §3.3. |
| DM-4 | **Accepted (provider-boundary form).** Repo returns raw `Complaint`; a provider layer projects to views; raw complaints never reach widgets. §3.5. Extra repo queries (`byReporter`, `byDepartment`) land in S2.6. |
| SM-OI-1 | **Resolved.** Added `StatusMachine.validateTransition(Complaint, to, AppUser, TransitionRequest) → ValidationResult` (L2). `canTransition` stays pure L1. §5. |
| SM-OI-2 | **Deferred.** v1 uses annotation events for reassign-in-`assigned` (no `eventKind` field). Revisit if management timelines need categorization. |
| SM-OI-3 | **Accepted.** No `system` role; auto-route event attributed to the reviewing human with `Assignment.isManual == false`. |
| SM-OI-4 | **Accepted.** `admin` is a superset of `verifier` powers (one admin user covers A2). |
| SM-OI-5 | **Deferred to Phase 2.** Separation of duties (resolver ≠ verifier) not enforced in v1 (A2 small-college). |
| PE-OI-1 | **Fixed.** `ARCHITECTURE.md` §6 now says `PriorityInputs`. |
| PE-OI-2 | **Resolved.** Keep both: `Priority.weight` (4…1) for scoring/comparison; `Priority.rank` (0…3) for ascending "most-urgent-first" sort. Consistency asserted in tests. |
| PE-OI-3 | **Deferred.** `locationSensitivity` not scored in v1; the optional field/comment stays for R15. |
| PE-OI-4 | **Confirmed.** `category == safety` implies a safety floor even if the flag is unset; the report UI forces the flag on for that category. |
| UI-verify/close | **Override of the S0.3 UI composite.** Keep `verified`→`closed` as two user actions: the **mobile verifier** only *verifies* (complaint rests in `verified`), the **admin web** *closes*. Preserves a visible `verified` state (R9's 7 stages). State machine unchanged (T5/T6 already separate). |
| New models (S2.6) | `AppNotification` + `NotificationRepository`; a user directory (`UserRepository`/`UserDirectory`) to resolve actor/assignee names for admin views; `CampusDirectory` (buildings→floors→rooms) for the report form. |
| New service (S2.7) | `ComplaintService` (transition executor per status-machine L3) + `NotificationService` (generate/serve in-app notifications). |
