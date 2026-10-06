# CampusFix AI

A college-only smart complaint & maintenance management app. Students and staff report campus
problems (electrical, plumbing, civil, furniture, cleanliness, IT, safety) with photos; the system
assigns a unique Complaint ID, computes priority, routes to the right maintenance team, tracks the
repair through a verified status flow, and keeps before/after evidence — **while hiding reporter
identity on all normal views**.

> Status: **Phase 1 — Design system + clickable prototype (mock data).** Firebase backend is planned
> for Phase 2 and is deliberately out of scope until the prototype is approved.

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
├── docs/            # Plan, run ledger, architecture, requirements, specs, design
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
| [docs/PLAN.md](docs/PLAN.md) | Master plan — sections (epics) broken into agent-sized chunks |
| [docs/RUN-LEDGER.md](docs/RUN-LEDGER.md) | Live progress tracker (resume point) |
| [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md) | Distilled requirements + traceability |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Technical decisions & structure |
| [docs/ORCHESTRATION.md](docs/ORCHESTRATION.md) | How orchestrator + agents collaborate |
| [docs/specs/](docs/specs/) | Detailed specs (data model, priority, status, assignment, privacy, screens) |
| [docs/design/](docs/design/) | Design system definition + Claude Design links |

## Running (once scaffolded)
```bash
# Mobile (iOS simulator)
cd apps/mobile && flutter run

# Admin (Chrome)
cd apps/admin && flutter run -d chrome
```
