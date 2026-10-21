Read("src/gap/nielsen.g");;
SizeScreen([1000000, 1000000]);;

if not IsBound(GAPInfo.SystemEnvironment.M23_OUTPUT) then
  Error("M23_OUTPUT must name the output file");
fi;
if not IsBound(GAPInfo.SystemEnvironment.M23_CODE_REVISION) then
  Error("M23_CODE_REVISION must name the generating Git revision");
fi;
output := GAPInfo.SystemEnvironment.M23_OUTPUT;;

# Seguin, Example 5.5.  Keep the printed convention b = h^-1*a*h.
a := (1,22,14)(2,13,9)(3,8,6)(7,16,21)(10,18,19)(11,23,12);;
h := (1,17)(3,21,7)(4,13)(5,22,15,23,9,16)
     (6,10,11,8,20,19)(12,14,18);;
b := h^-1 * a * h;;

G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
class3A := First(classes, class -> a in class);;
class3AElements := AsList(class3A);;
centralizer := Centralizer(G, a);;
centralizerElements := AsList(centralizer);;

Assert(0, Order(a) = 3);
Assert(0, Size(class3A) = 56672);
Assert(0, Size(centralizer) = 180);
Assert(0, Size(G) = 10200960);
Assert(0, IsTrivial(Centre(G)));
Assert(0, a^-1 in class3A);

CanonicalFixedFirst := function(tuple)
  local minimum, element, candidate;
  Assert(0, tuple[1] = a);
  minimum := fail;
  for element in centralizerElements do
    candidate := SimultaneousConjugate(tuple, element);
    if minimum = fail or candidate < minimum then
      minimum := candidate;
    fi;
  od;
  return minimum;
end;;

NormalizeFirst := function(tuple)
  local transporter, normalized;
  if tuple[1] = a then
    return tuple;
  fi;
  transporter := RepresentativeAction(G, tuple[1], a);
  if transporter = fail then
    Error("a Hurwitz image left class 3A");
  fi;
  normalized := SimultaneousConjugate(tuple, transporter);
  Assert(0, normalized[1] = a);
  return normalized;
end;;

CanonicalHurwitzImage := function(tuple, generator)
  local moved;
  moved := HurwitzMove(tuple, generator);
  Assert(0, IsProductOneTuple(moved));
  Assert(0, IsGeneratingTuple(G, moved));
  return CanonicalFixedFirst(NormalizeFirst(moved));
end;;

CanonicalMovedImage := function(tuple, move)
  local moved;
  moved := move(tuple);
  Assert(0, IsProductOneTuple(moved));
  Assert(0, IsGeneratingTuple(G, moved));
  Assert(0, ForAll(moved, entry -> entry in class3A));
  return CanonicalFixedFirst(NormalizeFirst(moved));
end;;

DiscoverFullBraidComponent := function(seed)
  local state, position, generator, image, known;
  seed := CanonicalFixedFirst(seed);
  state := rec(
    representatives := [seed],
    index := NewDictionary(seed, true),
    transitions := [[], [], []]
  );
  AddDictionary(state.index, seed, 1);
  position := 1;
  while position <= Length(state.representatives) do
    for generator in [2..4] do
      image := CanonicalHurwitzImage(
        state.representatives[position], generator);
      known := LookupDictionary(state.index, image);
      if known = fail then
        Add(state.representatives, image);
        known := Length(state.representatives);
        AddDictionary(state.index, image, known);
      fi;
      state.transitions[generator - 1][position] := known;
    od;
    position := position + 1;
  od;
  state.permutations := List(state.transitions, PermList);
  Assert(0, IsTransitive(Group(state.permutations),
    [1..Length(state.representatives)]));
  return state;
end;;

ComponentActionPermutation := function(component, move)
  local images, tuple, image, index;
  images := [];
  for tuple in component.representatives do
    image := CanonicalMovedImage(tuple, move);
    index := LookupDictionary(component.index, image);
    if index = fail then
      Error("symmetric action left its full braid component");
    fi;
    Add(images, index);
  od;
  return PermList(images);
end;;

NumberCyclesOn := function(permutation, degree)
  return Length(Cycles(permutation, [1..degree]));
end;;

CycleShape := function(permutation, degree)
  local lengths;
  lengths := Collected(List(Cycles(permutation, [1..degree]), Length));
  return JoinStringsWithSeparator(List(lengths, pair ->
    Concatenation(String(pair[1]), "^", String(pair[2]))), " ");
end;;

ComponentSymmetricData := function(component)
  local degree, beta3, eta23, eta234, genus;
  degree := Length(component.representatives);
  beta3 := ComponentActionPermutation(component,
    tuple -> HurwitzMove(tuple, 3));
  eta23 := ComponentActionPermutation(component, Eta23Move4);
  eta234 := ComponentActionPermutation(component, Eta234Move4);
  genus := 1 - degree +
    (3 * degree - NumberCyclesOn(beta3, degree) -
      NumberCyclesOn(eta23, degree) -
      NumberCyclesOn(eta234, degree)) / 2;
  Assert(0, IsInt(genus));
  Assert(0, IsTransitive(Group([beta3, eta23, eta234]), [1..degree]));
  return rec(
    genus := genus,
    beta3_cycle_shape := CycleShape(beta3, degree),
    eta23_cycle_shape := CycleShape(eta23, degree),
    eta234_cycle_shape := CycleShape(eta234, degree)
  );
end;;

seguinSeed := [a, a^-1, b, b^-1];;
Assert(0, IsProductOneTuple(seguinSeed));
Assert(0, IsGeneratingTuple(G, seguinSeed));
Assert(0, ForAll(seguinSeed, entry -> entry in class3A));

firstComponent := DiscoverFullBraidComponent(seguinSeed);;

