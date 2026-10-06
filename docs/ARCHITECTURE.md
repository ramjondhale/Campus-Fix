# CampusFix AI — Architecture

## 1. Guiding principles
1. **Privacy by construction** — reporter identity is structurally separated from the "public" view
   of a complaint. UI layers for board/lists/maintenance consume a `PublicComplaintView` that *cannot*
   carry PII. Identity lives behind a role-gated `AdminComplaintView`. (See `specs/privacy-spec.md`.)
2. **Reuse over duplication** — one design system, one widget library, one domain model shared by the
   mobile app and the admin web app. No screen reimplements a token, color, or model.
3. **Pure logic is isolated & tested** — priority, status transitions, assignment routing, and privacy
   projections are pure Dart functions in `campusfix_core`, each with unit tests. No UI or Firebase
   dependency, so they're trivially parallelizable across agents and verifiable without a build.
4. **Mock now, Firebase later** — all data access goes through repository *interfaces*. The prototype
   binds in-memory mock repos; Phase 2 swaps in Firebase implementations with no UI change.

## 2. Monorepo structure
```
campusfix/
├── packages/
│   ├── campusfix_core/        # Pure Dart: models, enums, logic, repo interfaces, mocks, seed data
│   │   └── lib/
│   │       ├── models/        # Complaint, AppUser, Attachment, StatusEvent, Assignment
│   │       ├── enums/         # Category, Priority, ComplaintStatus, Role, Department
│   │       ├── logic/         # priority_engine, status_machine, assignment_router, privacy
│   │       ├── repositories/  # abstract interfaces (ComplaintRepository, AuthRepository, ...)
│   │       └── mock/          # in-memory repos + seed_data
│   └── campusfix_design/      # Flutter: theme, tokens, reusable widgets (depends on core for enums)
│       └── lib/
│           ├── theme/         # colors, typography, spacing, radii, elevation, ThemeData
│           └── widgets/       # buttons, inputs, cards, chips, status_badge, priority_tag, etc.
└── apps/
    ├── mobile/                # Flutter app — reporter + maintenance + verifier
    └── admin/                 # Flutter Web — management dashboard
```
**Dependency direction (acyclic):** `core` ← `design` ← `apps`. `core` depends on nothing Flutter.
Packages are wired with path dependencies (no melos needed at this size).

## 3. State management & routing
- **Riverpod** (`flutter_riverpod`) for providers/state. Repos exposed as providers so swapping mock→
  Firebase is a one-line override. Chosen for testability and compile-safe DI.
- **go_router** for declarative, URL-addressable routing — works for mobile deep links *and* the web
  admin's browser URLs with one mental model.

## 4. Role model
| Role | App | Can see reporter identity? | Key actions |
|------|-----|---------------------------|-------------|
| Reporter (student/staff) | mobile | own complaints only | submit, track own, view board (anon) |
| Maintenance staff | mobile | **no** | see assigned (anon), start/progress, upload after-repair photo+note |
| Verifier / Management | mobile + admin | **no** on board; audit-gated in admin | verify resolution, close |
| Admin | admin web | **yes** (audit-gated) | assign, change priority/status, view all, dashboard |

## 5. Privacy architecture (R5/R6) — the load-bearing constraint
- `Complaint` (core) holds `reporterId` + `ReporterIdentity` (PII).
- `Complaint.toPublicView()` → `PublicComplaintView` with **no PII** (only Complaint ID, category,
  location, photos, description, priority, timestamps, status). This is the *only* type the board,
  lists, and maintenance screens accept.
- `Complaint.toAdminView(requester)` → `AdminComplaintView`; returns identity **only** if
  `requester.role == admin` (and in Phase 2, writes an audit entry). Enforced in `logic/privacy.dart`
  with unit tests proving PII never leaks into a public view.

## 6. Priority engine (R7) — rule-based, pluggable
Pure function `computePriority(ComplaintSignals) → Priority`. Weighted factors: safety flag (hard
override to Critical/High), category base weight, reporter-rated severity, people affected, location
sensitivity, waiting time (aging escalation). Fully specified in `specs/priority-engine-spec.md`.
AI/ML (R15) can later replace the scorer behind the same interface.

## 7. Status flow (R9) — explicit state machine
`Reported → Reviewed → Assigned → In Progress → Resolved → Verified → Closed`. Allowed transitions are
role-gated (e.g., only maintenance moves `Assigned→In Progress`; only verifier `Resolved→Verified`).
A pure `StatusMachine.canTransition(from, to, role)` with tests. Each transition appends a
`StatusEvent` to the complaint timeline (who/when/note — "who" stored but privacy-filtered on display).

## 8. Assignment routing (R8)
`routeToDepartment(Category) → Department` pure map, with manual override supported in admin. Spec in
`specs/assignment-routing-spec.md`.

## 9. Firebase mapping (Phase 2 — not built yet)
| Concern | Firebase |
|---|---|
| Auth (ID+password) | Firebase Auth (custom claims for role) |
| Complaints / status / assignments | Firestore collections (`complaints`, `statusEvents`, `users`) |
| Photos (before/after) | Cloud Storage; store download URLs on the complaint |
| Notifications (R11) | Cloud Messaging (FCM) + Firestore triggers (Cloud Functions) |
| Privacy | Firestore Security Rules enforce that non-admin reads exclude identity fields; identity in a separate restricted subcollection/doc |
Repository interfaces in `core` are designed so these are drop-in. A dedicated Phase-2 plan doc will
be produced at the end of the prototype.

## 10. Reversible defaults (say the word to change)
- Flutter Web admin (vs a separate React admin).
- Riverpod (vs Bloc/Provider).
- In-memory mock data (vs a local JSON/SQLite mock) for the prototype.
