import M23Formal.Hurwitz.Basic

/-!
# Prefix-conjugated inversion

For a standard real bouquet, complex conjugation acts on branch cycles by
inverting each entry and conjugating it by the product of preceding entries.
This file verifies the purely algebraic properties of that formula. It does
not formalize the geometric branch-cycle theorem identifying this operation
with the Galois action.
-/

namespace M23Formal.Hurwitz

variable {G : Type*} [Group G]

/-- Prefix-conjugated inversion, carrying the current prefix explicitly. -/
def conjugateAux (acc : G) : List G → List G
  | [] => []
  | g :: tail =>
      (acc * g⁻¹ * acc⁻¹) :: conjugateAux (acc * g) tail

/-- Prefix-conjugated inversion beginning with the identity prefix. -/
def complexConjugate (tuple : List G) : List G :=
  conjugateAux 1 tuple

@[simp] theorem conjugateAux_length (acc : G) (tuple : List G) :
    (conjugateAux acc tuple).length = tuple.length := by
  induction tuple generalizing acc with
  | nil => rfl
  | cons g tail ih => simp [conjugateAux, ih]

/-- The product of a conjugated list is the conjugate of its inverse product. -/
theorem prod_conjugateAux (acc : G) (tuple : List G) :
    (conjugateAux acc tuple).prod = acc * tuple.prod⁻¹ * acc⁻¹ := by
  induction tuple generalizing acc with
  | nil => simp [conjugateAux]
  | cons g tail ih =>
      simp [conjugateAux, ih]
      group

@[simp] theorem prod_complexConjugate (tuple : List G) :
    (complexConjugate tuple).prod = tuple.prod⁻¹ := by
  simp [complexConjugate, prod_conjugateAux]

theorem complexConjugate_preserves_product_one {tuple : List G}
    (productOne : tuple.prod = 1) : (complexConjugate tuple).prod = 1 := by
  simp [productOne]

/-- Prefix-conjugated inversion is an involution, with inverse prefix. -/
theorem conjugateAux_involutive (acc : G) (tuple : List G) :
    conjugateAux acc⁻¹ (conjugateAux acc tuple) = tuple := by
  induction tuple generalizing acc with
  | nil => simp [conjugateAux]
  | cons g tail ih =>
      simp only [conjugateAux]
      rw [List.cons.injEq]
      constructor
      · group
      · have nextAcc : acc⁻¹ * (acc * g⁻¹ * acc⁻¹) = (acc * g)⁻¹ := by
          group
        rw [nextAcc]
        exact ih (acc * g)

@[simp] theorem complexConjugate_involutive (tuple : List G) :
    complexConjugate (complexConjugate tuple) = tuple := by
  simpa [complexConjugate] using conjugateAux_involutive (1 : G) tuple

end M23Formal.Hurwitz
