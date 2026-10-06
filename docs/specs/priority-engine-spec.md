# Spec: Priority Engine (`campusfix_core/lib/logic/priority_engine.dart`)

**Chunk:** S2.2 implements this. **Traceability:** R7 (priority system), R2, R12 (admin override).
**Authority:** subordinate to `data-model-spec.md` (names of enums, fields, and the signature below are
taken verbatim from it). Where this spec adds a *non-contract* helper it is labelled so.

## 1. Contract

```dart
// data-model-spec §5 (unchanged)
Priority computePriority(PriorityInputs inputs);
class PriorityInputs {
  ProblemCategory category; bool safetyFlag; Severity severity;
  PeopleAffected peopleAffected; Duration waitingTime; /* locationSensitivity optional */
}
```

| Property | Rule |
|----------|------|
| Purity | No `DateTime.now()`, no randomness, no I/O, no global state. `waitingTime` is *injected*. Same inputs => same output, always. |
| Totality | Defined for every combination of enum values and every `Duration` (negative durations are clamped to zero, see §3.4). Never throws. |
| Output | One of `Priority.critical / high / medium / low`. |
| Scope | The engine computes the **system** priority only. It knows nothing about `priorityOverride` (admin manual override), which is applied by `Complaint.effectivePriority` (§7). |
| Pluggable (R15) | A future AI/ML scorer may replace the body of `computePriority` behind the same signature; nothing else changes. |

**Non-contract helper (recommended, `@visibleForTesting`):**
`int computePriorityScore(PriorityInputs inputs)` returns the raw additive score of §3.5 *before* the
safety rules. It exists only so tests can assert intermediate scores; if the orchestrator prefers not
to expose it, tests may assert `Priority` only, and the "Score" columns below become documentation.

## 2. Inputs and how they are obtained

| `PriorityInputs` field | Source on `Complaint` | Who sets it |
|------------------------|-----------------------|-------------|
| `category` | `Complaint.category` | Reporter (Category step); immutable in v1. |
| `safetyFlag` | `Complaint.safetyFlag` | Reporter (Impact section; **forced on** when category = `safety`). **Admin** may toggle it at triage (`reported -> reviewed`) or any time before `resolved`; verifiers cannot (they never see the flag, privacy-spec §3). |
| `severity` | `Complaint.severity` | Reporter (Impact section). |
| `peopleAffected` | `Complaint.peopleAffected` | Reporter (Impact section). |
| `waitingTime` | `now - Complaint.createdAt` (`Complaint.waitingTime`) | Derived by the caller; `now` is supplied by the caller/clock provider. |
| *(reserved)* `locationSensitivity` | n/a | **Not scored in v1** (contributes 0). R7 lists "location" as a factor; the data model leaves the field optional/untyped, so v1 defers it. See §9. |

## 3. Algorithm

The algorithm is: **additive score -> band -> safety rules (floor / critical trigger)**.

### 3.1 Category base weight (`B`)
Reflects inherent hazard / urgency of the *kind* of problem.

| `ProblemCategory` | `B` | Rationale |
|-------------------|-----|-----------|
| `safety` | 20 | Direct physical-risk category. |
| `electrical` | 15 | Shock/fire risk; also stops teaching. |
| `civil` | 10 | Structural / building envelope. |
| `plumbing` | 10 | Leaks, flooding, washroom hygiene. |
| `it` | 5 | Disruptive but rarely hazardous. |
| `cleanliness` | 5 | Hygiene; rarely hazardous. |
| `furniture` | 0 | Comfort / convenience. |
| `other` | 0 | Unknown; manual triage decides (admin can override). |

### 3.2 Severity contribution (`S`) — reporter-rated
`S = 10 x severity.weight` (uses `Severity.weight` from the data model).

| `Severity` | `weight` | `S` |
|------------|----------|-----|
| `minor` | 1 | 10 |
| `moderate` | 2 | 20 |
| `severe` | 3 | 30 |

### 3.3 People-affected contribution (`P`)
`P = 5 x peopleAffected.weight` (uses `PeopleAffected.weight`).

