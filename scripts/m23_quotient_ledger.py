#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sqlite3
import sys
import time
from pathlib import Path
from typing import TextIO


SCHEMA = """
CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS certificates (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  status TEXT NOT NULL CHECK(status IN ('closed','overflow','linked')),
  walk_status TEXT NOT NULL CHECK(walk_status IN ('closed','overflow','linked')),
  linked_certificate INTEGER REFERENCES certificates(id),
  seed_ordinal INTEGER NOT NULL,
  seed_twist INTEGER NOT NULL,
  checked_vertices INTEGER NOT NULL,
  discovered_vertices INTEGER NOT NULL,
  discovered_classes INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS vertices (
  ordinal INTEGER NOT NULL,
  twist INTEGER NOT NULL,
  certificate INTEGER NOT NULL REFERENCES certificates(id),
  PRIMARY KEY (ordinal, twist)
) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS certificate_vertices (
  certificate INTEGER NOT NULL REFERENCES certificates(id),
  position INTEGER NOT NULL,
  ordinal INTEGER NOT NULL,
  twist INTEGER NOT NULL,
  PRIMARY KEY (certificate, position),
  FOREIGN KEY (ordinal, twist) REFERENCES vertices(ordinal, twist)
) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS frontier (
  sequence INTEGER PRIMARY KEY AUTOINCREMENT,
  ordinal INTEGER NOT NULL UNIQUE
);
CREATE TABLE IF NOT EXISTS planned_work (
  sequence INTEGER PRIMARY KEY AUTOINCREMENT,
  ordinal INTEGER NOT NULL UNIQUE,
  shard_index INTEGER NOT NULL,
  shard_count INTEGER NOT NULL,
  CHECK(shard_count > 0 AND shard_index > 0 AND shard_index <= shard_count)
);
CREATE TABLE IF NOT EXISTS blocks (
  sequence INTEGER PRIMARY KEY AUTOINCREMENT,
  ordinal INTEGER NOT NULL UNIQUE,
  source TEXT NOT NULL CHECK(source IN ('ordinal','frontier')),
  refined_vertices INTEGER NOT NULL,
  generating_vertices INTEGER NOT NULL,
  new_certificates INTEGER NOT NULL,
  ledger_hits INTEGER NOT NULL,
  worker TEXT,
  shard_index INTEGER NOT NULL DEFAULT 1,
  shard_count INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS leases (
  worker TEXT PRIMARY KEY,
  ordinal INTEGER NOT NULL UNIQUE,
  source TEXT NOT NULL CHECK(source IN ('ordinal','frontier')),
  expires REAL NOT NULL,
  shard_index INTEGER NOT NULL DEFAULT 1,
  shard_count INTEGER NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS vertices_certificate_idx ON vertices(certificate);
CREATE INDEX IF NOT EXISTS certificates_seed_ordinal_idx
  ON certificates(seed_ordinal);
CREATE INDEX IF NOT EXISTS planned_work_shard_idx
  ON planned_work(shard_count,shard_index,sequence);
"""


