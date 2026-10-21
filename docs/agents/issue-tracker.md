# Issue tracker: committed local Markdown

Wayfinder strategic decisions for this repository live under
`docs/wayfinder/` and are committed and pushed with the evidence they govern.
This is an intentionally narrower tracker than a general implementation
backlog.

The upstream local-Markdown template uses `.scratch/`. This project instead
uses a tracked directory because strategic state must survive machine loss,
branch changes, and chat compaction. Do not create a parallel `.scratch`
Wayfinder map.

## Conventions

- The canonical map is `docs/wayfinder/map.md`.
- Decision tickets are individual files under `docs/wayfinder/tickets/`.
- Numeric filename prefixes provide stable ordering only. Human-facing prose
  uses linked ticket titles.
- Ticket front matter records type, mode, status, claim, and blockers.
- Detailed resolutions live in the ticket. The map receives only a linked
  one-line gist.
- Numbered experiment notes and derived artifacts remain the evidence layer.

## When a skill says “publish to the issue tracker”

For Wayfinder work, create or update the appropriate file under
`docs/wayfinder/` using the schema in `docs/wayfinder/README.md`. Do not create
GitHub issues or install another tracker unless the user explicitly changes
this configuration.

## When a skill says “fetch the relevant ticket”

Read the named file under `docs/wayfinder/tickets/`. If only a title is given,
run `python3 scripts/wayfinder_status.py` and match by the human-readable
title.

## Wayfinding operations

- **Map**: `docs/wayfinder/map.md`.
- **Child ticket**: one file under `docs/wayfinder/tickets/`, following the
  front-matter and body schema in `docs/wayfinder/README.md`.
- **Blocking**: `blocked_by` lists ticket filenames. A ticket is unblocked when
  every listed ticket has `status: closed`.
- **Frontier**: run `python3 scripts/wayfinder_status.py`. The first unclaimed,
  unblocked ticket by filename wins unless the user names another.
- **Claim**: replace `claim: unclaimed` with a short session or owner name
  before substantive work. Status remains `open` while claimed.
- **Resolve**: write the detailed answer under `## Resolution`, link evidence,
  set `status: closed`, and reset the claim only if useful for history. Append
  a linked one-line gist to the map's `Decisions so far`.
- **New visibility**: create and wire newly sharp questions. Keep indistinct
  in-scope work in `Not yet specified`; move beyond-destination work to
  `Out of scope`.
- **Durability**: validate, commit, and push tracker changes at the same logical
  breakpoint as the decision or evidence.
