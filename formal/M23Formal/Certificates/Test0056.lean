import M23Formal.Certificates.Test0056Data

/-!
# Kernel-checked summary certificate for test 0056

The imported table is generated from the reproducible GAP artifact. Lean
checks, using kernel reduction (`by decide`, not the native evaluator), that it
is an involution with exactly two fixed full components and no fixed symmetric
half.

This first certificate checks the finite summary. It does not yet independently
recompute the tuple-level GAP-to-component assignments; that is the next
certificate seam.
-/

namespace M23Formal.Certificates.Test0056

theorem fullImage_involutive : ∀ i, fullImage (fullImage i) = i := by
  decide

theorem fullImage_fixed_iff : ∀ i : Fin 14,
    fullImage i = i ↔ i = 2 ∨ i = 5 := by
  decide

theorem symmetricImage_involutive : ∀ i, symmetricImage (symmetricImage i) = i := by
  decide

theorem symmetricImage_fixed_never : ∀ i : Fin 28, symmetricImage i ≠ i := by
  decide

end M23Formal.Certificates.Test0056
