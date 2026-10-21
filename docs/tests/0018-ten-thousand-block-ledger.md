# Test 0018: ten-thousand-block quotient ledger

## Question

Does the 25,000-class frontier policy become cheaper as the reusable ledger
grows from 1,000 to 10,000 processed 4A macroblocks, while retaining exact
certificate replay and practical database growth?

## Method

Start from the exactly replayed 1,000-block SQLite ledger. Replay it again as a
pre-mutation gate, extend it by 9,000 frontier blocks with one GAP worker, then
replay every certificate in commit order and reconcile every processed block.
Freeze the verified database with an online SQLite backup, integrity and
foreign-key checks, and a SHA-256 manifest.

## Result

- 10,000 blocks, 36,241 refined vertices, and 28,921 generating vertices;
- 597,298 ledger vertices in 18,593 certificates;
- 18,586 linked, four overflow, and three closed certificates;
- 6,332 blocks required no new certificate and 10,328 generating vertices were
  ledger hits;
- the 9,000-block extension took 5,378 seconds, or 1.67 blocks/second;
- the extension added 402,293 vertices at about 74.8 vertices/second;
- complete replay took 6,291 seconds and reconstructed all 597,298 vertices;
- 40 MB database, SQLite quick and foreign-key checks pass;
- the frozen 10,000-block base has SHA-256
  `ac00ff206275edcd628623c020a18f822f6e2e7b35f89806e2572d2bbe457128`.

Block throughput improved by about 3.6 times over the preceding 900-block
extension even though vertex throughput remained similar. The accumulated
ledger is turning later components into shorter links. At 1.67 blocks/second,
unchanged single-worker throughput would still require about 55 days for all
7,928,184 nonidentity blocks, so parallel coverage is the next gate.

## Reproducibility record

- implementation revision preceding the snapshot: `04aa4b5`;
- snapshot implementation: `e398191`;
- operational ledger: `runs/4a-db-walk-limits-20/walk-25000/`;
- frozen base: `runs/4a-db-base-10000/`;
- 4A schema-2 pair checkpoint; proof limit 2,500; walk limit 25,000;
- deterministic nonidentity range 2 through 7,928,185 and rotating start
  ordinal 1,633,430.
