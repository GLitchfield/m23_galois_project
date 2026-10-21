# Third-party notices

Everything in this repository is released under the MIT License in
[`LICENSE`](LICENSE), except for the material listed in this file, which keeps
its own license. Papers and software that the project cites but does not
include are listed in [`docs/literature-basis.md`](docs/literature-basis.md).

## Häfner (2022), CC BY 4.0

Frank Häfner, *Braid orbits and the Mathieu group M23 as Galois group*,
arXiv:2202.08222, version 3 (29 May 2022),
<https://arxiv.org/abs/2202.08222>. arXiv distributes this paper under the
Creative Commons Attribution 4.0 International license,
<https://creativecommons.org/licenses/by/4.0/>.

The following files are this work or are derived from it:

| File | What it is | Changes |
| --- | --- | --- |
| `papers/hafner_2022_braid_orbits_m23.pdf` | The arXiv PDF | None |
| `papers/hafner_2022_braid_orbits_m23_source.tar` | The arXiv source download: a gzip-compressed single TeX file, despite the `.tar` suffix | None |
| `notes/hafner_2022_source/hafner_2022_braid_orbits_m23.tex` | The TeX source, decompressed from that download | Decompressed only |
| `data/reference/hafner_2022_braid_orbits.tsv` | Rows from the paper's braid-orbit table (`tab:Data_BraidOrbitsOfM23`) | Transcribed into TSV, with a status column added |
| `data/reference/hafner_2022_search_state.tsv` | Rows from the paper's table of computation status (`tab:CurrentStateOfComputations`) | Transcribed into TSV |
| `data/reference/hafner_2022_quadratic_field_orbits.tsv` | Data from the paper's theorem on M23 over quadratic fields | Transcribed into TSV |
| `data/reference/hafner_2022_class_vectors.tsv` | The paper's published class-vector counts and floors (`tab:Data_4DimClassvectorsM23`), next to values that this project computed in GAP | Published columns transcribed; computed columns added |

These files are redistributed under CC BY 4.0. Häfner does not endorse this
project. Everything else in the repository that compares against these numbers
is the project's own work and is MIT-licensed.

## Barth and Wenz conformal-welding method (reimplementation only)

Dominik Barth and Andreas Wenz, *Computation of Belyi maps with prescribed
ramification and applications in Galois theory*, Journal of Algebra 569
(2021), 616–642, <https://doi.org/10.1016/j.jalgebra.2020.10.040>.

- `scripts/barth_wenz_preprocess.py` is an independent Python
  reimplementation of the authors' Magma preprocessing step
  (`Step1_ComputeFundamentalDomains.txt`). It does not contain their source.
  It differs from the original in documented ways: deterministic traversal, no
  normalizer-based symmetrization, and empty `ConjugateEdges`. See
  [`barth_wenz/README.md`](barth_wenz/README.md).
- `scripts/prepare_barth_wenz_matlab.py` downloads the authors' ancillary
  archive and the BSD-licensed Schwarz–Christoffel Toolbox 3.1.3
  (<https://github.com/tobydriscoll/sc-toolbox>) when it runs, checks their
  SHA-256 hashes, and packages them for a local MATLAB run. Neither is
  included in this repository.
- `barth_wenz/matlab/run_class1.m` is a project-written wrapper that calls the
  authors' `Step2_DrawDessin.m`, which is not included.
- The `data/derived/m23_8a_barth_wenz_*` files are outputs that the project
  computed with this pipeline.

## Material used but not redistributed

- The MIT-licensed Magma Belyi-map package,
  <https://github.com/michaelmusty/Belyi> (pinned revision
  `f6f78dc2950343fcd9894c334f9a58f3ab065843`), is required by the
  `magma/8a_belyi/` bundle and by `scripts/check-belyi-carnoldi.sh`. Users
  supply their own checkout; no upstream code is included.
- The ATLAS of Finite Group Representations, M23 page,
  <https://atlas.math.rwth-aachen.de/Atlas/v3/spor/M23/index.html>, is cited
  for class names and group data. No copy of the page is included.
- Joachim König's dissertation artifact archive (Universität Würzburg OPUS)
  is not included. The replay targets that need it take a separately
  downloaded copy, for example through the `KOENIG_ARCHIVE` make variable.
- Lean 4, mathlib, GAP and its packages, SageMath, Julia packages, msolve and
  other toolchain components are installed separately. Their versions are
  pinned in `formal/`, `sage/8a_belyi/environment.yml`,
  `julia/8a_belyi/Manifest.toml` and the experiment notes.
