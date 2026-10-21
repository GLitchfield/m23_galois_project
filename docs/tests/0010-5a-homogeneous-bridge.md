# Test 0010: translated `(5A)^4` components

## Question

Do the certified `(5A,5A,2A,2A)` bridge classes translate to Häfner's three
known 30,400-class pure components and their combined 91,200-class symmetric
component in `(5A)^4`?

## Method

Apply the explicit `g_4,1` map from Häfner's translation theorem to the
fixed-first bridge representatives. Starting with one generating translate,
close under the three pure braid generators and the full equal-class symmetry
generators `beta3`, `eta23`, and `eta234`. Normalize every image back to the
fixed first coordinate algebraically and quotient by its centralizer.

The runner checks that every generating `g_4,1` translate from all 30,400
certified bridge classes occurs in the constructed action. The 4A case is a
separate small regression for the same generic implementation. Run a complete
bridge regeneration and homogeneous construction with:

```sh
make check-5a-homogeneous
```

## Result

- all 30,400 bridge representatives have generating `g_4,1` translates;
- those translates occupy one pure component;
- full symmetry closes on 91,200 inner classes;
- the pure subgroup has three components, each of size 30,400 and genus 5,626;
- the symmetric action is transitive and has genus 2,071;
- all six complete action cycle shapes have degree 91,200;
- independent Riemann--Hurwitz checks recover the sum of the pure genera and
  the symmetric genus from those cycle shapes.

All reported component sizes, multiplicities, and genera match Häfner. This
reproduces the components forced by the bridge; it is not an exhaustiveness
claim about the roughly 1.81 billion generating classes in `(5A)^4`.

## Reproducibility record

- implementation revision: recorded by the Git commit containing this note;
- GAP 4.12.1, AtlasRep 2.1.8, CTblLib 1.3.7;
- input: the certified 16-shard `(5A,5A,2A,2A)` bridge;
- provenance: locally regenerated orbit action, with the compact merged cycle
  data committed below.

## Artifact

- `data/derived/m23_5a_homogeneous_bridge_orbit.tsv`
