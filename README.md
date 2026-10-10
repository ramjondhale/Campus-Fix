<div align="center">

# CampusFix

**A privacy-first complaint and maintenance management app for colleges.**<br>
Report it. Route it. Fix it. Verify it. Without ever exposing who reported it.

[![Flutter](https://img.shields.io/badge/Flutter-3.41-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%C2%B7%20Firestore%20%C2%B7%20Hosting-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Material 3](https://img.shields.io/badge/Material-3-6750A4?logo=materialdesign&logoColor=white)](https://m3.material.io)
[![Tests](https://img.shields.io/badge/tests-1%2C500%20passing-brightgreen)](#tests)
[![Demo](https://img.shields.io/badge/demo-live-0F766E)](https://campus-fix-a8e09.web.app)

[**Live demo**](https://campus-fix-a8e09.web.app) ·
[Documentation](https://ramjondhale.github.io/Campus-Fix/) ·
[Walkthrough](https://ramjondhale.github.io/Campus-Fix/WALKTHROUGH.html) ·
[Architecture](https://ramjondhale.github.io/Campus-Fix/ARCHITECTURE.html) ·
[Quick start](#quick-start)

</div>

---

## What is CampusFix?

Students and staff report campus problems (electrical, plumbing, civil, furniture, cleanliness, IT,
safety) with photos. CampusFix assigns a unique Complaint ID (`CF-YYYY-NNNNN`), **computes a priority**,
**routes the complaint to the right maintenance team**, tracks the repair through a **verified
seven-step status flow**, and keeps **before/after evidence**, all while **hiding the reporter's
identity on every normal view**. Only an admin can see it, and only behind an explicit, audited reveal.

It is a single-college, Flutter monorepo: a **mobile app** for reporters, maintenance staff and
verifiers, a **Flutter Web console** for admins and verifiers, and a **Firebase backend**.

## Live demo

> ### [campus-fix-a8e09.web.app](https://campus-fix-a8e09.web.app)
> The admin web console, running on a free Firebase (Spark) project with **demo data only**.
> No installation needed. Sign in with a demo account below.

All demo accounts use the password **`campusfix-demo`**.

| Role | ID number | Works on |
|------|-----------|----------|
| Admin | `ADM-01` | Web console (full access: dashboard, manage, audited identity reveal) |
| Verifier | `VER-01` | Web console (limited) and the mobile app |
| Reporter | `S2024-1001` | Mobile app (the web console shows an access-denied page by design) |
| Maintenance (IT) | `MNT-IT-01` | Mobile app (the web console shows an access-denied page by design) |

The login screen also has a **Demo accounts** quick-fill. The reporter and maintenance accounts are
meant for the mobile app, which you can run yourself (see [Quick start](#quick-start)).

## Features

### By role

| Role | App | What they do |
|------|-----|--------------|
| **Reporter** (student or staff) | Mobile | Guided report flow (category, location, 1 to 5 photos, severity and safety flag, review with possible-duplicate hints). Gets a Complaint ID and the computed priority. Tracks their own complaints on a status stepper with before/after photos. Browses the anonymous **Campus Board** with filters, search and sorting. Receives in-app notifications. |
| **Maintenance staff** | Mobile | A work queue scoped to their own department (To start, In progress, Rework), most urgent first. Starts work (which claims the job), then submits **after-repair photos and a resolution note**. |
| **Verifier** | Mobile and Web | A verification queue with before/after evidence. **Verifies** a repair, or **rejects** it with a required reason, which sends it back to maintenance as rework. |
| **Admin** | Web | A dashboard (eight metric cards, four charts, triage lists), a filterable and sortable complaint list whose state lives in the URL, and a manage screen with every status action, assignment and priority override. The **only** role that can close a complaint or reveal a reporter's identity. |

### Cross-cutting

- **Privacy by construction.** UI code only ever receives a `PublicComplaintView`, a type that has no
  field for reporter identity. Identity lives in a separate `AdminComplaintView`, is admin-only, and is
  shown only after an explicit reveal, which the Firebase backend audits with a required reason.
  Architecture-guard tests scan the apps' source to keep it that way. In Firestore the same idea is
  enforced by Security Rules (see [Privacy model](#privacy-model)).
- **Design system as law.** `campusfix_design` is the single source of UI truth: tokens, light and dark
  themes (Material 3 `ThemeExtension`s) and about 29 reusable widgets. App code may not use raw colors,
  ad-hoc text styles or hard-coded sizes, and tests enforce it.
- **Priority engine.** A pure, rule-based scorer (safety flag, category weight, severity, people
  affected, location, waiting time with aging) produces Critical, High, Medium or Low. An admin override
  always wins. Pluggable, so ML can replace the scorer later.
- **Status machine.** `Reported, Reviewed, Assigned, In Progress, Resolved, Verified, Closed`: seven
  states, role-gated transitions, explicit preconditions (for example, evidence is required before
  Resolved), and an append-only timeline. Rework is a marker, not an eighth state.
- **Assignment routing.** Category to department (Electrician, Plumber, Carpenter, Civil Maintenance,
  IT Team, Housekeeping), with manual triage for Safety and Other.

## Tech stack

| Layer | Technology |
|-------|------------|
| Apps | Flutter 3.41.x, Dart 3.11.x (mobile: Android and iOS; admin: Flutter Web) |
| State and routing | Riverpod, go_router (URL-addressable on web, deep links on mobile) |
| UI | Material 3 with `ThemeExtension`s; Archivo, Public Sans and JetBrains Mono |
| Backend (Phase 2 MVP) | Firebase Auth, Cloud Firestore, Firebase Hosting on the free **Spark** plan (no Cloud Functions) |
| Privacy enforcement | Firestore Security Rules over a 3-way document split |
| Tooling | Firebase Emulator Suite, an Admin-SDK (Node) seed script |

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│ apps/mobile   reporter · maintenance · verifier                     │
│ apps/admin    Flutter Web: admin + verifier console                 │
│ ── Riverpod providers: the privacy boundary (public views only) ──  │
├─────────────────────────────────┬───────────────────────────────────┤
│ campusfix_design                │ campusfix_firebase                │
│ tokens · themes · ~29 widgets   │ Firebase repository impls         │
├─────────────────────────────────┴───────────────────────────────────┤
│ campusfix_core  (pure Dart: no Flutter, no Firebase)                │
│ models · 11 enums · priority engine · status machine ·              │
│ assignment routing · privacy projections · services ·               │
│ repository INTERFACES · in-memory mocks + seed data                 │
└─────────────────────────────────────────────────────────────────────┘
  Each layer depends only on the layers below it.
```

**The repository seam.** All data access goes through four small interfaces defined in
`campusfix_core` (auth, users, complaints, notifications). The apps obtain them only through Riverpod
providers:

- `lib/main.dart` binds **in-memory mock repositories** seeded with 29 complaints and 25 users. This is
  the offline, zero-setup mode and the one the tests use.
- `lib/main_firebase.dart` **overrides those four providers** with the implementations in
  `campusfix_firebase`. No widget, route or business rule changes.

That seam is also the upgrade path: moving from the free MVP to a server-authoritative production
backend swaps implementations, not the UI. The full write-up is in the
[Architecture doc](https://ramjondhale.github.io/Campus-Fix/ARCHITECTURE.html).

### Privacy model

Firestore rules are per document, not per field, so each complaint is **split into three documents**:

| Document | Contains | Who can read it |
|----------|----------|-----------------|
| `complaints/{id}` | The 17-field public projection | Signed-in users (the board, lists, maintenance, verifier) |
| `complaints/{id}/private/admin` | Priority inputs, full assignment, actor-bearing timeline | Admin |
| `complaints/{id}/private/identity` | The reporter's identity | Admin only, reveal is audited with a required reason |

> **Honest MVP tradeoff.** The free-tier MVP has no server, so complaint **writes run client-side**,
> reusing the tested `campusfix_core` logic, with Security Rules enforcing the status-transition matrix
> and admin-only close. Reads and identity privacy are rules-enforced from day one, but the MVP trusts
> the client for write integrity. Production adds a server executor behind the same seams. Do not point
> real college data at the MVP configuration. Details: the
> [Phase 2 MVP plan](https://ramjondhale.github.io/Campus-Fix/phase-2-mvp.html).

## Repository layout

```
campusfix/
├── apps/
│   ├── mobile/                 # Flutter app: reporter / maintenance / verifier
│   │   └── lib/main.dart            mock mode  ·  lib/main_firebase.dart  Firebase mode
│   └── admin/                  # Flutter Web: admin + verifier console (same two entrypoints)
├── packages/
│   ├── campusfix_core/         # pure Dart: models, 11 enums, logic, repo interfaces, mocks, services
│   ├── campusfix_design/       # design system: tokens, themes, ~29 widgets, gallery
│   └── campusfix_firebase/     # Firebase implementations of the repository interfaces
├── backend/                    # firebase.json, Security Rules, Firestore indexes, Admin-SDK seed script
├── docs/                       # all documentation (also published on GitHub Pages)
├── CLAUDE.md                   # working rules and notes for contributors and agents
└── README.md
```

## Quick start

**Prerequisites:** Flutter 3.41.x (stable) with Dart 3.11.x, and Chrome for the admin web console. For
the mobile app, an Android emulator or device (or an iOS simulator on a Mac).

- **On Windows?** Follow the beginner-friendly
  [Windows Setup guide](https://ramjondhale.github.io/Campus-Fix/WINDOWS-SETUP.html). iOS cannot run
  on Windows; use Chrome and the Android emulator.
- **On macOS or Linux?** See [Building & Running](https://ramjondhale.github.io/Campus-Fix/BUILDING.html)
  (it also covers the iOS simulator notes).

**1. Get the code and fetch dependencies.** The repo has no workspace tool, so run `pub get` once in
each package and app.

```bash
git clone https://github.com/ramjondhale/Campus-Fix.git campusfix
cd campusfix

(cd packages/campusfix_core     && dart pub get)
(cd packages/campusfix_design   && flutter pub get)
(cd packages/campusfix_firebase && flutter pub get)
(cd apps/mobile                 && flutter pub get)
(cd apps/admin                  && flutter pub get)
```

**2. Run in mock mode** (the simplest way to see it work: in-memory data, no backend, no accounts).

```bash
# Admin web console, in Chrome
cd apps/admin && flutter run -d chrome

# Mobile app (a connected Android emulator or device; an iOS simulator on a Mac)
cd apps/mobile && flutter run
```

Sign in with the [demo accounts](#live-demo). In mock mode the mobile app and the console are separate
processes with separate in-memory stores, and data resets on every start.

**3. Run against Firebase** (local emulators or the dev project) with the Firebase entrypoint, for
example `flutter run -d chrome -t lib/main_firebase.dart --dart-define=CF_USE_EMULATOR=true`. The
emulator setup, seed script, rules and Hosting deploy are all in the
[backend runbook (`backend/README.md`)](backend/README.md).

### Tests

```bash
cd packages/campusfix_core && dart test        # 651
cd packages/campusfix_design && flutter test   # 232
cd apps/mobile && flutter test                 # 199
cd apps/admin && flutter test                  # 344
```

That is **1,426 tests**. After any change under `apps/`, run **both** the app suite and the core suite:
core's privacy architecture guard statically scans the apps' source.

## Documentation

Full documentation is published at **<https://ramjondhale.github.io/Campus-Fix/>**. The sources live in
[`docs/`](docs/).

| Doc | What it covers |
|-----|----------------|
| [Walkthrough](https://ramjondhale.github.io/Campus-Fix/WALKTHROUGH.html) | **Start here.** Guided tour: what exists, how to run it, who does what, the lifecycle and the privacy model. |
| [Architecture](https://ramjondhale.github.io/Campus-Fix/ARCHITECTURE.html) | Principles, monorepo structure, state and routing, roles, privacy and the Firebase mapping. |
| [Requirements](https://ramjondhale.github.io/Campus-Fix/REQUIREMENTS.html) | The distilled requirements (R1 to R18) with traceability. |
| [Building & Running](https://ramjondhale.github.io/Campus-Fix/BUILDING.html) | Prerequisites, build, run and test commands, iOS notes. |
| [Windows Setup](https://ramjondhale.github.io/Campus-Fix/WINDOWS-SETUP.html) | Beginner-friendly setup for a fresh Windows machine, including the Firebase emulator. |
| [Phase 2 Firebase plan](https://ramjondhale.github.io/Campus-Fix/phase-2-firebase-plan.html) | The full production backend design: Auth, Firestore split, Security Rules, Storage, FCM. |
| [Phase 2 MVP plan](https://ramjondhale.github.io/Campus-Fix/phase-2-mvp.html) | The simplified free-tier demo plan and its C0 to C5 milestones. |
| [Design system](https://ramjondhale.github.io/Campus-Fix/design/design-system.html) | The published style guide ([token contract](https://ramjondhale.github.io/Campus-Fix/design/design-contract.html)). |
| Specs | [Data model](https://ramjondhale.github.io/Campus-Fix/specs/data-model-spec.html) · [Privacy](https://ramjondhale.github.io/Campus-Fix/specs/privacy-spec.html) · [Status machine](https://ramjondhale.github.io/Campus-Fix/specs/status-machine-spec.html) · [Priority engine](https://ramjondhale.github.io/Campus-Fix/specs/priority-engine-spec.html) · [Assignment routing](https://ramjondhale.github.io/Campus-Fix/specs/assignment-routing-spec.html) · [Screens](https://ramjondhale.github.io/Campus-Fix/specs/screens-spec.html) |
| Build history | [Plan](https://ramjondhale.github.io/Campus-Fix/process/PLAN.html) · [Run ledger](https://ramjondhale.github.io/Campus-Fix/process/RUN-LEDGER.html) · [Orchestration](https://ramjondhale.github.io/Campus-Fix/process/ORCHESTRATION.html) |

## Project status

| Phase | State |
|-------|-------|
| **Phase 1**: design system plus clickable prototype on mock data | **Complete.** Both apps are feature-complete with 1,426 tests passing. |
| **Phase 2 MVP**: Firebase backend (Auth, Firestore, Hosting), free Spark plan, Android plus admin web | **In progress.** The read path is live and the admin console is deployed; the write path is landing. |

## Roadmap

Phase 2 MVP milestones (see the [MVP plan](https://ramjondhale.github.io/Campus-Fix/phase-2-mvp.html)):

- [x] **C0** Scaffolding: `backend/`, `campusfix_firebase`, the Firebase entrypoints, the seed pipeline
- [x] **C1** Auth and users: ID-number alias sign-in, roles via custom claims
- [x] **C2** Read path: the public / admin / identity document split, rules-enforced
- [x] **C3** Write path: complaint writes through the Firebase repositories, with rules enforcing
      transitions and admin-only close, plus the audited identity reveal
- [x] **C4** In-app notifications on Firestore (feed and unread badge)
- [ ] **C5** Hosting and demo polish: the admin web is live; the Android build and end-to-end verification remain

After the MVP:

- [ ] **Mobile on Firebase** (Android first)
- [ ] **Production environment**: Cloud Functions or Cloud Run as a trusted write executor, server-set
      claims, tamper-proof identity-reveal audit
- [ ] **Push notifications** (FCM) and **iOS** (both deferred until they are needed)

## Working on the codebase

Three hard rules keep the project coherent (the full list is in [`CLAUDE.md`](CLAUDE.md)):

1. **Design system is law**: style only through `campusfix_design`; no raw colors, hex values or ad-hoc
   text styles in app code.
2. **Privacy by construction**: widgets consume public views only, never raw complaints or reporter
   identity.
3. **Verify both suites** after any app change: the app's tests and `campusfix_core`'s.

## License

**To be decided.** No `LICENSE` file has been added yet, so by default all rights are reserved by the
author. A license will be chosen and added before any outside contributions are accepted.

## Built with

This project is built with an **Opus-orchestrator plus Sonnet-agent workflow**: Claude Opus plans,
decides and verifies, while Claude Sonnet agents implement each chunk in its own git worktree. The
process is recorded in the [build history](https://ramjondhale.github.io/Campus-Fix/process/RUN-LEDGER.html).
