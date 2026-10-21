// Bounded one-class pilot body for the pinned michaelmusty/Belyi package.
// Invoke after data/derived/m23_8a_8a_2a_belyi_input.m in the same Magma
// process, from the root of the Belyi package checkout.

IntegerEnvironment := function(name)
  raw := GetEnv(name);
  if raw eq "" then
    error Sprintf("required environment variable %o is missing", name);
  end if;
  return StringToInteger(raw);
end function;

stage := GetEnv("M23_BELYI_STAGE");
powser_mode := GetEnv("M23_BELYI_POWSER");
if stage notin {"numerical", "exact"} then
  error "M23_BELYI_STAGE must be numerical or exact";
end if;
if powser_mode eq "arnoldi" then
  powser_al := "Arnoldi";
elif powser_mode eq "carnoldi" then
  powser_al := "CArnoldi";
else
  error "M23_BELYI_POWSER must be arnoldi or carnoldi";
end if;

prec := IntegerEnvironment("M23_BELYI_PREC");
prec_newton := IntegerEnvironment("M23_BELYI_PREC_NEWTON");
degree_bound := IntegerEnvironment("M23_BELYI_DEGREE_BOUND");
class_id := IntegerEnvironment("M23_BELYI_CLASS_ID");
if prec lt 1 or prec_newton lt prec or degree_bound lt 1 or
   class_id lt 1 or class_id gt 28 then
  error "invalid precision, degree-bound, or class-ID configuration";
end if;

assert assigned triples;
assert #triples eq 28;
sigma := triples[class_id];
Gamma := TriangleSubgroup(sigma);
assert Genus(Gamma) eq 0;
assert IndexDegree(Gamma) eq 23;

// Reduce display wrapping where the runtime honors this setting. The
// restricted adapter also accepts balanced multiline sequence values.
SetColumns(0);
SetVerbose("Shimura", true);
printf "M23_PILOT_STAGE=%o\n", stage;
printf "M23_PILOT_POWSER=%o\n", powser_al;
printf "M23_PILOT_PREC=%o\n", prec;
printf "M23_PILOT_PREC_NEWTON=%o\n", prec_newton;
printf "M23_PILOT_DEGREE_BOUND=%o\n", degree_bound;
printf "M23_PILOT_CLASS_ID=%o\n", class_id;

if stage eq "numerical" then
  _ := UnitDisc(Gamma : Precision := prec);
  k := 0;
  while SkDimension(Gamma, k) lt 2 do
    k +:= 2;
  end while;
  Sk := PowerSeriesBasis(Gamma, k : dim := 2, Federalize := true,
                         Al := powser_al);
  approximate := TrianglePhiGenusZeroNumericalBelyiMap(
    Sk, Gamma : Al := "Newton", m := degree_bound,
    precNewton := prec_newton, justCC := true);
  printf "M23_NUMERICAL_LEADING=%o\n", approximate[1];
  printf "M23_NUMERICAL_NUMERATOR=%o\n", approximate[2];
  printf "M23_NUMERICAL_DENOMINATOR=%o\n", approximate[3];
  print "M23_NUMERICAL_SUCCESS=true";
else
  X, phi, solved_gamma := BelyiMap(
    Gamma : prec := prec, Al := "Newton", ExactAl := "AlgebraicNumbers",
    DegreeBound := degree_bound, precNewton := prec_newton,
    Federalize := true, PowserAl := powser_al);
  sanity := BelyiMapSanityCheck(sigma, X, phi);
  assert sanity;

  K := solved_gamma`TriangleK;
  if Type(K) eq FldRat then
    field_polynomial := [Rationals() | ];
    coefficient_vector := func<c | [Rationals() | c]>;
  else
    field_polynomial := Coefficients(DefiningPolynomial(K));
    coefficient_vector := func<c | Eltseq(c)>;
  end if;
  leading := solved_gamma`TriangleExactBelyiMapLeadingCoefficient;
  numerator := [leading*c :
    c in solved_gamma`TriangleExactBelyiMapNumeratorCoefficients];
  denominator := solved_gamma`TriangleExactBelyiMapDenominatorCoefficients;

  printf "M23_EXACT_FIELD_POLYNOMIAL=%o\n", Sprint(field_polynomial);
  printf "M23_EXACT_NUMERATOR=%o\n",
         Sprint([coefficient_vector(c) : c in numerator]);
  printf "M23_EXACT_DENOMINATOR=%o\n",
         Sprint([coefficient_vector(c) : c in denominator]);
  print "M23_EXACT_SANITY=true";
end if;

print "M23_PILOT_COMPLETE=true";
quit;
