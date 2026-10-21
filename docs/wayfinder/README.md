# M23 Wayfinder operating contract

> **Status:** inactive since 2026-08-01. This file documents how strategic
> decisions were made while the project was active. The `tickets/` directory
> described below is not included in this release; the map keeps only the
> decisions that link to published evidence.

This directory adapts Matt Pocock's Wayfinder decision-map framework to the
M23 inverse-Galois project. It is the durable strategic layer above the
project roadmap and numbered experiment notes.

The layers have different jobs:

1. `map.md` is the low-resolution index: destination, decisions already made,
   fog, and scope boundaries.
2. `tickets/` stores one sharp decision or investigation per file, including
   dependencies, claim state, and the eventual detailed resolution.
3. `docs/tests/`, `data/derived/`, and source code store reproducible evidence.
   Tickets link to that evidence; they do not restate it.
4. `docs/roadmap.md` is the milestone/history narrative. While the project was
   active, the Wayfinder map was authoritative for which strategic question was
   next.

## Why this is local Markdown

No tracker-specific Wayfinder setup has been selected for this repository.
The upstream framework defaults to a local Markdown tracker in that case.
Its stock local convention uses `.scratch/`; this adaptation deliberately uses
tracked files instead, satisfying the project's recovery and provenance needs.
The installed skill discovers the exact operations through
`docs/agents/issue-tracker.md`. A future decision may migrate the map to GitHub
issues or another local tracker, but migration is not implicit and two trackers
must never compete as canonical sources.

## Ticket schema

Each ticket begins with simple front matter:

```text
---
title: A human-readable decision name
type: research
mode: AFK
status: open
claim: unclaimed
blocked_by: none
---
```

Allowed types are `research`, `prototype`, `grilling`, and `task`. Allowed
modes are `AFK` and `HITL`. Status is `open` or `closed`. `blocked_by` is
`none` or a comma-separated list of ticket filenames. A claim is `unclaimed`
or a short human-readable session/owner name.

The body contains:

- `Question`: the decision or investigation being resolved;
- `Decision criteria`: what a sufficient answer must distinguish;
- `Resolution`: populated only when the ticket closes;
- `Evidence`: links to notes, artifacts, commits, or external sources.

The extra criteria and evidence headings are this project's adaptation. They
make expensive computational tickets falsifiable without turning the ticket
into an implementation checklist.

## Session protocol

1. Read `map.md`, then run:

   ```sh
   python3 scripts/wayfinder_status.py
   ```

2. Choose the first unclaimed frontier ticket unless the user names another.
   Edit its `claim` before substantive work.
3. Resolve one decision ticket in the session. Research tickets may be
   parallelized only when the user has authorized subagents.
4. Before resolving a strategic ticket or changing the selected frontier,
   run a bounded Codex/Fable adversarial review of the proposed decision and its
   selected evidence. Treat the review as advisory, record material objections
   and responses, and never substitute model agreement for a mathematical or
   computational certificate.
5. Put detailed reasoning in the ticket's `Resolution`, set it to `closed`,
   and link reproducible evidence.
6. Add one linked gist to `Decisions so far`. Create newly sharp tickets,
   wire their blockers, and move newly visible but still indistinct work into
   `Not yet specified`.
7. Run proportionate checks, including `make test` before a commit, then commit
   and push the decision state with its evidence.

## Planning and execution

Upstream Wayfinder plans by default. This project explicitly carries execution
inside the map because mathematical decisions are often resolved only by
computation. A ticket may authorize a bounded run when it states:

- what uncertainty the run resolves;
- deterministic inputs and stopping bounds;
- what result advances the route;
- what result redirects it;
- what result closes it;
- what independent certificate will support the conclusion.

Routine implementation needed by an already-made decision does not require a
new decision ticket. A long run with no stated decision payoff does.

## Codex/Fable review boundary

The repository's read-only adversarial-review harness
([`docs/adversarial-review.md`](../adversarial-review.md)) is the standard
second look for Wayfinder planning. A "Codex/Fable review" is one run of that
harness: Codex and Claude Fable each review the same evidence packet
independently, then each critiques the other's answer once. (Development notes
in the private history called the Codex reviewer "Sol".) Use it when a ticket
selects, redirects, or closes a strategic route, and when a map update
promotes a new frontier. The review
should receive the sharp question, declared decision criteria, compact
evidence, and proposed consequence. It should not receive secrets, operational
credentials, or large raw run directories.

Codex/Fable findings are planning evidence only. A review may expose a missing
control, overclaim, or cheaper discriminator; it cannot certify a computation,
prove a theorem, or authorize external action. Link the bounded review summary
from the ticket when it materially affects the resolution.

## Names and identifiers

Filenames have numeric prefixes only for stable local ordering. In prose, use
the ticket title as a link. Never refer to a decision merely as “ticket 0001”
or by a filename slug.
