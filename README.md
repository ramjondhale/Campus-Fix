# CampusFix AI

A college-only smart complaint & maintenance management app. Students and staff report campus
problems (electrical, plumbing, civil, furniture, cleanliness, IT, safety) with photos; the system
assigns a unique Complaint ID, computes priority, routes to the right maintenance team, tracks the
repair through a verified status flow, and keeps before/after evidence — **while hiding reporter
identity on all normal views**.

> Status: **Phase 1 complete — design system + clickable prototype (mock data).** The mobile app (all
> three roles) and the admin web console are feature-complete; **1,418 tests pass** (core 651, design 224,
> mobile 199, admin 344). Firebase backend is Phase 2 (see the [plan](docs/phase-2-firebase-plan.md)).
> New here? Start with the **[Walkthrough](docs/WALKTHROUGH.md)**.

## Tech at a glance
- **Mobile app** — Flutter (`apps/mobile`) for students/staff, maintenance staff, and verifiers.
- **Admin dashboard** — Flutter Web (`apps/admin`) for management.
- **Shared design system** — `packages/campusfix_design` (theme, tokens, reusable widgets).
- **Shared domain + logic** — `packages/campusfix_core` (models, priority engine, status machine,
  assignment routing, privacy projections, mock repositories + seed data).
- **State / routing** — Riverpod + go_router.
- **Backend (Phase 2)** — Firebase: Auth, Firestore, Storage, FCM.

## Repository layout
```
campusfix/
├── docs/            # Walkthrough, building, architecture, requirements, phase-2 plan, specs, design, process/
├── packages/
│   ├── campusfix_core/      # pure-Dart models + business logic + mock data
│   └── campusfix_design/    # design system (theme, tokens, widgets)
└── apps/
    ├── mobile/      # Flutter mobile app
    └── admin/       # Flutter Web admin dashboard
```

## Documentation
| Doc | Purpose |
|---|---|
| [docs/WALKTHROUGH.md](docs/WALKTHROUGH.md) | **Start here** — guided tour: what exists, how to run it, who does what, the privacy model |
| [docs/BUILDING.md](docs/BUILDING.md) | Prerequisites, build/run/test commands, the iOS build note |
| [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md) | Distilled requirements + traceability |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Technical decisions & structure |
| [docs/phase-2-firebase-plan.md](docs/phase-2-firebase-plan.md) | The Phase-2 backend plan (Auth, Firestore + security rules, Storage, FCM) |
| [docs/specs/](docs/specs/) | Detailed specs (data model, priority, status, assignment, privacy, screens) |
| [docs/design/](docs/design/) | Design system definition + published style guide |
| [docs/process/](docs/process/) | Build-history archive (plan, run ledger, orchestration) |

## Running
```bash
# Admin web console — the fully runnable target
cd apps/admin && flutter run -d chrome

# Mobile app (iOS simulator / Android device; see BUILDING.md for the current iOS build note)
cd apps/mobile && flutter run

# Tests (core 651 · design 224 · mobile 199 · admin 344)
cd packages/campusfix_core && dart test
cd packages/campusfix_design && flutter test
cd apps/mobile && flutter test
cd apps/admin && flutter test
```
See the [Walkthrough](docs/WALKTHROUGH.md) for demo accounts and the role-by-role flows, and
[BUILDING.md](docs/BUILDING.md) for prerequisites and the iOS build note.
