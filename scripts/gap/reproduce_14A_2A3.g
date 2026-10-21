Read("src/gap/m23_fixed_first.g");;
SizeScreen([100000, 100000]);;

G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
class2 := First(classes, class -> Order(Representative(class)) = 2);;
classes14 := Filtered(classes, class -> Order(Representative(class)) = 14);;

Assert(0, Length(classes14) = 2);
Assert(0, Size(class2) = 3795);

expected := rec(
  product_tuples := 3724,
  product_orbits := 280,
  nielsen_size := 84,
  beta3_cycle_shape := "3^1 4^3 5^3 6^9",
  eta23_cycle_shape := "2^42",
  eta234_cycle_shape := "3^28",
  symmetric_genus := 0
);;

results := List(classes14, class -> AnalyzeM23FixedFirstInvolutionTriple(
  G, class2, class, Position(classes, class), expected));;

if not IsBound(GAPInfo.SystemEnvironment.M23_OUTPUT) then
  Error("M23_OUTPUT must name the generated TSV file");
fi;
WriteM23FixedFirstResults(GAPInfo.SystemEnvironment.M23_OUTPUT,
  "scripts/gap/reproduce_14A_2A3.g", G, results);
QUIT;
