# Test 0015: transactional quotient ledger

## Question

Can an indexed transactional ledger replace repeated serialization of the
complete GAP scan state without changing frontier order or mathematical
certificates?

## Method

Store configuration, certificates, uniquely owned refined vertices, frontier
ordinals, processed blocks, and an active block lease in SQLite. GAP maintains
a persistent pipe to the Python ledger service while retaining all
group-theoretic computation. Insert each certificate and all of its vertices in
one transaction.

Unit-test configuration rejection, transaction rollback on duplicate vertices,
frontier priority, and restart of an unfinished active lease. Through the real
GAP protocol, reproduce the frontier pilot, stop after two blocks, resume to ten
and then twenty blocks, and compare its counters with the in-memory run.
Independently replay database certificates and rematerialize every processed
macroblock.

## Result

- ten blocks reproduce exactly three certificates, seven fully covered blocks,
  nine hits, and 765 ledger vertices;
- fair one-invocation runtime is about 14 seconds, versus roughly 13 seconds for
  the in-memory implementation;
- restart to 20 blocks produces 11 overflow certificates, 19 hits, 15 covered
  blocks, and 2,796 vertices;
- the resulting SQLite database is about 228 KB;
- `PRAGMA integrity_check` and exact GAP replay both pass.

The modest lookup overhead does not currently justify a separate memory cache.
Database persistence removes whole-checkpoint write amplification and makes
certificate-level crash recovery possible. Parallel leases are not yet
implemented.

## Reproducibility record

- baseline revision: `ebb2a3f`; implementation is the commit containing this
  note;
- Python standard-library SQLite and GAP IO 4.8.0;
- 4A schema-2 pair checkpoint; nonidentity macroblocks 2 through 7,928,185;
- deterministic start ordinal 1,633,430 and proof/walk limit 2,500;
- operational checkpoint: `runs/4a-frontier-db-pilot/ledger.sqlite3`.
