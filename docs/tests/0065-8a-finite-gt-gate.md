# Test 0065: finite Grothendieck--Teichmüller gate for the 8A boundary target

## Question

Can Guillot's explicit finite Grothendieck--Teichmüller group for a
nonabelian simple group determine, or tightly constrain, the unknown Galois
action on the 28 generating `(8A,8A,2A)` inner classes from test 0064?

## Primary theorem and conventions

Let `P_c` be the simultaneous-conjugacy classes of ordered generating pairs
`[g,h]` in a finite group `G`.  In Section 4 of
[Guillot](https://arxiv.org/abs/1407.3112), the two relevant permutations are

```text
theta [g,h] = [h,g]
delta [g,h] = [h^-1*g^-1,h].
```

They generate an image of `S3`.  Guillot defines `S(G)` to be the
permutations of `P_c` that commute with `Out(G)` and these two permutations,
while preserving each block defined by the conjugacy classes of the first and
second entries.  His main theorem for simple groups identifies

```text
GT_1(G) = S(G)
```

for nonabelian simple `G`.

The ATLAS M23 page gives `Out(M23) = 1`, so no extra outer-automorphism
condition occurs here.

## Passport calculation

The test-0064 certificate shows that `theta` acts without fixed points on the
28 classes of the ordered passport `(8A,8A,2A)`: it is a product of 14
transpositions.  Applying `delta` and `theta` moves the unique `2A` entry
through the three positions.  Each transposition pair therefore expands to a
regular six-element `S3` orbit across the three ordered class-vector blocks

```text
(8A,8A), (8A,2A), (2A,8A).
```

There are 14 such regular orbits, all with the same block-incidence profile.
An `S3`-equivariant permutation may permute those 14 orbits arbitrarily.  On
each orbit, the block-preserving equivariant automorphisms form `C2`, generated
by the swap inside the `(8A,8A)` block.  Guillot's explicit description thus
gives the passport factor

```text
C2 wr S14
```

of order

```text
2^14 * 14! = 1,428,329,123,020,800.
```

The finite checks needed here—the complete class count and the fixed-point-free
involution `theta`—are reproduced by:

```sh
make reproduce-8a-small-orbits
python3 scripts/verify_8a_small_orbits.py
```

## Result and boundary

This framework is mathematically relevant but does **not** determine the
actual absolute-Galois image.  On this passport its `GT_1(M23)` upper bound
permits the full `C2 wr S14`; equivalently, commutation with the rational swap
is essentially the only restriction visible on the 28-class slice.  Computing
the rest of the enormous generating-pair universe would recover a global
finite GT group, but would not select the much smaller subgroup actually
realized by Galois on these classes.

The useful next input must therefore be genuinely arithmetic:

- fields of moduli or equations for the 28 three-point covers;
- Frobenius data capable of identifying their Galois orbits; or
- a theorem or specialist computation that determines the actual Galois image
  on this passport.

This is a negative scaling gate, not a negative result about the 8A route.  It
prevents a large computation whose output would still be too coarse, while
leaving the exact 28-class certificate ready for arithmetic data when it is
available.

## Evidence

- `data/derived/m23_8a_8a_2a_inner_classes.tsv`;
- `scripts/gap/reproduce_8A_small_orbits.g`;
- `scripts/verify_8a_small_orbits.py`;
- the ATLAS of Finite Group Representations M23 page
  (<https://atlas.math.rwth-aachen.de/Atlas/v3/spor/M23/index.html>, `Out = 1`); and
- Pierre Guillot, *The Grothendieck-Teichmüller group of a finite group and
  G-dessins d'enfants*, Section 4, especially the `theta` and `delta` lemmas
  and the main theorem for nonabelian simple groups.