# Fixing the first entry a leaves conjugation by C_G(a).  Its orbits on the
# possible second generator c exhaust the inner classes of inverse-pair tuples
# (a,a^-1,c,c^-1).  This is much smaller than enumerating all (3A)^4 tuples.
secondGeneratorOrbits := OrbitsDomain(centralizer, class3AElements, OnPoints);;
Assert(0, Sum(secondGeneratorOrbits, Length) = Size(class3A));

generatingRecords := [];;
otherSeed := fail;;
nonGeneratingOrbitCount := 0;;
nonGeneratingElementCount := 0;;
for orbit in secondGeneratorOrbits do
  candidateB := orbit[1];
  if Group(a, candidateB) = G then
    candidateSeed := CanonicalFixedFirst(
      [a, a^-1, candidateB, candidateB^-1]);
    firstIndex := LookupDictionary(firstComponent.index, candidateSeed);
    Add(generatingRecords, rec(
      seed := candidateSeed,
      orbit_size := Length(orbit),
      in_first := firstIndex <> fail
    ));
    if firstIndex = fail and otherSeed = fail then
      otherSeed := candidateSeed;
    fi;
  else
    nonGeneratingOrbitCount := nonGeneratingOrbitCount + 1;
    nonGeneratingElementCount := nonGeneratingElementCount + Length(orbit);
  fi;
od;
Assert(0, otherSeed <> fail);

secondComponent := DiscoverFullBraidComponent(otherSeed);;
componentSizes := Set([
  Length(firstComponent.representatives),
  Length(secondComponent.representatives)
]);;
Assert(0, componentSizes = [8316, 28980]);
Assert(0, Sum(componentSizes) = 37296);

firstPairOrbitCount := 0;;
firstPairElementCount := 0;;
secondPairOrbitCount := 0;;
secondPairElementCount := 0;;
for record in generatingRecords do
  if record.in_first then
    firstPairOrbitCount := firstPairOrbitCount + 1;
    firstPairElementCount := firstPairElementCount + record.orbit_size;
  else
    Assert(0, LookupDictionary(secondComponent.index, record.seed) <> fail);
    secondPairOrbitCount := secondPairOrbitCount + 1;
    secondPairElementCount := secondPairElementCount + record.orbit_size;
  fi;
od;
Assert(0, firstPairOrbitCount > 0 and secondPairOrbitCount > 0);
Assert(0, ForAll(generatingRecords, record -> record.orbit_size = Size(centralizer)));
Assert(0, firstPairElementCount + secondPairElementCount +
  nonGeneratingElementCount = Size(class3A));

firstSymmetric := ComponentSymmetricData(firstComponent);;
secondSymmetric := ComponentSymmetricData(secondComponent);;
Assert(0, firstSymmetric.genus = 1206);
Assert(0, secondSymmetric.genus = 325);

PrintTo(output,
  "# generated_by\tscripts/gap/reconcile_seguin_3a_components.g\n",
  "# code_revision\t", GAPInfo.SystemEnvironment.M23_CODE_REVISION, "\n",
  "# gap_version\t", GAPInfo.Version, "\n",
  "# atlasrep_version\t", GAPInfo.PackagesInfo.atlasrep[1].Version, "\n",
  "# ctbllib_version\t", GAPInfo.PackagesInfo.ctbllib[1].Version, "\n",
  "# transgrp_version\t", GAPInfo.PackagesInfo.transgrp[1].Version, "\n",
  "# group\tM23\n",
  "# group_order\t", Size(G), "\n",
  "# atlas_class\t3A\n",
  "# source_tuple\tSeguin Example 5.5\n",
  "# published_comparison\tHafner 2022 table Data_BraidOrbitsOfM23\n",
  "property\tvalue\n",
  "class_size\t", Size(class3A), "\n",
  "fixed_first_centralizer_order\t", Size(centralizer), "\n",
  "fixed_first_second_generator_orbits\t",
    Length(secondGeneratorOrbits), "\n",
  "computed_two_component_size_sum\t", Sum(componentSizes), "\n",
  "generating_inverse_pair_orbits\t", Length(generatingRecords), "\n",
  "generating_inverse_pair_elements\t",
    firstPairElementCount + secondPairElementCount, "\n",
  "nongenerating_second_generator_orbits\t", nonGeneratingOrbitCount, "\n",
  "nongenerating_second_generator_elements\t", nonGeneratingElementCount, "\n",
  "both_full_braid_components_contain_inverse_pairs\ttrue\n",
  "\n",
  "component\tinner_full_braid_size\tmarked_full_braid_size\t",
    "computed_symmetric_genus\tinverse_pair_centralizer_orbits\t",
    "inverse_pair_elements\tbeta3_cycle_shape\teta23_cycle_shape\t",
    "eta234_cycle_shape\trepresentative_second_generator\n",
  "seguin_printed_h\t", Length(firstComponent.representatives), "\t",
    Length(firstComponent.representatives) * Size(G), "\t",
    firstSymmetric.genus, "\t", firstPairOrbitCount, "\t",
    firstPairElementCount, "\t", firstSymmetric.beta3_cycle_shape, "\t",
    firstSymmetric.eta23_cycle_shape, "\t",
    firstSymmetric.eta234_cycle_shape, "\t", b, "\n",
  "other_component\t", Length(secondComponent.representatives), "\t",
    Length(secondComponent.representatives) * Size(G), "\t",
    secondSymmetric.genus, "\t", secondPairOrbitCount, "\t",
    secondPairElementCount, "\t", secondSymmetric.beta3_cycle_shape, "\t",
    secondSymmetric.eta23_cycle_shape, "\t",
    secondSymmetric.eta234_cycle_shape, "\t", otherSeed[3], "\n");
QUIT;
