# Sage environment for the degree-23 8A Belyi system

This environment supplies the open exact-algebra layer around the numerical
Belyi search.  Sage integrates Singular and the FLINT/PARI arithmetic used for
modular elimination, exact recognition, and independent checking.  It is not
itself a permutation-triple-to-Belyi-map constructor.

Create the pinned, repository-local environment:

```sh
./scripts/setup-8a-sage.sh
```

The default prefix is `build/sage-8a`, which is ignored by Git.  Override it
with `M23_SAGE_PREFIX`.  `run-8a-sage.sh` also puts Sage's writable cache under
`build/dot-sage` rather than relying on a machine-specific home directory.
The generated system is ordinary Python syntax for the Sage runtime and can be
loaded without Sage's preparser:

```sh
./scripts/run-8a-sage.sh data/derived/m23_8a_belyi_normalized_system.sage
```

For scripts that need ordinary command-line arguments, use the wrapper's
`--python` mode; Sage 10.9's top-level CLI otherwise consumes those arguments:

```sh
./scripts/run-8a-sage.sh --python scripts/export_8a_belyi_msolve.sage \
  --prime 13 --presentation reduced --output /tmp/m23-8a-p13.ms
```

Regenerate both the Sage and Magma presentations with:

```sh
python3 scripts/generate_8a_belyi_equations.py \
  > data/derived/m23_8a_belyi_normalized_system.m
python3 scripts/generate_8a_belyi_equations.py --format sage \
  > data/derived/m23_8a_belyi_normalized_system.sage
```

The two files encode the same normalization and full/reduced equations.  The
routine repository test regenerates and compares both presentations.  Solver
benchmarks must remain bounded: the unsaturated production ideal contains
degenerate components and is not safe to hand to an unbounded Gröbner-basis
run.

## msolve

The current conda-forge Sage package does not bundle the optional `msolve`
executable. Install the official, statically linked Linux x86-64 release under
`build/` with:

```sh
./scripts/setup-msolve.sh
make check-8a-exact-algebra
```

The setup script pins `msolve` 0.10.1 and verifies the upstream archive's
SHA-256 before extraction. Other architectures should build that same release
from source and set `M23_MSOLVE` to the resulting executable.

One bounded comparison of the complete system can be launched with:

```sh
./scripts/benchmark-8a-exact-algebra.sh 13 full 60 8
```

Machine-local inputs, logs, resource measurements, and solver output stay
under `runs/`. Exit status 124 is an expected bounded timeout, not a claim that
the ideal has no solutions.
