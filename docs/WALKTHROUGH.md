# CampusFix AI — Walkthrough

A guided tour of the working prototype: what exists, how to run it, who can do what, and why it is
built the way it is. Written for a new developer or a stakeholder. Everything here reflects the code as
built (state recorded in [RUN-LEDGER.md](process/RUN-LEDGER.md)); the specs under [specs/](specs/) are the
contracts the code implements.

**Contents**
1. [What CampusFix is](#1-what-campusfix-is)
2. [What is in the repository](#2-what-is-in-the-repository)
3. [Run it](#3-run-it)
4. [Demo accounts](#4-demo-accounts)
5. [Role-by-role flows](#5-role-by-role-flows) (reporter, maintenance, verifier, admin and verifier on the web)
6. [The complaint lifecycle](#6-the-complaint-lifecycle)
7. [The privacy model](#7-the-privacy-model)
8. [The design system](#8-the-design-system)
9. [Known limitations](#9-known-limitations)
10. [Where to go next](#10-where-to-go-next)

---

## 1. What CampusFix is

CampusFix AI is a college-only complaint and maintenance app. Students and staff report campus problems
(electrical, plumbing, civil, furniture, cleanliness, IT, safety, other) with photos. The system assigns a
unique Complaint ID (`CF-YYYY-NNNNN`), computes a priority, routes the complaint to the right maintenance
department, tracks the repair through a verified seven-step status flow, and keeps before and after
evidence. **Reporter identity is hidden on every normal view**; only an admin can see it, and only
behind an explicit reveal in the complaint detail screen. See [REQUIREMENTS.md](REQUIREMENTS.md) for the
requirement list (R1 to R18).

> **This is a prototype over in-memory mocks.** There is no backend: both apps run on mock repositories
> seeded with 29 complaints and 25 users. Firebase (Auth, Firestore, Storage, FCM) is Phase 2; the plan is
> in [phase-2-firebase-plan.md](phase-2-firebase-plan.md).

## 2. What is in the repository

| Part | Path | What it is | Tests (per [RUN-LEDGER.md](process/RUN-LEDGER.md)) |
|---|---|---|---|
| Mobile app | [`apps/mobile`](../apps/mobile) | Flutter app for **reporters, maintenance staff and verifiers** (all three role flows are complete). | 199 |
| Admin web console | [`apps/admin`](../apps/admin) | Flutter **Web** console for **admins and verifiers**: login, dashboard, complaint list, complaint detail and manage. | 344 |
| Core | [`packages/campusfix_core`](../packages/campusfix_core) | Pure Dart (no Flutter): models, 11 enums, the priority engine, status machine, assignment router, privacy projections, repository interfaces, in-memory mock repositories, seed data, `ComplaintService` and `NotificationService`. | 651 |
| Design system | [`packages/campusfix_design`](../packages/campusfix_design) | Theme (tokens, `AppTheme.light/dark`, `ThemeExtension`s), about 29 reusable widgets and a widget gallery. PII-free. | 224 |

Dependency direction is acyclic: `campusfix_core` <- `campusfix_design` <- the two apps. Both apps use
Riverpod for state and go_router for routing. Details: [ARCHITECTURE.md](ARCHITECTURE.md).

The enums are `ProblemCategory` (8 values), `Priority` (4), `ComplaintStatus` (7), `UserRole` (4),
`Department` (6), `Severity`, `PeopleAffected`, `AttachmentKind` and `NotificationType`.

## 3. Run it

Prerequisites and the iOS notes live in [BUILDING.md](BUILDING.md) (Flutter 3.41.x stable, Dart 3.11.x).
Both apps resolve the two packages through path dependencies, so there is nothing to publish or link.

**The admin web console is the fully runnable target.** It builds and runs in Chrome:

```bash
cd apps/admin
flutter run -d chrome        # live run
flutter build web            # production build (works)
```

**The mobile app:**

```bash
cd apps/mobile
flutter run                  # choose a connected iOS simulator or Android emulator/device
```

The **iOS simulator build is currently blocked** (`flutter build ios --simulator` fails with
`App.framework: No such file`); see [BUILDING.md](BUILDING.md) for what was tried and the suggested
next step (build `ios/Runner.xcworkspace` in Xcode directly). Android has not been verified in this
environment, and `apps/mobile` has no `web/` platform folder, so it cannot be run in Chrome. The mobile
app's logic and screens are nevertheless fully covered by widget tests. If you run iOS builds, export a
UTF-8 locale first: `export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8`.

**The design-system gallery** (every widget and token, light and dark):

```bash
cd packages/campusfix_design/example
flutter run -d chrome
```

**Tests:**

```bash
cd packages/campusfix_core   && dart test        # 651
cd packages/campusfix_design && flutter test     # 224
cd apps/mobile               && flutter test     # 199
cd apps/admin                && flutter test     # 344
```

After **any mobile change run both** the mobile suite and the core suite: core's privacy architecture
guard (PR-T14) statically scans `apps/mobile/lib` and `apps/admin/lib`, so an app edit can break a core
test.

Things to know when running:

- **Data is in memory and resets on every start.** Each app builds its own seed
  (`SeedData.build(now: DateTime.now())`), so timestamps look fresh. The mobile app and the admin console
  are separate processes with **separate stores**: a complaint filed on mobile does not appear in the
  console. Cross-app flow needs the Phase 2 backend.
- Repositories simulate **400 ms of latency** so loading states are visible.
- Fonts (Archivo, Public Sans, JetBrains Mono) are fetched at runtime through `google_fonts`, so the
  first load needs network access.
- The login screens show a "Demo accounts" quick-fill. It is on by default and can be switched off with
  `--dart-define=SHOW_DEMO_ACCOUNTS=false`.

## 4. Demo accounts

All 25 seeded accounts share one password, **`campusfix-demo`** (`seedDemoPassword` in
[`seed_data.dart`](../packages/campusfix_core/lib/mock/seed_data.dart)). Sign-in is by **ID number**
(trimmed, case-insensitive) plus password; a wrong ID and a wrong password give the same message.

The login screens list "Demo accounts" as one button per role. Tapping a button fills the ID number and
password fields; then press **Sign in**.

| Role (button label) | ID number | Person | Mobile login | Admin web login |
|---|---|---|---|---|
| Reporter | `S2024-1001` | Aditi Sharma | Works | Signs in, then **E-403** with Sign out |
| Maintenance | `MNT-ELE-01` | Suresh Patil (Electrician) | Works | Signs in, then **E-403** with Sign out |
| Verifier | `VER-01` | Kiran Joshi | Works | Works (limited console) |
| Admin | `ADM-01` | Sandeep Kapoor | Shows "Admins use the web console"; no session starts | Works (full console) |

- The **mobile** login lists all four buttons; the **admin** login lists only Verifier and Admin.
- Other accounts you can type in: reporters `S2024-1002`, `S2023-0871`, `F2019-0127` and so on; a second
  verifier `VER-02`; maintenance staff `MNT-<ELE|PLU|CAR|CIV|IT|HK>-01` and `-02` (two per department).
- **Maintenance demo tip.** On the stock seed the quick-fill electrician (`MNT-ELE-01`) has an empty work
  queue (see [limitations](#9-known-limitations)). To see a populated queue, sign in manually as
  `MNT-HK-01` (Housekeeping: 1 to start, 1 in progress) or `MNT-IT-01` (IT Team: 1 to start, 1 rework
  with a verifier's note).

**What the seed contains** (29 complaints, 25 users, 226 notifications):

| Status | Complaints |
|---|---|
| Reported | 4 (`CF-2026-00025`, `00027`, `00028`, `00029`) |
| Reviewed (waiting for manual triage) | 3 (`00023`, `00024`, `00026`; Safety and Other) |
| Assigned | 4 |
| In Progress | 6 |
| Resolved | 4 (`00012`, `00015`, `00016`, `00018`) |
| Verified | 3 |
| Closed | 5 |

Users: 10 reporters, 12 maintenance staff, 2 verifiers, 1 admin. The demo reporter `S2024-1001` owns five
complaints across statuses (`CF-2026-00003` closed, `00012` resolved, `00014` assigned, `00020` in
progress, `00025` reported), so "My Complaints" is populated on first sign-in.

## 5. Role-by-role flows

Screen IDs (M-xx mobile, A-xx admin) are the ones in [specs/screens-spec.md](specs/screens-spec.md).

### 5.1 Reporter (mobile)

Sign in as `S2024-1001`. The bottom navigation is **Home, My Complaints, Board, Alerts**; reporting is
the Home call to action, not a tab.

**Report a Problem** (M-03 to M-08, [`features/report/`](../apps/mobile/lib/features/report)):

1. **Home** (M-02): tap **Report a Problem**. Home also shows "My active complaints" (up to three) and
   "Campus board highlights" (up to three open Critical/High complaints).
2. **Category** (M-03): pick one of the eight categories ("What kind of problem is it?").
3. **Location** (M-04): choose a building (campus list or "Other..."), a floor, and a room or location
   (suggestions are offered). The screen notes that location is visible to everyone on the campus board.
4. **Photos** (M-05): add 1 to 5 photos. The prototype has no camera or gallery: both options pick a
   bundled **sample** photo (labelled "(sample)"). Captions are public.
5. **Details** (M-06): a description (10 to 1000 characters; the helper text warns against names and
   contact details), **severity** (Minor, Moderate, Severe; default Moderate), **people affected** (Just
   me, A few people, A class/lab/floor, Whole campus; default Just me) and a **safety hazard** switch
   (locked on for the Safety category).
6. **Review** (M-07): a read-only summary with an **Edit** link per section (the draft is preserved),
   the notice that your name and contact details are never shown on the board or to maintenance staff,
   and up to three non-blocking **Possible duplicates** from the board. **Submit** files the report;
   **Cancel report** asks before discarding.
7. **Confirmation** (M-08): shows "Thanks, your report is in", the new **Complaint ID** (copyable), the
   Reported badge and the **computed priority**, plus the stages the complaint will move through. Actions:
   View complaint, Report another, Home.

**Track and browse:**

8. **My Complaints** (M-09): your own complaints, newest update first, with All / Active / Closed
   segments and search by ID or description.
9. **Complaint Details** (M-10): the tracking page: a status stepper (with a rework marker), location,
   description, before photos and, once repaired, after photos with a before/after comparison, the
   resolution note, the assigned **department** (never a person) and a timeline of role, time and note.
   Closed complaints show a read-only banner. A complaint that exists but is not yours opens as a board
   item instead; an unknown ID shows E-404 without saying whether it exists.
10. **Campus Board** (M-11, M-11b): every complaint on campus with **no reporter identity**. Filter by
    category, priority, status and building; toggle **Include closed**; search; sort by Priority (default),
    Newest, Oldest or Recently updated. A board item shows only the public board fields.
11. **Notifications** (M-12, tab label "Alerts"): your in-app feed grouped Today / Earlier with unread
    markers and an unread badge on the tab. Tapping an item marks it read and opens the complaint.
    **Mark all as read** is available. Messages are generated from fixed templates and are PII-free.

### 5.2 Maintenance (mobile)

Sign in as `MNT-HK-01` or `MNT-IT-01` to see work (see the [demo tip](#4-demo-accounts)). The bottom
navigation is **Work, Board, Notifications**.

1. **Home** (M-02): "My work" for your department with counts for **To start**, **In progress** and
   **Rework needed**, and buttons to open your work or the campus board.
2. **Assigned Work** (M-13): three tabs, scoped to your own department and sorted most urgent first, then
   longest waiting:
   - **To start**: `assigned` to your department and not claimed by a colleague;
   - **In progress**: `inProgress` and claimed by you;
   - **Rework**: your jobs a verifier sent back (the latest event is a rejection).
3. **Work Detail** (M-14): the complaint as a public view (photos, description, timeline; no reporter).
   A rework job shows the verifier's note in a banner. **Start work** (optional note) performs T3 and
   **claims** the job for you; a colleague then sees "Already claimed by a colleague." Once it is yours and
   in progress, **Mark as resolved** appears.
4. **After-Repair** (M-15): the before photos for reference, then add 1 to 5 **after-repair photos** (sample
   picker) and a **resolution note** (required, up to 500 characters). **Mark resolved** asks for
   confirmation, performs T4 and shows "Sent for verification". After a rejection, fresh photos are
   required (rule P1: evidence must postdate the rejection).

### 5.3 Verifier (mobile)

Sign in as `VER-01`. The bottom navigation is **Verify, Board, Notifications**.

1. **Home** (M-02): an "Awaiting verification" count and a button to open the queue.
2. **Verification Queue** (M-16): complaints that maintenance marked **resolved** (all departments), most
   urgent first, then longest since resolved. Cards show the ID, category, location, priority and
   before/after thumbnails. The stock seed has four.
3. **Verify repair** (M-17): the complaint with its before/after evidence and resolution note, and a
   **Note** field (optional to verify, required to reject).
   - **Verify** confirms the repair (T5) and the complaint rests in `verified`; the dialog states that an
     admin closes it.
   - **Reject** (destructive style) requires a reason, performs T7 and sends the job back to maintenance
     as Rework.
   - **There is no close on mobile.** Closing (T6) is an admin action on the web console.

### 5.4 Admin and verifier (web)

Run the console (`cd apps/admin && flutter run -d chrome`) and sign in as `ADM-01` (full) or `VER-01`
(limited). The shell is desktop-first: side navigation at 1024 px and wider, an icon rail from 600 px, a
drawer below that. The top bar shows the page title, your name, a role pill and **Sign out**.

1. **Login** (A-01): ID number and password, with Demo accounts for Verifier and Admin. A deep link you
   opened while signed out is remembered and restored after sign-in. Reporter and maintenance credentials
   sign in but land on **E-403** ("You don't have access to this page") with a Sign out action.
2. **Dashboard** (A-02): identical for admin and verifier, built only from public views and aggregates.
   - A **Created in** range control: 7 d, 30 d, 90 d or All (default All) recomputes everything.
   - **Eight metric cards**: Total, Pending, Critical / High, Assigned, In progress, Resolved, Closed and
     Awaiting verification. Pending + Assigned + In progress + Resolved + Closed always equals Total.
   - **Four charts**: Status breakdown (all seven statuses), Unresolved by priority, Unresolved by
     category and Intake per day (last 14 days).
   - **Three triage lists** (five rows each, with View all): Needs attention (unresolved Critical/High),
     Oldest unresolved and Awaiting manual triage.
   - Clicking a card, a chart bar or View all opens the complaint list **pre-filtered to exactly the set
     that was counted**; clicking a list row opens the complaint.
3. **Complaint List** (A-03): a table (ID, Category, Location, Priority, Status, Department, Waiting,
   Updated) with **no reporter column and no reporter-based filter**.
   - Filters: Status, Priority, Category, Department (including Unassigned), Building, **Created in**, the
     toggles **Unresolved only** and **Needs manual triage**, and search by ID, description or location.
     Within one filter values OR together; different filters AND together. **Reset filters** clears all.
   - Sort by any column; the default is priority (heaviest first), then longest waiting. Page size 25 or 50.
   - The **URL carries filter, sort and page state**, so a view can be bookmarked or shared and the
     browser's Back and Forward move through it. Opening a row shows the detail on top of the list, so
     Back returns to the same filters and page.
4. **Complaint Detail / Manage** (A-04): the screen is **role-split by construction**.

   | | Admin | Verifier |
   |---|---|---|
   | Data | Admin view: priority inputs, full assignment, actor-bearing timeline | Public view only |
   | Panels | Priority (effective, computed, override, severity, people affected, safety flag, aging); Assignment (department, assignee, assigned by/at, Auto or Manual); **Reporter identity** | Department label and the public timeline (role, time, note) |
   | Timeline | Actor name and ID plus role | Role, time and note only |
   | Actions | All ten (below) | Review & Route (accept the auto-route), Verify, Reject |

   The **ten manage actions** are shown only when the status machine allows that role to take them, and
   are disabled with the unmet rule when a precondition fails: **Review & Route** (admin may choose the
   department and staff member; Safety/Other complaints stop at Reviewed unless an admin names a
   department), **Assign** (admin; for a Reviewed complaint with no route), **Reassign** (admin; reason
   required), **Start work** and **Resolve on behalf** (admin), **Verify**, **Reject** (reason required),
   **Close** (**admin only**), **Set priority override**, and **Flag / Remove safety flag**. A closed
   complaint is read-only. If someone else changed the complaint meanwhile, the action reports "This
   complaint changed; refresh" rather than overwriting.

   **Identity reveal (admin only).** The **Reporter identity** panel is collapsed by default and the
   identity is not even built into the page until the admin clicks **Reveal reporter identity**. It then
   shows full name, ID number, email and phone, and re-collapses on **Hide**, on navigating away and on
   sign-out. The identity never appears in the URL or the page title and cannot be copied or exported
   in bulk. A verifier has no identity panel at all.

## 6. The complaint lifecycle

Seven statuses, in order: **Reported, Reviewed, Assigned, In Progress, Resolved, Verified, Closed**
(`ComplaintStatus`). Rework is a **marker** on the timeline, not an eighth status. The full contract is
[specs/status-machine-spec.md](specs/status-machine-spec.md); the implementation is
[`status_machine.dart`](../packages/campusfix_core/lib/logic/status_machine.dart) (pure rules) and
[`complaint_service.dart`](../packages/campusfix_core/lib/services/complaint_service.dart) (the atomic
executor).

| Edge | Transition | Allowed roles (state machine) | Where it happens |
|---|---|---|---|
| Submit | creates `reported` | reporter | Mobile Report flow |
| T1 | Reported to Reviewed | verifier, admin | Console A-04 Review & Route |
| T2 | Reviewed to Assigned | verifier (auto-route only), admin | Same action for auto-routable categories; admin Assign for Safety/Other |
| T3 | Assigned to In Progress | maintenance, admin | Mobile M-14 Start work (claims the job) |
| T4 | In Progress to Resolved | maintenance, admin | Mobile M-15 (after photo plus note required) |
| T5 | Resolved to Verified | verifier, admin | Mobile M-17 or console A-04 |
| T6 | Verified to Closed | verifier, admin in the state machine; **offered to admins only** | Console A-04 Close |
| T7 | Resolved to In Progress (reject) | verifier, admin | Mobile M-17 or console A-04; note required |
| T8 | In Progress to Assigned (pull-back) | admin | Console A-04 Reassign; reason required |

Notes:

- **Close is admin-only in both apps.** The state machine's L1 matrix technically lists the verifier on
  T6, but the product decision (see the "UI-verify/close" row in
  [specs/data-model-spec.md](specs/data-model-spec.md) section 7) is that the mobile verifier only
  verifies and the admin closes. Neither app offers Close to a verifier. A Phase 2 server should enforce
  the same rule ([plan](phase-2-firebase-plan.md)).
- **Review & Route is atomic.** For the six auto-routable categories T1 and T2 happen together (the
  complaint is never stored in Reviewed). Category to department: Electrical to Electrician, Plumbing to
  Plumber, Civil to Civil Maintenance, Furniture to Carpenter, Cleanliness to Housekeeping, IT to IT Team.
  Safety and Other have no route and wait for an admin ([assignment-routing-spec.md](specs/assignment-routing-spec.md)).
- **Priority** is rule-based and pure ([priority-engine-spec.md](specs/priority-engine-spec.md)): category
  weight, severity, people affected and waiting time, with hard safety rules (a safety matter is at least
  High, and Critical when severe or campus-wide). An admin override wins in the "effective priority" that
  every screen shows. Priority freezes once a complaint is Resolved and unfreezes on a reject.
- **Preconditions** (P1 to P9) include: at least one fresh after-repair photo and a resolution note before
  Resolved (P1, P2), a required reason on reject and reassign (P3), a stale check so two people cannot
  collide (P8), and "a closed complaint is immutable".

## 7. The privacy model

Hidden reporter identity is the heart of the product (requirements R5 and R6). The full contract is
[specs/privacy-spec.md](specs/privacy-spec.md).

**Two projections of one aggregate.** The raw `Complaint` (the "backend" record) carries a
`ReporterIdentity`. UI code never sees it; it sees one of two views from
[`complaint_views.dart`](../packages/campusfix_core/lib/models/complaint_views.dart), produced by
[`privacy.dart`](../packages/campusfix_core/lib/logic/privacy.dart):

| | `PublicComplaintView` | `AdminComplaintView` |
|---|---|---|
| Built by | `toPublicView(c)` (same output for every caller) | `toAdminView(c, requester)` (returns `null` unless `requester.role == admin`) |
| Fields | 17: ID, category, title, location, description, before/after photos, **effective** priority, status, safety flag, assigned **department label**, resolution note, a timeline of role/time/note, created/updated | Everything public, plus `reporter` (the identity), raw priority and override, severity, people affected, full assignment (assignee, assigned by) and a timeline with actor IDs |
| Used by | Board, My Complaints, maintenance, verifier, notifications, admin dashboard and list, **and the verifier's A-04** | Admin A-04 only |

`PublicStatusEvent` has no actor ID field, so a public timeline cannot carry a name even by mistake.

**What this means in practice**

- Reporter identity (name, ID, email, phone) is visible to **admins only**, only in **A-04**, only after an
  explicit **Reveal**. Staff identity (assignee, who assigned, timeline actors) is also admin-only.
- It never appears in lists, the board, maintenance, verifier, notification or dashboard surfaces, nor in
  URLs, page titles or logs. Routes carry only the Complaint ID. Notification text comes from fixed
  templates built from the ID, labels and location. Not even the owner sees the `reporter` block on their
  own complaint.
- The **verifier** is not trusted with identity: on mobile and on the web they get the public view only.

**The provider boundary.** Each app has one file that may read raw complaints:
`lib/providers/complaints.dart`, where the raw stream is file-private and everything it exports is a
public view. In the admin app the providers barrel hides `complaintRepositoryProvider`, and only the
`features/complaint_detail/` directory (the A-04 controller) may build an `AdminComplaintView`; only
`identity_panel.dart` may touch `ReporterIdentity`. Ownership ("my complaints") and department/claim
filtering run inside this layer, before projection.

**Architecture guards enforce it as tests**, not convention:

- **Core PR-T14** ([`privacy_test.dart`](../packages/campusfix_core/test/logic/privacy_test.dart)) scans
  `apps/mobile/lib`, `apps/admin/lib` and `campusfix_design/lib` for `ReporterIdentity`, `.reporter`,
  `AdminComplaintView`, `toAdminView` and logging of complaints. The mobile allow-list is exactly
  `report_submit.dart` (builds the identity from the signed-in user at submit) and `complaints.dart`.
- **Admin guard** ([`architecture_guard_test.dart`](../apps/admin/test/architecture_guard_test.dart))
  mirrors it with an **exact** allow-list (no stale entries) and also forbids raw colors and ad-hoc text
  styles. The mobile and design packages have their own guards.
- **PII sweeps** (PR-T1 to PR-T16): sentinel identities are injected and asserted absent from every
  public projection, from the seed data (`seed_privacy_test.dart`) and from every generated
  notification; the public view's key set must equal exactly the allowed 17 (default deny).

**Honesty clause.** The prototype runs entirely client-side, so these are structural and layering
guarantees proven by tests, not a security boundary against a malicious device. The real boundary is the
Phase 2 combination of Firestore Security Rules, a separately stored identity document and an audit log
([plan](phase-2-firebase-plan.md), privacy-spec section 9).

## 8. The design system

[`packages/campusfix_design`](../packages/campusfix_design) is the **single source of UI truth** and a
hard project rule: app code styles only through design tokens, `ThemeExtension`s, `BuildContext` helpers
and widgets. No raw `Colors.*` (except `Colors.transparent`), `Color(0x...)`, hex values, ad-hoc
`TextStyle` or hard-coded sizes and radii. A missing token is added to the design system, never inlined.

- Contract and rationale: [design/design-system.md](design/design-system.md) (tokens, 26 specified
  components, accessibility rules, the Flutter mapping) and its HTML form
  [design/design-system.html](design/design-system.html).
- **Published style guide:** <https://claude.ai/artifact/X521FrUxyrBpwzuus8xUyQ> ("CampusFix Design
  System", private to the account).
- Look and feel: petrol-teal primary; Archivo, Public Sans and JetBrains Mono; semantic color sets for
  the 8 categories, 4 priorities and 7 statuses; light and dark themes; Material icons.
- In code: `AppTheme.light()` / `AppTheme.dark()`, the `CampusColors`, `CategoryPalette`,
  `PriorityPalette` and `StatusPalette` extensions, and widgets such as `StatusBadge`, `PriorityTag`,
  `ComplaintCard`, `ComplaintTable`, `MetricCard`, `FilterBar`, `PhotoUploader`, `BeforeAfter` and
  `EmptyState`. Browse them in the gallery (see [Run it](#3-run-it)).
- The design package is PII-free: any widget that shows a complaint takes a `PublicComplaintView`. The
  identity reveal panel lives in the admin app, not here.

## 9. Known limitations

| Limitation | Detail |
|---|---|
| **No backend** | Everything is in-memory mocks; Firebase is Phase 2 ([plan](phase-2-firebase-plan.md)). Data resets on restart, and the mobile app and admin console do not share data. |
| **iOS build blocked** | `flutter build ios --simulator` fails with `App.framework: No such file` despite a UTF-8 locale, an iOS 15.0 target and clean pods. See [BUILDING.md](BUILDING.md). Android is unverified. The admin web build is the one fully runnable and visually verifiable target. |
| **`AppSelect` wide-window bug** | The design system's `AppSelect` throws ("RenderShrinkWrappingViewport does not support returning intrinsic dimensions") on non-compact windows; only the phone bottom-sheet path is tested. The admin console works around it with toggle chips for department and staff choices. The mobile Location step (building and floor pickers) uses `AppSelect`, so keep the mobile app at phone width until the widget is fixed. Tracked in [CLAUDE.md](../CLAUDE.md) as an S6 design fix. |
| **Maintenance demo queue is empty on the stock seed** | The quick-fill electrician `MNT-ELE-01` has no open work, so M-13 shows its empty states. The flows are correct and test-covered; use `MNT-HK-01` or `MNT-IT-01` for a live demo. The planned fix is a coordinated change to the seed, the core seed-count tests and the mobile work fixtures. The demo verifier is unaffected (four resolved complaints). |
| **Mobile cannot review or route** | Reviewing and assigning (T1/T2) is console-only. A complaint reported on mobile stays Reported in that app's store. |
| **Photos are placeholders** | Complaint photos are Flutter-drawn placeholders (category color, icon, BEFORE/AFTER label). The camera and gallery pickers add a bundled **sample**; nothing is uploaded or stored. |
| **In-app notifications only** | No push, e-mail or SMS, and no admin notification feed (admins are covered by the dashboard lists). |
| **Priority aging is not live** | `ComplaintService.refreshAging` exists in core and is tested, but neither app calls it; seed priorities are aged relative to the seed's build time. Phase 2 plans a scheduled job. |
| **Privacy is structural, not a security boundary** | See [section 7](#7-the-privacy-model). There is no audit log of identity reveals yet (Phase 2). |
| **Fonts need network on first load** | Fonts are fetched at runtime through `google_fonts`. |

## 10. Where to go next

| You want to | Read |
|---|---|
| See the build record and plan | [process/RUN-LEDGER.md](process/RUN-LEDGER.md), [process/PLAN.md](process/PLAN.md) |
| Understand the structure and decisions | [ARCHITECTURE.md](ARCHITECTURE.md), [CLAUDE.md](../CLAUDE.md) (hard rules and known issues) |
| Trace a requirement to a behavior | [REQUIREMENTS.md](REQUIREMENTS.md), [specs/](specs/) |
| Build, run and debug | [BUILDING.md](BUILDING.md) |
| Style a screen | [design/design-system.md](design/design-system.md) |
| Build the real backend | [phase-2-firebase-plan.md](phase-2-firebase-plan.md) |
