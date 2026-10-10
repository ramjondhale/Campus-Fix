---
title: CampusFix
description: A privacy-first college complaint & maintenance app. Flutter + Firebase. Documentation hub.
---

**CampusFix** is a college-only complaint and maintenance management app. Students and staff report
campus problems (electrical, plumbing, civil, furniture, cleanliness, IT, safety) with photos. The
system assigns a unique Complaint ID, computes a priority, routes the complaint to the right maintenance
team, tracks the repair through a verified seven-step status flow, and keeps before/after evidence,
**while hiding reporter identity on every normal view**.

It is a Flutter monorepo: a mobile app for reporters, maintenance staff and verifiers, a Flutter Web
console for admins and verifiers, and a Firebase backend (Auth, Firestore, Hosting).

**Quick links:** [Live demo](https://campus-fix-a8e09.web.app) ·
[Source on GitHub](https://github.com/ramjondhale/Campus-Fix) ·
[Walkthrough](WALKTHROUGH.md) · [Architecture](ARCHITECTURE.md)

---

## Try it now

> **Live demo:** <https://campus-fix-a8e09.web.app> is the admin web console, running against a free
> Firebase (Spark plan) project loaded with demo data only. No setup needed.

Sign in with a demo account. The password for every account is `campusfix-demo`.

| Role | ID number | Where it works |
|------|-----------|----------------|
| Admin | `ADM-01` | Web console (full: dashboard, manage, audited identity reveal) |
| Verifier | `VER-01` | Web console (limited) and the mobile app |
| Reporter | `S2024-1001` | Mobile app (the web console shows an access-denied page by design) |
| Maintenance (IT) | `MNT-IT-01` | Mobile app (the web console shows an access-denied page by design) |

The login screen also has a **Demo accounts** quick-fill. Want to run it yourself instead? See
[Windows Setup](WINDOWS-SETUP.md) or [Building & Running](BUILDING.md).

---

## Documentation

### Start here

| Page | What it covers |
|------|----------------|
| [Walkthrough](WALKTHROUGH.md) | **Start here.** A guided tour: what exists, how to run it, who can do what, the lifecycle and the privacy model. |
| [Windows Setup](WINDOWS-SETUP.md) | Beginner-friendly, step-by-step setup for a fresh Windows machine, including the optional Firebase emulator. |
| [Building & Running](BUILDING.md) | Prerequisites, build, run and test commands, and the iOS simulator notes. |

### Product and architecture

| Page | What it covers |
|------|----------------|
| [Architecture](ARCHITECTURE.md) | Guiding principles, monorepo structure, state and routing, role model, privacy architecture, and the Firebase mapping. |
| [Requirements](REQUIREMENTS.md) | The distilled requirements (R1 to R18) with traceability, and the decisions taken with the product owner. |
| [Design system (style guide)](design/design-system.html) | The published, viewable style guide and live component gallery (HTML). |
| [Design system (token contract)](design/design-system.md) | The written contract: tokens, components, accessibility rules and the Flutter mapping. |

### Phase 2: the Firebase backend

| Page | What it covers |
|------|----------------|
| [Phase 2 MVP plan](phase-2-mvp.md) | The simplified, free-tier demo plan: Spark plan, no Cloud Functions, Android plus admin web, and the C0 to C5 chunks. |
| [Phase 2 Firebase plan](phase-2-firebase-plan.md) | The full production design: Auth, the Firestore document split, Security Rules, Storage, FCM and rollout. |

### Specifications

The contracts the code implements.

| Spec | Covers |
|------|--------|
| [Data model](specs/data-model-spec.md) | Entities, enums and views. |
| [Privacy](specs/privacy-spec.md) | Hidden reporter identity; the load-bearing spec of the product. |
| [Status machine](specs/status-machine-spec.md) | The seven statuses, role-gated transitions and preconditions. |
| [Priority engine](specs/priority-engine-spec.md) | The rule-based priority scoring. |
| [Assignment routing](specs/assignment-routing-spec.md) | Category to department routing and manual override. |
| [Screens](specs/screens-spec.md) | Every mobile (M-xx) and admin (A-xx) screen. |

### Build history (archive)

How the project was built, kept for reference. Not needed to use or run the product.

| Page | What it covers |
|------|----------------|
| [Build plan](process/PLAN.md) | The master plan, broken into agent-sized chunks and waves. |
| [Run ledger](process/RUN-LEDGER.md) | The live progress and checkpoint log kept during the build. |
| [Orchestration](process/ORCHESTRATION.md) | The Opus-orchestrator plus Sonnet-agent working model. |

---

## Project status

- **Phase 1: complete.** Design system plus a clickable prototype on in-memory mock data. Both apps
  are feature-complete, with about **1,426 tests** passing (core 651, design 232, mobile 199, admin 344).
- **Phase 2 MVP: in progress.** A Firebase backend on the free Spark plan (Auth, Firestore, Hosting;
  no Cloud Functions), targeting Android and the admin web. The read path is live; the write path is
  landing next. iOS and push notifications are deferred.

## Source

- Repository: <https://github.com/ramjondhale/Campus-Fix>
- These pages are rendered from the Markdown files in the repository's
  [`docs/`](https://github.com/ramjondhale/Campus-Fix/tree/main/docs) folder, so edit them there.
- Backend runbook (emulators, seed script, rules, hosting deploy):
  [`backend/README.md`](https://github.com/ramjondhale/Campus-Fix/blob/main/backend/README.md).
- Working rules for contributors and agents:
  [`CLAUDE.md`](https://github.com/ramjondhale/Campus-Fix/blob/main/CLAUDE.md).
