# Test 0014: frontier quotient scheduling

## Question

Does processing macroblocks reached by a bounded witness before returning to
the ordinal stream materially improve reuse of exact quotient certificates?

## Method

Persist a priority queue of macroblock ordinals found in new certificate
vertices. Take queued macroblocks first and otherwise advance a rotating
deterministic ordinal cursor. Record the exact processing source and order so a
separate verifier can replay certificates against precisely the ledger that
existed when each traversal ran.

Start at the first order-11 4A macroblock and exclude only the exceptional
identity macroblock from this scheduling pilot. Compare the first ten processed
blocks with the prior sequential sample, then extend the frontier run to 100
blocks. Separately test a coverage-walk limit of 25,000 while retaining 2,500 as
the mathematical proof bound.

## Result

- first ten frontier blocks: three certificates, seven fully covered blocks;
- 100 frontier blocks: 240 refined vertices, 213 generating vertices, 99 ledger
  hits, 67 fully covered blocks;
- 114 certificates: 78 overflow and 36 linked, covering 23,078 vertices;
- elapsed scan time about 330 seconds; checkpoint size about 792 KB;
- exact frontier-order replay passes;
- 20-block larger-witness pilot: 15 covered blocks, 19 hits, 11 certificates
  (three overflow and eight linked), and 12,533 stored vertices.

Frontier scheduling is a real improvement, but single-process throughput and
whole-record checkpoint growth remain inadequate for the complete scan. The
next engine should use an indexed transactional ledger and retain the larger
coverage-walk experiment.

## Reproducibility record

- baseline revision: `40b2312`; implementation is the commit containing this
  note;
- GAP 4.12.1, AtlasRep 2.1.8, CTblLib 1.3.7;
- 4A schema-2 pair checkpoint; nonidentity macroblocks 2 through 7,928,185;
- deterministic start ordinal 1,633,430;
- operational checkpoints: `runs/4a-frontier-pilot/` and
  `runs/4a-frontier-25k-pilot/`.
