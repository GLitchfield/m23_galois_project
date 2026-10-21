# Bounded Magma pilot for the 8A Belyi target

> **Status:** the target run was never executed. The project had no Magma
> access, and the exact class-1 map was later computed without Magma (tests
> 0086--0091). Apart from the seconds-long serialization smoke test on the
> online Magma calculator (test 0075), only the local fake-Magma regressions
> have run. The bundle is kept as tested code.

This bundle turns the first external Magma request into one bounded run with a
useful result even when the solver fails. It has two deliberately separate
stages:

- `numerical` tests the power-series and Newton pipeline but stops before
  algebraic recognition;
- `exact` additionally asks the package to recognize a number field and exact
  map, then exports the result for independent local verification.

Completing the numerical stage does not commit a volunteer to the exact stage,
the other 27 triples, parameter tuning, or package debugging.

## Prerequisites

The runner expects:

1. a licensed `magma` executable;
2. a clean checkout of
   [michaelmusty/Belyi](https://github.com/michaelmusty/Belyi) at commit
   `f6f78dc2950343fcd9894c334f9a58f3ab065843`, including its submodules; and
3. GNU `timeout`, Git, Python 3, and GAP.

The pinned Belyi revision introduced an optional external C/FLINT Arnoldi
solver. The classical pure-Magma implementation remains the default here so a
volunteer is not implicitly asked to build another toolchain. The helper now
passes the project's pinned-source local build and self-test gate; this does
not replace the still-missing Magma integration run.

## Seconds-long adapter smoke test

Before the target computation, validate the Magma runtime's exact
serialization conventions without loading the Belyi package:

```sh
timeout --signal=TERM --kill-after=5s 60s \
  magma -b magma/8a_belyi/serialization_smoke.m \
  >magma-serialization-smoke.log 2>&1 &&
python3 scripts/check_magma_8a_serialization_smoke.py \
  magma-serialization-smoke.log
```

The smoke fixture uses `Q(sqrt(2))`, a zero coefficient, and a non-one leading
coefficient. It checks that `Coefficients` and `Eltseq` produce the low-to-high,
fixed-width lists assumed by the adapter. It does not exercise Belyi package
attributes or solve the target. If it fails, return the transcript and stop;
the adapter should be corrected before any long run.

The fixture passed on the official free calculator running Magma V2.29-8. That
run also showed that `Sprint` may wrap nested sequences despite
`SetColumns(0)`, so the restricted adapter accepts balanced multiline lists.
The preserved transcript and provenance are documented in
`docs/tests/0075-magma-serialization-smoke.md`. Repeat the smoke on the actual
host because its Magma version and output environment may differ.

## First bounded request

From this project checkout, run:

```sh
M23_BELYI_STAGE=numerical \
M23_BELYI_WALL_SECONDS=21600 \
./magma/8a_belyi/run-class1-pilot.sh \
  /path/to/Belyi /new/path/for/m23-class1-numerical
```

The defaults are class 1, `prec=145`, `precNewton=500`, `DegreeBound=28`,
classical Arnoldi, a six-hour wall-clock limit, and no process virtual-memory
limit.
They are conservative pilot settings, not a package-author recommendation or
a claim that 500 digits suffice for degree-28 recognition. Override them only
with the run recorded:

```sh
M23_BELYI_PREC=200 \
M23_BELYI_PREC_NEWTON=1000 \
M23_BELYI_DEGREE_BOUND=28 \
M23_BELYI_MEMORY_MIB=16384 \
M23_BELYI_WALL_SECONDS=43200 \
./magma/8a_belyi/run-class1-pilot.sh \
  /path/to/Belyi /new/path/for/m23-class1-numerical
```

For the optional C solver, first run the project gate against the same pinned
Belyi checkout. Use `DEPENDENCY_PREFIX` only for a no-admin local build:

```sh
make check-belyi-carnoldi \
  BELYI_CHECKOUT=/path/to/Belyi \
  OUTPUT_DIR=/new/path/for/carnoldi-gate \
  DEPENDENCY_PREFIX=/path/to/local/prefix
```

Then use the resulting package binary:

```sh
POWSER_ARNOLDI_BIN=/absolute/path/to/powser_arnoldi \
M23_BELYI_POWSER=carnoldi \
./magma/8a_belyi/run-class1-pilot.sh \
  /path/to/Belyi /new/path/for/m23-class1-numerical-c
```

The same bounded bundle can select any certified class. The all-class
conditioning census identifies class 22 as a useful follow-up, but does not
predict that Magma will converge:

```sh
M23_BELYI_CLASS_ID=22 \
M23_BELYI_STAGE=numerical \
./magma/8a_belyi/run-class1-pilot.sh \
  /path/to/Belyi /new/path/for/m23-class22-numerical
```

The historical runner filename is retained for compatibility; `config.tsv`
records the selected class ID.

## Exact follow-up

An exact attempt is separately authorized:

```sh
M23_BELYI_STAGE=exact \
M23_BELYI_PREC_NEWTON=1000 \
M23_BELYI_WALL_SECONDS=43200 \
./magma/8a_belyi/run-class1-pilot.sh \
  /path/to/Belyi /new/path/for/m23-class1-exact
```

If Magma returns an exact map, the runner extracts its field, numerator, and
denominator into `candidate.json`. The local verifier then asks GAP to prove
the defining polynomial irreducible and checks exact coprimality,
ramification, degree, and Riemann--Hurwitz. A successful outcome is named
`success_exact_verified_ramification`, not “proved M23”: cover monodromy is a
separate missing certificate.

## Returned directory

The new output directory contains:

- `driver.m`: the exact concatenated Magma program;
- `config.tsv`: immutable input hashes, revisions, limits, and solver options;
- `belyi-submodules.txt`: the recursively recorded package submodule state;
- `transcript.log`: complete Magma stdout and stderr;
- `status.tsv`: separate Magma, extraction, verification, and runner exit
  codes, elapsed time, outcome, and artifact hashes;
- `extraction.log` and `verification.log`: present when exact intake reaches
  those stages;
- `candidate.json`: present only after extractable exact output; and
- `verification.json`: present only after successful local exact verification.

Return the whole directory. A `timeout`, `timeout_killed`, `failed`, or
`exact_output_rejected_locally` status is a useful result and ends the bounded
request.

The runner refuses an existing output directory, a changed project input, a
dirty Belyi checkout, or a Belyi revision other than the pin. Diagnostic
overrides exist for development, but such a run records the changed revision
and dirty state and is not the preferred public pilot.

## Current validation boundary

No Magma executable is installed in the project environment. Deterministic
fake-Magma regressions cover a completed numerical stage, timeout escalation,
zero exit without completion markers, nonzero exit despite apparent success
markers, and local rejection of exact output. Parser, schema, GAP
irreducibility, and diagnostic-bypass regressions are also local. The
serialization body has now passed on the official Magma V2.29-8 calculator,
including the multiline parser correction prompted by its output. The target
body has been compared with the pinned package source but has not been executed
under Magma. The package attribute path therefore remains provisional until an
exact package result is returned.

An adversarial Fable/Codex handoff review prompted the bounded version
preflight, recursive submodule gate, explicit marker framing, atomic accepted
artifacts, preserved stderr and raw stage exit codes, stronger timeout tests,
and the explicit runtime gate above. That review is a software-design check,
not mathematical evidence for the target.

Run the local checks with:

```sh
make check-magma-8a-pilot
```
