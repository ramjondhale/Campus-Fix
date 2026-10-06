# Spec: Complaint Status Machine (`campusfix_core/lib/logic/status_machine.dart`)

**Chunk:** S2.3 implements this. **Traceability:** R9 (status flow), R10 (repair proof / verification),
R11 (notification triggers), R12 (admin status control), R14.
**Authority:** subordinate to `data-model-spec.md`. All status/role names below are the exact enum
values: `ComplaintStatus { reported, reviewed, assigned, inProgress, resolved, verified, closed }`,
`UserRole { reporter, maintenance, verifier, admin }`.

Role abbreviations used in tables: **Rp** = `reporter`, **M** = `maintenance`, **V** = `verifier`,
**A** = `admin`.

## 1. Layered contract

| Layer | What | Where | Inputs |
|-------|------|-------|--------|
| **L1 — edge + role** (the data-model contract) | `StatusMachine.canTransition(from, to, role)` and `StatusMachine.nextStatuses(from, role)` | `logic/status_machine.dart` (pure, static) | statuses + role only |
| **L2 — preconditions** | Boolean predicates **P1–P9** (§4) over `Complaint` + acting `AppUser` + request payload (note, assignment, attachments) | same file or a sibling; **signature is not fixed by the data model** (see SM-OI-1) | complaint, actor, payload |
| **L3 — executor** | Applies a legal, precondition-satisfying transition **atomically**: updates `status`, `updatedAt`, appends `StatusEvent`(s), applies side-effects (§3), then calls `ComplaintRepository.update` | repository/service layer (prototype: mock repo) | request |

Rules:
* `canTransition` returns `true` **iff** `(from, to)` is an edge in §2 **and** `role` is allowed on that
  edge. It does not look at the complaint, so preconditions never influence it.
* `nextStatuses(from, role)` returns every `to` for which `canTransition(from, to, role)` is true,
  **sorted ascending by `ComplaintStatus.order`**, with no duplicates. It ignores L2 (UI may show an
  action disabled with the unmet-precondition reason).
* A transition request is rejected unless **L1 and L2 both pass** (L3 must call both).
* **Creation is not a transition.** Submitting a complaint creates it directly in `reported`
  (`timeline = [StatusEvent(status: reported, actorId: reporter.userId, actorRole: reporter, at: createdAt)]`).
  `canTransition` never has a `from` for creation.
* **No skipping, no self-transitions, no reopening** in v1 (illegal set, §6). Admin is *not* a bypass
  for the sequence; admin only gains extra edges (pull-back) and acts "on behalf" with the same
  preconditions.

## 2. Legal transitions (complete)

Eight edges, 15 legal `(edge, role)` pairs.

| ID | From -> To | Allowed roles | Preconditions (L2) | Side effects (L3) | Event `note` | Notifies (R11) |
|----|------------|---------------|--------------------|-------------------|--------------|----------------|
| **T1** | `reported -> reviewed` | V, A | P8 | Recompute priority (priority-engine §6). An **admin** reviewer may also toggle `safetyFlag` and set `priorityOverride` (verifiers cannot: they never see those fields). **Immediately followed by auto-routing, see T2 / assignment-routing-spec §3.** | optional | Reporter |
| **T2** | `reviewed -> assigned` | V, A | P4, P5, P8 | Write `Assignment`. V may only accept the auto-route (`isManual` false); A may pick any department (`isManual` derived, assignment-routing-spec §4). Set `assignedBy` = actor id, `assignedAt` = `at`. | optional; auto-route writes `Auto-routed to <Department.label>` | Reporter; staff of the assigned department |
| **T3** | `assigned -> inProgress` | M, A | P6, P7, P8 | **Claim:** if actor is M and `assignment.assigneeId == null`, set `assigneeId = actor.id`. Recompute priority. | optional | Reporter |
| **T4** | `inProgress -> resolved` | M, A | P1, P2, P6, P7, P8, P9 | Set `resolutionNote`. Persist the after-photos (`AttachmentKind.afterPhoto`) into `afterPhotos` (done by the same request). If actor is M and `assigneeId == null`, set it. **Freeze priority.** | = `resolutionNote` text (copied so the timeline shows it) | Reporter; all verifiers |
| **T5** | `resolved -> verified` | V, A | P1, P2 (must still hold), P8 | none beyond event. | optional | Reporter; staff of the assigned department |
| **T6** | `verified -> closed` | V, A | P8 | Complaint becomes **terminal/immutable** (INV-4). | optional | Reporter |
| **T7** | `resolved -> inProgress` (**reject / verification failed**) | V, A | P3 (rejection note required), P8 | **Unfreeze priority** (recompute). Existing `afterPhotos` and `resolutionNote` are **retained** (history) but a re-resolve needs *fresh* evidence (P1). | **required** (rejection reason) | Staff of the assigned department (rework needed, includes note); Reporter (work resumed) |
| **T8** | `inProgress -> assigned` (**pull-back / reassign**) | A only | P3 (reason note required), P4, P5, P8 | New `Assignment` replaces the old one (`assigneeId` reset to null unless A picks one). Priority recomputed. See assignment-routing-spec §6. | **required** (reason) | Reporter; old and new department staff |

