# M23 inverse Galois computations

The Mathieu group `M23` is the only sporadic simple group not known to occur
as a Galois group over `Q`. The open problem is to find a polynomial in `Z[x]`
whose Galois group over `Q` is `M23` in its degree-23 action. This repository
follows the braid-orbit (Hurwitz space) approach of Frank Häfner,
[*Braid orbits and the Mathieu group M23 as Galois group*](https://arxiv.org/abs/2202.08222)
(arXiv:2202.08222, 2022). It reproduces several of his reported computations,
completes one bounded search, and tests several arithmetic routes from a
Hurwitz component to a cover defined over `Q`.

## Status

- The project has been inactive since 2026-08-01.
- The problem remains open. Nothing in this repository realizes `M23` over `Q`.
- The results below are final for this repository. Plans for work that was
  never carried out are not included.

## Results

Test numbers refer to the experiment notes in [`docs/tests/`](docs/tests/),
indexed in [`docs/research_log.md`](docs/research_log.md).

| Result | Evidence |
| --- | --- |
| **Reproduction of Häfner's small cases.** `(14A,2A,2A,2A)` has 84 inner Nielsen classes in one pure braid orbit, `(15A,2A,2A,2A)` has 90, `(8A,8A,2A)` has 28 classes, from which the reported small `(8A)^4` orbits are derived, and `(4A,4A,2A,2A)` has 2,456 classes with pure genus 447 and symmetric genus 169. | Tests [0001](docs/tests/0001-m23-class-atlas.md)–[0005](docs/tests/0005-4a-4a-2a-2a-orbit.md) |
| **Bridge computations.** For `C = 5A, 6A, 8A`, the `(C,C,2A,2A)` bridges have 30,400 / 72,528 / 198,488 generating inner classes. Each forms one pure orbit (genus 5,223 / 15,125 / 41,277) and one symmetric orbit (genus 2,071 / 6,065 / 16,617), matching the values reported by Häfner. Each run uses 16 / 32 / 64 deterministic shards and has an independent exhaustiveness check. | Tests [0007](docs/tests/0007-5a-bridge.md), [0008](docs/tests/0008-6a-bridge.md), [0009](docs/tests/0009-8a-bridge.md); [`docs/sharded-engine.md`](docs/sharded-engine.md) |
| **`(5A)^4` from the 5A bridge.** Translating the bridge gives Häfner's three pure `(5A)^4` components (30,400 classes each, genus 5,626), joined into one symmetric component of 91,200 classes (genus 2,071). This is a construction only. **`(5A)^4` exhaustiveness is not certified**: nothing here rules out other small components among the roughly 1.81 billion generating classes. | Test [0010](docs/tests/0010-5a-homogeneous-bridge.md) |
| **Bounded 4A search.** `B4((4A)^4,2500)` consists of exactly three pure components, each with 2,456 inner classes. Every other generating class lies in a component with a replayable connected witness of 2,501 classes. All 7,928,185 symbolic macroblocks were scanned and replayed, and a separate GAP audit checked all 10,099 identity-block vertices and re-enumerated the three components. The proof package is published separately at <https://github.com/GLitchfield/m23_4a_bounded_proof>. | Test [0054](docs/tests/0054-complete-4a-bounded-search.md); [`docs/bounded-search.md`](docs/bounded-search.md) |
| **Negative result 1: the small 8A route is closed.** The 14 small four-branch `(8A)^4` components (from the 28 `(8A,8A,2A)` classes) form a single absolute Galois orbit, so none is defined over `Q`. The proof transfers the three-point Galois orbit of Negative result 2 to the four-branch components through the admissible-cover gluing morphism at a ramified node, which is cited from the literature. | Tests [0056](docs/tests/0056-8a-small-component-descent.md), [0095](docs/tests/0095-8a-absolute-galois-orbit.md), [0097](docs/tests/0097-8a-fixed-field-galois-and-boundary-bijection.md), [0098](docs/tests/0098-8a-ramified-node-galois-transfer.md) |
| **Negative result 2: the three-point `(8A,8A,2A)` passport has no cover over `Q`.** An exact degree-23 Belyi map with passport `(8,8,4,2,1)/(8,8,4,2,1)/(2^8,1^7)` has all 23 coefficients in one irreducible degree-28 number field. Interval (Arb ball) continuation over 16,384 arcs proves that its monodromy group is `M23`, matching inner class 1. Its field of moduli has degree 28, all 28 ordered maps form one Galois orbit, and so no cover with this passport is defined over `Q`. This is a computer-assisted proof (SageMath/Arb and GAP), not kernel-checked. It relies on Weil descent and standard branch-cycle theory as outside inputs. | Tests [0089](docs/tests/0089-8a-barth-wenz-domain2-candidate.md)–[0095](docs/tests/0095-8a-absolute-galois-orbit.md), especially [0091](docs/tests/0091-8a-exact-degree28-belyi-map.md), [0092](docs/tests/0092-8a-rigorous-exact-cover-monodromy.md), [0095](docs/tests/0095-8a-absolute-galois-orbit.md) |
| **König's M24 genus-11 curve has no `Q_2`-point.** König's dissertation gives an M24 family `(2A,2A,2B,8A)` for which obtaining an `M23` polynomial from a point stabilizer of M24 required a rational point on a genus-11 Hurwitz curve. The authenticated 633-term model of that curve has a smooth projective normalization with no `Q_2`-point, and therefore no rational point, so this family does not give `M23` over `Q`. | Tests [0146](docs/tests/0146-m24-koenig-genus11-two-adic-gate.md)–[0151](docs/tests/0151-m24-koenig-genus11-tropical-exhaustion.md), especially [0151](docs/tests/0151-m24-koenig-genus11-tropical-exhaustion.md) |
| **Seguin's `(3A)^4` example.** The 37,296 generating `(3A)^4` inner classes form exactly two braid components (8,316 and 28,980 classes). Combined with Seguin's published theorem, both components are defined over `Q`. No equations or rational points are produced. | Tests [0099](docs/tests/0099-seguin-3a-marked-inner-reconciliation.md), [0100](docs/tests/0100-3a-inner-nielsen-exhaustiveness.md) |

One further route stopped at its declared gates: **König's M23
`(2A,2A,3A,5A)` curve.** The genus-43 archive was authenticated and checked
(tests 0101–0112). The bounded attempts to reconstruct its characteristic-zero
coefficient family did not succeed (tests 0113–0145).

## What is not claimed

- No polynomial, and no `M23` cover over `Q(t)` or over `Q`, is constructed.
- The negative results are the owner's computations. No expert in the field
  has checked them yet. Each one closes a specific passport or component, not
  the `M23/Q` problem.
- No exhaustive `(5A)^4`, `(6A)^4` or `(8A)^4` search was run.
- Lean does not check any headline result (see below).
- Agreement with numbers in Häfner's preprint is regression evidence, not an
  independent literature confirmation. No claim of priority is made. Source
  quality and dependencies are recorded in
  [`docs/literature-basis.md`](docs/literature-basis.md).

## How the work was done

- **Agents.** The work was carried out mainly by OpenAI's Codex agent under
  the owner's direction, following [`AGENTS.md`](AGENTS.md).
  [`CLAUDE.md`](CLAUDE.md) points Claude sessions to the same rules.
- **Two-model review harness.** `scripts/m23_adversarial_review.py` gives
  Claude Fable and Codex the same read-only evidence packet. Each reviews it
  independently, then each critiques the other's answer once. Every report is
  labeled advisory, not proof. The Wayfinder documents call one run a
  "Codex/Fable review". In the private history the Codex reviewer was
  nicknamed "Sol", so older commit messages say "Sol/Fable". See
  [`docs/adversarial-review.md`](docs/adversarial-review.md).
- **Long computations.** Runs are deterministic, sharded and resumable from
  checkpoints. Each result carries an exhaustiveness certificate that a
  checker separate from the producer verifies before the result is committed.
  See
  [`docs/sharded-engine.md`](docs/sharded-engine.md),
  [`docs/bounded-search.md`](docs/bounded-search.md) and
  [`docs/reproducibility.md`](docs/reproducibility.md).
- **Experiment notes.** Each numbered note in `docs/tests/` records a
  question, method, result and provenance (code revision, inputs, versions,
  hashes). Some note numbers are not used in this release. Strategic decisions were recorded on a decision map in
  [`docs/wayfinder/`](docs/wayfinder/map.md).
- **Lean layer.** `formal/` pins Lean `v4.29.1` and mathlib `v4.29.1`. It
  proves the Hurwitz-move and complex-conjugation algebra for arbitrary
  groups. Beyond that, it kernel-checks only finite steps of tests 0056, 0058
  (with the 0059 and 0061 extensions) and 0099. It does not check the bridge
  counts, the 4A search, the two negative results or the König obstruction.
  `scripts/check-lean.sh` rejects `sorry`, `admit`, `axiom` and
  `native_decide`, and regenerates the certificate data files and compares
  them byte for byte before building. See
  [`docs/formal-verification.md`](docs/formal-verification.md).

## Layout

| Path | Contents |
| --- | --- |
| `src/gap/`, `scripts/gap/` | GAP kernels: Nielsen classes, braid actions, shards, macroblocks, audits |
| `scripts/` | Python, Sage and shell producers, independent checkers and run managers |
| `src/native/`, `tests/native/`, `src/cuda/` | C++20 search backend and its tests; an experimental CUDA batch kernel |
| `formal/` | Lean 4 project |
| `data/reference/`, `data/derived/`, `data/schema/` | Committed reference data, compact results and certificates (with `SHA256SUMS`), JSON schemas |
| `docs/tests/`, `docs/research_log.md` | Numbered experiment notes and their index |
| `docs/` | Method and policy documents; [`docs/roadmap.md`](docs/roadmap.md) lists completed milestones |
| `sage/`, `julia/`, `barth_wenz/` | Pinned Sage and Julia environments; the Barth–Wenz MATLAB handoff |
| `magma/` | A Magma handoff bundle for the 8A target that was never executed (no Magma access) |
| `papers/`, `notes/` | Häfner 2022 (PDF and TeX source); small GAP fact files and a Magma smoke transcript |

## Reproducing

Toolchain:

- GAP 4.12 with AtlasRep ≥ 2.1.8, CTblLib ≥ 1.3.7 and TransGrp ≥ 3.6.5
  (`scripts/check-environment.sh` checks these);
- a C++20 compiler (`g++`), `sha256sum` and `rg` (ripgrep);
- Lean through `elan`. `lake` fetches the pinned mathlib on first build;
- Python 3.12 with NumPy (`requirements-8a-belyi-pilot.txt` pins NumPy and
  SciPy);
- SageMath 10.9 in a repository-local environment created by
  `./scripts/setup-8a-sage.sh` (under `build/`, see
  [`sage/8a_belyi/README.md`](sage/8a_belyi/README.md));
- for specific targets only: msolve 0.10.1 (`./scripts/setup-msolve.sh`),
  Julia 1.12.6 with the locked `julia/8a_belyi` project, and CUDA for
  `make check-cuda-batch`.

Commands:

```sh
make test          # environment, compact certificates, manifests, Lean, self-tests
make test-replay   # plus exact medium-size GAP reproductions and byte comparisons
make test-long     # plus full 5A/6A bridge recomputation and long replays
```

Individual `make check-*` and `make reproduce-*` targets are listed in the
`Makefile`, and each experiment note gives its own commands. The working
directory `runs/` (about 43 GB of checkpoints, ledgers and logs) is not
included. Replays that need it, or König's external dissertation archive
(supplied separately, for example through `KOENIG_ARCHIVE`), say so in their
notes.

## License

MIT; see [`LICENSE`](LICENSE). Third-party material keeps its own license: the
Häfner paper and the tables derived from it are CC BY 4.0. See
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

This repository was published with a fresh history on 2026-10-20; commit IDs
cited in the notes refer to the private development history.
