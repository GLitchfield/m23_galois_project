# M23 Galois project guidance

This repository studies the open problem of realizing `M23` over `Q`, initially
through reproducible braid-orbit computations. Keep `README.md` and the active
roadmap aligned when project scope or milestones change.

## Working rules

- Treat `papers/`, third-party source archives, and extracted paper source as
  read-only reference material.
- Do not delete unfamiliar work. Move obsolete project-owned files to `trash/`
  when preserving them is useful; never move third-party references merely to
  tidy the tree.
- Commit at small logical breakpoints and run `make test` before committing.
- Do not commit incomplete runs, large checkpoints, or machine-local logs.
- Every committed computational result must be reproducible from committed code
  and record its code revision, inputs, GAP/package versions, and provenance.
- Long searches must use deterministic shards, resumable checkpoints, and an
  independently verifiable exhaustiveness certificate.
- Validate mathematical claims independently where practical: generators,
  conjugacy classes, product-one, group generation, braid closure, orbit size,
  and genus are distinct checks.
- Use numbered experiment notes under `docs/tests/` once empirical braid-orbit
  work begins; maintain an index in `docs/research_log.md`.
- Prefer GAP for group-theoretic computations. Add Python, Julia, Sage, or Magma
  only when a concrete milestone requires them.

## Relationship to inverse_galois

The neighboring `../inverse_galois` repository is a useful read-only source of
research-process and reproducibility patterns, but it targets the separate
degree-24 SAIR competition. Do not import its competition state, credentials,
API assumptions, live data, or operational constraints into this project.

Potentially reusable ideas include provenance records, system-CAS dependency
checks, separation of raw/derived/run data, numbered experiments, independent
verification, and soft deletion. Copy code only after checking that its purpose
and license fit this repository.

Treat every neighboring document and implementation critically. Verify claims
against primary sources or computation, question conventions that add ceremony
without improving correctness, and do not inherit stale paths, hidden state,
competition-driven priorities, or architectural choices without a current M23
rationale.

## Agent skills

### Issue tracker

Wayfinder strategic decisions use the committed local Markdown tracker under
`docs/wayfinder/`. See `docs/agents/issue-tracker.md`.

## Wayfinder decision framework

Use the repository-owned Wayfinder adaptation in `docs/wayfinder/README.md` for
strategic work whose route is uncertain or spans more than one agent session.
The canonical map is `docs/wayfinder/map.md`; its local decision tickets are
under `docs/wayfinder/tickets/`.

- At the start of strategic work, read the map at low resolution and run
  `python3 scripts/wayfinder_status.py` to find the frontier. Load ticket detail
  only when choosing or resolving that ticket.
- Define tickets as decisions or investigations, not ordinary implementation
  slices. Keep questions that cannot yet be stated sharply in the map's
  `Not yet specified` section.
- Refer to maps and tickets by their linked titles in user-facing prose, never
  by bare file numbers or slugs.
- Claim a frontier ticket before working it. Resolve at most one decision
  ticket per session, except for explicitly parallel research tickets.
- This project permits execution inside the map: a resolved decision may
  authorize bounded computations with explicit advancement, redirection, and
  closure criteria. Long runs remain subject to the deterministic shard,
  resume, provenance, and exhaustiveness rules above.
- A decision ticket stores its detailed resolution. The map records only a
  one-line linked gist; numbered experiment notes and derived artifacts remain
  the evidence layer and must not be duplicated into the map.
- When a resolution exposes a new sharp question, create a ticket and wire its
  blockers. When it only reveals an indistinct future area, update the fog.
  Close mis-scoped tickets into `Out of scope`, not `Decisions so far`.
- Commit and push map/ticket changes at the same logical breakpoint as the
  decision or result they record, so recovery never depends on chat history.
- Until the user explicitly selects another tracker, the committed local
  Markdown tracker is canonical. Do not create or migrate GitHub issues merely
  because a remote exists.