**Composite actions** (UI affordances; each sub-step is a normal legal transition, appended in order,
all-or-nothing):

| Composite | Steps | Used by |
|-----------|-------|---------|
| **Review & Route** | T1, then T2 if the category is auto-routable (`routeToDepartment(category) != null`); for `safety`/`other` it stops after T1 and the complaint waits in `reviewed` for manual assignment by A | A-04 (admin web); V on web |
| **Verify & Close** | T5, then T6 | M-17 (verifier mobile), A-04 |
| **Reject** | T7 | M-17, A-04 |
| **Reassign** | T8 if `inProgress`; or an **annotation event** (§5) if already `assigned` | A-04 |

> The second hop of Review & Route and Verify & Close carries the **same actor** as the first hop
> (there is no `system` role; see SM-OI-3). Both events get the same `at`.

## 3. Transition matrix (from rows x to columns; cell = roles allowed)

`—` = illegal for every role. The matrix is the *whole* of L1.

| from \ to | reported | reviewed | assigned | inProgress | resolved | verified | closed |
|-----------|----------|----------|----------|------------|----------|----------|--------|
| **reported** | — | **V A** (T1) | — | — | — | — | — |
| **reviewed** | — | — | **V A** (T2) | — | — | — | — |
| **assigned** | — | — | — | **M A** (T3) | — | — | — |
| **inProgress** | — | — | **A** (T8) | — | **M A** (T4) | — | — |
| **resolved** | — | — | — | **V A** (T7) | — | **V A** (T5) | — |
| **verified** | — | — | — | — | — | — | **V A** (T6) |
| **closed** | — | — | — | — | — | — | — |

Reporter (`Rp`) has **no** legal transition on any edge (v1). A future "reporter confirms/reopens"
is backlog (R15-adjacent).

### 3.1 `nextStatuses(from, role)` expected output (golden)

| from | reporter | maintenance | verifier | admin |
|------|----------|-------------|----------|-------|
| `reported` | `[]` | `[]` | `[reviewed]` | `[reviewed]` |
| `reviewed` | `[]` | `[]` | `[assigned]` | `[assigned]` |
| `assigned` | `[]` | `[inProgress]` | `[]` | `[inProgress]` |
| `inProgress` | `[]` | `[resolved]` | `[]` | `[assigned, resolved]` |
| `resolved` | `[]` | `[]` | `[inProgress, verified]` | `[inProgress, verified]` |
| `verified` | `[]` | `[]` | `[closed]` | `[closed]` |
| `closed` | `[]` | `[]` | `[]` | `[]` |

## 4. Precondition catalogue (L2)

Notation: `c` = complaint **before** the transition, `u` = acting `AppUser`, `req` = request payload.
Blank means `null`, empty, or whitespace-only after trimming.

