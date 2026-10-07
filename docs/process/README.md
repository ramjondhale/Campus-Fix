# Build-process archive

These are the **process artifacts** from building the CampusFix prototype, kept for history. They are
not needed to use, run, or understand the product — for that, start at the repo
[README](../../README.md) and the [Walkthrough](../WALKTHROUGH.md).

| File | What it is |
|---|---|
| [PLAN.md](PLAN.md) | The master build plan — sections (epics) broken into agent-sized chunks and execution waves. |
| [RUN-LEDGER.md](RUN-LEDGER.md) | The live progress tracker / checkpoint log kept during the build (every chunk, its merge commit, and test counts). |
| [ORCHESTRATION.md](ORCHESTRATION.md) | How the build ran: an Opus orchestrator dispatching Sonnet worker agents, with the hard rules (design-system fidelity, privacy, verify gates). |

The product/reference docs live one level up in [`docs/`](../): architecture, requirements, build
instructions, the walkthrough, the Phase-2 Firebase plan, the design system, and the detailed specs.
