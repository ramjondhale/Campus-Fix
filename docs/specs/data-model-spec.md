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

Helpers: `effectivePriority` (`priorityOverride ?? priority`), `waitingTime` (`now - createdAt`),
`copyWith`, value equality, `toJson/fromJson`.

## 3. View projections (R5/R6) — privacy is structural
### 3.1 `PublicComplaintView` — **no PII**
Fields: `id`, `category`, `building`, `floor`, `room`, `description`, `beforePhotos`, `afterPhotos`,
`effectivePriority`, `status`, `createdAt`, `updatedAt`. Used by the board, lists, and all
maintenance/verifier screens.

### 3.2 `AdminComplaintView`
All of `PublicComplaintView` **plus** `reporter`, `assignment`, full `timeline` (with actor), and
`resolutionNote`. Only materializes when the requester is `admin`.

### 3.3 Projection functions (in `logic/privacy.dart`)
```dart
PublicComplaintView toPublicView(Complaint c);
AdminComplaintView? toAdminView(Complaint c, AppUser requester); // null unless requester.role == admin
```
**Invariant (unit-tested):** `PublicComplaintView` has no field that can carry reporter name, email,
ID, or phone. A test asserts the serialized public view contains none of the reporter's PII strings.

## 4. Complaint ID generation
Format `CF-<year>-<5-digit zero-padded sequence>`, e.g. `CF-2026-00042`. In the mock layer a
monotonic counter per year produces the sequence. Interface: `String nextComplaintId(DateTime now)`.

## 5. Logic signatures (implemented in later chunks; stubs/contracts here)
```dart
// S2.2 priority-engine
Priority computePriority(PriorityInputs inputs);
class PriorityInputs { ProblemCategory category; bool safetyFlag; Severity severity;
  PeopleAffected peopleAffected; Duration waitingTime; /* locationSensitivity optional */ }

// S2.3 status-machine
abstract class StatusMachine {
  static bool canTransition(ComplaintStatus from, ComplaintStatus to, UserRole role);
  static List<ComplaintStatus> nextStatuses(ComplaintStatus from, UserRole role);
}

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
