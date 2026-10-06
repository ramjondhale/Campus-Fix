# CampusFix AI — Master Plan

Phase 1 goal: **a clickable Flutter prototype (mobile + web admin) on mock data, backed by a real
design system and shared domain logic.** Firebase backend is Phase 2 (after approval).

Legend — Owner: **O** = orchestrator (Opus), **A** = Sonnet agent. Chunks are sized so one agent can
finish independently. IDs are stable and referenced by the run ledger.

---

## S0 — Foundation & scaffolding (Owner: O)
| ID | Chunk | Deps | Deliverable / acceptance |
|----|-------|------|--------------------------|
| S0.1 | Repo structure, git, contract docs | — | This repo + docs/ committed. ✅ checkpoint. |
| S0.2 | Flutter monorepo scaffold | S0.1 | `flutter create` for 2 packages + 2 apps; path deps wired; `dart analyze` clean; mobile builds on iOS sim, admin builds on Chrome (empty shells). |
| S0.3 | Detailed specs | S0.1 | `docs/specs/*`: data-model, priority-engine, status-machine, assignment-routing, privacy, screens. (Agent-drafted, O-reviewed.) |

## S1 — Design system & UX in Claude Design (Owner: O drives, A drafts)
| ID | Chunk | Deps | Deliverable / acceptance |
|----|-------|------|--------------------------|
| S1.1 | Design foundations | S0.3 | `docs/design/design-system.md` + Claude Design project: color (incl. semantic tokens for 8 categories, 4 priorities, 7 statuses), typography scale, spacing, radius, elevation, iconography. |
| S1.2 | Core components | S1.1 | Reusable component set designed once: AppButton, TextField, SelectTile, CategoryTile, ComplaintCard, StatusBadge, PriorityTag, PhotoUploader, BeforeAfter, Timeline, MetricCard, FilterBar, EmptyState, AppBar, BottomNav. Each with states/variants. |
| S1.3 | Reporter screens | S1.2 | Login, Home, Report flow (Category→Location→Photo→Description→Review→Confirmation w/ Complaint ID), My Complaints, Complaint Details, Campus Problem Board (anon), Notifications. |
| S1.4 | Maintenance + verifier screens | S1.2 | Assigned Work list, Work Detail (start/progress), After-Repair Upload (photo+note), Verify & Close. |
| S1.5 | Admin web screens | S1.2 | Dashboard (metric cards + simple charts), Complaint List + Filters, Complaint Detail/Manage (assign, priority, status, photos, timeline). |
| S1.6 | Design → code handoff | S1.3–1.5 | `docs/design/handoff.md` mapping each design component/screen to its Flutter widget/route, with token names. |

## S2 — Core package `campusfix_core` (Owner: A — pure Dart, high parallelism)
| ID | Chunk | Deps | Deliverable / acceptance |
|----|-------|------|--------------------------|
| S2.1 | Models & enums | S0.2, S0.3 | Category, Priority, ComplaintStatus, Role, Department enums; Complaint, AppUser, Attachment, StatusEvent, Assignment, ReporterIdentity models (immutable, `copyWith`, (de)serialize). Unit tests. |
| S2.2 | Priority engine | S2.1, S0.3 | `computePriority()` per spec + exhaustive unit tests (each factor + overrides + aging). |
| S2.3 | Status state machine | S2.1, S0.3 | `StatusMachine.canTransition/next()` role-gated + tests covering legal/illegal transitions. |
| S2.4 | Assignment routing | S2.1, S0.3 | `routeToDepartment()` + manual-override model + tests. |
| S2.5 | Privacy projections | S2.1, S0.3 | `PublicComplaintView`, `AdminComplaintView`, `toPublicView/toAdminView` + tests proving no PII in public view. |
| S2.6 | Repos + seed data | S2.1–2.5 | Repository interfaces + in-memory mock impls + realistic seed data (≥24 complaints spanning all categories/priorities/statuses, with before/after samples). |

## S3 — Design system package `campusfix_design` (Owner: A — Flutter code)
| ID | Chunk | Deps | Deliverable / acceptance |
|----|-------|------|--------------------------|
| S3.1 | Theme & tokens | S0.2, S1.1 | `theme/` — ColorScheme, TextTheme, spacing/radii/elevation constants, category/priority/status color maps, light theme (dark optional). `dart analyze` clean. |
| S3.2 | Reusable widgets | S3.1, S1.2 | All S1.2 components as Flutter widgets with a widgetbook/gallery screen for visual QA. |