| `PeopleAffected` | `weight` | `P` |
|------------------|----------|-----|
| `individual` | 1 | 5 |
| `small` | 2 | 10 |
| `many` | 3 | 15 |
| `campusWide` | 4 | 20 |

### 3.4 Waiting-time (aging) contribution (`A`)
Let `w = max(waitingTime, Duration.zero)` (negative values from clock skew are clamped to 0).
Lower bound of each bucket is **inclusive**; upper bound exclusive.

| Bucket | Condition on `w` | `A` |
|--------|------------------|-----|
| fresh | `w < 24 h` | 0 |
| day-old | `24 h <= w < 72 h` | 5 |
| stale | `72 h <= w < 7 d` | 10 |
| week-old | `7 d <= w < 14 d` | 15 |
| neglected | `w >= 14 d` | 25 |

Aging applies **only while the complaint is unresolved** (status before `resolved`); see §6.

### 3.5 Raw score and band
`score = B + S + P + A`  (all terms are multiples of 5; range **15..95**; no clamping needed).

| Score range | Band |
|-------------|------|
| `score >= 65` | `critical` |
| `45 <= score <= 64` | `high` |
| `25 <= score <= 44` | `medium` |
| `score <= 24` | `low` |

> Because every term is a multiple of 5, a score of 64/44/24 is unreachable; the tightest "just below"
> cases in tests are 60/40/20.

### 3.6 Safety rules (hard override on top of the band)
Definitions:

* `safetyFloor  = safetyFlag || category == ProblemCategory.safety`
  (a Safety-category complaint is always a safety matter even if the flag was somehow unset).
* `safetyCritical = safetyFloor && (severity == Severity.severe || peopleAffected == PeopleAffected.campusWide)`

```
Priority computePriority(inputs):
    band = bandOf(computePriorityScore(inputs))
    if safetyCritical : return Priority.critical
    if safetyFloor    : return maxByWeight(band, Priority.high)   // never below High
    return band
```

| Rule | Statement |
|------|-----------|
| SR-1 | `safetyFloor` => result is **at least High** (`weight >= 3`). |
| SR-2 | `safetyFloor` AND (`severe` OR `campusWide`) => result is **Critical**. |
| SR-3 | The safety rules can only **raise** the band, never lower it (a High-by-score stays High; a Critical-by-score stays Critical). |
| SR-4 | `many` (not `campusWide`) and `moderate` do **not** trigger SR-2 on their own; they follow the band (>= High via SR-1). |

## 4. Priority-change rules outside the engine
| Rule | Statement |
|------|-----------|
| PC-1 | **Admin manual override** sets `Complaint.priorityOverride`; it always wins in `effectivePriority`. Only role `admin` may set/clear it. It is never touched by recomputation. |
| PC-2 | Recomputation writes only `Complaint.priority`; it never writes `priorityOverride`. |
| PC-3 | UI (board, lists, tags, sorting, dashboard "critical/high") always uses `effectivePriority` (`priorityOverride ?? priority`). |
| PC-4 | Sorting/comparison uses `Priority.weight` (critical = 4 ... low = 1). `Priority.rank` is not used by this spec (see Open Issues). |

## 5. Worked examples (golden test vectors)

`B/S/P/A` per §3; "Floor?" = `safetyFloor`. "By score" = band from §3.5. All use `waitingTime` as stated.

