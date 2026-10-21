# Test 0075: real-Magma exact serialization smoke

## Question

Does the official Magma runtime serialize rational polynomials and
power-basis number-field coefficients in the convention required by the 8A
exact-candidate adapter?

## Method

The fixture `magma/8a_belyi/serialization_smoke.m` constructs
`K = Q(a)/(a^2-2)` and prints:

- the defining polynomial;
- a numerator containing a zero coefficient and the non-one leading
  coefficient `3-a`; and
- a denominator containing `a`.

The input at project revision `1e3323f` had SHA-256
`10ad37d47b19324ed7c225eb921bd7acaf92a2a4765989998ea3be254a231d80`.
It was submitted on 2026-07-22 to the University of Sydney's official free
Magma calculator. The service reported Magma V2.29-8, seed `3840916506`,
0.020 seconds, and 32.09 MB. The reconstructed plain-text response is
preserved in `notes/magma_8a_serialization_smoke.txt` with SHA-256
`9d7835c469df6804a199e0fedfb3989c8ab197f499a3211dc082e549e93af10b`.

## Observed adapter defect and correction

The mathematical values were correct, but Magma wrapped both nested sequences
across physical output lines despite `SetColumns(0)`. The original checker
therefore rejected a valid result because it expected each marker on one line.

The restricted parser now collects exactly one balanced bracketed sequence
after each marker, allowing whitespace and line breaks while retaining the
same rational/list-only grammar. It still rejects duplicate, missing,
unterminated, unbalanced, or expression-bearing markers. Regression fixtures
cover the actual wrapped shape and an unterminated sequence.

## Reproduction

```sh
python3 scripts/check_magma_8a_serialization_smoke.py \
  notes/magma_8a_serialization_smoke.txt
make check-magma-8a-pilot
```

## Result

Passed. Magma V2.29-8 returned the defining-polynomial coefficients
`[-2,0,1]` and fixed-width power-basis vectors in low-to-high order:

```text
numerator = [[2,1], [0,0], [3,-1]]
denominator = [[1,0], [0,1]]
```

This validates the runtime serialization convention and the multiline intake
seam. It does not load the external Belyi package, validate its stored exact
attributes, solve the degree-23 target, or certify cover monodromy.
