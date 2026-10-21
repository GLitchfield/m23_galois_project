import Mathlib.GroupTheory.Perm.Fin

/-!
# Finite logical certificate for tests 0099 and 0100

The geometric and computational inputs are deliberately outside this file:

* Seguin supplies a fixed component in the rational passport;
* GAP supplies the two exhaustive component sizes and inverse-pair counts.

Lean checks the finite deduction applied to those inputs. In particular, a
permutation of a two-element component set with one fixed point is the identity.
-/

namespace M23Formal.Certificates.Test0099

theorem component_sizes_exhaust_total : 8316 + 28980 = 37296 := by
  decide

theorem inverse_pair_orbits_exhaust_total : 12 + 28 = 40 := by
  decide

theorem inverse_pair_elements_exhaust_total : 2160 + 5040 = 7200 := by
  decide

theorem fixed_one_of_two_forces_both :
    ∀ σ : Equiv.Perm (Fin 2),
      (∃ i, σ i = i) → ∀ j, σ j = j := by
  decide

end M23Formal.Certificates.Test0099
