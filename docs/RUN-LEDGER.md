# CampusFix AI — Run Ledger

Single source of truth for progress. **Resume point:** first non-✅ chunk whose deps are ✅.
Status: ⬜ not started · 🟡 in progress · 🔵 in review (merged, verifying) · ✅ done · ⛔ blocked.

_Last updated: 2026-10-07 — by orchestrator._

## Current state
- **Phase:** 1 (design system + clickable prototype).
- **Active wave:** Wave 6 (admin web). **Mobile app (all 3 roles) feature-complete** (Wave 5 done:
  S4.1–S4.6). Admin web: **S5.1 foundation ✅, S5.2 dashboard ✅**. Resume at **S5.3 (list + filters)** →
  S5.4 (detail/manage + identity reveal) → S6 (integration).
- **S5.3 inputs ready:** parse the URL filter keys from `apps/admin/lib/providers/complaint_query.dart`
  (keys: status/priority/category/department/building/q/unresolved/triage/created). Reuse `CreatedRange`
  (+ `CreatedRange.contains`) and the predicates `isUnresolvedStatus`/`isCriticalOrHigh` from
  `providers/dashboard.dart`. `triage` = status==reviewed & unassigned; filters AND together. Use design's
  `ComplaintTable` + `FilterBar`. Dashboard presets already emit these URLs (AC-47 exact).
- **✅ Admin web BUILDS:** `cd apps/admin && flutter build web` succeeds (unlike the blocked iOS target),
  so the admin console is the one **visually verifiable** app — do a live preview / screenshots at S5.2+.
- **🔑 Admin privacy is pre-wired in core's PR-T14 guard** (it scans `apps/admin/lib`): `AdminComplaintView`
  is allowed ONLY under `apps/admin/lib/features/complaint_detail/`, and `ReporterIdentity`/`.reporter` ONLY
  in `apps/admin/lib/features/complaint_detail/identity_panel.dart`; `AdminComplaintView` is forbidden in
  `providers/`. So **S5.4's admin-view controller + identity panel must live under `features/complaint_detail/`**
  (the S5.1 stub is already placed there). Dashboard (S5.2) + list (S5.3) use `PublicComplaintView` only via
  `apps/admin/lib/providers/complaints.dart` (`allComplaintsProvider`, `complaintViewProvider(id)`).
- **Minor cleanup (S6):** M-17 imports `WorkActionBar` + `kNoteVisibilityHelper` from
  `features/work/work_widgets.dart` (cross-feature). Consider hoisting shared action-bar/note widgets to
  `features/shared`. Some test finders (`button`/`dialogButton`/`tapButton`) are duplicated across
  work/verify fixtures. Non-blocking.
- **⚠ Demo-data gap (S6 task, maintenance only):** the stock seed leaves the **demo maintenance login**
  (`_maintenance.first` = electrician `u-mnt-ele-01`) with an **empty queue**, so a live run shows **M-13**
  empty states. **The demo verifier is fine** (4 `resolved` complaints exist, queue isn't department-scoped,
  so M-16 is populated — confirmed by S4.6). The flows are fully correct + test-covered (S4.5 work tests
  re-purpose seed complaints via `apps/mobile/test/support/work_fixtures.dart`). Fix at S6 as a **coordinated
  seed change** — give the demo electrician real open work in `seed_data.dart` — updating the dependent core
  seed-count tests AND the mobile work fixtures together. (A quick demo-account swap was tried and reverted:
  it breaks the 34 electrician-pinned work tests; the seed itself must change, not just the login.)