class Ledger:
    def __init__(self, path: Path, readonly: bool = False):
        self.path = path
        if readonly:
            self.db = sqlite3.connect(
                f"file:{path.resolve()}?mode=ro", uri=True, timeout=300
            )
            self.db.execute("PRAGMA foreign_keys=ON")
            self.db.execute("PRAGMA busy_timeout=300000")
            return
        path.parent.mkdir(parents=True, exist_ok=True)
        self.db = sqlite3.connect(path, timeout=300)
        self.db.execute("PRAGMA foreign_keys=ON")
        self.db.execute("PRAGMA busy_timeout=300000")
        # Switching journal modes takes an exclusive lock.  Reissuing that
        # PRAGMA in every worker can therefore strand late-starting workers
        # behind an already active writer even when the database is in WAL
        # mode.  Only perform schema/journal setup for a new ledger; the
        # parallel launcher prepares it once before workers are forked.
        has_schema = self.db.execute(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name='meta'"
        ).fetchone() is not None
        if not has_schema:
            self.db.execute("PRAGMA journal_mode=WAL")
            self.db.execute("PRAGMA synchronous=FULL")
            self.db.executescript(SCHEMA)
        elif self.db.execute("PRAGMA journal_mode").fetchone()[0].lower() != "wal":
            self.db.execute("PRAGMA journal_mode=WAL")
        self.db.execute("PRAGMA synchronous=FULL")
        self._ensure_columns("blocks", {
            "worker": "TEXT",
            "shard_index": "INTEGER NOT NULL DEFAULT 1",
            "shard_count": "INTEGER NOT NULL DEFAULT 1",
        })
        self._ensure_columns("leases", {
            "shard_index": "INTEGER NOT NULL DEFAULT 1",
            "shard_count": "INTEGER NOT NULL DEFAULT 1",
        })
        self._ensure_index(
            "certificates_seed_ordinal_idx",
            "CREATE INDEX certificates_seed_ordinal_idx "
            "ON certificates(seed_ordinal)",
        )
        self._prune_completed_frontier()

    def _ensure_columns(self, table: str, columns: dict[str, str]) -> None:
        existing = {row[1] for row in self.db.execute(f"PRAGMA table_info({table})")}
        with self.db:
            for name, declaration in columns.items():
                if name not in existing:
                    self.db.execute(
                        f"ALTER TABLE {table} ADD COLUMN {name} {declaration}"
                    )

    def _ensure_index(self, name: str, declaration: str) -> None:
        exists = self.db.execute(
            "SELECT 1 FROM sqlite_master WHERE type='index' AND name=?",
            (name,),
        ).fetchone()
        if exists is None:
            with self.db:
                self.db.execute(declaration)

    def _prune_completed_frontier(self) -> None:
        # `blocks` is the durable history, including whether an item came from
        # the frontier.  Keeping completed rows in the scheduling table makes
        # every future claim scan the whole history.  Old ledgers are migrated
        # lazily; current finishes remove their row in the same transaction.
        completed = self.db.execute(
            "SELECT 1 FROM frontier f JOIN blocks b USING(ordinal) LIMIT 1"
        ).fetchone()
        if completed is not None:
            with self.db:
                self.db.execute(
                    "DELETE FROM frontier WHERE ordinal IN "
                    "(SELECT ordinal FROM blocks)"
                )

    def close(self) -> None:
        self.db.close()

    def _meta(self, key: str) -> str | None:
        row = self.db.execute("SELECT value FROM meta WHERE key=?", (key,)).fetchone()
        return row[0] if row else None

    def _set_meta(self, key: str, value: object) -> None:
        self.db.execute(
            "INSERT INTO meta(key,value) VALUES(?,?) "
            "ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            (key, str(value)),
        )

    def initialize(self, config: dict[str, object]) -> None:
        existing = self._meta("schema_version")
        normalized = {key: str(value) for key, value in config.items()}
        if existing is None:
            with self.db:
                self._set_meta("schema_version", 1)
                for key, value in normalized.items():
                    self._set_meta("config_" + key, value)
                self._set_meta("sequential_next", normalized["start_ordinal"])
                self._set_meta("sequential_wrapped", 0)
            return
        if existing != "1":
            raise ValueError(f"unsupported ledger schema {existing}")
        for key, value in normalized.items():
            stored = self._meta("config_" + key)
            if key == "traversal_order" and stored is None:
                stored = "legacy"
            if stored != value:
                raise ValueError(f"ledger configuration mismatch for {key}")

    def lookup(self, ordinal: int, twist: int) -> int | None:
        row = self.db.execute(
            "SELECT certificate FROM vertices WHERE ordinal=? AND twist=?",
            (ordinal, twist),
        ).fetchone()
        return row[0] if row else None

    def lookup_before(self, ordinal: int, twist: int,
                      max_certificate: int) -> int | None:
        if max_certificate < 0:
            raise ValueError("maximum certificate must be nonnegative")
        row = self.db.execute(
            "SELECT certificate FROM vertices "
            "WHERE ordinal=? AND twist=? AND certificate<=?",
            (ordinal, twist, max_certificate),
        ).fetchone()
        return row[0] if row else None

    def add_certificate(self, data: dict[str, object],
                        vertices: list[tuple[int, int]]) -> int:
        if not vertices or len(vertices) != int(data["discovered_vertices"]):
            raise ValueError("certificate vertex count mismatch")
        with self.db:
            return self._insert_certificate(data, vertices)

    def _insert_certificate(self, data: dict[str, object],
                            vertices: list[tuple[int, int]]) -> int:
        linked = data.get("linked_certificate")
        cursor = self.db.execute(
            "INSERT INTO certificates(status,walk_status,linked_certificate,"
            "seed_ordinal,seed_twist,checked_vertices,discovered_vertices,"
            "discovered_classes) VALUES(?,?,?,?,?,?,?,?)",
            (
                data["status"], data["walk_status"], linked,
                data["seed_ordinal"], data["seed_twist"],
                data["checked_vertices"], data["discovered_vertices"],
                data["discovered_classes"],
            ),
        )
        certificate = int(cursor.lastrowid)
        self.db.executemany(
            "INSERT INTO vertices(ordinal,twist,certificate) VALUES(?,?,?)",
            ((ordinal, twist, certificate) for ordinal, twist in vertices),
        )
        self.db.executemany(
            "INSERT INTO certificate_vertices(certificate,position,ordinal,twist) "
            "VALUES(?,?,?,?)",
            ((certificate, position, ordinal, twist)
             for position, (ordinal, twist) in enumerate(vertices, 1)),
        )
        if self._meta("config_schedule") == "frontier":
            first = int(self._meta("config_first_ordinal") or 0)
            last = int(self._meta("config_last_ordinal") or -1)
            self.db.executemany(
                "INSERT OR IGNORE INTO frontier(ordinal) "
                "SELECT ? WHERE NOT EXISTS "
                "(SELECT 1 FROM blocks WHERE ordinal=?)",
                ((ordinal, ordinal) for ordinal in dict.fromkeys(
                    ordinal for ordinal, _ in vertices
                    if first <= ordinal <= last)),
            )
        return certificate

    def try_add_certificate(self, worker: str, ordinal: int,
                            data: dict[str, object],
                            vertices: list[tuple[int, int]]) -> tuple[str, int]:
        if not vertices or len(vertices) != int(data["discovered_vertices"]):
            raise ValueError("certificate vertex count mismatch")
        with self.db:
            # Acquire the writer lock before checking for overlap, so another
            # worker cannot commit a conflicting vertex between the check and
            # the certificate insertion.
            self.db.execute("BEGIN IMMEDIATE")
            lease = self.db.execute(
                "SELECT ordinal FROM leases WHERE worker=? AND expires>?",
                (worker, time.time()),
            ).fetchone()
            if lease is None or lease[0] != ordinal:
                raise ValueError("worker does not hold the active block lease")
            for vertex_ordinal, twist in vertices:
                conflict = self.lookup(vertex_ordinal, twist)
                if conflict is not None:
                    return "conflict", conflict
            return "added", self._insert_certificate(data, vertices)

    def _processed(self, ordinal: int) -> bool:
        return self.db.execute(
            "SELECT 1 FROM blocks WHERE ordinal=?", (ordinal,)
        ).fetchone() is not None

    def enqueue_special_block(self, ordinal: int) -> None:
        """Queue an explicitly audited block outside the configured scan range."""
        macroblock_count = int(self._meta("config_macroblock_count") or 0)
        if ordinal < 1 or ordinal > macroblock_count:
            raise ValueError("special block ordinal is outside the macroblock census")
        if self._processed(ordinal):
            raise ValueError("special block is already processed")
        if self._meta("active_ordinal") == str(ordinal):
            raise ValueError("special block is already active")
        if self.db.execute(
                "SELECT 1 FROM leases WHERE ordinal=?", (ordinal,)
        ).fetchone():
            raise ValueError("special block already has a lease")
        with self.db:
            self.db.execute(
                "INSERT OR IGNORE INTO frontier(ordinal) VALUES(?)", (ordinal,)
            )

    def next_block(self) -> tuple[int, str] | None:
        active = self._meta("active_ordinal")
        if active is not None:
            return int(active), str(self._meta("active_source"))
        row = self.db.execute(
            "SELECT ordinal FROM frontier ORDER BY sequence LIMIT 1"
        ).fetchone()
        if row:
            with self.db:
                self._set_meta("active_ordinal", row[0])
                self._set_meta("active_source", "frontier")
            return int(row[0]), "frontier"

        first = int(self._meta("config_first_ordinal") or 0)
        last = int(self._meta("config_last_ordinal") or -1)
        start = int(self._meta("config_start_ordinal") or first)
        candidate = int(self._meta("sequential_next") or start)
        wrapped = self._meta("sequential_wrapped") == "1"
        while True:
            if not wrapped:
                if candidate <= last:
                    chosen = candidate
                    candidate += 1
                elif start > first:
                    wrapped = True
                    candidate = first
                    continue
                else:
                    return None
            else:
                if candidate < start:
                    chosen = candidate
                    candidate += 1
                else:
                    return None
            with self.db:
                self._set_meta("sequential_next", candidate)
                self._set_meta("sequential_wrapped", int(wrapped))
                if not self._processed(chosen):
                    self._set_meta("active_ordinal", chosen)
                    self._set_meta("active_source", "ordinal")
                    return chosen, "ordinal"

    @staticmethod
    def _owned_at_or_after(first: int, last: int, candidate: int,
                           shard_index: int, shard_count: int) -> int | None:
        candidate += (shard_index - 1 - (candidate - first)) % shard_count
        return candidate if candidate <= last else None

    def claim_block(self, worker: str, lease_seconds: int,
                    block_target: int = 0, shard_index: int = 1,
                    shard_count: int = 1) -> tuple[int, str] | str | None:
        if lease_seconds < 1:
            raise ValueError("lease duration must be positive")
        if shard_count < 1 or shard_index < 0 or shard_index > shard_count:
            raise ValueError("invalid deterministic shard index/count")
        dynamic_shards = shard_index == 0
        now = time.time()
        with self.db:
            self.db.execute("DELETE FROM leases WHERE expires<=?", (now,))
            existing = self.db.execute(
                "SELECT ordinal,source,shard_index,shard_count FROM leases "
                "WHERE worker=?", (worker,)
            ).fetchone()
            if existing:
                if existing[3] != shard_count or (
                    not dynamic_shards and existing[2] != shard_index
                ):
                    raise ValueError("worker lease has different shard assignment")
                self.db.execute(
                    "UPDATE leases SET expires=? WHERE worker=?",
                    (now + lease_seconds, worker),
                )
                return int(existing[0]), str(existing[1])
            if block_target > 0:
                committed = self.db.execute("SELECT COUNT(*) FROM blocks").fetchone()[0]
                active = self.db.execute("SELECT COUNT(*) FROM leases").fetchone()[0]
                if committed + active >= block_target:
                    return None
            first = int(self._meta("config_first_ordinal") or 0)
            last = int(self._meta("config_last_ordinal") or -1)
            row = self.db.execute(
                "SELECT f.ordinal FROM frontier f "
                "LEFT JOIN leases l USING(ordinal) "
                "WHERE l.ordinal IS NULL "
                "AND (? = 1 OR ((f.ordinal - ?) % ?) = ?) "
                "ORDER BY f.sequence LIMIT 1",
                (int(dynamic_shards), first, shard_count, shard_index - 1),
            ).fetchone()
            if row:
                chosen, source = int(row[0]), "frontier"
            else:
                if shard_count == 1 and self.db.execute(
                    "SELECT 1 FROM leases LIMIT 1"
                ).fetchone():
                    return "wait"
                start = int(self._meta("config_start_ordinal") or first)
                scheduling_index = 1 if dynamic_shards else shard_index
                scheduling_count = 1 if dynamic_shards else shard_count
                suffix = ("" if scheduling_count == 1 else
                          f"_{scheduling_index}_of_{scheduling_count}")
                next_key = "sequential_next" + suffix
                wrapped_key = "sequential_wrapped" + suffix
                initial = self._owned_at_or_after(
                    first, last, start, scheduling_index, scheduling_count
                )
                if initial is None:
                    initial = last + shard_count
                candidate = int(self._meta(next_key) or initial)
                wrapped = self._meta(wrapped_key) == "1"
                chosen = None
                while chosen is None:
                    if not wrapped:
                        if candidate <= last:
                            proposed = candidate
                            candidate += scheduling_count
                        elif start > first:
                            wrapped = True
                            candidate = self._owned_at_or_after(
                                first, last, first,
                                scheduling_index, scheduling_count
                            )
                            if candidate is None:
                                return None
                            continue
                        else:
                            return None
                    else:
                        if candidate < start:
                            proposed = candidate
                            candidate += scheduling_count
                        else:
                            return None
                    self._set_meta(next_key, candidate)
                    self._set_meta(wrapped_key, int(wrapped))
                    if not self._processed(proposed) and self.db.execute(
                        "SELECT 1 FROM leases WHERE ordinal=?", (proposed,)
                    ).fetchone() is None:
                        chosen, source = proposed, "ordinal"
            self.db.execute("INSERT OR IGNORE INTO frontier(ordinal) VALUES(?)", (chosen,))
            assigned_shard = 1 + ((chosen - first) % shard_count)
            self.db.execute(
                "INSERT INTO leases(worker,ordinal,source,expires,shard_index,"
                "shard_count) VALUES(?,?,?,?,?,?)",
                (worker, chosen, source, now + lease_seconds,
                 assigned_shard, shard_count),
            )
            return chosen, source

    def renew_lease(self, worker: str, ordinal: int, lease_seconds: int) -> None:
        with self.db:
            cursor = self.db.execute(
                "UPDATE leases SET expires=? WHERE worker=? AND ordinal=? AND expires>?",
                (time.time() + lease_seconds, worker, ordinal, time.time()),
            )
            if cursor.rowcount != 1:
                raise ValueError("cannot renew absent or expired block lease")

    def finish_worker_block(self, worker: str, ordinal: int, source: str,
                            refined: int, generating: int) -> None:
        with self.db:
            self.db.execute("BEGIN IMMEDIATE")
            lease = self.db.execute(
                "SELECT ordinal,source,shard_index,shard_count FROM leases "
                "WHERE worker=? AND expires>?",
                (worker, time.time()),
            ).fetchone()
            if lease is None or lease[:2] != (ordinal, source):
                raise ValueError("finished block does not match worker lease")
            new_certificates = self.db.execute(
                "SELECT COUNT(*) FROM certificates WHERE seed_ordinal=?", (ordinal,)
            ).fetchone()[0]
            hits = generating - new_certificates
            self.db.execute(
                "INSERT INTO blocks(ordinal,source,refined_vertices,generating_vertices,"
                "new_certificates,ledger_hits,worker,shard_index,shard_count) "
                "VALUES(?,?,?,?,?,?,?,?,?)",
                (ordinal, source, refined, generating, new_certificates, hits,
                 worker, lease[2], lease[3]),
            )
            self.db.execute("DELETE FROM frontier WHERE ordinal=?", (ordinal,))
            self.db.execute("DELETE FROM leases WHERE worker=?", (worker,))

    def finish_block(self, ordinal: int, source: str, refined: int,
                     generating: int) -> None:
        if self._meta("active_ordinal") != str(ordinal) or \
                self._meta("active_source") != source:
            raise ValueError("finished block does not match active lease")
        with self.db:
            new_certificates = self.db.execute(
                "SELECT COUNT(*) FROM certificates WHERE seed_ordinal=?",
                (ordinal,),
            ).fetchone()[0]
            hits = generating - new_certificates
            if hits < 0:
                raise ValueError("block has more seed certificates than generating vertices")
            self.db.execute(
                "INSERT INTO blocks(ordinal,source,refined_vertices,generating_vertices,"
                "new_certificates,ledger_hits) VALUES(?,?,?,?,?,?)",
                (ordinal, source, refined, generating, new_certificates, hits),
            )
            self.db.execute("DELETE FROM frontier WHERE ordinal=?", (ordinal,))
            self.db.execute("DELETE FROM meta WHERE key IN ('active_ordinal','active_source')")

    def stats(self) -> dict[str, int]:
        blocks = self.db.execute(
            "SELECT COUNT(*),COALESCE(SUM(source='frontier'),0),"
            "COALESCE(SUM(new_certificates=0),0),COALESCE(SUM(refined_vertices),0),"
            "COALESCE(SUM(generating_vertices),0),COALESCE(SUM(ledger_hits),0) FROM blocks"
        ).fetchone()
        certificates = self.db.execute(
            "SELECT COUNT(*),COALESCE(SUM(status='closed'),0),"
            "COALESCE(SUM(status='overflow'),0),COALESCE(SUM(status='linked'),0) "
            "FROM certificates"
        ).fetchone()
        vertices = self.db.execute("SELECT COUNT(*) FROM vertices").fetchone()[0]
        pending = self.db.execute("SELECT COUNT(*) FROM frontier").fetchone()[0]
        database_bytes = (
            self.db.execute("PRAGMA page_count").fetchone()[0]
            * self.db.execute("PRAGMA page_size").fetchone()[0]
        )
        return dict(zip(
            ("blocks", "frontier_blocks", "covered_blocks", "refined_vertices",
             "generating_vertices", "ledger_hits", "certificates", "closed",
             "overflow", "linked", "vertices", "pending", "database_bytes"),
            (*blocks, *certificates, vertices, pending, database_bytes),
        ))

    def certificate(self, certificate: int) -> tuple[sqlite3.Row | tuple, list[tuple[int, int]]]:
        row = self.db.execute(
            "SELECT id,status,walk_status,linked_certificate,seed_ordinal,seed_twist,"
            "checked_vertices,discovered_vertices,discovered_classes "
            "FROM certificates WHERE id=?", (certificate,)
        ).fetchone()
        if row is None:
            raise KeyError(certificate)
        vertices = self.db.execute(
            "SELECT ordinal,twist FROM certificate_vertices WHERE certificate=? "
            "ORDER BY position", (certificate,)
        ).fetchall()
        return row, vertices

    def blocks(self) -> list[tuple]:
        return self.db.execute(
            "SELECT ordinal,source,refined_vertices,generating_vertices,"
            "new_certificates,ledger_hits FROM blocks ORDER BY sequence"
        ).fetchall()

    def block(self, ordinal: int) -> tuple:
        row = self.db.execute(
            "SELECT ordinal,source,refined_vertices,generating_vertices,"
            "new_certificates,ledger_hits,"
            "(SELECT COUNT(*) FROM certificates c "
            " WHERE c.seed_ordinal=blocks.ordinal) "
            "FROM blocks WHERE ordinal=?", (ordinal,)
        ).fetchone()
        if row is None:
            raise KeyError(ordinal)
        return row

    def block_segment_count(self, base_blocks: int, segment_index: int,
                            segment_count: int) -> int:
        self._validate_block_segment(base_blocks, segment_index, segment_count)
        return self.db.execute(
            "SELECT COUNT(*) FROM blocks WHERE sequence>? "
            "AND ((sequence - ? - 1) % ?) = ?",
            (base_blocks, base_blocks, segment_count, segment_index - 1),
        ).fetchone()[0]

    def iter_block_segment(self, base_blocks: int, base_certificates: int,
                           segment_index: int, segment_count: int):
        self._validate_block_segment(base_blocks, segment_index, segment_count)
        if base_certificates < 0:
            raise ValueError("base certificate count must be nonnegative")
        return self.db.execute(
            "SELECT b.ordinal,b.source,b.refined_vertices,b.generating_vertices,"
            "b.new_certificates,b.ledger_hits,"
            "(SELECT COUNT(*) FROM certificates c "
            " WHERE c.seed_ordinal=b.ordinal AND c.id>?) "
            "FROM blocks b WHERE b.sequence>? "
            "AND ((b.sequence - ? - 1) % ?) = ? ORDER BY b.sequence",
            (base_certificates, base_blocks, base_blocks, segment_count,
             segment_index - 1),
        )

    @staticmethod
    def _validate_block_segment(base_blocks: int, segment_index: int,
                                segment_count: int) -> None:
        if base_blocks < 0:
            raise ValueError("base block count must be nonnegative")
        if segment_count < 1 or not 1 <= segment_index <= segment_count:
            raise ValueError("invalid block segment index/count")

    def vertices(self, max_certificate: int | None = None) -> list[tuple[int, int, int]]:
        where = "" if max_certificate is None else "WHERE certificate<=?"
        parameters = () if max_certificate is None else (max_certificate,)
        return self.db.execute(
            "SELECT ordinal,twist,certificate FROM vertices " + where +
            " ORDER BY ordinal,twist", parameters
        ).fetchall()

    def certificate_prefix_stats(self, max_certificate: int) -> tuple[int, ...]:
        certificates = self.db.execute(
            "SELECT COUNT(*),COALESCE(SUM(status='closed'),0),"
            "COALESCE(SUM(status='overflow'),0),COALESCE(SUM(status='linked'),0) "
            "FROM certificates WHERE id<=?", (max_certificate,)
        ).fetchone()
        vertices = self.db.execute(
            "SELECT COUNT(*) FROM vertices WHERE certificate<=?",
            (max_certificate,),
        ).fetchone()[0]
        return (*certificates, vertices)

    def seed_counts(self, first_certificate: int,
                    last_certificate: int) -> list[tuple[int, int]]:
        return self.db.execute(
            "SELECT seed_ordinal,COUNT(*) FROM certificates WHERE id BETWEEN ? AND ? "
            "GROUP BY seed_ordinal ORDER BY seed_ordinal",
            (first_certificate, last_certificate),
        ).fetchall()


