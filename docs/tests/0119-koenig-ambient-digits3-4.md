# Test 0119: König ambient digits 3 and 4

## Question

Does the successful cutoff-105 ambient relation continue from `19^2` through
`19^4` in the same deterministic gauge?

## Result

Digit 3 succeeds on every row:

```text
modulus 19^3 = 6,859
fitting residuals: 0 of 16,000
holdout residuals: 0 of 384
```

Digit 4 does not lie in the cutoff-105 image:

```text
modulus 19^4 = 130,321
fitting residuals: 869
holdout residuals: 370 of 384
```

This is another ansatz-expansion gate, not a failure of the mixed local
family. The original recovery matrix includes denominator monomials through
degree 110. Those 545 extra columns raise the exact mod-19 rank from 15,091
to 15,151 and are the next controlled test.

The valid mod-6,859 coefficient seed is committed. The rejected pivot-fitted
digit-4 vector is retained only under ignored `runs/`; it is not evidence and
is not committed. The complete cutoff-105 row and column profiles are
committed for later comparison and reuse.

## Evidence

Implementation revision:
`38bf8c853ec4d140e9830c936edeb9229e08e778`.

```text
f40eaddc7c11ca25207c54b7f7a1ae239144db8e8ade5c1181406042f8d17c96
  data/derived/m23_koenig_a_relation_ambient_digits4.tsv
8c4e0bcff4225dc49fcb843f8da6d3680ae46d29a6050a2940c89b99df622cfe
  data/derived/m23_koenig_a_relation_ambient_profiles.tsv
aaff41ba7d7cc96e65e2688e8cea19531f3825b2cefdd10b124bf7e532a5dc1c
  data/derived/m23_koenig_a_relation_coefficients_mod6859.tsv
```

The run used Sage 10.9, took 19 minutes 33 seconds wall time, and reached
3,768,700 KiB maximum RSS.
