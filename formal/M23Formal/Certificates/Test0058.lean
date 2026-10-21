import M23Formal.Certificates.Test0056Data
import M23Formal.Certificates.Test0058Data

/-!
# Tuple-level certificate for the small 8A components

This certificate checks concrete degree-23 permutation tables.  For every
vertex and each adjacent Hurwitz generator, GAP supplied a destination vertex
and a simultaneous-conjugation witness.  It supplied the analogous witness for
prefix-conjugated inversion.  Lean recomputes all operations and checks those
witnesses in the kernel.

The certificate establishes the tuple-to-component assignments omitted by
test 0057.  It still does not formalize the geometric branch-cycle theorem that
identifies prefix-conjugated inversion with complex conjugation on covers.
-/

namespace M23Formal.Certificates.Test0058

open M23Formal.Permutations

def expandReachable (component : Fin 14) (seen : List (Fin 12)) : List (Fin 12) :=
  (seen ++ seen.flatMap fun vertex =>
    [edgeTargets component vertex 0,
     edgeTargets component vertex 1,
     edgeTargets component vertex 2]).eraseDups

def reachable (component : Fin 14) : Nat → List (Fin 12)
  | 0 => [0]
  | steps + 1 => expandReachable component (reachable component steps)

def checkPermutationTables (component : Fin 14) : Bool :=
  (List.finRange 12).all fun vertex =>
    (componentTuples component vertex).validBool &&
    (conjugateConjugators component vertex).validBool &&
    (List.finRange 3).all fun generator =>
      (edgeConjugators component vertex generator).validBool

def checkTupleInvariants (component : Fin 14) : Bool :=
  (List.finRange 12).all fun vertex =>
    (componentTuples component vertex).productOneBool &&
    (componentTuples component vertex).entriesOrderEightBool

def pairPositions : Fin 6 → Fin 4 × Fin 4 :=
  ![(0, 1), (0, 2), (0, 3), (1, 2), (1, 3), (2, 3)]

def pairProduct (tuple : Tuple4) (pair : Fin 6) : Perm23 :=
  Perm23.mul (tuple (pairPositions pair).1) (tuple (pairPositions pair).2)

def pairProductOrderTwoLabel (tuple : Tuple4) (pair : Fin 6) : Bool :=
  Perm23.sameBool (Perm23.pow (pairProduct tuple pair) 2) Perm23.one

def checkPairProductOrder (tuple : Tuple4) (pair : Fin 6) : Bool :=
  !Perm23.sameBool (pairProduct tuple pair) Perm23.one &&
    Perm23.sameBool (Perm23.pow (pairProduct tuple pair) 4) Perm23.one

def inversePairBool (tuple : Tuple4) (left right : Fin 4) : Bool :=
  Perm23.sameBool (tuple right) (Perm23.inv (tuple left))

def hasTwoInversePairs (tuple : Tuple4) : Bool :=
  (inversePairBool tuple 0 1 && inversePairBool tuple 2 3) ||
  (inversePairBool tuple 0 2 && inversePairBool tuple 1 3) ||
  (inversePairBool tuple 0 3 && inversePairBool tuple 1 2)

def checkCanonicalTuplesDistinct (component₁ : Fin 14) : Bool :=
  (List.finRange 12).all fun vertex₁ =>
    (List.finRange 14).all fun component₂ =>
      (List.finRange 12).all fun vertex₂ =>
        if component₁ == component₂ && vertex₁ == vertex₂ then true
          else !(componentTuples component₁ vertex₁).sameBool
            (componentTuples component₂ vertex₂)

def checkHurwitzEdges (component : Fin 14) : Bool :=
  (List.finRange 12).all fun vertex =>
    (List.finRange 3).all fun generator =>
      (Tuple4.simultaneousConjugate
        (Tuple4.hurwitzMoves (componentTuples component vertex) generator)
        (edgeConjugators component vertex generator)).sameBool
      (componentTuples component (edgeTargets component vertex generator))

def checkComponentConnectivity (component : Fin 14) : Bool :=
  (List.finRange 12).all fun vertex => (reachable component 12).contains vertex

def checkComplexConjugation (component : Fin 14) : Bool :=
  (List.finRange 12).all fun vertex =>
    (Tuple4.simultaneousConjugate
      (Tuple4.complexConjugate (componentTuples component vertex))
      (conjugateConjugators component vertex)).sameBool
    (componentTuples
      (conjugateTargetComponents component vertex)
      (conjugateTargetVertices component vertex))

def checkComponentMap (component : Fin 14) : Bool :=
  (List.finRange 12).all fun vertex =>
    conjugateTargetComponents component vertex ==
      M23Formal.Certificates.Test0056.fullImage component

def checkComponent (component : Fin 14) : Bool :=
  checkPermutationTables component &&
  checkTupleInvariants component &&
  checkCanonicalTuplesDistinct component &&
  checkHurwitzEdges component &&
  checkComponentConnectivity component &&
  checkComplexConjugation component &&
  checkComponentMap component

set_option maxHeartbeats 0

set_option maxRecDepth 1000000 in theorem component01_verified : checkComponent 0 = true := by rfl
set_option maxRecDepth 1000000 in theorem component02_verified : checkComponent 1 = true := by rfl
set_option maxRecDepth 1000000 in theorem component03_verified : checkComponent 2 = true := by rfl
set_option maxRecDepth 1000000 in theorem component04_verified : checkComponent 3 = true := by rfl
set_option maxRecDepth 1000000 in theorem component05_verified : checkComponent 4 = true := by rfl
set_option maxRecDepth 1000000 in theorem component06_verified : checkComponent 5 = true := by rfl
set_option maxRecDepth 1000000 in theorem component07_verified : checkComponent 6 = true := by rfl
set_option maxRecDepth 1000000 in theorem component08_verified : checkComponent 7 = true := by rfl
set_option maxRecDepth 1000000 in theorem component09_verified : checkComponent 8 = true := by rfl
set_option maxRecDepth 1000000 in theorem component10_verified : checkComponent 9 = true := by rfl
set_option maxRecDepth 1000000 in theorem component11_verified : checkComponent 10 = true := by rfl
set_option maxRecDepth 1000000 in theorem component12_verified : checkComponent 11 = true := by rfl
set_option maxRecDepth 1000000 in theorem component13_verified : checkComponent 12 = true := by rfl
set_option maxRecDepth 1000000 in theorem component14_verified : checkComponent 13 = true := by rfl

theorem ordered_braid_actions_equivalent :
    ∀ component vertex generator,
      orderedGeneratorTransporters component
        (edgeTargets 0 vertex generator) =
      edgeTargets component
        (orderedGeneratorTransporters component vertex) generator := by
  decide

theorem pair_product_orders_verified :
    ∀ component vertex pair,
      checkPairProductOrder (componentTuples component vertex) pair = true := by
  decide

theorem pair_product_labels_equivalent :
    ∀ component vertex pair,
      pairProductOrderTwoLabel (componentTuples 0 vertex) pair =
      pairProductOrderTwoLabel
        (componentTuples component
          (orderedGeneratorTransporters component vertex)) pair := by
  decide

theorem small_components_have_no_inverse_pair_factorization :
    ∀ component vertex,
      hasTwoInversePairs (componentTuples component vertex) = false := by
  decide

end M23Formal.Certificates.Test0058
