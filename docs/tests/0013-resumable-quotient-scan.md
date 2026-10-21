# Test 0013: resumable quotient scan

## Question

Can deterministic macroblock ranges be converted into persistent, replayable
bounded-coverage certificates over the exact pair-twist quotient?

## Method

For every refined vertex in an ordinal range, test generation using a
materialized representative. Unseen generating vertices start a weighted
quotient traversal with bound 2,500. Stop only when the component closes, its
weight exceeds the bound, or it reaches an earlier ledger vertex. Store every
visited refined vertex and atomically replace the scan checkpoint after each
completed macroblock.

Resume the completed checkpoint, then independently rebuild the locator and
ledger. Replay certificates in order and compare status, link, checked count,
class weight, and the exact refined-vertex set. Finally rematerialize every
scanned macroblock and check that all its generating vertices occur in the
ledger.

## Result

Ten adjacent order-11 4A macroblocks contain ten generating refined vertices.
They produce ten overflow certificates covering 2,507 quotient vertices; every
certificate has weight greater than 2,500. An end-of-range resume performs no
new work. Independent replay verifies all certificates and block coverage.

No certificate linked to another. Sequential ordinal order therefore does not
yet exploit the graph locality exposed by each witness, and should not be
extrapolated as the production global schedule.

## Reproducibility record

- baseline revision: `7e71f19`; implementation is the commit containing this
  note;
- GAP 4.12.1, AtlasRep 2.1.8, CTblLib 1.3.7;
- 4A schema-2 pair checkpoint, macroblocks 1,633,430 through 1,633,439;
- commands: `scripts/scan-direct-pair-quotient.sh` and
  `scripts/verify-direct-pair-quotient-scan.sh`.