| ID | Name | Applies to | Predicate (must be true) | Failure message (UI) |
|----|------|------------|--------------------------|----------------------|
| **P1** | FRESH_EVIDENCE | T4, T5 | Let `cycleStart` = `at` of the most recent T7 (reject) event in `c.timeline`, else `c.createdAt`. Then `c.afterPhotos ∪ req.afterPhotos` contains **>= 1** `Attachment` with `kind == afterPhoto` and `createdAt > cycleStart`. | "Add at least one after-repair photo." |
| **P2** | RESOLUTION_NOTE | T4, T5 | `resolutionNote` (existing or `req`) is not blank and has <= 500 chars. | "Add a resolution note." |
| **P3** | NOTE_REQUIRED | T7, T8 | `req.note` is not blank and <= 500 chars. | "Add a reason." |
| **P4** | ASSIGNMENT_VALID | T2, T8 | The resulting `Assignment` is non-null with `department` in `Department.values`, `assignedBy == u.id`; for T8 it differs from the current assignment in `department` or `assigneeId`. If `assigneeId != null`, that user exists, has `role == maintenance` and `department == assignment.department`. | "Choose a department." / "Assignee not in that department." |
| **P5** | MANUAL_ADMIN_ONLY | T2, T8 | If `assignment.isManual` then `u.role == admin`. (`isManual == (department != routeToDepartment(c.category))`, assignment-routing-spec §4. Hence a verifier can only write the auto-route.) | "Only an admin can assign a custom department." |
| **P6** | DEPT_MATCH | T3, T4 (actor M) | `u.department == c.assignment.department`. | "This work belongs to another department." |
| **P7** | ASSIGNEE_MATCH | T3, T4 (actor M) | `c.assignment.assigneeId == null` **or** `== u.id`. | "Already claimed by a colleague." |
| **P8** | STALE_CHECK | all | The request's `expectedFrom` equals `c.status` (guards double-tap / concurrent admins). Also `c.status != closed`. | "This complaint changed; refresh and retry." |
| **P9** | NOTE_LENGTH | all | Any supplied note is <= 500 chars (trimmed). | "Note too long (500 max)." |

*(Role requirements for A acting "on behalf" skip P6/P7 — admin is not department-bound — but still need
P1/P2 for T4.)*

## 5. Timeline events (R9, R10; privacy-spec §6 governs display)

Each executed transition appends exactly one `StatusEvent`:
`StatusEvent(id, status: <the status entered>, actorId: u.id, actorRole: u.role, note: <see §2>, at: now)`
and sets `Complaint.status = to`, `Complaint.updatedAt = at`.

**Annotation event (not a transition).** Reassigning while already `assigned` (no status change)
appends `StatusEvent(status: assigned, actorRole: admin, note: "Reassigned: <Old.label> -> <New.label> — <reason>")`.
It is the **only** way a status repeats in a timeline and bypasses `canTransition` (L1 treats `from == to`
as illegal). Only A, only while `status == assigned`, requires P3/P4/P5/P8. See SM-OI-2.

### 5.1 Notification triggers (R11) — consumed by the Notifications screen
In-app only for the prototype (A1). Recipient sets: **Owner** = the complaint's reporter; **Dept** =
`maintenance` users with `department == assignment.department`; **Verifiers** = all `verifier`/`admin`
users; **Admins** = all `admin` users.

| Event | Owner | Dept | Verifiers | Admins | Message template (no PII) |
|-------|:-----:|:----:|:---------:|:------:|---------------------------|
| Creation (`reported`) | yes | — | — | yes | Owner: "Complaint `{id}` submitted." Admins: "New {priority} complaint `{id}` — {category}, {building}." |
| T1 `reviewed` | yes | — | — | — | "`{id}` has been reviewed." |
| T2 `assigned` | yes | yes | — | — | Owner: "`{id}` assigned to {Department.label}." Dept: "New work: `{id}` — {category}, {building} {floor} {room}." |
| T3 `inProgress` | yes | — | — | — | "Work has started on `{id}`." |
| T4 `resolved` | yes | — | yes | — | Owner: "Repair completed on `{id}`; awaiting verification." Verifiers: "`{id}` is ready to verify." |
| T5 `verified` | yes | yes | — | — | "`{id}` repair verified." |
| T6 `closed` | yes | — | — | — | "`{id}` is closed." |
| T7 reject | yes | yes | — | — | Dept: "Rework needed on `{id}`: {note}." Owner: "`{id}` needs more work; work resumed." |
| T8 pull-back / reassign | yes | yes (old and new) | — | — | Owner: "`{id}` reassigned to {Department.label}." Old dept: "`{id}` removed from your queue." New dept: "New work: `{id}`…" |

Messages **must not** contain reporter name/ID/email/phone or any staff name (privacy-spec §7).

