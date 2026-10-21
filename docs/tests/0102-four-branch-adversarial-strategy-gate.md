# Test 0102: four-branch adversarial strategy gate

## Question

After the negative small-`(8A)^4` result and recovery of König's explicit
curve, which claims survive an adversarial evidence review and which
calculation has the highest direct arithmetic value?

## Review protocol

At clean revision `a8201b7`, the local adversarial-review harness supplied the
same 191,066-byte evidence packet to Claude Fable 5 and Codex `gpt-5.4`.
Each model first answered independently and then critiqued the other's
answer.  The packet hash was
`c5dd1c0f11e5de9c3cb7b42493fe5b4d26c38da21ddc4be48f91208e3247e104`.
The complete ignored run is under
`runs/reviews/0101-four-branch-and-next-route-retry/`.

Model output is advisory and is not mathematical evidence.  The useful
outcome is a list of falsifiable objections that the repository can answer
with primary text or exact computation.

## Adjudicated claims

| Claim | Status | Basis |
| --- | --- | --- |
| the generating inner `(3A)^4` Nielsen class has 37,296 elements and exactly two full components | supported computationally | Test 0100's complete macroblock enumeration and Test 0099's two closed traversals |
| the finite two-element Galois-set deduction is valid | supported conditionally | Lean checks the finite tail; the hypotheses come from theory and computation |
| both `(3A)^4` components are defined over `Q` | valid theorem chain with external premises | the accepted Seguin text explicitly supplies a connected full-`M23` component; Proposition 2.4(iv) and Section 2.3.4 supply the convention bridge |
| König's archived equation is already independently certified as the characteristic-zero genus-43 Hurwitz curve | unsupported | absolute irreducibility, two modular genus-43 certificates, exact singular branches, and the complete numerical coefficient-map audit pass; the exact nonconstant component-to-plane map remains open |
| a known rational point produces an `M23/Q` realization | unsupported | boundary status, normalization branches, the coefficient map, and the precise reduced-curve descent statement remain unresolved |
| a bounded `(5A)^4` census is presently the best next calculation | unsupported as a priority | it proves bounded exhaustiveness but presently has no stronger arithmetic implication |

## Objections converted to certificates

The review exposed four concrete improvements.

1. Test 0099 now pins each Seguin bridge to its exact accepted-paper location
   and records why the fixed component is inside the generating two-set.
2. The two `(3A)^4` symmetric genera are computed from the actual
   `β₃,η₂₃,η₂₃₄` actions instead of being imported from Häfner.
3. Test 0100 adds a global character-theoretic mass identity and both Seguin
   artifacts record code and package provenance.
4. Tests 0101 and 0103 make the characteristic-zero normalization genus a hard
   gate before coefficient-map reconstruction. Absolute irreducibility,
   modular genus 43 at two primes, and the reported singular-point branches
   are now exact; only the characteristic-zero comparison remains.

## Ranked continuation with stopping gates

1. Having certified absolute irreducibility, two modular genus-43
   normalizations, and the places over both known singular rational points,
   certify the characteristic-zero genus through the component-to-plane map
   or a direct global delta sum. Stop and re-examine the archive
   identification if the comparison fails.
2. Pin the theorem that translates a rational interior place on the relevant
   `C2`-symmetrized inner/reduced curve into cover data over `Q`; do not assume
   that a rational point on a quotient automatically lifts rationally.
3. Decode or reconstruct the 46 archived numerical cover coefficients, the
   rational map from the normalized curve to coefficient space, and the
   degeneration divisor.  Stop and switch to certified numerical
   reconstruction if the archived precision cannot distinguish the map.
4. Determine exactly whether each known rational place is boundary or
   interior.  An interior place becomes an explicit realization candidate;
   proving that all known places are boundary only eliminates those places.
5. Only then run a preregistered rational-point search or local-obstruction
   calculation.  Defer the bounded 5A census and equations for the high-genus
   `(3A)^4` components until they acquire a clearer arithmetic payoff.

This ranking does not claim that the König route will succeed.  It says that
its next failure or success can be expressed as a narrow, independently
checkable arithmetic certificate.
