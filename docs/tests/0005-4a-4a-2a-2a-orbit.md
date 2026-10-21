# Test 0005: the `(4A,4A,2A,2A)` orbit

## Question

Can the first larger completed rational M23 computation be reproduced: 2,456
inner Nielsen classes in one pure braid orbit of genus 447, with symmetric genus
169?

## Method

Fix `s1` in `4A`, enumerate the roughly 14.4 million ordered involution pairs
`(s3,s4)`, and derive

```text
s2 = s1^-1 (s3 s4)^-1.
```

Retain tuples where `s2` has order 4, quotient under `C_M23(s1)`, and filter for
generation. A GAP dictionary indexes every fixed-first representative, avoiding
linear scans while constructing the induced permutations of `beta12`,
`beta13`, `beta14`, `beta4`, and `eta34`.

The pure genus is computed from the first three actions. Because the class
vector is symmetric in its final two positions, the symmetric genus uses
`beta13`, `beta4`, and `eta34`, following Häfner's convention.

Run:

```sh
make reproduce-4a-orbit
make test
```

## Result

- 609,553 product-one tuples after fixing `s1`;
- 19,609 inner classes before generation is imposed;
- 2,456 generating inner Nielsen classes;
- one transitive pure `B4` orbit of size 2,456;
- pure genus 447;
- symmetric orbit size 2,456 and genus 169.

The Nielsen count, orbit size, and both genera reproduce Häfner's table exactly.
The generated artifact also records complete cycle shapes for the five actions.

## Artifact

`data/derived/m23_4a_4a_2a_2a_orbit.tsv`