| # | Category | safetyFlag | Severity | PeopleAffected | waitingTime | B | S | P | A | Score | By score | Safety rule applied | **Result** |
|---|----------|-----------|----------|----------------|-------------|---|---|---|---|-------|----------|---------------------|------------|
| E1 | furniture | no | minor | individual | 2 h | 0 | 10 | 5 | 0 | 15 | low | — | **Low** |
| E2 | furniture | no | minor | small | 23 h 59 m | 0 | 10 | 10 | 0 | 20 | low | — | **Low** |
| E3 | furniture | no | minor | small | 24 h exactly | 0 | 10 | 10 | 5 | 25 | medium | — | **Medium** (aging crosses the 24 h boundary AND the Low/Medium boundary) |
| E4 | furniture | no | moderate | individual | 0 | 0 | 20 | 5 | 0 | 25 | medium | — | **Medium** (lower Medium boundary, exact) |
| E5 | it | no | moderate | many | 1 h | 5 | 20 | 15 | 0 | 40 | medium | — | **Medium** |
| E6 | civil | no | moderate | many | 0 | 10 | 20 | 15 | 0 | 45 | high | — | **High** (lower High boundary, exact) |
| E7 | plumbing | no | severe | many | 1 h | 10 | 30 | 15 | 0 | 55 | high | — | **High** |
| E8 | electrical | no | severe | individual | 0 | 15 | 30 | 5 | 0 | 50 | high | — | **High** |
| E9 | electrical | no | severe | campusWide | 0 | 15 | 30 | 20 | 0 | 65 | critical | — | **Critical** (lower Critical boundary, exact) |
| E10 | it | no | severe | campusWide | 0 | 5 | 30 | 20 | 0 | 55 | high | — | **High** (network outage is not Critical without safety) |
| E11 | it | no | severe | many | 7 d exactly | 5 | 30 | 15 | 15 | 65 | critical | — | **Critical** (aging flips High -> Critical) |
| E12 | it | no | severe | many | 6 d 23 h 59 m 59 s | 5 | 30 | 15 | 10 | 60 | high | — | **High** (one second before E11) |
| E13 | furniture | no | minor | individual | 30 d | 0 | 10 | 5 | 25 | 40 | medium | — | **Medium** (the lowest possible score, 15, tops out at 40 after maximum aging; any Low-band start, <= 20, can reach at most High, 45, by aging alone) |
| E14 | electrical | yes | minor | individual | 0 | 15 | 10 | 5 | 0 | 30 | medium | SR-1 (floor -> High) | **High** |
| E15 | furniture | yes | minor | individual | 0 | 0 | 10 | 5 | 0 | 15 | low | SR-1 (floor -> High) | **High** (extreme floor: Low-by-score becomes High) |
| E16 | civil | yes | severe | individual | 0 | 10 | 30 | 5 | 0 | 45 | high | SR-2 (severe) | **Critical** |
| E17 | plumbing | yes | moderate | campusWide | 0 | 10 | 20 | 20 | 0 | 50 | high | SR-2 (campusWide) | **Critical** |
| E18 | safety | no | minor | individual | 0 | 20 | 10 | 5 | 0 | 35 | medium | SR-1 (implicit floor: category = safety) | **High** |
| E19 | safety | no | severe | small | 0 | 20 | 30 | 10 | 0 | 60 | high | SR-2 (implicit floor + severe) | **Critical** |
| E20 | safety | yes | moderate | small | 10 d | 20 | 20 | 10 | 15 | 65 | critical | — (already Critical by score) | **Critical** (SR-3: rules never lower) |
| E21 | other | no | minor | individual | -5 min (clamped to 0) | 0 | 10 | 5 | 0 | 15 | low | — | **Low** (negative `waitingTime` handled) |
| E22 | electrical | yes | moderate | many | 0 | 15 | 20 | 15 | 0 | 50 | high | SR-1 (no-op); SR-4 (`many`/`moderate` do not trigger SR-2) | **High** |

**Override example (not an engine output, `effectivePriority`):** `priority = High`,
`priorityOverride = Low` => `effectivePriority = Low`. `computePriority` for the same inputs is still `High`.

### 5.1 Category-base vectors
With `severity = minor`, `peopleAffected = individual`, `waitingTime = 0`, `safetyFlag = false`, the
raw scores must be: `safety 35, electrical 30, civil 25, plumbing 25, it 20, cleanliness 20,
furniture 15, other 15` (bands: Medium, Medium, Medium, Medium, Low, Low, Low, Low; after safety rules the
`safety` row becomes **High**).

