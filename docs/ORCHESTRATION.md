# CampusFix AI — Orchestration Protocol

How this project is built: one **Opus orchestrator** (the chat session) + **Sonnet worker agents**.
This exists to keep Opus (expensive) focused on planning/decisions/verification and push
implementation, exploration, and analysis onto cheaper Sonnet agents.

## Roles
| Actor | Model | Responsibilities |
|-------|-------|------------------|
| **Orchestrator** | Opus (this chat) | Plan, decide architecture, write/curate the contract docs, dispatch agents, **merge**, **build**, **verify**, screenshot, update run ledger, clean up worktrees/branches, checkpoint. |
| **Worker agent** | Sonnet | One chunk at a time: explore / analyze / implement code + unit tests / write specs. Works in an isolated branch. Does **not** merge, does **not** run full app builds. |

## Hard rules (from product owner)
1. **≤ 4 agents in parallel.** Never dispatch a 5th until one of the 4 returns.
2. **No simultaneous full builds by agents.** Agents may run *static* checks on their own package
   (`dart format`, `dart analyze`, and `dart test` for a pure-Dart package only). Agents must **not**
   run `flutter run`, `flutter build`, iOS/web app builds, or launch simulators. All app builds and
   cross-package verification happen **only in the orchestrator**, serially, after merge.
3. **Orchestrator owns integration.** Agents push code to their branch; the orchestrator merges into
   the integration branch, resolves conflicts, builds, and verifies.
4. **Checkpoint everything.** After every completed chunk (agent or orchestrator), commit with a
   `[chunk-id]` prefixed message and update `RUN-LEDGER.md`. Work is never left only in an agent's
   head or an un-committed tree.
5. **Clean up after merge.** Once an agent's branch is merged and verified, delete the branch and
   remove its worktree.
6. **Design system is law — no UI drift.** Every UI agent MUST style exclusively through the design
   system: `campusfix_design` theme tokens, `ThemeExtension`s (`CampusColors`, category/priority/status
   palettes), the `BuildContext` helpers, and the shared widgets. **No raw `Colors.*`, `Color(0x…)`,
   literal hex, ad-hoc `TextStyle`, or hardcoded sizes/radii in app code** (`Colors.transparent` is the
   only allowed literal). Need a color/role that doesn't exist? Add it to the design system (and
   `design-system.md`), don't inline it. The orchestrator greps every merged UI chunk for raw colors
   and rejects drift. This keeps the final UI faithful to `docs/design/design-system.md` and the
   published style guide.
7. **Prefer FOREGROUND agents for Flutter app chunks.** Background agents have been killed by a stream
   watchdog; foreground dispatch (`run_in_background: false`) is reliable. Agents must **commit code in
   stages** before running slow `flutter` commands, so any interruption is salvageable.

## Branch & worktree model
- Trunk (the orchestrator's integration branch): **`main`**. All verified work lands here; every
  commit on `main` is a checkpoint.
- Each agent chunk gets a branch **`agent/<chunk-id>`** in a git worktree under
  `../campusfix-worktrees/<chunk-id>` (sibling dir, not committed), cut from the current `main`.
- Flow per chunk:
  1. Orchestrator creates worktree + branch `agent/<chunk-id>` off `main`.
  2. Agent implements in that worktree, runs allowed static checks, commits on its branch.
  3. Orchestrator merges `agent/<chunk-id>` → `main`, resolves conflicts, **builds/verifies**.
  4. Orchestrator updates `RUN-LEDGER.md`, commits the checkpoint, removes the worktree + deletes the
     branch.

> Note: Sonnet agents dispatched via the `Agent` tool share this repo's working tree by default. To
> honor rules 2–3 and avoid clobbering, the orchestrator assigns each parallel agent a **disjoint set
> of files/directories** per wave, or runs them in isolated worktrees (`isolation: worktree`) when
> file overlap is possible. Agents are told their exact file boundaries in the dispatch brief.

## Agent dispatch brief (template)
Every agent is given: the chunk ID + goal, the exact files/dirs it owns (and must not touch others),
the relevant spec doc(s), acceptance criteria, the "no full builds / no simulators" rule, and an
instruction to end by reporting: files changed, static-check results, and anything the orchestrator
must verify.

## Verification gate (orchestrator, after each merge)
- `dart analyze` clean across touched packages.
- `dart test` green for `campusfix_core` (and any package with tests).
- For UI chunks: `flutter build` (or `flutter run` smoke) for the affected app; capture a screenshot
  where a visual deliverable is claimed.
- Only then: mark the chunk ✅ in the ledger, commit, clean up.

## Resume protocol
`RUN-LEDGER.md` is the single source of truth for progress. To resume after any interruption: read it,
find the first non-✅ chunk whose dependencies are ✅, and continue. Every ledger row names its
checkpoint commit so state is reconstructable.
