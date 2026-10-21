# Test 0020: fifty-thousand-block production wave

## Question

Do the selected 32 GB production settings—eight dynamic scan workers and four
composable replay workers—remain balanced through a 40,000-block extension?

## Method

Start from the immutable, exactly replayed 10,000-block base. Extend to 50,000
blocks with eight physical workers and eight deterministic virtual shards.
Freeze the database state for replay, divide the certificate delta into four
contiguous weight-balanced segments, and reconcile the block delta in four
segments. Compose all segment totals and independently audit the frozen base,
ordinal ownership, leases, SQLite integrity, and database hash.

## Result

- 40,000 new blocks scanned in 3,978 seconds: 10.055 blocks/second;
- the same delta replayed in 3,907 seconds: 10.238 verified blocks/second;
- 50,000 total blocks, 1,237,281 ledger vertices, and 77,938 certificates;
- 77,931 linked, four overflow, and three closed certificates;
- the delta contains 639,983 vertices in 59,345 certificates, all linked;
- 40,000 delta blocks contain 127,089 refined and 101,891 generating vertices,
  with 42,546 ledger hits;
- all four block segments and all four certificate segments pass;
- base preservation, deterministic ownership, exact composition, SQLite quick
  check, and final audit pass;
- operational database SHA-256:
  `d3046288113d356267597b3b2fa0b08f13b362f559895cf9a61d33911d589fb1`;
- frozen 50,000-block base SHA-256:
  `864baeee5c24d35c4d077d29c756c2555d5bb558f8d16e874c1b815ca2396b6d`.

Four replay workers are slightly faster than eight scan workers at this scale.
The selected 32 GB configuration can therefore pipeline scan and replay without
accumulating a verification backlog. Extrapolating the slower scan rate gives
about 9.1 days for complete 4A enumeration, before recovery margin but within
the two-week target. Additional RAM is not required for the present 4A plan.

## Reproducibility record

- production runner revision: `7aac6b0`;
- result recording revision: the commit containing this note;
- operational run: `runs/4a-db-production-to-50k/`;
- frozen base: `runs/4a-db-base-50000/`;
- 4A schema-2 pair checkpoint; proof limit 2,500; walk limit 25,000;
- deterministic nonidentity range 2 through 7,928,185;
- full repository test suite passed before production launch.
