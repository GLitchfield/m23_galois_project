import Mathlib.Data.Fin.Tuple.Reflection

/-!
# Checkable degree-23 permutation tables

The computational certificates encode a permutation by its forward and inverse
tables.  The `Valid` predicate checks that the tables really are mutual
inverses.  Multiplication uses GAP's right-action convention:
`i^(a*b) = (i^a)^b`.
-/

namespace M23Formal.Permutations

structure Perm23 where
  forward : Fin 23 → Fin 23
  inverse : Fin 23 → Fin 23

namespace Perm23

def Valid (permutation : Perm23) : Prop :=
  (∀ point, permutation.inverse (permutation.forward point) = point) ∧
  (∀ point, permutation.forward (permutation.inverse point) = point)

def Same (left right : Perm23) : Prop :=
  ∀ point, left.forward point = right.forward point

def validBool (permutation : Perm23) : Bool :=
  (List.finRange 23).all fun point =>
    permutation.inverse (permutation.forward point) == point &&
    permutation.forward (permutation.inverse point) == point

def sameBool (left right : Perm23) : Bool :=
  (List.finRange 23).all fun point =>
    left.forward point == right.forward point

def one : Perm23 := ⟨id, id⟩

def mul (left right : Perm23) : Perm23 :=
  ⟨fun point => right.forward (left.forward point),
   fun point => left.inverse (right.inverse point)⟩

def inv (permutation : Perm23) : Perm23 :=
  ⟨permutation.inverse, permutation.forward⟩

def pow (permutation : Perm23) : Nat → Perm23
  | 0 => one
  | exponent + 1 => mul (pow permutation exponent) permutation

def orderEight (permutation : Perm23) : Prop :=
  Same (pow permutation 8) one ∧ ¬Same (pow permutation 4) one

def orderEightBool (permutation : Perm23) : Bool :=
  sameBool (pow permutation 8) one && !sameBool (pow permutation 4) one

/-- GAP's `g^x = x^-1*g*x` convention. -/
def conjugate (element conjugator : Perm23) : Perm23 :=
  mul (mul (inv conjugator) element) conjugator

end Perm23

abbrev Tuple4 := Fin 4 → Perm23

namespace Tuple4

def Same (left right : Tuple4) : Prop :=
  ∀ index, Perm23.Same (left index) (right index)

def Valid (tuple : Tuple4) : Prop :=
  ∀ index, (tuple index).Valid

def validBool (tuple : Tuple4) : Bool :=
  (List.finRange 4).all fun index => (tuple index).validBool

def product (tuple : Tuple4) : Perm23 :=
  Perm23.mul (Perm23.mul (Perm23.mul (tuple 0) (tuple 1)) (tuple 2))
    (tuple 3)

def productOne (tuple : Tuple4) : Prop :=
  Perm23.Same tuple.product Perm23.one

def productOneBool (tuple : Tuple4) : Bool :=
  Perm23.sameBool tuple.product Perm23.one

def entriesOrderEight (tuple : Tuple4) : Prop :=
  ∀ index, (tuple index).orderEight

def entriesOrderEightBool (tuple : Tuple4) : Bool :=
  (List.finRange 4).all fun index => (tuple index).orderEightBool

def sameBool (left right : Tuple4) : Bool :=
  (List.finRange 4).all fun index => Perm23.sameBool (left index) (right index)

def simultaneousConjugate (tuple : Tuple4) (conjugator : Perm23) : Tuple4 :=
  fun index => Perm23.conjugate (tuple index) conjugator

/-- The three adjacent Hurwitz moves, corresponding to GAP indices 2, 3, 4. -/
def hurwitzMoves (tuple : Tuple4) : Fin 3 → Tuple4 :=
  ![
    ![Perm23.mul (Perm23.mul (tuple 0) (tuple 1)) (Perm23.inv (tuple 0)),
      tuple 0, tuple 2, tuple 3],
    ![tuple 0,
      Perm23.mul (Perm23.mul (tuple 1) (tuple 2)) (Perm23.inv (tuple 1)),
      tuple 1, tuple 3],
    ![tuple 0, tuple 1,
      Perm23.mul (Perm23.mul (tuple 2) (tuple 3)) (Perm23.inv (tuple 2)),
      tuple 2]
  ]

private def prefixInverse (accumulator element : Perm23) : Perm23 :=
  Perm23.mul (Perm23.mul accumulator (Perm23.inv element))
    (Perm23.inv accumulator)

/-- Prefix-conjugated inversion specialized to four entries. -/
def complexConjugate (tuple : Tuple4) : Tuple4 :=
  let prefix12 := Perm23.mul (tuple 0) (tuple 1)
  let prefix123 := Perm23.mul prefix12 (tuple 2)
  ![Perm23.inv (tuple 0),
    prefixInverse (tuple 0) (tuple 1),
    prefixInverse prefix12 (tuple 2),
    prefixInverse prefix123 (tuple 3)]

end Tuple4

end M23Formal.Permutations
