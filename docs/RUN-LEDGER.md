# CampusFix AI — Run Ledger

Single source of truth for progress. **Resume point:** first non-✅ chunk whose deps are ✅.
Status: ⬜ not started · 🟡 in progress · 🔵 in review (merged, verifying) · ✅ done · ⛔ blocked.

_Last updated: 2026-10-06 — by orchestrator._

## Current state
- **Phase:** 1 (design system + clickable prototype).
- **Active wave:** Wave 1 (specs + core models) — ready to dispatch.
- **Trunk:** `main` (agent branches `agent/<chunk-id>` cut from it).
- **Baseline:** scaffold builds — core/design/mobile/admin analyze clean; admin web build ✓.
- **Next action:** dispatch Wave 1 — S0.3 (specs) ‖ S2.1 (models & enums).

## Ledger
| Chunk | Status | Owner | Branch | Checkpoint commit | Notes |
|-------|--------|-------|--------|-------------------|-------|
| S0.1 Repo + docs | ✅ | O | main | 0ba9dfb | Repo, git, .gitignore, README, REQUIREMENTS, ARCHITECTURE, ORCHESTRATION, PLAN, RUN-LEDGER. |
| S0.2 Flutter scaffold | ✅ | O | main | _this commit_ | 2 packages + 2 apps; Riverpod+go_router; path deps; analyze clean; admin web build ✓. |
| S0.3 Detailed specs | ⬜ | A | | | data-model, priority, status, assignment, privacy, screens. |
| S1.1 Design foundations | ⬜ | O/A | | | tokens + Claude Design project. |
| S1.2 Core components | ⬜ | O/A | | | reusable component set. |
| S1.3 Reporter screens | ⬜ | A | | | login→report→track→board→notifications. |
| S1.4 Maintenance+verifier screens | ⬜ | A | | | assigned/work/after-repair/verify. |
| S1.5 Admin web screens | ⬜ | A | | | dashboard/list/manage. |
| S1.6 Design→code handoff | ⬜ | A | | | component↔widget map. |
| S2.1 Models & enums | ⬜ | A | | | spine of core. |
| S2.2 Priority engine | ⬜ | A | | | rule-based + tests. |
| S2.3 Status state machine | ⬜ | A | | | role-gated transitions + tests. |
| S2.4 Assignment routing | ⬜ | A | | | category→department + tests. |
| S2.5 Privacy projections | ⬜ | A | | | public/admin views + tests. |
| S2.6 Repos + seed data | ⬜ | A | | | mock repos + ≥24 complaints. |
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
| 1 | 2026-10-06 | _this commit_ | S0.2 Flutter scaffold (2 pkgs + 2 apps, deps wired, baseline builds). |

## Event / decision log
- 2026-10-06 — Kickoff. Product-owner decisions: Flutter mobile + Flutter Web admin; prototype-first;
  Firebase (Phase 2); Student/Staff ID+password auth. Defaults: Riverpod, go_router, in-memory mocks.
