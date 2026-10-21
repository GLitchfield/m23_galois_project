// Fast runtime check for the exact-output conventions used by class1_pilot.m.
// This does not load the Belyi package or attempt the M23 computation.

SetColumns(0);
Qx<x> := PolynomialRing(Rationals());
K<a> := NumberField(x^2 - 2);

field_polynomial := Coefficients(DefiningPolynomial(K));
numerator := [K | 2 + a, 0, 3 - a];
denominator := [K | 1, a];
coefficient_vector := func<c | Eltseq(c)>;

printf "M23_SMOKE_FIELD_POLYNOMIAL=%o\n", Sprint(field_polynomial);
printf "M23_SMOKE_NUMERATOR=%o\n",
       Sprint([coefficient_vector(c) : c in numerator]);
printf "M23_SMOKE_DENOMINATOR=%o\n",
       Sprint([coefficient_vector(c) : c in denominator]);
print "M23_SMOKE_COMPLETE=true";
quit;
