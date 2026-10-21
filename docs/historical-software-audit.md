# Historical braid-orbit software audit

## Scope

This audit (2026-07-10) asked whether the arXiv source bundles then available
locally contain the implementation behind the published M23 computations, and
whether a maintained package can serve as a verifier or implementation base.
Only the Häfner bundle is redistributed here; the others are cited below.

## Findings

1. The arXiv source download for Magaard, Shpectorov, and Völklein
   (arXiv:math/0304376) is a gzip-compressed single TeX file, not a tar archive.
   It contains the paper, not the BRAID GAP package described by the paper.
2. The arXiv source downloads for Häfner (arXiv:2202.08222) and Müller
   (arXiv:1204.1328) are likewise gzip-compressed single TeX files. Häfner's
   extracted TeX contains results and mathematical braid actions, but no
   computation scripts or serialized orbit data.
3. The 2003 BRAID package has a maintained successor, MapClass. MapClass 1.4.6
   supports Nielsen/mapping-class orbit computation, tuple minimization, partial
   enumeration, save/restore, and tuple counting. It requires GAP 4.9 or newer
   and is GPL-2.0-or-later.
4. MapClass is not part of the current system GAP installation. Installing it is
   not yet necessary for the class-table milestone, and adopting it wholesale
   would introduce a broad mapping-class abstraction before the M23 workload is
   characterized.
5. GAP's Orb package offers resumable hashed orbit enumeration, but it too is not
   installed locally. Its generic orbit layer may become useful after tuple
   representation and canonicalization are benchmarked.

## Decision

The project implemented the small mathematical core needed to validate tuples
and Hurwitz actions in its own GAP code, and reproduced known complete orbits
before starting the large searches. MapClass was inspected as a comparison
implementation (test 0011) but not used as the search engine; Orb was not
adopted.

## Sources

- K. Magaard, S. Shpectorov, and H. Völklein, *A GAP package for braid orbit
  computation, and applications*, Experimental Mathematics 12 (2003),
  arXiv:math/0304376, <https://arxiv.org/abs/math/0304376>.
- Frank Häfner, *Braid orbits and the Mathieu group M23 as Galois group* (2022),
  arXiv:2202.08222, <https://arxiv.org/abs/2202.08222>; PDF and TeX source in
  `papers/` and `notes/hafner_2022_source/`.
- Peter Müller, *A one-parameter family of polynomials with Galois group M24
  over Q(t)* (2012), arXiv:1204.1328, <https://arxiv.org/abs/1204.1328>.
- MapClass package site and manual: <https://gap-packages.github.io/MapClass/>.
- Orb package manual: <https://gap-packages.github.io/orb/>.

