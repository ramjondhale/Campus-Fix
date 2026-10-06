# CampusFix AI — Requirements (distilled + traceability)

Source: `CampusFix_AI_Developer_Requirement_Document.pdf` (functional baseline). The doc grants
"developer technical freedom" — it defines *what*, not *how*. IDs below (R1–R18) map 1:1 to the
document sections and are used for traceability in specs, the plan, and acceptance checks.

## Core non-negotiables (must be retained)
**Privacy (hidden reporter identity) · complaint tracking · priority · assignment · status flow ·
management dashboard · before/after repair evidence.**

## Requirement index
| ID | Requirement | Notes for build |
|----|-------------|-----------------|
| R1 | College-only complaint & maintenance app | Single-tenant (one college); access-controlled. |
| R2 | Faster, organized, trackable maintenance | Record → identify priority → assign → track → evidence. |
| R3 | Problem categories | Electrical; Plumbing/Water/Washroom; Civil/Building; Furniture; Cleanliness/Sanitation; IT/Network; Safety; Other. |
| R4 | Complaint registration | category + building + floor + room/location + photo(s) + description → **unique Complaint ID** + date/time. |
| R5 | **Privacy / hidden reporter identity** | Name, email, student ID, phone **never** on normal lists/boards/maintenance screens. Identity retained in backend only for auth/audit/admin. |
| R6 | Campus problem board | Authorized users see complaints **without reporter identity**: ID, category, location, photo, description, priority, date/time, status. Reduces duplicates. |
| R7 | Priority system | Critical / High / Medium / Low. Factors: safety risk, urgency, severity, people affected, location, category, waiting time. **Rule-based first**, AI later. |
| R8 | Department assignment | Electrical→Electrician; Plumbing/Washroom→Plumber; Furniture→Carpenter; Civil→Civil Maintenance; IT→IT Team; Cleanliness→Housekeeping. Auto or manual. |
| R9 | Complaint status flow | Reported → Reviewed → Assigned → In Progress → Resolved → Verified → Closed. Authorized management updates status. |
| R10 | Repair proof / verification | Staff upload **after-repair photo + resolution note**; verifier approves before closure; before/after linked to Complaint ID. |
| R11 | Notifications | Submission, assignment, status changes, completion, closure. Channel (push/email/SMS) developer-recommended. |
| R12 | Management / admin module | Secure admin area + dashboard: totals, pending, critical/high, assigned, in-progress, resolved, closed; view details, assign, change priority/status, view photos, monitor unresolved. |
| R13 | Main app screens | Login; Home; Report a Problem; Category; Location; Photo Upload; Complaint Details; Complaint ID/Confirmation; My Complaints/Status; Campus Problem Board; Notifications; Admin Dashboard. |
| R14 | Basic app flow | Login → Report → Category → Building/Floor/Room → Photo → Description → Submit → Complaint ID → Priority → Review → Assignment → Work Started → Completed → After-Repair Photo → Verification → Closed. |
| R15 | Advanced / future | AI image recognition, AI priority, QR room ID, heatmap, repeat detection, predictive maintenance, multilingual, web dashboard, analytics, cost/spare-parts, asset history. **Out of prototype scope** — tracked as backlog. |
| R16 | Developer technical freedom | Stack/db/auth/hosting/notifications/AI/architecture are our choice (see ARCHITECTURE.md). |
| R17 | Development approach | **Clickable/working prototype of main screens first**, then full development + testing. ← current phase. |
| R18 | Expected outcome | Quick reporting; protected identity on normal views; urgent issues prioritized; teams get assigned work; management monitors; repairs verified with evidence. |

## Decisions resolved with product owner (kickoff)
- **Platform:** Flutter mobile + Flutter Web admin.
- **Scope now:** Design system + clickable prototype on mock data; **stop before** Firebase backend.
- **Backend (Phase 2):** Firebase (Auth, Firestore, Storage, FCM).
- **Auth:** Student/Staff **ID + password** (mocked in prototype).
- **Roles:** Reporter (student/staff) · Maintenance staff (per department) · Verifier/Management · Admin.

## Open questions / assumptions (flag if wrong)
- A1: Notifications in the prototype are **in-app only** (a notifications screen + mock events). Real
  push/email/SMS is Phase 2. — *assumption, low risk.*
- A2: "Verifier" and "Management/Admin" may be the same people in a small college; modeled as
  distinct roles but a single user can hold both. — *assumption.*
- A3: One college / one campus for the prototype; multi-campus is a future concern. — *assumption.*
- A4: Photo uploads in the prototype use device gallery/camera mock or bundled sample images (no real
  storage until Phase 2). — *assumption.*
