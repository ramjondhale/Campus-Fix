# Spec: Screens (functional)

**Chunk:** drives S1.3–S1.5 (screen design), S4.x (mobile), S5.x (admin web). **Traceability:** R13
(main screens), R14 (end-to-end flow), R4, R5, R6, R9–R12.
**Scope:** *functional* only — purpose, who sees it, data, actions, navigation, states, privacy.
Visual design is a separate track (S1) and is **not** specified here.
**Authority:** enums/models/logic names come from `data-model-spec.md`; roles/edges/preconditions from
`status-machine-spec.md` (T1–T8, P1–P9); routing from `assignment-routing-spec.md`; data visibility from
`privacy-spec.md`. `[DM-n]` marks fields that exist only if the data-model amendment in privacy-spec §3.4
is accepted (DM-1 public timeline, DM-2 resolution note + department, DM-3 admin priority inputs).

Role abbreviations: **Rp** reporter, **M** maintenance, **V** verifier, **A** admin.

## 1. Screen inventory

| ID | Screen | App | Roles | R13 / plan item |
|----|--------|-----|-------|------------------|
| M-01 | Login | mobile | all (signed-out) | Login (S4.1) |
| M-02 | Home (role-aware) | mobile | Rp, M, V | Home (S4.1) |
| M-03 | Report: Category | mobile | Rp | Category (S4.2) |
| M-04 | Report: Location (building/floor/room) | mobile | Rp | Location (S4.2) |
| M-05 | Report: Photo Upload | mobile | Rp | Photo Upload (S4.2) |
| M-06 | Report: Description & Impact | mobile | Rp | Report a Problem (S4.2) |
| M-07 | Report: Review | mobile | Rp | Report a Problem (S4.2) |
| M-08 | Confirmation (Complaint ID) | mobile | Rp | Complaint ID/Confirmation (S4.2) |
| M-09 | My Complaints / Status | mobile | Rp | My Complaints/Status (S4.3) |
| M-10 | Complaint Details (own) | mobile | Rp (owner) | Complaint Details (S4.3) |
| M-11 | Campus Problem Board (+ **M-11b** Board Item Detail) | mobile | Rp, M, V | Campus Problem Board (S4.4) |
| M-12 | Notifications | mobile | Rp, M, V | Notifications (S4.4) |
| M-13 | Assigned Work | mobile | M | (S1.4/S4.5) |
| M-14 | Work Detail (start / progress) | mobile | M | (S1.4/S4.5) |
| M-15 | After-Repair Upload (resolve) | mobile | M | (S1.4/S4.5), R10 |
| M-16 | Verification Queue | mobile | V | (S1.4/S4.6) |
| M-17 | Verify & Close | mobile | V | (S1.4/S4.6), R10 |
| A-01 | Admin Login | admin web | A, V | (S5.1) |
| A-02 | Admin Dashboard | admin web | A, V | Admin Dashboard (S5.2) |
| A-03 | Complaint List + Filters | admin web | A, V | (S5.3) |
| A-04 | Complaint Detail / Manage | admin web | A (full), V (limited) | (S5.4) |
| E-403 / E-404 | Not authorized / Not found | both | any | shared |

R13 coverage check: Login (M-01, A-01) · Home (M-02) · Report a Problem (M-03..M-07) · Category (M-03) ·
Location (M-04) · Photo Upload (M-05) · Complaint Details (M-10) · Complaint ID/Confirmation (M-08) ·
My Complaints/Status (M-09) · Campus Problem Board (M-11) · Notifications (M-12) · Admin Dashboard (A-02).
M-13..M-17, A-03, A-04 are the maintenance, verifier and admin-management screens required by R9/R10/R12.

### 1.1 Proposed routes (go_router)
Mobile: `/login`, `/home`, `/report/category`, `/report/location`, `/report/photos`, `/report/details`,
`/report/review`, `/report/done/:id`, `/complaints`, `/complaints/:id`, `/board`, `/board/:id`,
`/notifications`, `/work`, `/work/:id`, `/work/:id/resolve`, `/verify`, `/verify/:id`.
Admin web: `/login`, `/dashboard`, `/complaints` (filters in query string — filter values only),
`/complaints/:id`. Routes carry only the Complaint ID (privacy LK-5).

## 2. Global conventions (apply to every screen)

