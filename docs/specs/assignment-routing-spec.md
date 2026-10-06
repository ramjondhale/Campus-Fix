# Spec: Assignment Routing (`campusfix_core/lib/logic/assignment_router.dart`)

**Chunk:** S2.4 implements this. **Traceability:** R8 (department assignment, auto or manual), R9, R12
(admin assigns), R11.
**Authority:** subordinate to `data-model-spec.md` (§1.1 mapping, §1.5 `Department`, §2.5 `Assignment`,
§5 signature). Transition roles and preconditions are defined in `status-machine-spec.md` (T1, T2, T3, T8;
P4–P7); this spec is the routing/assignment half.

## 1. Contract

```dart
// data-model-spec §5 (unchanged)
Department? routeToDepartment(ProblemCategory category); // null => manual triage
```

| Property | Rule |
|----------|------|
| Purity | Pure, total, no I/O. `routeToDepartment(c) == c.defaultDepartment` for every category. |
| Source of truth | `ProblemCategory.defaultDepartment` (data-model §1.1). The router must not carry a second, independent table (reuse; no duplicated mapping). |
| `autoRoutable` | `c.autoRoutable == (c.defaultDepartment != null)` for all categories (test asserts the redundancy never drifts). |
| Output `null` | Means **manual triage**: only `ProblemCategory.safety` and `ProblemCategory.other`. |

## 2. Category -> department mapping (R8)

| `ProblemCategory` | Label | `routeToDepartment` | `Department.label` | Auto-routable | Initial path |
|-------------------|-------|---------------------|--------------------|---------------|--------------|
| `electrical` | Electrical | `electrician` | Electrician | yes | Review & Route -> `assigned` |
| `plumbing` | Plumbing / Water / Washroom | `plumber` | Plumber | yes | Review & Route -> `assigned` |
| `civil` | Civil / Building | `civilMaintenance` | Civil Maintenance | yes | Review & Route -> `assigned` |
| `furniture` | Furniture | `carpenter` | Carpenter | yes | Review & Route -> `assigned` |
| `cleanliness` | Cleanliness / Sanitation | `housekeeping` | Housekeeping | yes | Review & Route -> `assigned` |
| `it` | IT / Network / Projector / Computer | `itTeam` | IT Team | yes | Review & Route -> `assigned` |
| `safety` | Safety | **`null`** | — | **no** | stops at `reviewed`; **admin manual triage** |
| `other` | Other | **`null`** | — | **no** | stops at `reviewed`; **admin manual triage** |

Coverage property: `Department.values` (6) are each the route of **exactly one** category; no department
is unreachable by auto-routing; no two categories share a department.

## 3. When assignment auto-fires in the status flow

Auto-routing is **not** a separate status event emitted at submission. It fires inside the
**Review & Route** composite (status-machine-spec §2):

```
reporter submits  ->  status = reported   (assignment == null; priority computed)
                          |
      verifier/admin performs "Review"  (T1: reported -> reviewed)
                          |
        route = routeToDepartment(category)
          /                                          \
   route != null                                   route == null  (safety / other)
   (same operation, atomic)                          |
   T2: reviewed -> assigned                      status stays `reviewed`
   Assignment(department: route,                 appears in admin "Needs manual triage"
              assigneeId: null,                  queue; admin runs T2 manually
              assignedBy: reviewer.id,           (isManual = true)
              assignedAt: now,
              isManual: false)
   event note: "Auto-routed to <label>"
```

Rules:
| ID | Rule |
|----|------|
| AR-1 | Auto-route happens **only** as part of Review (T1). There is no assignment before review (`assignment == null` while `reported`). |
| AR-2 | For auto-routable categories T1 + T2 are one atomic composite; the complaint is **never persisted in `reviewed`** (status-machine INV-2). |
| AR-3 | The auto-assignment event is attributed to the reviewing user (`actorId`, `actorRole`), see SM-OI-3. Both events share the same `at`. |
| AR-4 | A verifier performing Review may only accept the auto-route. An admin performing Review may **change the department before confirming** (manual override, §4); the complaint then gets `isManual = true`. |
| AR-5 | For `safety`/`other`, T1 completes and the complaint waits in `reviewed`; **only an admin** can perform T2 (P5), choosing any department. No default department is pre-selected for these. |
| AR-6 | Auto-routing never changes `category`, `priority`, or `safetyFlag`. |
| AR-7 | `assigneeId` is **always `null`** at auto-route (department-level assignment). It is set by a claim (T3, §5) or by an admin choosing a specific staff member. |