## 6. When the priority is (re)computed
| Trigger | Action |
|---------|--------|
| Complaint submission | `priority = computePriority(inputs)` with `waitingTime = 0`. Shown on the Confirmation screen. |
| Triage edit (admin toggles `safetyFlag`) | Recompute immediately. |
| Every status transition while the **resulting** status is before `resolved` | Recompute with `waitingTime = now - createdAt`. |
| Complaint list/detail load for an **unresolved** complaint (`status` in `reported, reviewed, assigned, inProgress`) | Recompute with current `now` so aging is visible without a background job (prototype). If the value changed, persist via `ComplaintRepository.update`. |
| Status reaches `resolved`, `verified`, `closed` | **Freeze**: stop recomputing; `priority` keeps its last value (history). |
| Reject path `resolved -> inProgress` | **Unfreeze**: recompute with the full `now - createdAt`. |

Phase 2: replace the on-read recompute with a scheduled Cloud Function (daily/hourly) writing
`priority`; the engine is unchanged.

## 7. `effectivePriority` precedence (summary)
`effectivePriority = priorityOverride ?? priority`. The safety rules are inside `priority`; an admin
override may deliberately lower a safety complaint (admin accountability; Phase 2 audit entry recorded —
see privacy-spec §9). The UI shows an "overridden" marker when `priorityOverride != null`.

## 8. Test plan for S2.2 (all pure-Dart, no UI)
1. **Golden vectors:** assert E1–E22 (Priority; and score if the helper is exposed).
2. **Category base table:** assert §5.1 for all 8 categories.
3. **Boundaries:** score thresholds (60/65, 40/45, 20/25) and aging thresholds
   (23:59:59 / 24:00:00, 71:59:59 / 72:00:00, 6d23:59:59 / 7d, 13d23:59:59 / 14d, `Duration(-1)`).
4. **Safety rules:** SR-1..SR-4, including `category == safety` with `safetyFlag == false`.
5. **Property tests over the full cross product** (8 categories x 3 severities x 4 people x 5 aging
   buckets x 2 safety flags = 960 inputs):
   * *Determinism:* two calls with equal inputs return equal outputs.
   * *Monotone in severity:* raising `severity` never lowers the result (other inputs fixed).
   * *Monotone in peopleAffected:* same.
   * *Monotone in waitingTime:* larger `waitingTime` never lowers the result.
   * *Safety dominance:* `safetyFlag = true` result `>=` `safetyFlag = false` result (by `weight`), and
     `safetyFlag = true` => result `>= High` always.
   * *Floor-only-raises (SR-3):* result `>=` `bandOf(score)`.
   * *Critical triggers:* `safetyFloor && (severe || campusWide)` => `critical` for every category/age.
6. **Immutability/purity:** `PriorityInputs` equality; no clock access (verified by passing fixed
   `waitingTime` values only; a lint/grep test asserts `priority_engine.dart` does not reference `DateTime.now`).

## 9. Out of scope / future (R15)
* Location sensitivity (e.g. labs, hostels, exam halls weighted higher), repeat-complaint detection,
  AI image severity, predictive maintenance: not scored in v1; the `PriorityInputs` object may be
  extended later without changing `computePriority`'s signature.
* Per-college tunable thresholds (config), SLA timers, and an admin "why this priority" breakdown
  panel (needs the §1 helper plus per-term accessors).

## 10. Open issues for the orchestrator
| ID | Issue |
|----|-------|
| PE-OI-1 | `ARCHITECTURE.md` §6 still says `computePriority(ComplaintSignals)`; the authoritative name is `PriorityInputs` (data-model §5). Update ARCHITECTURE §6. |
| PE-OI-2 | `Priority.rank` vs `Priority.weight` are both specified in data-model §1.2 with no definition of `rank`. This spec uses `weight` only. Define `rank` (e.g. 0 = critical for ascending sort) or drop it. |
| PE-OI-3 | `locationSensitivity` is mentioned as optional but is untyped; v1 does not score it. Decide whether to drop the comment or add a type. |
| PE-OI-4 | Treating `category == safety` as an implicit `safetyFlag` (SR rules, E18/E19) is a design decision made here; confirm. The UI also forces `safetyFlag = true` for that category, so the two are consistent. |
