# Test 0032: native global coordinate checkpoint

## Question

Can GAP export the complete direct-coordinate normalization layer in a compact,
versioned binary format that C++ validates and loads without materializing any
of the millions of per-macroblock relative maps?

## Inputs and provenance

- implementation: `cbb8ab95ba90b8bcdf7fb6bbe455ab0672bcd0b1`;
- schema-v2 4A pair checkpoint SHA-256
  `add26b95401d74fbaf29167782667080275d848b8cddabceecef40c2051c75c4`;
- GAP 4.12.1 and g++ 13.3.0;
- the resource-bounded eight-worker 4A production scan remained resident
  during this deliberately conservative export measurement.

## Format and method

Schema 1 is an immutable little-endian file with an explicit magic value,
schema and endian markers, degree, target-class invariants, five table counts,
the target permutation, fixed-width checkpoint/Git/GAP provenance, and packed
rows. Target-pair rows occupy 100 bytes, right-pair rows 77 bytes, macroblock
segments 16 bytes, relative rows 35 bytes, and refinement rows 20 bytes.

The production global export writes only target-pair, right-pair, and symbolic
segment rows. Relative and refinement counts are zero: C++ now accepts those
rows later through checked incremental insertion, which is the lazy per-block
boundary required by the search. The reader rejects bad magic, schema, endian,
degree, byte counts, permutations, provenance widths, duplicate conflicts, and
trailing data.

GAP reconstructs every row in the same deterministic loops used to build the
production dictionaries and proves the emitted counts against the pair
checkpoint census. The C++ checker reads the completed file, constructs both
global hash indexes, and reports its metadata. The ordinary native regression
also round-trips each micro-checkpoint through the binary format. Test 0033
supplies the now-implemented lazy native relative/refinement construction.

Reproduce an operational export with:

```bash
scripts/generate-native-coordinate-checkpoint.sh \
  runs/4a-pair-orbits-v2.g runs/4a-coordinate-tables-v1.bin
```

The generated binary and manifest remain under `runs/` and are not committed.

## Result

The complete 4A global checkpoint contains:

| layer | rows |
| --- | ---: |
| target-pair normalization | 318,780 |
| right-pair transport | 180,465 |
| macroblock segments | 17 |
| eager relative/refinement rows | 0 |

Its exact size is 45,774,292 bytes: the previously predicted 45,773,805 row
bytes plus the 215-byte header and 272 segment bytes. GAP export, native
compilation, full C++ load, and validation completed in 21.74 seconds with
188,924 KiB maximum RSS for the largest process. The generated SHA-256 was
`261cbcdbc96a2d726d07e1b4febb041586dcd78da8f6615e2794f88df185d2ab`.

The same committed exporter then completed the full 5A global layer:

| layer | rows |
| --- | ---: |
| target-pair normalization | 680,064 |
| right-pair transport | 823,048 |
| macroblock segments | 17 |
| eager relative/refinement rows | 0 |

The 5A file is 131,381,583 bytes and has SHA-256
`08b2b789db8e2fc9e00c917ac4f28a750965fe9390e8cae7ae4a793ce9b4cedc`.
Export, compilation, complete native load, and hash-index validation took 76.13
seconds with 311,120 KiB maximum RSS while the eight-worker 4A scan remained
active.

## Follow-on gate

This establishes the complete 4A and 5A global data boundary and a lazy
insertion API. Test 0033 implements and differentially checks native
construction of a block's relative double cosets and twist refinement. A small
native quotient walk is now the next integration measurement.

## Verdict

Passed the versioned 4A/5A global-export, exact byte-count, native-load,
provenance, and lazy-local-table boundary gates.
