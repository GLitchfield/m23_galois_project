#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TICKET_DIR = ROOT / "docs/wayfinder/tickets"
ALLOWED_TYPES = {"research", "prototype", "grilling", "task"}
ALLOWED_MODES = {"AFK", "HITL"}
ALLOWED_STATUSES = {"open", "closed"}


@dataclass(frozen=True)
class Ticket:
    path: Path
    title: str
    ticket_type: str
    mode: str
    status: str
    claim: str
    blockers: tuple[str, ...]


def read_ticket(path: Path) -> Ticket:
    lines = path.read_text().splitlines()
    if not lines or lines[0] != "---":
        raise ValueError(f"{path}: missing opening front-matter delimiter")
    try:
        end = lines.index("---", 1)
    except ValueError as error:
        raise ValueError(f"{path}: missing closing front-matter delimiter") from error
    metadata: dict[str, str] = {}
    for line in lines[1:end]:
        if ": " not in line:
            raise ValueError(f"{path}: invalid front-matter line {line!r}")
        key, value = line.split(": ", 1)
        if key in metadata:
            raise ValueError(f"{path}: duplicate {key!r} field")
        metadata[key] = value
    required = {"title", "type", "mode", "status", "claim", "blocked_by"}
    if set(metadata) != required:
        raise ValueError(
            f"{path}: front matter must contain exactly {sorted(required)}"
        )
    if metadata["type"] not in ALLOWED_TYPES:
        raise ValueError(f"{path}: invalid type {metadata['type']!r}")
    if metadata["mode"] not in ALLOWED_MODES:
        raise ValueError(f"{path}: invalid mode {metadata['mode']!r}")
    if metadata["status"] not in ALLOWED_STATUSES:
        raise ValueError(f"{path}: invalid status {metadata['status']!r}")
    blockers = (
        ()
        if metadata["blocked_by"] == "none"
        else tuple(part.strip() for part in metadata["blocked_by"].split(","))
    )
    body = "\n".join(lines[end + 1 :])
    for heading in ("## Question", "## Decision criteria", "## Resolution", "## Evidence"):
        if heading not in body:
            raise ValueError(f"{path}: missing {heading!r}")
    return Ticket(
        path=path,
        title=metadata["title"],
        ticket_type=metadata["type"],
        mode=metadata["mode"],
        status=metadata["status"],
        claim=metadata["claim"],
        blockers=blockers,
    )


def main() -> None:
    tickets = [read_ticket(path) for path in sorted(TICKET_DIR.glob("*.md"))]
    by_name = {ticket.path.name: ticket for ticket in tickets}
    if len(by_name) != len(tickets):
        raise ValueError("duplicate ticket filename")
    for ticket in tickets:
        for blocker in ticket.blockers:
            if blocker not in by_name:
                raise ValueError(f"{ticket.path}: unknown blocker {blocker!r}")
            if blocker == ticket.path.name:
                raise ValueError(f"{ticket.path}: ticket blocks itself")

    frontier: list[Ticket] = []
    blocked: list[tuple[Ticket, list[Ticket]]] = []
    claimed: list[Ticket] = []
    for ticket in tickets:
        if ticket.status == "closed":
            continue
        unresolved = [
            by_name[name]
            for name in ticket.blockers
            if by_name[name].status != "closed"
        ]
        if unresolved:
            blocked.append((ticket, unresolved))
        elif ticket.claim != "unclaimed":
            claimed.append(ticket)
        else:
            frontier.append(ticket)

    print("Frontier:")
    if frontier:
        for ticket in frontier:
            print(f"- {ticket.title} [{ticket.ticket_type}/{ticket.mode}]")
    else:
        print("- none")
    print("Claimed:")
    if claimed:
        for ticket in claimed:
            print(f"- {ticket.title} [{ticket.claim}]")
    else:
        print("- none")
    print("Blocked:")
    if blocked:
        for ticket, unresolved in blocked:
            names = ", ".join(blocker.title for blocker in unresolved)
            print(f"- {ticket.title} <- {names}")
    else:
        print("- none")


if __name__ == "__main__":
    main()
