# Test 0068: normalized equations and finite-field gate for the 8A Belyi target

## Question

Can the degree-23 passport be turned into a canonical algebraic system that is
small enough for modular experimentation, and do the first finite fields offer
usable seeds?

## Normalization

Write the ordered map as `phi=P/Q`.  Over the first branch fibre, the points of
multiplicity 4, 2, and 1 are unique.  A unique source Mobius transformation
therefore sends them to `0`, `1`, and infinity.  With monic quadratic factors
`A` and `B`, the normalized identity is

```text
P = alpha A^8 x^4 (x-1)^2
F = B^8 (x-c4)^4 (x-c2)^2 (x-c1)
Q = U^2 V
P + F - Q = 0,
```

where `U` and `V` are monic of degrees 8 and 7.  Then `phi-1=-F/Q`, so the
three fibres have the desired multiplicities.  Equating degrees 0 through 22
gives 23 equations in 23 variables; the degree-23 terms of `F` and `Q` cancel.

For elimination, put `H=P+F` and retain only the condition that a monic
degree-8 polynomial `U` divides both `H` and `H'`.  The two remainders give 16
equations in the eight geometric parameters and eight coefficients of `U`.
Solutions must still be saturated away from collisions and checked to ensure
that `U` and `H/U^2` are squarefree and coprime.

## Small-characteristic probe

A dependency-free exhaustive program tested every normalized parameter tuple
over `F_3` and `F_5`, with nonzero scale and all noncollision/squarefreeness
filters:

```text
p=3 tested=4374 raw_gcd8=0 valid=0
p=5 tested=312500 raw_gcd8=0 valid=0
```

Thus neither field supplies a seed in this normalization.  This is a useful
negative engineering result, not arithmetic evidence about the 28 maps:
characteristics 3 and 5 are smaller than the ramification indices and divide
the order of `M23`.  A good-prime search begins at 13, where blind enumeration
of eight parameters is already infeasible and a Groebner, homotopy, or
dessin-seeded method is required.

Most importantly, the equations impose the cycle passport, not `M23`
monodromy.  Test 0067 shows that the ambient passport is enormous.  Every
candidate seed must eventually be connected to one of the 28 certified
permutation triples or supplied with an independent monodromy certificate.

## Reproduction

```sh
./scripts/check-8a-belyi-equations.sh
python3 scripts/search_8a_belyi_modp.py --prime 5
./scripts/setup-8a-sage.sh
./scripts/run-8a-sage.sh data/derived/m23_8a_belyi_normalized_system.sage
```

The slower `F_5` enumeration is recorded above but intentionally excluded from
the routine test suite.  The committed Magma and Sage files contain the same
full and reduced presentations.  The Sage environment is pinned separately
because installing its roughly 1 GB dependency closure is not appropriate for
the routine test suite.  Loading the generated Sage file constructs and checks
both equation lists without launching an unbounded Groebner-basis computation.

## Evidence

- `data/derived/m23_8a_belyi_normalized_system.m`;
- `data/derived/m23_8a_belyi_normalized_system.sage`;
- `sage/8a_belyi/environment.yml`;
- `scripts/generate_8a_belyi_equations.py`; and
- `scripts/search_8a_belyi_modp.py`.
