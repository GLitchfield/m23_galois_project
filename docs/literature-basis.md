# Literature basis and source-risk audit

## Purpose

Claims in this repository are separated by source quality and by whether the
repository checks them independently. This audit was refreshed on 2026-07-24 after a
search for journal, monograph, preprint, and current-status sources.

Frank Häfner's *Braid orbits and the Mathieu group M23 as Galois group*
(arXiv:2202.08222, 2022) is the source of the braid-orbit approach and the
numerical targets followed here. It catalogues candidate class vectors,
conventions, numerical orbit results, and search suggestions. As of this
audit it is a preprint, so the repository cites established theory for the
underlying method (below) and treats the preprint's M23 tables as external
numerical targets that its own computations compare against. Häfner's earlier
work on inverse Galois problems includes *Einige orthogonale und
symplektische Gruppen als Galoisgruppen über Q*, **Mathematische Annalen
292** (1992), 587--618 ([EuDML record](https://eudml.org/doc/164931)).

## Source hierarchy

Use the following evidence labels in project prose and reviews:

1. **Established theory:** a peer-reviewed paper or research monograph gives
   the mathematical implication being used.
2. **Canonical data:** ATLAS or a standard CAS dataset supplies group data,
   with important entries rechecked in the natural permutation group.
3. **Independent computation:** committed code derives a numerical statement
   from group and braid definitions without importing the claimed answer.
4. **External numerical target:** a preprint or other source reports a number
   that our computation may compare against, but that comparison is not an
   independent literature confirmation.

A public computational claim should have established theory plus independent
computation. Agreement with an external numerical target is useful regression
evidence, not the foundation of the claim.

## Stronger foundations

### Inverse Galois and braid/Hurwitz theory

- B. Heinrich Matzat, *Zöpfe und Galoissche Gruppen*, **Journal für die reine
  und angewandte Mathematik 420** (1991), 99--160. This is a peer-reviewed,
  direct treatment of braid groups, fields of definition, rationality, and the
  inverse Galois problem. [EuDML record and full text](https://eudml.org/doc/153355).
- Helmut Völklein, *Groups as Galois Groups: An Introduction*, Cambridge
  University Press (1996). This supplies the rigidity and Hurwitz-space
  framework independently of any M23 table.
  [Cambridge record](https://www.cambridge.org/core/books/groups-as-galois-groups/frontmatter/2CADE5303D6C9D197BCFBA6C34FBB2E2).
- Gunter Malle and B. Heinrich Matzat, *Inverse Galois Theory*, second edition,
  Springer Monographs in Mathematics (2018), especially the chapter *Action
  of Braids*. [Springer record](https://link.springer.com/book/10.1007/978-3-662-55420-3).
- Kay Magaard, Sergey Shpectorov, and Helmut Völklein, *A GAP Package for
  Braid Orbit Computation and Applications*, **Experimental Mathematics 12**
  (2003), 385--393. It states the braid-orbit/irreducible-family
  correspondence and gives an established computational method.
  [Journal article](https://doi.org/10.1080/10586458.2003.10504507).

Two further background papers were consulted early in the project:

- Peter Müller, *A one-parameter family of polynomials with Galois group M24
  over Q(t)*, arXiv:1204.1328 (2012), <https://arxiv.org/abs/1204.1328>.
- Michael D. Fried, *Alternating groups and moduli space lifting invariants*,
  arXiv:math/0611591, <https://arxiv.org/abs/math/0611591>.

The Magaard--Shpectorov--Völklein paper is also available as
arXiv:math/0304376, <https://arxiv.org/abs/math/0304376>. None of these papers
is redistributed here.

These sources support the use of Nielsen classes, Hurwitz moves, inner
simultaneous-conjugacy quotients, braid components, and Riemann--Hurwitz cycle
calculations. Our exact implementation conventions must still be checked
against their definitions.

### Admissible-cover compactification and ramified nodes

- Dan Abramovich, Alessio Corti, and Angelo Vistoli, *Twisted bundles and
  admissible covers*, **Communications in Algebra 31** (2003), 3547--3618,
  construct the admissible-`G`-cover stack over a base scheme and identify it
  with balanced twisted `G`-covers. Their definition permits ramification at
  balanced nodes. [arXiv paper](https://arxiv.org/abs/math/0106211).
- Tyler J. Jarvis, Ralph Kaufmann, and Takashi Kimura, *Pointed admissible
  G-covers and G-equivariant cohomological field theories*,
  **Compositio Mathematica 141** (2005), 926--978, define the pointed stack,
  its marking, group, symmetric, and braid actions, and the gluing-trees
  morphism for inverse node monodromies. Definition 2.28 is the exact
  four-point/two-three-point factorization used in test 0098.
  [Journal paper](https://www.math.purdue.edu/~rkaufman/pubfiles/JKK1.pdf).
- Johannes Schmitt and Jason van Zelm, *Intersections of loci of admissible
  covers with tautological classes*, **Selecta Mathematica 26** (2020),
  gives a modern admissible-`G`-graph formulation of balanced ramified
  boundary strata and their natural gluing maps.
  [Journal article](https://link.springer.com/article/10.1007/s00029-020-00603-4).

These sources, together with the adjacent-split finite audit, support the
ramified-node Galois transfer in test 0098. Cau's unramified-node
specialization is not used for that step.

### M23 data and present arithmetic status

- The [ATLAS of Finite Group Representations M23 page](https://atlas.math.rwth-aachen.de/Atlas/v3/spor/M23/index.html)
  supplies class names, centralizer orders, power maps, representatives, and
  maximal subgroups. The repository separately reconstructs the relevant
  natural-action classes and tests generation in the permutation group.
- David Zywina, *The Inverse Galois Problem for Small Simple Groups*, updated
  August 2025, independently lists `M23` among the simple groups of order at
  most `10^8` not known to occur over `Q`.
  [Author-hosted paper](https://pi.math.cornell.edu/~zywina/papers/smallGalois.pdf).
- Béranger Seguin, *Fields of Definition of Components of Hurwitz Spaces*,
  accepted for publication in **Annali della Scuola Normale Superiore di Pisa,
  Classe di Scienze** in May 2025, proves the existence of a four-branch
  component of marked connected `M23` covers defined over `Q`. It does not
  produce a rational point, a cover over `Q`, or equations.
  [arXiv paper](https://arxiv.org/abs/2303.05903),
  [journal DOI](https://doi.org/10.2422/2036-2145.202310_013).
- Joachim König's peer-reviewed *Computation of Hurwitz spaces and new explicit
  polynomials for almost simple Galois groups*, **Mathematics of Computation
  86** (2017), 1473--1498, is a strong worked model for passing from Hurwitz
  computations to explicit polynomials, although its main groups are not
  `M23`. [Journal DOI](https://doi.org/10.1090/mcom/3116).
- König's 2014 dissertation, *Computation of Hurwitz Spaces*, contains the
  primary `(2A,2A,3A,5A)` `M23` calculation in Chapter 5.3. Its official OPUS
  attachment supplies the 980 numerical covers and the exact
  bidegree-`(97,98)` genus-43 curve equation.
  [Dissertation](https://opus.bibliothek.uni-wuerzburg.de/opus4-wuerzburg/files/10014/Koenig_Joachim_Dissertation.pdf),
  [official artifact archive](https://opus.bibliothek.uni-wuerzburg.de/opus4-wuerzburg/files/10014/Polynomials_And_Approximation_Data.zip).
  Test 0101 authenticates the archive, independently recomputes the braid
  count and genera, and exactly checks its reported rational points. The M23
  chapter is a dissertation source rather than a peer-reviewed numerical
  reproduction, so the repository keeps those distinctions explicit.

### Explicit Belyi computation

- Jeroen Sijsling and John Voight, *On computing Belyi maps*, **Publications
  Mathématiques de Besançon** (2014), 73--131, surveys direct, complex,
  modular, and p-adic methods. Its Example 7.9 specifically enumerates a
  degree-23 passport by working inside `M23` and records that `M23` is its own
  normalizer in `S23`.
  [Journal article](https://doi.org/10.5802/pmb.5).
- Michael Musty, Sam Schiavone, Jeroen Sijsling, and John Voight, *A Database
  of Belyi Maps*, **Open Book Series 2** (2019), 375--392, describes the
  numerical database and descent data. The associated
  [Belyi package](https://github.com/michaelmusty/Belyi) accepts permutation
  triples directly in Magma.
- Dominik Barth and Andreas Wenz, *Computation of Belyi maps with prescribed
  ramification and applications in Galois theory*, **Journal of Algebra 569**
  (2021), 616--642, computes and rigorously verifies high-degree genus-zero
  maps with prescribed almost-simple and sporadic monodromy.
  [Journal DOI](https://doi.org/10.1016/j.jalgebra.2020.10.040).
- Noam Elkies, *The complex polynomials P(x) with Gal(P(x)-t) = M23*,
  **Open Book Series 1** (2013), 359--367, gives an explicit degree-23 `M23`
  Belyi polynomial obtained from an eight-variable finite-field and lifting
  calculation. Its passport differs from this project's target, but it is the
  closest published end-to-end benchmark.
  [Journal DOI](https://doi.org/10.2140/obs.2013.1.359).
- Dominik Barth and Andreas Wenz, *On Elkies' method for bounding the
  transitivity degree of Galois groups*, **Journal of Symbolic Computation
  108** (2022), 17--22, formulates the Hasse--Weil point-count method for
  rational functions. Test 0112 applies its exact induced-subset genus
  calculation to König's mod-19 anchor and records why direct counting over
  the required extension field is not competitive.
  [Journal DOI](https://doi.org/10.1016/j.jsc.2021.05.001),
  [arXiv](https://arxiv.org/abs/1905.05624).
- Timothy Duff and Kisun Lee, *Certifying Galois/monodromy Actions via Homotopy
  Graphs* (2026 preprint), gives a certified numerical monodromy algorithm and
  re-certifies the `M23` monodromy of Elkies' polynomial. It is a modern
  model for certifying monodromy of a numerical Belyi map.
  [arXiv](https://arxiv.org/abs/2603.17288).

These sources support treating the complete `(8A,8A,2A)` permutation
certificate as direct input to established Belyi algorithms and separating
exact ramification from certified monodromy. They do not claim that this exact
passport was already solved in the literature. The repository has since
produced and independently verified an exact equation and a rigorous interval
monodromy certificate; those are new computational results, not claims drawn
from these references.

Elkies' published polynomial has three-point passport
`(23A/23B,2A,4A)` in the natural action, so it is not itself a solved member of
the `(4A,3A,8A)` source passport identified by test 0081.  The project has an
exact branch-cycle family connecting that source passport to the
`(8A,8A,2A)` target, but did not compute source equations or the
four-point deformation.  A targeted search found no published equation for
this exact source passport; this is a search result, not a nonexistence theorem.

## Claim-by-claim dependency

| Project claim | Primary basis | Current independent evidence | Residual risk |
| --- | --- | --- | --- |
| Hurwitz moves act on product-one generating tuples, and braid orbits represent components | Matzat; Völklein; Malle--Matzat; Magaard--Shpectorov--Völklein | GAP and native implementations test the relations and preserve all tuple invariants | Reconcile pure, full, symmetric, inner, and marked conventions explicitly for each theorem |
| The order-2 boundary glues two three-point admissible covers and is Galois-stable | Abramovich--Corti--Vistoli; Jarvis--Kaufmann--Kimura; Schmitt--van Zelm | Test 0098 restricts to the standard adjacent split and checks both ordered clutching factors plus the 14-to-14 incidence | New convention proof should receive specialist review |
| M23 conjugacy classes, centralizers, power maps, and maximal subgroups | ATLAS | GAP character-table data, natural degree-23 permutations, direct class and generation checks | Paired non-rational class names require convention care |
| M23 over Q remains open | Zywina 2025; Seguin's motivation and result | Literature audit | This is time-sensitive and must be rechecked before publication |
| Häfner's small and bridge orbit numbers | Häfner 2022 preprint, as an external numerical target | Recomputed from group elements by committed GAP programs, with closure, generation, genus, and merge checks | We found no second independent publication of the exact M23 table |
| Both full `(3A)^4` components are defined over `Q` | Seguin Proposition 2.4(iv), Section 2.3.4, Theorem 5.4, and Example 5.5 | Test 0099 pins the accepted-paper scope, traverses both adjacent-braid orbits, and independently computes their genera; test 0100 certifies the complete 37,296-class total and a global character-theoretic mass identity | This is a theorem application with external geometric premises; it gives no equations or rational points |
| König's `(2A,2A,3A,5A)` curve has 980 classes and genera 119/43 before/after `C2` symmetry | König dissertation Chapter 5.3 and official archive | Tests 0101, 0103, 0104, and 0112 independently compute the inner braid actions, authenticate the archive, prove absolute irreducibility, compute genus 43 for reductions at 13 and 17, resolve singular branches, audit the coefficient map numerically, and exactly match the braid and algebraic `C2` conventions | The exact characteristic-zero coefficient-map identity and boundary interpretation are not yet independently certified; finite-field monodromy is narrowed to `M23` or `A23`, not resolved |
| The bridge-to-homogeneous `5A` construction gives three 30,400-class components | Häfner 2022 supplies the explicit construction and target | Tuple-level translation, orbit closure, sizes, genera, and component hashes are recomputed | The conceptual translation should receive a clean derivation from standard Hurwitz formulas and a second implementation review |
| `B4((4A)^4,2500)` contains exactly three components | Project-defined bounded statement; general theory from the established sources above | Complete 7,928,185-macroblock ledger, exact replay, identity-block audit, direct component reconstruction, and public proof package | This is new computational evidence, not independently peer reviewed yet |
| `B4((5A)^4,30400)` | Project-defined extension of the bounded method | Three known components are constructed; the exhaustive search was not carried out | No `(5A)^4` exhaustiveness claim is made |

## Consequences for 4A and 5A

The completed 4A statement does **not** require accepting Häfner's computation.
Häfner influenced the candidate selection, conventions, and historical
comparison. The final bounded claim is defined in the repository and is
supported by a complete computation plus separate audits. External specialists
should still review whether the certificate semantics prove precisely the
stated bounded theorem.

The `(5A)^4` construction has a stronger preprint dependency, because the
explicit bridge translation and the three known 30,400-class components were
first taken from Häfner. The repository reproduces those components but does
not certify `(5A)^4` exhaustiveness.

## Citation language

Use precise phrases:

- "reported in Häfner's 2022 preprint" for its numerical tables;
- "recomputed independently by this repository" only when the program starts
  from group/class inputs rather than the reported output;
- "peer-reviewed" only for an actual journal article;
- "accepted for publication" for Seguin until the journal assigns the final
  issue; and
- "proved by the computational certificate, subject to review" for the new
  4A statement.