| ID | Convention |
|----|------------|
| G-1 | **Auth guard:** signed-out access to any route other than login redirects to login; after login return to the requested route if the role may open it, else the role home. |
| G-2 | **Role guard:** a role opening a screen it is not listed for gets **E-403** ("You don't have access to this page") with a "Go home" action. Admin signing in on **mobile** gets a notice "The admin console is on the web" with Sign out (v1). Reporter/maintenance signing in on **admin web** gets E-403. |
| G-3 | **Loading:** list and detail screens show skeleton placeholders (never a blank screen); buttons that trigger writes show an in-progress state and are disabled (no double submit). Mock repos simulate 300–600 ms latency so these states are demonstrable. |
| G-4 | **Error:** a failed load shows a message + **Retry**, keeping previously loaded data visible where it exists. A failed write keeps the user's input and shows an inline error. Independent sections of one screen fail independently. |
| G-5 | **Empty:** every list has a specific empty message and (where useful) a primary action; "no results for filters" is distinct from "nothing exists" and offers "Clear filters". |
| G-6 | **Not found / not permitted:** unknown Complaint ID, or one the role may not open, shows **E-404** (never reveals whether it exists). |
| G-7 | **Forms:** inline validation on blur and on attempted submit; the step's primary button is disabled until the step is valid; free text is trimmed; limits are enforced with counters. |
| G-8 | **Display rules:** priority always `effectivePriority`; status/priority always via the shared StatusBadge/PriorityTag with **text** (not colour alone); Complaint ID shown exactly as stored (`CF-YYYY-NNNNN`) and copyable; time shown relative under 24 h ("2 h ago"), otherwise absolute date + time. |
| G-9 | **Navigation:** mobile bottom nav per role (Rp: Home, My Complaints, Board, Notifications; M: Home/Work, Board, Notifications; V: Home/Verify, Board, Notifications). System back never lands inside a completed write flow (e.g. after M-08 back goes to M-02). Unsaved input prompts "Discard?" before leaving. |
| G-10 | **Privacy:** every screen consumes only the view types allowed for it (privacy-spec §4/§5); no screen renders a reporter block except A-04's reveal panel; free-text inputs for notes show the "visible to people involved" helper (privacy §6). |
| G-11 | **Prototype fidelity:** data from in-memory mock repos; notifications in-app only (A1); photos from bundled samples (A4); login accepts seeded accounts (a "Demo accounts" quick-fill on M-01/A-01, removable via build flag for Phase 2). |
| G-12 | **Accessibility (functional):** all controls have semantic labels; focus order follows reading order; status/priority conveyed by text; touch targets and contrast are specified in the design track. |
| G-13 | **Reuse:** screens compose the shared component set (PLAN S1.2: AppButton, TextField, SelectTile, CategoryTile, ComplaintCard, StatusBadge, PriorityTag, PhotoUploader, BeforeAfter, Timeline, MetricCard, FilterBar, EmptyState, AppBar, BottomNav). No screen defines its own copy of a component, token, enum label, or status/priority mapping. |

**Report draft (UI state, non-contract):** `{category, building, floor, room, beforePhotos[1..5], description,
severity=moderate, peopleAffected=individual, safetyFlag=false}`; lives in memory across M-03..M-07,
cleared on successful submit or confirmed discard.

---

## 3. Mobile screens

### M-01 Login
* **Purpose:** authenticate with ID + password (mocked) and route by role (R13, R16).
* **Roles:** signed-out users.
* **Data shown:** none. *Prototype only:* "Demo accounts" quick-fill listing one seeded account per role.
* **Inputs/actions:** ID number (required, trimmed); Password (required, masked, show/hide); **Sign in** ->
  `AuthRepository.signIn(idNumber, password)`. Success -> role home (Rp/M/V -> M-02; A -> G-2 notice).
  Failure (`null`) -> inline "ID or password is incorrect" (does not say which).
* **Navigation:** in: app launch, sign-out, session end. Out: M-02.
* **States:** submitting (button spinner, fields disabled); invalid credentials; unexpected error with Retry.
  No empty state.
* **Privacy:** password never logged, echoed or retained after the call; no complaint data on screen;
  error text is non-enumerating.
* **Acceptance:** AC-01 empty fields keep Sign in disabled; AC-02 wrong password shows the generic error and
  clears the password; AC-03 each seeded role lands on its home; AC-04 admin account on mobile shows the web-console notice.