## S4 — Mobile app `apps/mobile` (Owner: A)
| ID | Chunk | Deps | Deliverable / acceptance |
|----|-------|------|--------------------------|
| S4.1 | App shell + auth | S2.6, S3.2 | go_router + Riverpod wiring; mock ID+password login with role selection; role-aware home/nav. |
| S4.2 | Report-a-Problem flow | S4.1 | Category→Location(building/floor/room)→Photo→Description→Review→Submit→Confirmation (shows generated Complaint ID + computed priority). |
| S4.3 | My Complaints + Details | S4.1 | List of own complaints with status; detail screen with timeline + before/after + privacy-safe display. |
| S4.4 | Problem Board + Notifications | S4.1 | Anonymous board (filter by category/priority/status) + notifications screen (mock events). |
| S4.5 | Maintenance flow | S4.1 | Assigned-work list → work detail → start/progress → upload after-repair photo + resolution note. |
| S4.6 | Verifier flow | S4.1 | Verify resolution (view before/after) → Verified → Closed. |

## S5 — Admin web `apps/admin` (Owner: A)
| ID | Chunk | Deps | Deliverable / acceptance |
|----|-------|------|--------------------------|
| S5.1 | Admin shell + auth + layout | S2.6, S3.2 | Responsive web layout, side nav, mock admin login. |
| S5.2 | Dashboard | S5.1 | Metric cards (total/pending/critical+high/assigned/in-progress/resolved/closed) + simple charts; from mock repo. |
| S5.3 | Complaint list + filters | S5.1 | Sortable/filterable/searchable table of complaints (admin view). |
| S5.4 | Complaint management | S5.3 | Detail: assign team, change priority, change status (role-gated), view before/after + timeline. |

## S6 — Integration, verification & polish (Owner: O)
| ID | Chunk | Deps | Deliverable / acceptance |
|----|-------|------|--------------------------|
| S6.1 | Integrate + build + smoke | all S2–S5 | Merge all branches; mobile builds/runs on iOS sim, admin on Chrome; end-to-end flow walked; screenshots captured. |
| S6.2 | Prototype walkthrough + cleanup | S6.1 | `docs/WALKTHROUGH.md`; remove stale tracking artifacts; tidy ledger. |
| S6.3 | Phase-2 Firebase plan | S6.1 | `docs/PHASE2-FIREBASE.md` — the backend build plan to execute after approval. |

---

## Execution waves (respecting ≤4 parallel agents, no simultaneous builds)
> Agents write code + unit tests and run only static checks; the **orchestrator builds after each merge.**

- **Wave 0 (O):** S0.1 ✅ → S0.2 scaffold (O builds baseline).
- **Wave 1 (≤2 A):** S0.3 specs (A) ‖ S2.1 models+enums (A). *(S2.1 is the spine — unblocks S2.2–2.6.)*
  - O reviews specs, merges & verifies models.
- **Wave 2 (≤4 A):** S2.2 priority ‖ S2.3 status ‖ S2.4 assignment ‖ S2.5 privacy (all depend only on S2.1 + specs; disjoint files). O merges + runs `dart test` after each.
- **Wave 3 (≤2):** S2.6 repos+seed (A) ‖ S1.1 design foundations (O-driven in Claude Design, A may draft tokens doc).
- **Wave 4 (≤2):** S3.1 theme/tokens (A) ‖ S1.2 components design. O builds design package.
- **Wave 5 (≤2):** S3.2 widgets (A) ‖ S1.3–1.5 screen designs (A drafts, O curates in Claude Design).
- **Wave 6 (≤4):** S4.1 shell → then S4.2 ‖ S4.3 ‖ S4.4 (disjoint feature dirs). O builds mobile between merges.
- **Wave 7 (≤2):** S4.5 maintenance ‖ S4.6 verifier. O builds mobile.
- **Wave 8 (≤4):** S5.1 shell → S5.2 ‖ S5.3 → S5.4. O builds admin web.
- **Wave 9 (O):** S6.1 integrate + smoke + screenshots → S6.2 cleanup → S6.3 Phase-2 plan → **pause for approval.**

Dependencies are the real gate; waves are the default cadence. The orchestrator may reshuffle as long
as deps hold and the ≤4 / no-simultaneous-build rules are respected.
