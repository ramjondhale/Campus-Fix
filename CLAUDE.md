# CLAUDE.md — CampusFix AI working notes

College-only complaint & maintenance app. **Flutter mobile + Flutter Web admin**, Firebase backend is
**Phase 2** (prototype uses in-memory mocks). Full plan/state live in `docs/` — start at
[docs/process/RUN-LEDGER.md](docs/process/RUN-LEDGER.md) (the build record) and [docs/process/PLAN.md](docs/process/PLAN.md).

## Repo layout
- `packages/campusfix_core` — pure Dart: models, 11 enums, logic (priority engine, status machine,
  assignment, privacy projections), mock repos + seed data, `ComplaintService`/`NotificationService`.
  **Complete, 651 tests.**
- `packages/campusfix_design` — theme (tokens, `AppTheme.light/dark`, `ThemeExtension`s) + ~29 reusable
  widgets + gallery. **Complete, 224 tests.** This is the **single source of UI truth**.
- `apps/mobile` — Flutter app (reporter/maintenance/verifier). **Feature-complete** (all 3 role flows;
  199 tests). Verifier verifies (T5)/rejects (T7) only — **no close on mobile** (close is admin-only, web).
- `apps/admin` — Flutter **Web** admin. **Feature-complete (S5.1–S5.4, 344 tests):** themed app, mock auth +
  A-01 login (A/V only; reporter/maintenance→E-403), go_router + role guard, responsive desktop-first shell
  (side-nav ≥1024 / icon-rail ≥600 / drawer <600), A-02 dashboard, A-03 list+filters, A-04 detail/manage
  with the **admin-only identity reveal**. **`flutter build web` works** (the mobile app also builds + runs
  on the iOS simulator now — see known issues). **Admin privacy allow-list lives in core's PR-T14 AND `apps/admin/test/architecture_guard_test.dart`**
  (both scan `apps/admin/lib`): `AdminComplaintView`/`toAdminView`/raw-complaint/ids only under
  `features/complaint_detail/`; `ReporterIdentity`/`.reporter` only in
  `features/complaint_detail/identity_panel.dart`. Dashboard/list use `PublicComplaintView` only via
  `providers/complaints.dart`. Filter URL contract: `providers/complaint_query.dart`.
- `docs/` — ARCHITECTURE, REQUIREMENTS, BUILDING, WALKTHROUGH, phase-2-firebase-plan, specs/, design/;
  build-process archive (PLAN, RUN-LEDGER, ORCHESTRATION) under `docs/process/`.

## HARD RULES (do not violate)
1. **Design system is law.** Style only via `campusfix_design` tokens/`ThemeExtension`s/`BuildContext`
   helpers/widgets. **No raw `Colors.*`, `Color(0x…)`, hex, ad-hoc `TextStyle`, or hardcoded
   sizes/radii** in app code (`Colors.transparent` is the sole exception). Missing a token? Add it to the
   design system, don't inline. Orchestrator greps each UI chunk for raw colors.
2. **Privacy by construction (R5).** Widgets consume **`PublicComplaintView`/`PublicStatusEvent` only** —
   never raw `Complaint`, `ReporterIdentity`, `.reporter`, `actorId`, or `AdminComplaintView`. Mapping to
   views happens in `lib/providers/`. The ONLY app files allowed to touch `ReporterIdentity` are
   allow-listed in core's `privacy_test.dart` `mobileReporterAllowList` (currently `report_submit.dart`
   and `complaints.dart`). Timelines show role+time+note, never actor identity.
3. **Verify BOTH suites after any mobile change.** Core's PR-T14 guard scans `apps/mobile/lib`, so mobile
   edits can break `campusfix_core` tests. Always run `apps/mobile` tests AND `dart test` in core.

## Orchestration model (this is an Opus-orchestrator / Sonnet-worker project)
- Opus (the chat) plans/decides/merges/verifies; **Sonnet agents do all implementation**.
- Each chunk = its own git worktree + `agent/<chunk-id>` branch off `main`; orchestrator merges, verifies,
  checkpoints (commit + update RUN-LEDGER), then removes the worktree + branch.
- **Flutter app agents: dispatch FOREGROUND** (`run_in_background: false`) — background agents get killed
  by a stream watchdog. Tell agents to **commit code in stages** before slow `flutter` commands so any
  interruption/stall is salvageable (several chunks were recovered this way).
- Agents never run `flutter run`/app builds/simulators; the **orchestrator** does builds/visual QA.

## Commands
```bash
# Tests
cd packages/campusfix_core && dart test
cd packages/campusfix_design && flutter test
cd apps/mobile && flutter test
# Admin web
cd apps/admin && flutter run -d chrome
```
**iOS builds require a UTF-8 locale** (CocoaPods crashes otherwise):
`export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8`.

## Known issues
- **Demo-data gap (S6, maintenance only):** the stock seed leaves the demo maintenance login (electrician
  `u-mnt-ele-01`) with an **empty queue**, so **M-13** shows empty states on a live run. (The demo verifier
  is fine — 4 `resolved` complaints exist and the queue isn't department-scoped, so **M-16 is populated**.)
  Flows are correct + test-covered (work tests re-purpose seed complaints). Fix at S6 by changing
  `seed_data.dart` to give the demo electrician real open work, updating core seed-count tests + mobile
  `work_fixtures.dart` together — a mere demo-account swap breaks the electrician-pinned work tests.
- **iOS simulator build: FIXED** (was `App.framework: No such file`). Root cause: Xcode 27's `lipo`
  rejects Flutter 3.41's two-arch `lipo -verify_arch arm64 x86_64` in `thinFramework`, so universal
  simulator builds never produce `App.framework`. Fix: build arm64-only for the simulator via
  `EXCLUDED_ARCHS[sdk=iphonesimulator*] = x86_64` in `ios/Flutter/{Debug,Release}.xcconfig` + `ios/Podfile`
  post_install. `flutter build ios --simulator` and `flutter run` work; the app launches on the iPhone 16
  Pro sim. (arm64-only won't run on an Intel Mac's simulator — see [docs/BUILDING.md](docs/BUILDING.md).)

## Design system
Published style guide: https://claude.ai/artifact/X521FrUxyrBpwzuus8xUyQ — token contract in
[docs/design/design-system.md](docs/design/design-system.md). Petrol-teal primary; Archivo / Public Sans
/ JetBrains Mono. Semantic sets for 8 categories, 4 priorities, 7 statuses.

_Keep this file current as the project evolves._