- **Verify-gate reminder:** after merging any app chunk, re-run BOTH `apps/mobile` tests AND the
  `campusfix_core` suite (core's PR-T14 scans the mobile tree, so mobile changes can break core tests).
- **⚠ iOS build blocker (see docs/BUILDING.md):** `flutter build ios --simulator` fails with
  `App.framework: No such file`. Fixed along the way: CocoaPods needs `LANG=en_US.UTF-8`; deployment
  target pinned to 15.0 (Podfile post_install + pbxproj). Remaining error is a Flutter/Xcode pipeline
  quirk — resolve via Xcode-direct build at S6, or user's input. Visual QA on iOS deferred. Feature
  work continues (logic is fully unit/widget-tested).
- **⚠ Orchestration note:** background Sonnet agents are stalling on a stream watchdog (3 stalls). Running
  app agents in the **foreground** works reliably (S4.1 succeeded that way) but forces **serial** execution
  (no ≤4 parallel for now). Revert to parallel background when the stream recovers.
- **Trunk:** `main` (agent branches `agent/<chunk-id>` cut from it).
- **Baseline:** **`campusfix_core` COMPLETE — 651 tests green, analyze clean** (models, 8 enums, views,
  priority engine, status machine + validateTransition, assignment, privacy, mock repos + seed [29
  complaints/25 users/226 notifs], ComplaintService + NotificationService). Design system published.
- **Next action:** Wave 5 — S4.1 (mobile app shell: go_router + Riverpod + mock ID/password login +
  role-aware nav). Then S4.2/S4.3/S4.4 in parallel, then S4.5/S4.6. Visual QA on iOS simulator.

## Ledger
| Chunk | Status | Owner | Branch | Checkpoint commit | Notes |
|-------|--------|-------|--------|-------------------|-------|
| S0.1 Repo + docs | ✅ | O | main | 0ba9dfb | Repo, git, .gitignore, README, REQUIREMENTS, ARCHITECTURE, ORCHESTRATION, PLAN, RUN-LEDGER. |
| S0.2 Flutter scaffold | ✅ | O | main | _this commit_ | 2 packages + 2 apps; Riverpod+go_router; path deps; analyze clean; admin web build ✓. |
| S0.3 Detailed specs | ✅ | A | merged | fbf7ddb | 5 specs (priority/status/assignment/privacy/screens) merged; 14 open issues resolved by O (see data-model-spec §7). |
| S1.1 Design foundations | ✅ | A | merged | 5f1a7df | design-system.md (26 components, 200 contrast pairs ok, M3 mapping) + HTML style-guide Artifact (O visual-QA'd). URL below. |
| S1.2 Core components | ✅ | A | merged | 5f1a7df | covered by S1.1 style-guide component gallery (26 components). |
| S1.3 Reporter screens | ⏸️ deferred | — | | | static mockups deferred; Flutter app (S4) is the clickable prototype. |
| S1.4 Maintenance+verifier screens | ⏸️ deferred | — | | | deferred; realized in Flutter S4.5/S4.6. |
| S1.5 Admin web screens | ⏸️ deferred | — | | | deferred; realized in Flutter S5. |
| S1.6 Design→code handoff | ✅ | A | merged | 5f1a7df | design-system.md §10 (token→ThemeData/ColorScheme/ThemeExtension mapping) is the handoff. |
| S2.1 Models & enums | ✅ | A | merged | 5c1b2bb | 8 enums, 6 models, id gen, 2 repo interfaces; 73 tests green (O-verified). As-built notes folded into data-model-spec. |
| S2.2 Priority engine | ✅ | A | merged | aca2b37 | rule-based; 22 golden + 960-input property tests. |
| S2.3 Status state machine | ✅ | A | merged | 26ef78a | L1 matrix + validateTransition (P1–P9); exhaustive 196-tuple tests. |
| S2.4 Assignment routing | ✅ | A | merged | 59677d1 | category→department + isManual; full table tests. |
| S2.5 Privacy projections | ✅ | A | merged | d220f87 | public/admin views + PII-leak sweep + static architecture guard. |
| S2.6 Repos + seed data | ✅ | A | merged | 43a42bf | 4 mock repos + AppNotification/User/Campus directories; seed = 29 complaints/25 users/226 notifs; +144 tests (538 total). |
| S2.7 Services | ✅ | A | merged | a0b4466 | ComplaintService (executor, per-complaint locking, INV-4/5, P4/N15) + NotificationService (canonical templates); +113 tests (651 total). |
| S3.1 Theme & tokens | ✅ | A | merged | 62603b0 | token classes, google_fonts typography, 4 ThemeExtensions, AppTheme light/dark + component themes + context helpers; 66 tests, analyze clean. |
| S3.2 Reusable widgets | ✅ | A | merged | dd01ef4 | 29 PII-free widgets + gallery + example app + architecture guard; 224 tests, analyze clean. Agent stalled pre-commit; orchestrator verified+committed+merged. |
| S4.1 Mobile shell + auth | ✅ | A | merged | 79f744d | go_router + providers (privacy boundary) + mock login + role-aware shell/home + 7 feature stubs; 33 tests, analyze clean. (foreground agent; 2 prior bg stalls.) Reporter nav = Home/My Complaints/Board/Alerts per spec; Report is a Home CTA. |
| S4.2 Report-a-Problem flow | ✅ | A | merged | (ff) | Category→Location→Photos→Details→Review→Submit→Confirmation(ID+priority); draft state + privacy-safe submit controller; 59 mobile tests. Fixed pre-existing core PR-T14 regex (UserRole.reporter false-positive) + allow-listed boundary provider. |
| S4.3 My Complaints + Details | ✅ | A | merged | (merge) | list (own complaints) + details (timeline/before-after/privacy-safe); design-system-clean. |
| S4.4 Board + Notifications | ✅ | A | merged | (merge) | anon board (filters/search) + notifications (read state); 106 mobile tests; core guard green. |
| S4.5 Maintenance flow | ✅ | A | merged | 678c89a | M-13 Assigned Work (To start/In progress/Rework) + M-14 Work Detail (start/claim T3) + M-15 After-Repair resolve (T4); PII-free write controller in providers/work_actions.dart; 157 mobile tests (106+51), core 651 green, no raw colors. |
| S4.6 Verifier flow | ✅ | A | merged | 53305c2 | M-16 Verification Queue + M-17 Verify/Reject (verify T5 / reject T7 — **no close on mobile**, close is admin-only T6/web); PII-free verify_actions controller; 199 mobile tests (157+42), core 651 green, no raw colors. Reconciled stale "Verify & Close" spec text (M-17/AC-42/A-04). |
| S5.1 Admin shell+auth+layout | ✅ | A | merged | 4a75ea1 | Admin web foundation: themed MaterialApp.router, mock auth+session, A-01 login (A/V demo accounts; reporter/maintenance→E-403, AC-45), go_router + role guard, responsive desktop-first shell (side-nav/rail/drawer @1024/600px), public-view data boundary (allComplaintsProvider), dashboard/list/detail stubs, E-403/E-404. 63 admin tests, analyze clean, flutter build web ✓. Detail stub placed at features/complaint_detail/ per core PR-T14. |
| S5.2 Dashboard | ✅ | A | merged | 0a95a26 | A-02: 8 MetricCards (partition invariant 7+4+6+7+5=29 holds), 3 MetricBarRow breakdown charts (status/priority/category) + token-driven 14-day intake chart, 3 triage lists, AppSegmented date range (7/30/90/All), card/chart/row→A-03 presets (AC-47 exact: Critical/High→unresolved=1&priority=critical,high). Identity-free (public views+aggregates). 127 admin tests, core 651, analyze clean, web build ✓. Defines complaint_query.dart URL contract for S5.3. |
| S5.3 Complaint list + filters | ⬜ | A | | | table + filters. |
| S5.4 Complaint management | ⬜ | A | | | assign/priority/status/photos. |
| S6.1 Integrate + build + smoke | ⬜ | O | | | merge all + screenshots. |
| S6.2 Walkthrough + cleanup | ⬜ | O | | | WALKTHROUGH.md + tidy. |
| S6.3 Phase-2 Firebase plan | ⬜ | O | | | backend build plan. |

## Design system
- **Published Artifact (style guide):** https://claude.ai/artifact/X521FrUxyrBpwzuus8xUyQ ("CampusFix
  Design System", private to the account). Source: `docs/design/design-system.html`.
- **Token contract:** `docs/design/design-system.md` (petrol-teal primary; Archivo / Public Sans /
  JetBrains Mono; semantic sets for 8 categories / 4 priorities / 7 statuses; M3 ColorScheme mapping).
- **S1.1 design decisions (orchestrator verdicts on the 8 open questions):**
  1. **Dark theme is in v1** (tokens specified + contrast-verified; near-free via Flutter ThemeData). Light is default/system-driven.
  2. Brand = petrol-teal placeholder; a real college brand later swaps only `primary*` + `focusRing`.
  3. Bottom-nav label **"Alerts"**; the screen title stays **"Notifications"**.
  4. Need ~8 bundled sample before/after images — orchestrator provides placeholder assets for S3.2/S4.
  5. Icons = Material `Icons.*_outlined` (no extra dependency).
  6. Admin web is **desktop-first**; <1024px is a graceful fallback, not a requirement.
  7. Rework (T7) is a timeline/stepper **marker**, not an 8th status (7 statuses stand).
  8. No separate Claude Design project (account has no Design type) — the HTML Artifact is the deliverable.

## Scope decisions — UI phase (2026-10-06)
- **S1.2** (component designs) is **satisfied by S1.1**'s live component gallery — not a separate chunk.
- **S1.3–S1.5** (static HTML screen mockups) **deferred**: the Flutter app is the clickable prototype
  (prototype-first, R17). Can be produced later on request. Ledger rows kept as ⬜/deferred.
- **Complaint photos** = Flutter-**drawn placeholders** (category color + icon + BEFORE/AFTER label),
  no bundled image files; resolves S1.1 open-Q4. The seed's asset refs render via this placeholder.
- **Fonts**: `google_fonts` (runtime fetch) for Archivo/Public Sans/JetBrains Mono in the prototype.

## Checkpoint log
| # | Date | Commit | What landed |
|---|------|--------|-------------|
| 0 | 2026-10-06 | 0ba9dfb | S0.1 foundation (docs, plan, ledger). |
| 1 | 2026-10-06 | 8e330fc | S0.2 Flutter scaffold (2 pkgs + 2 apps, deps wired, baseline builds). |
| 2 | 2026-10-06 | 761b347 | S0.3 data-model spec (core contract). |
| 3 | 2026-10-06 | 5c1b2bb | S2.1 campusfix_core models/enums/id-gen/repo-interfaces (73 tests). |
| 4 | 2026-10-06 | 1570f7e | S2.1 integration + as-built notes. |
| 5 | 2026-10-06 | c3237b1 | S0.3 specs merged; open issues resolved (data-model §7); ARCHITECTURE fixes; S2.7 added. |
| 6 | 2026-10-06 | b21d181 | Wave 2 integrated: priority/status/assignment/privacy merged, barrel wired, userId redacted, privacy-spec synced; 394 tests green. |
| 7 | 2026-10-06 | 05ae5c6 | S2.6 merged: mock repos + seed (29 complaints) + directories; 538 tests green. |
| 8 | 2026-10-06 | 8dcfb8b | S1.1 design foundations merged (design-system.md + published style-guide Artifact); 8 design decisions logged. |
| 9 | 2026-10-06 | 4d9cafa | S2.7 merged: ComplaintService + NotificationService; core layer COMPLETE at 651 tests. |
| 10 | 2026-10-06 | 1d2fc99 | S3.1 merged: Flutter theme (tokens, typography, ThemeExtensions, AppTheme light/dark); 66 tests. |
| 11 | 2026-10-07 | c5aad09 | S3.2 merged: 29-widget library + gallery + example; 224 tests. Design package complete. |
| 12 | 2026-10-07 | d0f0e7f | S4.1 merged: mobile app shell (router/providers/login/nav + stubs); 33 tests. First runnable app. |
| 13 | 2026-10-07 | de60521 | S4.2 merged: Report-a-Problem flow (59 mobile tests) + fixed core PR-T14 guard regression; core 651 green. |
| 14 | 2026-10-07 | f8eaa1a | iOS config fixes (UTF-8 locale, deploy target 15.0) + BUILDING.md (App.framework blocker). |
| 15 | 2026-10-07 | 2798206 | S4.3+S4.4 reader screens merged (106 mobile tests); CLAUDE.md + hard design-system/foreground rules added. Phase paused for compaction. |
| 16 | 2026-10-07 | 678c89a | S4.5 maintenance flow merged (M-13/M-14/M-15 + work write controller); 157 mobile tests, core 651 green, analyze clean, no design drift. Demo-data gap logged as S6 task. |
| 17 | 2026-10-07 | 53305c2 | S4.6 verifier flow merged (M-16/M-17 verify+reject, no mobile close); 199 mobile tests, core 651 green, analyze clean. Mobile app feature-complete. Stale "Verify & Close" spec reconciled; demo-data gap corrected (verifier queue is fine). |
| 18 | 2026-10-07 | 4a75ea1 | S5.1 admin web foundation merged (shell/auth/routing/responsive layout/public-view boundary + stubs); 63 admin tests, core 651 green, analyze clean, flutter build web ✓. First runnable-target app (web). |
| 19 | 2026-10-07 | 0a95a26 | S5.2 admin dashboard merged (A-02 cards/charts/lists/date-range + A-03 query contract); 127 admin tests, core 651 green, analyze clean, web build ✓. |

## Event / decision log
- 2026-10-06 — Kickoff. Product-owner decisions: Flutter mobile + Flutter Web admin; prototype-first;
  Firebase (Phase 2); Student/Staff ID+password auth. Defaults: Riverpod, go_router, in-memory mocks.
- 2026-10-06 — S0.3 open issues resolved (full verdicts in `docs/specs/data-model-spec.md §7`):
  views gain public timeline + resolutionNote + assignedDepartment (DM-1/2/3); privacy via provider
  boundary (DM-4); added `validateTransition` L2 guard (SM-OI-1); verify & close kept as two actions
  (verifier verifies, admin closes); new models AppNotification/User/Campus directories (S2.6) and
  ComplaintService/NotificationService (S2.7).
- 2026-10-06 — Wave 2 carry-over notes (from agent reports; apply in later chunks):
  - **S2.7 ComplaintService must:** derive `Assignment.isManual` from `routeToDepartment` (don't trust
    the caller); ignore/reject `priorityOverride` from non-admins; enforce INV-5 (freeze priority on
    resolved/verified/closed, unfreeze on T7 reject); perform the deferred P4 user-directory check
    (assignee is a `maintenance` user of that department — the skipped N15); ensure true composite
    atomicity (validate all steps before committing any).
  - **S2.6 seed:** `test/support/fixtures.dart` `fullComplaint()` has an inconsistent `isManual` — make
    seed data router-consistent; re-run privacy PR-T9 sweep over real seed; re-run the priority
    recompute rules (§6) when seeding aged complaints.
  - **S4 report flow:** add the report-submit controller path to privacy test `mobileReporterAllowList`
    (PR-T14 architecture guard); it's the one allowed place to touch `ReporterIdentity` in mobile.