## 4. Manual assignment & override (admin)

Who/when: role `admin`, statuses `reviewed` (T2 manual) or at Review time (override of the auto-route),
and reassignment (§6).

| ID | Rule |
|----|------|
| MA-1 | Admin may choose **any** of the 6 `Department` values for any category (including `safety`/`other`). |
| MA-2 | **`isManual` is derived, not typed:** `isManual = (department != routeToDepartment(category))`. Picking the router's own department yields `isManual == false` (equivalent to auto-route); picking any other department, or any department for `safety`/`other`, yields `true`. |
| MA-3 | Admin may optionally select a specific staff member (`assigneeId`) — a user with `role == maintenance` and `department == chosen department` (P4). Default: none. |
| MA-4 | Every assignment records `assignedBy` (writer's `AppUser.id`) and `assignedAt`. |
| MA-5 | An override that changes department **does not change `category`**. Re-categorising is not supported in v1 (backlog). |
| MA-6 | The assignment form pre-selects `routeToDepartment(category)` when non-null, and a visible "Suggested: <label>" hint; for `null` routes nothing is pre-selected and the form shows "Manual triage required". |
| MA-7 | Verifiers cannot create a manual assignment (P5). |

## 5. Claiming (`assigneeId`)

| ID | Rule |
|----|------|
| CL-1 | On T3 (`assigned -> inProgress`) by a `maintenance` user with `assignment.assigneeId == null`: set `assigneeId = actor.id` ("claim"). The department's other staff can then no longer progress it (P7) unless an admin reassigns. |
| CL-2 | If `assigneeId != null` and not the actor: T3/T4 rejected for maintenance (P7). Admin may still act on behalf. |
| CL-3 | If T3 was done by an admin (assignee stays `null`), the first maintenance user of that department to execute T4 becomes `assigneeId` (set at T4). |
| CL-4 | `assigneeId` is **staff identity**: it is shown only in admin views (privacy-spec §2, class P2); the public/maintenance screens show **department only**. |

## 6. Reassignment rules (admin only)

| ID | Rule |
|----|------|
| RA-1 | Only role `admin` may reassign (P5). Verifier/maintenance cannot. |
| RA-2 | Allowed only while `status` in `{assigned, inProgress}`. Not allowed in `reported`/`reviewed` (nothing to reassign; use T2), nor `resolved`/`verified`/`closed` (reject first with T7 if rework is needed). |
| RA-3 | `status == assigned`: reassigning keeps status; appends an **annotation event** (status-machine §5) with note `Reassigned: <Old.label> -> <New.label> — <reason>`. |
| RA-4 | `status == inProgress`: reassigning is the pull-back transition **T8** (`inProgress -> assigned`) — the new team starts from `assigned`; note required (P3). |
| RA-5 | A reason (note, <= 500 chars) is **required** for every reassignment (P3). |
| RA-6 | The new assignment must differ from the current one in `department` or `assigneeId` (P4); a no-op is rejected. |
| RA-7 | On department change: `assigneeId` resets to `null` unless admin chooses one in the new department (P4). On same-department change of assignee only: `department` unchanged, `assigneeId` replaced. |
| RA-8 | Reassignment re-derives `isManual` (MA-2) and overwrites `assignedBy`/`assignedAt`. The previous assignment is preserved **only** as text in the timeline note (no assignment history model; see AR-OI-2). |
| RA-9 | Notifications: Owner, old Dept, new Dept (status-machine §5.1). |
| RA-10 | Reassignment never deletes attachments: `beforePhotos`, and any `afterPhotos`/`resolutionNote` retained from an earlier reject loop (T7), stay on the complaint. |

## 7. Visibility of assignment data
| Data | Public / maintenance / verifier / board | Admin |
|------|-----------------------------------------|-------|
| `assignment.department` | Shown as `Department.label` (via `assignedDepartment`, privacy-spec DM-2) | yes |
| `assigneeId` (staff) | **never** | yes (resolved to staff name/ID) |
| `assignedBy` | **never** | yes |
| `assignedAt` | via timeline event time only | yes |
| `isManual` | never | yes ("Auto" / "Manual" chip) |

## 8. Worked scenarios (test fixtures)

| # | Setup | Action | Expected result |
|---|-------|--------|-----------------|
| W1 | `electrical`, `reported` | Verifier does Review & Route | `status == assigned`, `assignment.department == electrician`, `isManual == false`, `assigneeId == null`; timeline: `reviewed`, `assigned("Auto-routed to Electrician")` same `at`. |
| W2 | `plumbing`, `reported` | Admin does Review, chooses `carpenter` | `assignment.department == carpenter`, `isManual == true`, `assignedBy == admin.id`. |
| W3 | `plumbing`, `reported` | Admin does Review, chooses `plumber` explicitly | `isManual == false` (MA-2). |
| W4 | `safety`, `reported` | Verifier does Review & Route | `status == reviewed`, `assignment == null`; "Needs manual triage" queue contains it. |
| W5 | W4 continued | Verifier attempts T2 with any department | Rejected (P5). |
| W6 | W4 continued | Admin assigns `civilMaintenance` | `status == assigned`, `isManual == true` (route is `null`). |
| W7 | `other`, `reviewed` | Admin assigns `itTeam` with specific `assigneeId` of an IT staff user | `isManual == true`, `assigneeId` set; assignee not in IT -> rejected (P4). |
| W8 | `furniture`, `assigned` (carpenter), `assigneeId == null` | Carpenter user A starts work (T3) | `inProgress`, `assigneeId == A.id` (claim). |
| W9 | W8 continued | Carpenter user B (same dept) attempts T4/T3 | Rejected (P7). |
| W10 | W8 continued | Plumber user C attempts T3 on an `assigned` electrical complaint | Rejected (P6). |
| W11 | `electrical`, `assigned` (electrician) | Admin reassigns to `itTeam` with reason | Status stays `assigned`; annotation event; `assigneeId == null`; `isManual == true`. |
| W12 | `civil`, `inProgress` (civilMaintenance, assignee X) | Admin reassigns to `electrician` with reason | T8: status `assigned`; `assigneeId == null`; timeline has `assigned` event with the reason note; X no longer sees it. |
| W13 | any `resolved` complaint | Admin attempts reassignment | Rejected (RA-2); must Reject (T7) first. |
| W14 | any `assigned` complaint | Admin "reassigns" to same department + same assignee | Rejected (P4 no-op). |

## 9. Test plan for S2.4 (pure Dart)
1. `routeToDepartment` for all 8 categories (§2); `null` exactly for `safety`, `other`.
2. `routeToDepartment(c) == c.defaultDepartment`; `autoRoutable == (defaultDepartment != null)`; department coverage property (§2).
3. `isManual` derivation (MA-2) as a pure helper/predicate (non-contract; may live in the L2 guard).
4. Scenarios W1–W14 against the executor/guard (shares fixtures with S2.3).
5. Mock `AppUser` fixtures for each department (one maintenance user per department) and per-department peers (to test claim/peer rejection).

## 10. Out of scope / future
* Multi-department complaints (e.g. safety needing electrician + civil), workload balancing,
  skills/shift schedules, SLAs/auto-escalation of unassigned items, vendor/outsourced teams, an
  assignment-history collection (Phase 2 audit), category re-classification, QR-code room routing (R15).

## 11. Open issues for the orchestrator
| ID | Issue |
|----|-------|
| AR-OI-1 | `ARCHITECTURE.md` §8 says `routeToDepartment(Category) -> Department` (non-null); the data model says `Department?`. Update ARCHITECTURE §8. |
| AR-OI-2 | `Assignment` stores only the current assignment; history survives only as timeline note text. A Phase-2 `assignmentHistory` or audit trail would be cleaner. |
| AR-OI-3 | Staff-member selection (MA-3) needs a user directory (list of `AppUser` by role/department). `AuthRepository` has none; seed data must expose a read-only `UserDirectory`/query (not in the data model). Without it, prototype admin assigns by department only (assigneeId always null until claim). |
| AR-OI-4 | `ProblemCategory.autoRoutable` duplicates `defaultDepartment != null`; keep one derived from the other in code. |