Delivery in the prototype (A1): the mobile Notifications screen (M-12) serves Owner, Dept and Verifiers
(admins do not use the mobile app). The **Admins** column has no notification screen in v1; it is surfaced
by the admin dashboard lists (A-02 "Needs attention", "Awaiting manual triage"). Real push/email/SMS and
an admin notification feed are Phase 2.

## 6. Illegal transitions (assert all of these)

There are 7 x 7 = 49 `(from, to)` pairs x 4 roles = **196** `(from, to, role)` tuples; exactly **15** are
legal (§2). **The remaining 181 must return `false`.**

### 6.1 Exhaustive test (primary)
`for from in ComplaintStatus.values, to in ComplaintStatus.values, role in UserRole.values:`
`expect(canTransition(from, to, role), LEGAL.contains((from, to, role)))` where `LEGAL` is the 15-tuple
set of §2/§3. Plus `nextStatuses` golden table (§3.1) and the invariant
`nextStatuses(from, role) == ComplaintStatus.values.where((to) => canTransition(from, to, role)).toList()`.

### 6.2 Named illegal cases (also assert individually, for readable failures)
| # | Case | Why illegal |
|---|------|-------------|
| I1 | any `from -> from` (7 self-transitions), any role | No self-transitions. |
| I2 | `reported -> assigned`, `reported -> inProgress`, `reported -> resolved`, `reported -> verified`, `reported -> closed` (all roles incl. admin) | No skipping `reviewed`. |
| I3 | `reviewed -> inProgress` / `resolved` / `verified` / `closed` (all roles) | Must be assigned first. |
| I4 | `assigned -> resolved`, `assigned -> verified`, `assigned -> closed` (all roles) | Work must start; verification only after resolve. |
| I5 | `inProgress -> verified`, `inProgress -> closed` (all roles) | Cannot skip `resolved`. |
| I6 | `resolved -> closed` (all roles) | Cannot skip `verified`. |
| I7 | `verified -> resolved`, `verified -> inProgress`, `verified -> assigned` ... any backward from `verified` | Verified work cannot be reopened in v1. |
| I8 | any transition **from** `closed` (all `to`, all roles) | `closed` is terminal (`ComplaintStatus.isTerminal`). |
| I9 | backward edges other than T7 and T8: `reviewed -> reported`, `assigned -> reviewed`, `assigned -> reported`, `inProgress -> reviewed`, `inProgress -> reported`, `resolved -> assigned`, `resolved -> reviewed`, `resolved -> reported` | Only reject (T7) and pull-back (T8) go backward. |
| I10 | `canTransition(*, *, reporter)` for all pairs | Reporter has no status powers. |
| I11 | maintenance on `reported->reviewed`, `reviewed->assigned`, `resolved->verified`, `verified->closed`, `resolved->inProgress`, `inProgress->assigned` | Maintenance cannot triage, assign, verify, close, reject or reassign. |
| I12 | verifier on `assigned->inProgress`, `inProgress->resolved`, `inProgress->assigned` | Verifier cannot do the work or pull it back. |
| I13 | `inProgress -> assigned` for M and V | Pull-back is admin-only. |

### 6.3 Precondition negatives (L2; one test each)
| # | Request | Expected |
|---|---------|----------|
| N1 | T4 with 0 after-photos | rejected (P1) |
| N2 | T4 with after-photos whose `kind != afterPhoto` (e.g. `beforePhoto`) | rejected (P1) |
| N3 | T4 with blank / whitespace `resolutionNote` | rejected (P2) |
| N4 | T4 after a T7 where the only after-photo is older than the reject event | rejected (P1 — fresh evidence) |
| N5 | T4 with `resolutionNote` length 501 | rejected (P2/P9) |
| N6 | T5 where `afterPhotos`/`resolutionNote` were somehow cleared (corrupt data) | rejected (P1/P2) |
| N7 | T7 with blank note | rejected (P3) |
| N8 | T8 with blank note, or new assignment identical to current | rejected (P3 / P4) |
| N9 | T3/T4 by a maintenance user whose `department != assignment.department` | rejected (P6) |
| N10 | T3/T4 by maintenance when `assigneeId` belongs to another user | rejected (P7) |
| N11 | T2 by verifier with a manual department (`isManual == true`) | rejected (P5) |
| N12 | T2 for a `safety`/`other` complaint by verifier (route is null => any assignment is manual) | rejected (P5); only admin can assign |
| N13 | Any transition with a stale `expectedFrom` | rejected (P8) |
| N14 | Any mutation of a `closed` complaint (including priority override, note edits) | rejected (P8 / INV-4) |
| N15 | T2 with an `assigneeId` that is not a maintenance user of that department | rejected (P4) |

