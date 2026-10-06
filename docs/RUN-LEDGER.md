# CampusFix AI — Run Ledger

Single source of truth for progress. **Resume point:** first non-✅ chunk whose deps are ✅.
Status: ⬜ not started · 🟡 in progress · 🔵 in review (merged, verifying) · ✅ done · ⛔ blocked.

_Last updated: 2026-10-06 — by orchestrator._

## Current state
- **Phase:** 1 (design system + clickable prototype).
- **Active wave:** Wave 2 (core logic engines) — dispatching.
- **Trunk:** `main` (agent branches `agent/<chunk-id>` cut from it).
- **Baseline:** scaffold builds; S2.1 core (73 tests) merged; all S0.3 specs merged + open issues resolved.
- **Next action:** dispatch Wave 2 — S2.2 priority ‖ S2.3 status ‖ S2.4 assignment ‖ S2.5 privacy (4 worktrees).

## Ledger
| Chunk | Status | Owner | Branch | Checkpoint commit | Notes |
|-------|--------|-------|--------|-------------------|-------|
| S0.1 Repo + docs | ✅ | O | main | 0ba9dfb | Repo, git, .gitignore, README, REQUIREMENTS, ARCHITECTURE, ORCHESTRATION, PLAN, RUN-LEDGER. |
| S0.2 Flutter scaffold | ✅ | O | main | _this commit_ | 2 packages + 2 apps; Riverpod+go_router; path deps; analyze clean; admin web build ✓. |
| S0.3 Detailed specs | ✅ | A | merged | fbf7ddb | 5 specs (priority/status/assignment/privacy/screens) merged; 14 open issues resolved by O (see data-model-spec §7). |
| S1.1 Design foundations | ⬜ | O/A | | | tokens + Claude Design project. |
| S1.2 Core components | ⬜ | O/A | | | reusable component set. |
| S1.3 Reporter screens | ⬜ | A | | | login→report→track→board→notifications. |
| S1.4 Maintenance+verifier screens | ⬜ | A | | | assigned/work/after-repair/verify. |
| S1.5 Admin web screens | ⬜ | A | | | dashboard/list/manage. |
| S1.6 Design→code handoff | ⬜ | A | | | component↔widget map. |
| S2.1 Models & enums | ✅ | A | merged | 5c1b2bb | 8 enums, 6 models, id gen, 2 repo interfaces; 73 tests green (O-verified). As-built notes folded into data-model-spec. |
| S2.2 Priority engine | ⬜ | A | | | rule-based + tests. |
| S2.3 Status state machine | ⬜ | A | | | role-gated transitions + tests. |
| S2.4 Assignment routing | ⬜ | A | | | category→department + tests. |
| S2.5 Privacy projections | ⬜ | A | | | public/admin views + tests. |
| S2.6 Repos + seed data | ⬜ | A | | | mock repos + ≥24 complaints + AppNotification/User/Campus directories. |
| S2.7 Services | ⬜ | A | | | ComplaintService (transition executor) + NotificationService. |
| S3.1 Theme & tokens | ⬜ | A | | | Flutter theme from S1.1. |
| S3.2 Reusable widgets | ⬜ | A | | | Flutter widgets + gallery. |
| S4.1 Mobile shell + auth | ⬜ | A | | | router+riverpod+mock login. |
| S4.2 Report-a-Problem flow | ⬜ | A | | | full submission flow. |
| S4.3 My Complaints + Details | ⬜ | A | | | list + timeline + before/after. |
| S4.4 Board + Notifications | ⬜ | A | | | anon board + notifications. |
| S4.5 Maintenance flow | ⬜ | A | | | assigned→progress→after-repair. |
| S4.6 Verifier flow | ⬜ | A | | | verify→close. |
| S5.1 Admin shell+auth+layout | ⬜ | A | | | responsive web shell. |
| S5.2 Dashboard | ⬜ | A | | | metric cards + charts. |
| S5.3 Complaint list + filters | ⬜ | A | | | table + filters. |
| S5.4 Complaint management | ⬜ | A | | | assign/priority/status/photos. |
| S6.1 Integrate + build + smoke | ⬜ | O | | | merge all + screenshots. |
| S6.2 Walkthrough + cleanup | ⬜ | O | | | WALKTHROUGH.md + tidy. |
| S6.3 Phase-2 Firebase plan | ⬜ | O | | | backend build plan. |

## Checkpoint log
| # | Date | Commit | What landed |
|---|------|--------|-------------|
| 0 | 2026-10-06 | 0ba9dfb | S0.1 foundation (docs, plan, ledger). |
| 1 | 2026-10-06 | 8e330fc | S0.2 Flutter scaffold (2 pkgs + 2 apps, deps wired, baseline builds). |
| 2 | 2026-10-06 | 761b347 | S0.3 data-model spec (core contract). |
| 3 | 2026-10-06 | 5c1b2bb | S2.1 campusfix_core models/enums/id-gen/repo-interfaces (73 tests). |
| 4 | 2026-10-06 | 1570f7e | S2.1 integration + as-built notes. |
| 5 | 2026-10-06 | _this commit_ | S0.3 specs merged; open issues resolved (data-model §7); ARCHITECTURE fixes; S2.7 added. |

## Event / decision log
- 2026-10-06 — Kickoff. Product-owner decisions: Flutter mobile + Flutter Web admin; prototype-first;
  Firebase (Phase 2); Student/Staff ID+password auth. Defaults: Riverpod, go_router, in-memory mocks.
- 2026-10-06 — S0.3 open issues resolved (full verdicts in `docs/specs/data-model-spec.md §7`):
  views gain public timeline + resolutionNote + assignedDepartment (DM-1/2/3); privacy via provider
  boundary (DM-4); added `validateTransition` L2 guard (SM-OI-1); verify & close kept as two actions
  (verifier verifies, admin closes); new models AppNotification/User/Campus directories (S2.6) and
  ComplaintService/NotificationService (S2.7).
