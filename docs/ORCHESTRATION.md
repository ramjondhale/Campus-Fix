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

## Branch & worktree model
- Integration branch: **`integration`** (cut from `main` after scaffold). All verified work lands here.
- `main` holds only verified checkpoints the orchestrator promotes from `integration`.
- Each agent chunk gets a branch **`agent/<chunk-id>`** in a git worktree under
  `../campusfix-worktrees/<chunk-id>` (sibling dir, not committed).
- Flow per chunk:
  1. Orchestrator creates worktree+branch off `integration`.
  2. Agent implements in that worktree, runs allowed static checks, commits on its branch.
  3. Orchestrator merges `agent/<chunk-id>` → `integration`, resolves conflicts, **builds/verifies**.
  4. Orchestrator updates `RUN-LEDGER.md`, commits the checkpoint, deletes branch + worktree.

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