## 7. Invariants (property/replay tests)

| ID | Invariant |
|----|-----------|
| INV-1 | `status` in `{assigned, inProgress, resolved, verified, closed}` => `assignment != null`. |
| INV-2 | `status == reviewed` => `routeToDepartment(category) == null` (auto-routable complaints never rest in `reviewed`; Review & Route is atomic). |
| INV-3 | `status` in `{resolved, verified, closed}` => P1 and P2 hold (after-photo(s) + note present) — before/after evidence is linked to the complaint ID (R10). |
| INV-4 | `status == closed` => the complaint is immutable (no further update accepted). |
| INV-5 | `status == resolved`, `verified`, or `closed` => `priority` frozen (not recomputed) unless T7 occurs. |
| TL-1 | `timeline.first` is `StatusEvent(status: reported, actorRole: reporter, at == createdAt)`. |
| TL-2 | `timeline[i].at <= timeline[i+1].at` (non-decreasing). |
| TL-3 | **Replay:** for each consecutive pair `(prev, next)` that is *not* an annotation event (`next.status != prev.status`), `canTransition(prev.status, next.status, next.actorRole)` is `true`. |
| TL-4 | `timeline.last.status == status` and `updatedAt == timeline.last.at`. |
| TL-5 | `status == closed` => the timeline contains `resolved` then `verified` then `closed` in that order. |
| TL-6 | `status` only moves backward through T7 (`resolved -> inProgress`) and T8 (`inProgress -> assigned`). |
| TL-7 | Every T7/T8 event has a non-blank `note`. |

## 8. Test plan for S2.3 (pure Dart)
1. Exhaustive L1 table (§6.1) + `nextStatuses` golden (§3.1) + ordering (ascending `order`, no duplicates).
2. Named illegal cases I1–I13.
3. L2 positives (one per T1–T8) and negatives N1–N15 against fixture complaints.
4. End-to-end happy path replay: `reported -> reviewed -> assigned -> inProgress -> resolved -> verified -> closed`
   (verify TL-1..TL-5, INV-1..INV-5).
5. Reject loop: `... -> resolved -> inProgress -> resolved -> verified -> closed` incl. N4 (fresh evidence).
6. Pull-back: `... -> inProgress -> assigned -> inProgress -> ...` with new department.
7. Manual-triage path: `safety`/`other` complaint stops at `reviewed` after Review & Route; admin assigns.
8. Atomicity: a composite whose second step fails (e.g. P5) leaves the complaint unchanged.

## 9. Open issues for the orchestrator
| ID | Issue |
|----|-------|
| SM-OI-1 | `canTransition(from, to, role)` cannot enforce R10's "after photo + resolution note required" because it has no `Complaint`. The data model needs an L2 guard. Suggested (not in the data model, so **not** invented here): a pure `ValidationResult validateTransition(Complaint c, ComplaintStatus to, AppUser actor, TransitionRequest req)` implementing P1–P9, with `canTransition` called inside it. Orchestrator to name/approve; S2.3 needs it. |
| SM-OI-2 | Reassign-in-`assigned` has no representation in the data model (no `ReassignmentEvent`; `StatusEvent.status` means "status entered"). This spec uses an *annotation event* (same status, descriptive note). Alternative: add an `eventKind` field to `StatusEvent`. Decide. |
| SM-OI-3 | There is no `system` actor in `UserRole`, yet auto-routing is system behaviour. This spec attributes the auto `assigned` event to the **reviewing human** (same `actorId`/`actorRole`) and writes the note `Auto-routed to ...`; `Assignment.isManual == false` distinguishes it. Confirm or add a system actor. |
| SM-OI-4 | A2 says one person may be both verifier and admin, but `AppUser.role` is single-valued. This spec makes `admin` a superset of `verifier` powers on every edge, so one `admin` user covers both. Confirm. |
| SM-OI-5 | Separation of duties (the user who resolved must not verify) is **not** enforced (A2 small-college assumption). Candidate Phase-2 rule. |
