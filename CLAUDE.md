# CLAUDE.md — CampusFix AI working notes

College-only complaint & maintenance app. **Flutter mobile + Flutter Web admin**, Firebase backend is
**Phase 2** (prototype uses in-memory mocks). Full plan/state live in `docs/` — start at
[docs/RUN-LEDGER.md](docs/RUN-LEDGER.md) (the resume point) and [docs/PLAN.md](docs/PLAN.md).

## Repo layout
- `packages/campusfix_core` — pure Dart: models, 8 enums, logic (priority engine, status machine,
  assignment, privacy projections), mock repos + seed data, `ComplaintService`/`NotificationService`.
  **Complete, 651 tests.**
- `packages/campusfix_design` — theme (tokens, `AppTheme.light/dark`, `ThemeExtension`s) + ~29 reusable
  widgets + gallery. **Complete, 224 tests.** This is the **single source of UI truth**.
- `apps/mobile` — Flutter app (reporter/maintenance/verifier). In progress.
- `apps/admin` — Flutter Web admin. Not started.
- `docs/` — PLAN, RUN-LEDGER, ARCHITECTURE, ORCHESTRATION, BUILDING, specs/, design/.

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
- **iOS simulator build blocked:** `flutter build ios --simulator` fails with `App.framework: No such
  file` despite UTF-8 locale + iOS 15.0 deployment target + clean pods. Likely a Flutter 3.41/Xcode
  pipeline quirk — try building `ios/Runner.xcworkspace` in Xcode directly. See
  [docs/BUILDING.md](docs/BUILDING.md). App logic is fully test-covered regardless.

## Design system
Published style guide: https://claude.ai/artifact/X521FrUxyrBpwzuus8xUyQ — token contract in
[docs/design/design-system.md](docs/design/design-system.md). Petrol-teal primary; Archivo / Public Sans
/ JetBrains Mono. Semantic sets for 8 categories, 4 priorities, 7 statuses.

_Keep this file current as the project evolves._