def respond(output: TextIO, *fields: object, flush: bool = True) -> None:
    output.write("\t".join(str(field) for field in fields) + "\n")
    if flush:
        output.flush()


def serve(ledger: Ledger, input_file: TextIO = sys.stdin,
          output: TextIO = sys.stdout) -> None:
    for raw in input_file:
        fields = raw.rstrip("\n").split("\t")
        command = fields[0]
        try:
            if command == "HELLO":
                respond(output, "OK", 1)
            elif command == "INIT":
                keys = ["target_order", "pair_schema", "macroblock_count",
                        "first_ordinal", "last_ordinal", "proof_limit",
                        "walk_limit", "schedule", "start_ordinal"]
                if len(fields) == 11:
                    keys.append("traversal_order")
                ledger.initialize(dict(zip(keys, fields[1:], strict=True)))
                respond(output, "OK")
            elif command == "GET":
                value = ledger.lookup(int(fields[1]), int(fields[2]))
                respond(output, "MISS" if value is None else "FOUND", "" if value is None else value)
            elif command == "GETBEFORE":
                value = ledger.lookup_before(
                    int(fields[1]), int(fields[2]), int(fields[3])
                )
                respond(output, "MISS" if value is None else "FOUND",
                        "" if value is None else value)
            elif command == "ADD":
                status, walk_status = fields[1:3]
                linked = int(fields[3]) or None
                values = list(map(int, fields[4:9]))
                count = int(fields[9])
                vertices = []
                for _ in range(count):
                    vertex_fields = input_file.readline().rstrip("\n").split("\t")
                    if len(vertex_fields) != 3 or vertex_fields[0] != "V":
                        raise ValueError("invalid vertex row")
                    vertices.append((int(vertex_fields[1]), int(vertex_fields[2])))
                certificate = ledger.add_certificate({
                    "status": status, "walk_status": walk_status,
                    "linked_certificate": linked, "seed_ordinal": values[0],
                    "seed_twist": values[1], "checked_vertices": values[2],
                    "discovered_vertices": values[3], "discovered_classes": values[4],
                }, vertices)
                respond(output, "ADDED", certificate)
            elif command == "TRYADD":
                worker, ordinal = fields[1], int(fields[2])
                status, walk_status = fields[3:5]
                linked = int(fields[5]) or None
                values = list(map(int, fields[6:11]))
                count = int(fields[11])
                vertices = []
                for _ in range(count):
                    vertex_fields = input_file.readline().rstrip("\n").split("\t")
                    if len(vertex_fields) != 3 or vertex_fields[0] != "V":
                        raise ValueError("invalid vertex row")
                    vertices.append((int(vertex_fields[1]), int(vertex_fields[2])))
                result, certificate = ledger.try_add_certificate(worker, ordinal, {
                    "status": status, "walk_status": walk_status,
                    "linked_certificate": linked, "seed_ordinal": values[0],
                    "seed_twist": values[1], "checked_vertices": values[2],
                    "discovered_vertices": values[3], "discovered_classes": values[4],
                }, vertices)
                respond(output, result.upper(), certificate)
            elif command == "NEXT":
                block = ledger.next_block()
                respond(output, "DONE" if block is None else "BLOCK",
                        "" if block is None else block[0], "" if block is None else block[1])
            elif command == "ENQUEUE_SPECIAL":
                ledger.enqueue_special_block(int(fields[1]))
                respond(output, "OK")
            elif command == "FINISH":
                ledger.finish_block(int(fields[1]), fields[2], *map(int, fields[3:5]))
                respond(output, "OK")
            elif command == "CLAIM":
                target = int(fields[3]) if len(fields) > 3 else 0
                shard_index = int(fields[4]) if len(fields) > 4 else 1
                shard_count = int(fields[5]) if len(fields) > 5 else 1
                block = ledger.claim_block(
                    fields[1], int(fields[2]), target, shard_index, shard_count
                )
                if block is None:
                    respond(output, "DONE")
                elif block == "wait":
                    respond(output, "WAIT")
                else:
                    respond(output, "BLOCK", block[0], block[1])
            elif command == "RENEW":
                ledger.renew_lease(fields[1], int(fields[2]), int(fields[3]))
                respond(output, "OK")
            elif command == "FINISHW":
                ledger.finish_worker_block(fields[1], int(fields[2]), fields[3],
                                           int(fields[4]), int(fields[5]))
                respond(output, "OK")
            elif command == "STATS":
                stats = ledger.stats()
                respond(output, "STATS", *(stats[key] for key in (
                    "blocks", "frontier_blocks", "covered_blocks", "refined_vertices",
                    "generating_vertices", "ledger_hits", "certificates", "closed",
                    "overflow", "linked", "vertices", "pending", "database_bytes")))
            elif command == "CERT":
                row, vertices = ledger.certificate(int(fields[1]))
                respond(output, "CERT", *(0 if value is None else value for value in row), len(vertices))
                for ordinal, twist in vertices:
                    respond(output, "V", ordinal, twist)
                respond(output, "END")
            elif command == "BLOCKS":
                blocks = ledger.blocks()
                respond(output, "BLOCKS", len(blocks))
                for block in blocks:
                    respond(output, "B", *block)
                respond(output, "END")
            elif command == "BLOCK":
                respond(output, "BLOCK", *ledger.block(int(fields[1])))
            elif command == "BLOCKSEGMENT":
                base_blocks, base_certificates, segment_index, segment_count = map(
                    int, fields[1:5]
                )
                count = ledger.block_segment_count(
                    base_blocks, segment_index, segment_count
                )
                respond(output, "BLOCKSEGMENT", count)
                for block in ledger.iter_block_segment(
                    base_blocks, base_certificates, segment_index, segment_count
                ):
                    respond(output, "B", *block, flush=False)
                respond(output, "END")
            elif command == "VERTICES":
                maximum = int(fields[1]) if len(fields) > 1 else None
                vertices = ledger.vertices(maximum)
                respond(output, "VERTICES", len(vertices))
                for ordinal, twist, certificate in vertices:
                    respond(output, "V", ordinal, twist, certificate)
                respond(output, "END")
            elif command == "PREFIX":
                respond(output, "PREFIX", *ledger.certificate_prefix_stats(
                    int(fields[1])))
            elif command == "SEEDCOUNTS":
                counts = ledger.seed_counts(int(fields[1]), int(fields[2]))
                respond(output, "SEEDCOUNTS", len(counts))
                for ordinal, count in counts:
                    respond(output, "S", ordinal, count)
                respond(output, "END")
            elif command == "QUIT":
                respond(output, "BYE")
                return
            else:
                raise ValueError(f"unknown command {command}")
        except Exception as error:
            respond(output, "ERROR", type(error).__name__, str(error).replace("\t", " "))


def main() -> None:
    parser = argparse.ArgumentParser(description="transactional M23 quotient ledger service")
    parser.add_argument("--readonly", action="store_true")
    parser.add_argument(
        "--initialize-only", action="store_true",
        help="prepare or migrate the ledger, then exit without serving requests",
    )
    parser.add_argument("database", type=Path)
    args = parser.parse_args()
    if args.readonly and args.initialize_only:
        parser.error("--readonly and --initialize-only are mutually exclusive")
    ledger = Ledger(args.database, readonly=args.readonly)
    try:
        if not args.initialize_only:
            serve(ledger)
    finally:
        ledger.close()


if __name__ == "__main__":
    main()