### M-02 Home (role-aware)
* **Purpose:** role dashboard and entry point (R13).
* **Roles:** Rp, M, V (header shows the signed-in user's own display name — session UI).
* **Data shown (public views only):**
  * **Rp:** primary "Report a Problem"; "My active complaints" (<= 3 most recently updated, status != `closed`) as ComplaintCards; "Campus board highlights" (<= 3 open complaints with `effectivePriority` critical/high); unread-notifications badge.
  * **M:** counts for the user's department — *To start* (`assigned`), *In progress*, *Rework needed* (see M-13); button "Open my work"; board; notifications.
  * **V:** count *Awaiting verification* (`status == resolved`); button "Open verification queue"; board; notifications.
* **Inputs/actions:** tap CTA/card/count; pull-to-refresh; user menu -> Sign out.
* **Navigation:** out: M-03 (Rp), M-10, M-09, M-11, M-12, M-13 (M), M-16 (V).
* **States:** loading skeleton per section; empty (Rp): "You haven't reported anything yet" + CTA; empty (M/V): "Nothing to do right now"; per-section error + Retry.
* **Privacy:** only `PublicComplaintView`; counts are aggregates; no identity or assignee names.
* **Acceptance:** AC-05 Rp home never shows another user's complaint except via board highlights; AC-06 counts equal the lists they open.

### M-03 Report: Category (step 1 of 5)
* **Purpose:** choose the problem category (R3, R4, R14 "Category"). Steps: Category, Location, Photo, Details, Review.
* **Roles:** Rp.
* **Data shown:** the 8 `ProblemCategory` values with `label`; helper under `safety`: "For immediate danger contact campus security directly" (configurable text); under `other`: "Will be reviewed manually".
* **Inputs/actions:** select exactly one (SelectTile); **Next** (enabled once selected). Selecting `safety` sets `draft.safetyFlag = true` (locked on in M-06); switching away resets it to `false`. **Close (X)** -> "Discard report?" if the draft has any input.
* **Navigation:** in: M-02, M-11 FAB, M-08 "Report another"; out: M-04.
* **States:** no loading/error (static data); empty n/a.
* **Privacy:** no complaint data; draft lives only in memory.
* **Acceptance:** AC-07 Next disabled until a category is chosen; AC-08 all 8 labels match `ProblemCategory.label`; AC-09 choosing `safety` then `electrical` clears the auto-set safety flag.

### M-04 Report: Location (step 2 of 5)
* **Purpose:** record building, floor, room/location detail (R4).
* **Roles:** Rp.
* **Data shown:** Building picker from the campus list in seed config (`SC-OI-3`) plus "Other…"; Floor picker (Basement, Ground, 1–10, Terrace, Outdoor/N.A.); Room/location text.
* **Inputs/actions:** Building (required; "Other…" reveals free text <= 60), Floor (required), Room/Location (required, <= 60 chars, e.g. "Lab 204", "Washroom near stairs"). **Next** enabled when all valid (trimmed non-empty). Back keeps values.
* **Navigation:** in: M-03, M-07 "Edit"; out: M-05, back M-03.
* **States:** empty building list -> only the free-text option; no loading/error.
* **Privacy:** helper: "Location is visible to everyone on the campus board."
* **Acceptance:** AC-10 Next disabled until building, floor and room are all non-blank; AC-11 values round-trip through Back/Next unchanged.

### M-05 Report: Photo Upload (step 3 of 5)
* **Purpose:** attach before-repair evidence (R4, R10). **1 to 5 photos required** (SC-OI-6).
* **Roles:** Rp.
* **Data shown:** thumbnails of attached photos (each an `Attachment(kind: beforePhoto)`); remaining-slots hint.
* **Inputs/actions:** Add photo -> source sheet (Camera mock / Gallery mock; prototype picks from bundled samples, A4); optional caption <= 80 chars; remove photo; **Next** enabled with >= 1 photo. Adding disabled at 5 ("Maximum 5 photos").
* **Navigation:** in: M-04, M-07 "Edit"; out: M-06.
* **States:** empty (0 photos): prominent "Add a photo"; per-photo loading placeholder; per-photo failure with Retry/Remove; (Phase 2: permission-denied explanation).
* **Privacy:** hint "Avoid including people's faces or documents" (LK-9); captions are public text; no EXIF handling in the prototype.
* **Acceptance:** AC-12 Next disabled with zero photos; AC-13 sixth photo cannot be added; AC-14 all attachments have `kind == beforePhoto`.

### M-06 Report: Description & Impact (step 4 of 5)
* **Purpose:** describe the problem and capture the priority inputs (R4, R7).
* **Roles:** Rp.
* **Data shown / inputs:**
  * **Description** — required, 10–1000 chars, live counter.
  * **Severity** (`Severity`): minor / moderate (default) / severe, each with a one-line plain-language hint.
  * **People affected** (`PeopleAffected`): "Just me" (individual, default) / "A few people" (small) / "A class, lab or floor" (many) / "Whole campus" (campusWide).
  * **This is a safety hazard** toggle (`safetyFlag`): off by default; **locked on** (with explanation) when category = `safety`; when on: "Marked urgent — minimum priority High".
* **Actions:** **Next** enabled when description is valid.
* **Navigation:** in: M-05, M-07 "Edit"; out: M-07.
* **States:** inline validation only.
* **Privacy:** helper: "Don't include names or contact details — complaints are visible on the campus board."
* **Acceptance:** AC-15 description shorter than 10 trimmed chars blocks Next; AC-16 defaults are moderate/individual/off; AC-17 safety toggle cannot be turned off for category `safety`.

### M-07 Report: Review (step 5 of 5)
* **Purpose:** confirm everything before submission (R14 "Submit").
* **Roles:** Rp.
* **Data shown:** read-only summary of the draft (category, location, photos, description, severity, people affected, safety flag) with an **Edit** link per section (-> M-03..M-06, draft preserved); the notice "Your name and contact details are never shown on the board or to maintenance staff"; **Possible duplicates** (non-blocking): up to 3 public views with `category == draft.category`, `building == draft.building`, `status != closed` (same floor ranked first), each opening M-11b.
* **Inputs/actions:** **Submit** (builds the `Complaint`: `id = nextComplaintId(now)`, `status = reported`, `reporter` from the session, `priority = computePriority(inputs, waitingTime 0)`, `timeline = [reported event]`, `createdAt = updatedAt = now`, then `ComplaintRepository.submit`). Disabled and showing progress while in flight; a second tap is ignored.
* **Navigation:** in: M-06; out: M-08 (replace), edit links, Cancel -> discard confirm -> M-02.
* **States:** submitting; submit failure -> inline banner + Retry with draft intact; duplicates panel loading/failed -> silently hidden (non-critical).
* **Privacy:** summary shows no identity; duplicates come from `PublicComplaintView`s; the submitted complaint's PII never leaves the submit controller (privacy §5.1).
* **Acceptance:** AC-18 submit creates exactly one complaint even on double-tap; AC-19 created complaint has `status == reported`, `assignment == null`, 1 timeline event; AC-20 draft survives Edit round-trips.

### M-08 Confirmation (Complaint ID)
* **Purpose:** show the unique Complaint ID, computed priority and what happens next (R4, R14 "Complaint ID -> Priority").
* **Roles:** Rp.
* **Data shown:** Complaint ID (large, **Copy**); StatusBadge `Reported`; PriorityTag (the computed `effectivePriority`); category; location; submitted date/time; next steps (Reviewed -> Assigned -> In Progress -> Resolved -> Verified -> Closed) and "You'll be notified at each step".
* **Actions:** **View complaint** -> M-10; **Report another** -> M-03 (fresh draft); **Home** -> M-02.
* **Navigation:** in: M-07 only. System back -> M-02.
* **States:** if the re-fetch fails, show the ID/priority returned by submit plus Retry for the rest.
* **Privacy:** no identity.
* **Acceptance:** AC-21 displayed ID matches `CF-\d{4}-\d{5}` and equals the stored complaint's `id`; AC-22 priority shown equals `computePriority` for the submitted inputs (priority-engine E-vectors).

### M-09 My Complaints / Status
* **Purpose:** list the signed-in reporter's own complaints with live status (R13).
* **Roles:** Rp.
* **Data shown (`PublicComplaintView`, ownership resolved in the repo/provider layer):** ComplaintCard: ID, category, location line, PriorityTag, StatusBadge, "updated 3 h ago", first before-photo thumbnail.
* **Inputs/actions:** segment **All / Active / Closed** (Active = status != `closed`); search by ID/description; pull-to-refresh; tap card -> M-10; FAB "Report a Problem". Sort: `updatedAt` desc.
* **Navigation:** in: bottom nav, M-02; out: M-10, M-03.
* **States:** loading skeleton; empty: "You haven't reported anything yet" + CTA; filtered-empty: "No matching complaints" + Clear; error + Retry.
* **Privacy:** public views only; a user can never see another user's complaint here.
* **Acceptance:** AC-23 only complaints whose `reporter.userId` equals the session user appear; AC-24 a newly submitted complaint appears at the top without manual refresh.

### M-10 Complaint Details (own)
* **Purpose:** full tracking page for one's own complaint, including before/after evidence (R10, R13).
* **Roles:** Rp (owner). Non-owner opening `/complaints/:id` is redirected to M-11b.
* **Data shown (`PublicComplaintView` + DM):** ID (copy), StatusBadge, PriorityTag; category; location; description; before-photo gallery; after-photo gallery and **BeforeAfter** comparison when `afterPhotos` exist; resolution note `[DM-2]` when status >= `resolved`; assigned department label `[DM-2]` when assigned; a 7-step progress tracker (Reported ... Closed) with the current step highlighted and a "Rework" marker if a reject (T7) occurred; **Timeline** `[DM-1]` in chronological order: status label, **actor role label only**, time, note; created / last-updated times.
* **Inputs/actions:** copy ID; open photo full-screen (zoom). **No status actions** (Rp has no transitions, status-machine §3).
* **Navigation:** in: M-09, M-02, M-08, M-12; out: back, photo viewer.
* **States:** loading skeleton; error + Retry; E-404; `closed` -> read-only banner "This complaint is closed."
* **Privacy:** no `reporter` block; no staff names/IDs; timeline per privacy §6 (role + time + note); department is a label.
* **Acceptance:** AC-25 timeline entries show role and never a name/ID; AC-26 after-photos and resolution note appear only once `afterPhotos`/`resolutionNote` exist; AC-27 no action buttons for status.

### M-11 Campus Problem Board  /  M-11b Board Item Detail
* **Purpose:** anonymous, campus-wide view of complaints so people can spot existing issues and avoid duplicates (R6).
* **Roles:** Rp, M, V (all authenticated mobile users).
* **Data shown (R6 fields only):** card: ID, category label, location line, first before-photo thumbnail, description (2 lines), PriorityTag (`effectivePriority`), date/time, StatusBadge. **M-11b** adds: all before/after photos, full description, full location. **Not shown:** timeline, notes, department, assignee, any "mine" marker, any identity.
* **Inputs/actions:** FilterBar: Category (multi), Priority (multi), Status (multi), Building (single); toggle **Include closed** (default off); search (ID/description/location); sort: *Priority* (default: `Priority.weight` desc, then `createdAt` desc) / Newest / Oldest / Recently updated; infinite scroll (page size 20); tap card -> M-11b; (Rp) FAB "Report a Problem".
* **Navigation:** in: bottom nav, M-02, M-07 duplicates; out: M-11b, M-03.
* **States:** loading skeleton; empty: "No open complaints on campus"; filtered-empty + Clear filters; error + Retry; M-11b not found -> E-404.
* **Privacy:** renders `PublicComplaintView` only; fields limited to the R6 set (privacy §4 "Board"); search indexes public fields only (LK-2).
* **Acceptance:** AC-28 default list excludes `closed` and is ordered priority weight desc then newest; AC-29 no widget in this feature references `reporter`/`assignment`/`timeline`; AC-30 rendered text for seed data contains none of the sentinel PII (privacy PR-T16).

### M-12 Notifications
* **Purpose:** in-app feed of events relevant to the user (R11, assumption A1).
* **Roles:** Rp, M, V.
* **Data shown:** `NotificationItem` view-models **derived** from `StatusEvent`s per status-machine §5.1 (SC-OI-1): icon by event kind, message, Complaint ID, relative time, unread dot; grouped Today / Earlier; newest first. Recipient rules: Rp — events on own complaints; M — assignments to the department, rework (T7), verification (T5), reassignments; V — complaints entering `resolved`.
* **Inputs/actions:** tap item -> marks read, opens M-10 (Rp) / M-14 (M) / M-17 (V) (if no longer accessible -> toast "No longer available"); **Mark all as read**; pull-to-refresh. Read state is local UI state in the prototype (Phase 2: server + FCM). Unread count feeds the bottom-nav/Home badge.
* **Navigation:** in: bottom nav, M-02; out: M-10 / M-14 / M-17.
* **States:** loading skeleton; empty: "You're all caught up"; error + Retry.
* **Privacy:** message text strictly per LK-1/status-machine §5.1 (no names, IDs, emails, phones; department label allowed); same for any Phase-2 push payload.
* **Acceptance:** AC-31 a T4 event yields a verifier notification and an owner notification, and no maintenance notification; AC-32 notification text for all seed events passes the PII sweep (PR-T15).

### M-13 Assigned Work (maintenance)
* **Purpose:** the department's work queue (R8/R9).
* **Roles:** M (scoped to `AppUser.department`).
* **Data shown (`PublicComplaintView`):** tabs **To start** (`status == assigned`, `assignedDepartment == user.department`), **In progress** (`inProgress` and claimed by me), **Rework** (`inProgress` whose latest event is a reject, claimed by me); card: ID, category, location, PriorityTag, StatusBadge, waiting time, thumbnail. Sort: `Priority.weight` desc then oldest first. Complaints already claimed by a *colleague* are excluded from "To start" (P7).
* **Actions:** tap -> M-14; pull-to-refresh.
* **Navigation:** in: bottom nav, M-02, M-12; out: M-14.
* **States:** loading skeleton; empty: "No work assigned to <Department.label>"; error + Retry.
* **Privacy:** public views only; department/claim filtering runs in the provider layer (privacy §5.3) — no assignee names.
* **Acceptance:** AC-33 a plumber never sees electrical complaints; AC-34 the three tab counts equal the Home counts.

### M-14 Work Detail (start / progress)
* **Purpose:** inspect a job and start it (T3) or go to resolve (T4).
* **Roles:** M (own department); E-404 otherwise.
* **Data shown:** all of M-10's data (public + DM) with a prominent **rejection note** when in Rework (`[DM-1]` latest T7 note); no reporter, no assignee.
* **Inputs/actions:** driven by `nextStatuses(status, maintenance)` and preconditions: `assigned` -> **Start work** (optional note <= 500; claims the job, CL-1; T3). `inProgress` -> **Mark as resolved** -> M-15. Unmet preconditions show the P6/P7/P8 message ("Already claimed by a colleague", "This complaint changed; refresh").
* **Navigation:** in: M-13, M-12; out: M-15, back M-13.
* **States:** loading, error + Retry, E-404; after T3 the screen updates in place (status `In Progress`, timeline entry).
* **Privacy:** `PublicComplaintView` only.
* **Acceptance:** AC-35 Start work moves status to `inProgress` and appends one event with `actorRole == maintenance`; AC-36 a colleague of the same department gets the P7 message after a claim.

### M-15 After-Repair Upload (resolve)
* **Purpose:** submit repair proof: after-photo(s) + resolution note (R10). T4.
* **Roles:** M (claimant).
* **Data shown:** the complaint's before photos for reference; inputs below.
* **Inputs/actions:** **After photos** 1–5 (`Attachment(kind: afterPhoto)`, optional caption <= 80); **Resolution note** required, <= 500 chars, counter, helper "Visible to people involved…"; **Mark resolved** enabled only when P1 (>= 1 *fresh* after-photo) and P2 hold; confirm dialog "Mark CF-… as resolved? A verifier will review."
* **Navigation:** in: M-14; out: M-13 on success (toast "Sent for verification"); Cancel -> discard confirm.
* **States:** uploading progress; failure keeps photos + note with Retry; empty (0 photos) shows "Add after-repair photo".
* **Privacy:** photo hint; note helper; no identity.
* **Acceptance:** AC-37 button disabled without photo or without note; AC-38 after a reject, only photos created after the reject count; AC-39 success sets `status == resolved`, stores `resolutionNote`, appends one event whose note equals the resolution note.

### M-16 Verification Queue
* **Purpose:** list work awaiting verification (R10).
* **Roles:** V.
* **Data shown (`PublicComplaintView`):** `status == resolved`, sorted by `Priority.weight` desc then longest waiting in `resolved`; card: ID, category, location, PriorityTag, before/after thumbnails, time since resolved.
* **Actions:** tap -> M-17; pull-to-refresh.
* **Navigation:** in: bottom nav, M-02, M-12; out: M-17.
* **States:** loading skeleton; empty: "Nothing awaiting verification"; error + Retry.
* **Privacy:** public views only.
* **Acceptance:** AC-40 only `resolved` complaints appear; AC-41 count equals Home "Awaiting verification".

### M-17 Verify & Close
* **Purpose:** approve or reject the repair with evidence side by side (R10; T5+T6 or T7).
* **Roles:** V.
* **Data shown:** BeforeAfter comparison (before vs after photos), resolution note `[DM-2]`, description, location, PriorityTag, timeline `[DM-1]`.
* **Inputs/actions:** `nextStatuses(resolved, verifier) == [inProgress, verified]`:
  **Verify & Close** (T5 then T6; optional note; confirm dialog) and **Reject — needs rework** (T7; **required** note, <= 500; confirm).
* **Navigation:** in: M-16, M-12; out: M-16 on success (toast).
* **States:** loading, error + Retry, E-404; if evidence is missing (corrupt data) actions are disabled with the P1/P2 message; stale -> P8 message.
* **Privacy:** public view only; verifier never sees identity.
* **Acceptance:** AC-42 Verify & Close ends in `closed` with `verified` then `closed` events; AC-43 Reject without a note is blocked; AC-44 Reject returns status to `inProgress` and notifies the department.

---

## 4. Admin web screens

### A-01 Admin Login
* **Purpose:** authenticate to the admin console (R12 "secure admin area").
* **Roles:** A, V sign in; others get E-403 after authentication.
* **Data/inputs/states:** as M-01 (web layout; deep link preserved through login; "Demo accounts" for A and V in the prototype).
* **Privacy:** as M-01. **Acceptance:** AC-45 reporter/maintenance credentials are rejected with E-403 on web.

### A-02 Admin Dashboard
* **Purpose:** management monitoring (R12; core "management dashboard").
* **Roles:** A, V (identical content; no identity on this screen).
* **Data shown (aggregates + `PublicComplaintView` lists; live via `watchAll`):**

| Card | Exact definition |
|------|------------------|
| Total | all complaints in range |
| Pending | `status` in {`reported`, `reviewed`} |
| Critical / High | unresolved (`status` in {`reported`, `reviewed`, `assigned`, `inProgress`}) with `effectivePriority` in {critical, high} |
| Assigned | `status == assigned` |
| In progress | `status == inProgress` |
| Resolved (incl. verified) | `status` in {`resolved`, `verified`} |
| Closed | `status == closed` |

  **Invariant:** Pending + Assigned + In progress + Resolved + Closed **= Total** (Critical/High is an overlay).
  Charts: status breakdown (all 7 statuses; sums to Total), unresolved by priority (4), by category (8), intake per day (last 14 days). Lists (5 rows each): **Needs attention** (unresolved critical/high by weight then age), **Oldest unresolved**, **Awaiting manual triage** (`reviewed`, no assignment), and an **Awaiting verification** count.
* **Inputs/actions:** date-range filter on `createdAt` (7 d / 30 d / 90 d / All; default All); clicking a card, chart bar or list row opens A-03 with the matching preset filters (or A-04 for a row).
* **Navigation:** in: login, side nav; out: A-03, A-04.
* **States:** loading skeleton cards; empty (no complaints): zeros + "No complaints yet"; each widget has its own error + Retry.
* **Privacy:** aggregates and public views only; no reporter, assignee or actor data.
* **Acceptance:** AC-46 card definitions and the partition invariant hold for the seed data; AC-47 clicking "Critical / High" lands on A-03 pre-filtered to exactly the counted set.

### A-03 Complaint List + Filters
* **Purpose:** find, sort and triage all complaints (R12 "monitor unresolved").
* **Roles:** A, V.
* **Data shown (`PublicComplaintView` + `assignedDepartment` `[DM-2]`):** table columns — ID, Category, Location (building · floor · room), Priority (effective), Status, Department (label or "Unassigned"), Waiting (since `createdAt`, unresolved only), Updated. **No reporter column; no reporter-based search/sort/filter** (PV-5); no override marker (that is on A-04 only).
* **Inputs/actions:** filters — Status (multi), Priority (multi), Category (multi), Department (multi incl. Unassigned), Building, Created date range, toggles "Unresolved only" and "Needs manual triage"; search by ID/description/location; sort by any column (default: priority weight desc, then waiting desc); pagination 25/50 per page; **Reset filters**. Filter state is reflected in the URL query (filter values only). Row click -> A-04. No bulk actions in v1.
* **Navigation:** in: side nav, A-02 presets; out: A-04.
* **States:** loading skeleton rows; empty (no complaints) vs filtered-empty ("No complaints match" + Reset); error + Retry.
* **Privacy:** built from public views only (admin views are constructed only in A-04, privacy §5.1).
* **Acceptance:** AC-48 table header contains no identity-related column; AC-49 each filter narrows results correctly and filters AND together; AC-50 default sort order matches the rule.

### A-04 Complaint Detail / Manage
* **Purpose:** review one complaint and act on it: review/route, assign/reassign, change priority/status, verify, see evidence and history (R9, R10, R12).
* **Roles:** **A** (full, `AdminComplaintView`), **V** (limited, `PublicComplaintView`; no panels marked "A only").
* **Data shown:**
  * Header: ID, StatusBadge, effective PriorityTag with **Overridden** marker (A), category, location, created/updated, waiting time.
  * Description; before photos; after photos + BeforeAfter; resolution note.
  * **Priority panel (A only) `[DM-3]`:** computed `priority`, `priorityOverride`, inputs (severity, people affected, safety flag), aging bucket.
  * **Assignment panel:** department label (A and V); **A only:** assignee (resolved to staff name/ID), `assignedBy`, `assignedAt`, **Auto/Manual** chip (`isManual`).
  * **Timeline:** A: full `StatusEvent`s with **actor name/ID + role** + note; V: public form (role + time + note) `[DM-1]`.
  * **Reporter identity panel (A only):** collapsed by default; **Reveal reporter identity** shows `fullName`, `idNumber`, `email`, `phone`; re-collapses on navigation/sign-out (LK-8). No export/copy-all.
* **Manage actions** (shown from `nextStatuses(status, role)` + preconditions; each asks for confirmation and a note where required):

| Action | Roles | Edge | Inputs |
|--------|-------|------|--------|
| **Review & Route** (status `reported`) | A, V | T1 (+T2) | A: department selector pre-set to `routeToDepartment(category)` (change => manual); V: confirm only. For `safety`/`other` nothing is pre-set: V's review ends in `reviewed` (V cannot assign); A may pick a department to assign in the same action, otherwise it also ends in `reviewed`. |
| **Assign** (status `reviewed`, no route) | A | T2 | department (required, nothing preselected), optional staff member (SC-OI-4) |
| **Reassign** (status `assigned` / `inProgress`) | A | annotation event / T8 | department (+ optional staff), **reason required** |
| **Start / Resolve on behalf** | A | T3 / T4 | resolve needs after-photo(s) + resolution note (same form as M-15) |
| **Verify & Close**, **Close** (status `verified`) | A, V | T5+T6 / T6 | optional note |
| **Reject — needs rework** | A, V | T7 | **required** note |
| **Set / clear priority override** | A | n/a (not a status change) | `Priority` or "Clear override"; shows resulting effective priority |
| **Toggle safety flag** | A | n/a | recomputes priority |

* **Navigation:** in: A-02, A-03; out: back to A-03 with filters preserved; photo viewer.
* **States:** loading skeleton; error + Retry; E-404; `closed` -> read-only banner and **no actions** (INV-4); action failures list unmet preconditions inline (P1–P9 messages); stale -> "This complaint changed; refresh".
* **Privacy:** admin view built only here; identity panel is the only place `ReporterIdentity` is rendered; verifier gets no P0/P1/P2 data; identity never in URL/title; Phase 2 writes an audit entry on reveal (privacy §9).
* **Acceptance:** AC-51 as A, the identity panel is collapsed on load and the page text contains no identity until Reveal; AC-52 as V, no identity panel, no assignee/actor names, no priority-input panel; AC-53 each Manage action appears only when `canTransition` allows it and is disabled with a reason when a precondition fails; AC-54 priority override changes `effectivePriority` everywhere (A-02/A-03/M-11) without altering the computed `priority`; AC-55 safety/other complaints can be assigned only by A.

### E-403 / E-404 (shared)
E-403: "You don't have access to this page" + Go home (G-2). E-404: "We couldn't find that complaint" + Go home (G-6). Neither screen reveals whether a Complaint ID exists.

---

## 5. Role-to-screen matrix

| Screen | Rp | M | V | A |
|--------|:--:|:-:|:-:|:-:|
| M-01 Login | Y | Y | Y | Y (notice only) |
| M-02 Home | Y | Y | Y | — |
| M-03..M-08 Report flow | Y | — | — | — |
| M-09 My Complaints, M-10 Details (own) | Y | — | — | — |
| M-11 Board, M-11b | Y | Y | Y | — (use A-03) |
| M-12 Notifications | Y | Y | Y | — |
| M-13..M-15 Work | — | Y | — | — |
| M-16, M-17 Verify | — | — | Y | — |
| A-01 Admin Login | — | — | Y | Y |
| A-02 Dashboard, A-03 List | — | — | Y | Y |
| A-04 Manage | — | — | Y (limited) | Y (full) |

## 6. Mapping to the end-to-end flow (R14)

| # | R14 step | Screen(s) | Status / transition |
|---|----------|-----------|---------------------|
| 1 | Login | M-01 | — |
| 2 | Report | M-02 CTA -> M-03 | — |
| 3 | Category | M-03 | — |
| 4 | Building / Floor / Room | M-04 | — |
| 5 | Photo | M-05 | — |
| 6 | Description (+ impact inputs for priority) | M-06 | — |
| 7 | Submit (after Review) | M-07 | complaint created, `reported` |
| 8 | Complaint ID | M-08 (and M-10) | `reported` |
| 9 | Priority | computed at submit (shown on M-08, M-10, board); admin may override in A-04 | `effectivePriority` |
| 10 | Review | A-04 *Review & Route* (admin/verifier) | T1 `reported -> reviewed` |
| 11 | Assignment | auto at T1 -> T2, or A-04 *Assign* for safety/other | T2 `reviewed -> assigned` |
| 12 | Work Started | M-13 -> M-14 *Start work* | T3 `assigned -> inProgress` |
| 13 | Completed | M-15 *Mark resolved* | T4 `inProgress -> resolved` |
| 14 | After-Repair Photo | M-15 (photos + note); visible in M-10, M-17, A-04 | R10 evidence |
| 15 | Verification | M-16 -> M-17 (or A-04) | T5 `resolved -> verified` (T7 reject loop) |
| 16 | Closed | M-17 *Verify & Close* / A-04 | T6 `verified -> closed`; reporter sees it in M-09/M-10/M-12 |

Throughout: Board (M-11) and Notifications (M-12) observe steps 8–16; A-02/A-03 monitor all steps.

## 7. Navigation graph (summary)
```
M-01 -> M-02 --Rp--> M-03 -> M-04 -> M-05 -> M-06 -> M-07 -> M-08 -> {M-10, M-03, M-02}
M-02 --Rp--> M-09 -> M-10 ;  M-02/bottom-nav -> M-11 -> M-11b ; -> M-12 -> {M-10 | M-14 | M-17}
M-02 --M---> M-13 -> M-14 -> M-15 -> M-13
M-02 --V---> M-16 -> M-17 -> M-16
A-01 -> A-02 <-> A-03 -> A-04 -> A-03
```

## 8. Open issues for the orchestrator
| ID | Issue |
|----|-------|
| SC-OI-1 | **No notification model** exists in the data model (R11 needs one). This spec derives `NotificationItem` view-models from `StatusEvent`s (+ local read state). Decide: keep derived (prototype) or add `AppNotification`/`NotificationRepository` in S2.1/S2.6. |
| SC-OI-2 | **Admin on mobile:** v1 blocks it (web-only). Confirm; the alternative is to give admin the V mobile screens. |
| SC-OI-3 | **Campus building/floor lists** are not in the data model (`building`/`floor` are plain `String`). Seed/config must supply the pickers (S2.6). |
| SC-OI-4 | **User directory** (resolve `actorId`/`assigneeId` to staff name/ID for A-04 and to list assignable staff) is not in the contract; `AuthRepository` has no lookup. Add a read-only directory in seed data. |
| SC-OI-5 | **Maintenance queue filtering** needs `assignment.department`/`assigneeId` on the raw aggregate; `ComplaintRepository` has no query for it. See privacy DM-4 (view-returning queries) or provider-boundary rule. |
| SC-OI-6 | **Photo required (min 1)** is a decision; R4 lists "photo(s)" but a few categories (IT outage) may not photograph well. Easy to relax to optional. |
| SC-OI-7 | **Verifier access to admin web** (dashboard + limited A-04) follows ARCHITECTURE §4 ("mobile + admin"); confirm. |
| SC-OI-8 | **Defaults** severity = moderate, people = individual pre-selected in M-06 (reduces friction; may cluster priorities at Medium). Confirm or force an explicit choice. |
| SC-OI-9 | `Complaint.title` is unused (not collected, not in any view). Drop it or define where it appears. |
