Read("src/gap/nielsen.g");;
SizeScreen([100000, 100000]);;

G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
class2 := First(classes, class -> Order(Representative(class)) = 2);;
class8 := First(classes, class -> Order(Representative(class)) = 8);;
first8 := Representative(class8);;
centralizer8 := Centralizer(G, first8);;

Assert(0, Size(class2) = 3795);
Assert(0, Size(class8) = 1275120);
Assert(0, Size(centralizer8) = 8);
Assert(0, Size(Centre(G)) = 1);
Assert(0, Normalizer(SymmetricGroup(23), G) = G);

productTuples := [];;
product4TupleCount := 0;;
generatingProduct4TupleCount := 0;;
for second in class8 do
  third := (first8 * second)^-1;
  if third <> One(first8) and third^2 = One(first8) then
    Add(productTuples, [first8, second, third]);
  elif third^2 <> One(first8) and third^4 = One(first8) then
    product4TupleCount := product4TupleCount + 1;
    if IsGeneratingTuple(G, [first8, second]) then
      generatingProduct4TupleCount := generatingProduct4TupleCount + 1;
    fi;
  fi;
od;

productOrbits := OrbitsDomain(centralizer8, productTuples,
  function(tuple, element)
    return SimultaneousConjugate(tuple, element);
  end);;
nielsenOrbits := Filtered(productOrbits, orbit ->
  IsGeneratingTuple(G, orbit[1]));;
baseRepresentatives := List(nielsenOrbits, orbit -> orbit[1]);;

Assert(0, Length(nielsenOrbits) = 28);
Assert(0, ForAll(nielsenOrbits, orbit -> Length(orbit) = 8));
Assert(0, generatingProduct4TupleCount mod Size(centralizer8) = 0);
generatingProduct4InnerClassCount :=
  generatingProduct4TupleCount / Size(centralizer8);;

M23Canonical8TupleWithConjugator := function(tuple)
  local transporter, normalized, elements, canonical, conjugator,
    centralizerElement, image;
  transporter := RepresentativeAction(G, tuple[1], first8);
  if transporter = fail then
    Error("tuple first coordinate is not in class 8A");
  fi;
  normalized := SimultaneousConjugate(tuple, transporter);
  elements := Elements(centralizer8);
  centralizerElement := elements[1];
  canonical := SimultaneousConjugate(normalized, centralizerElement);
  conjugator := transporter * centralizerElement;
  for centralizerElement in elements{[2..Length(elements)]} do
    image := SimultaneousConjugate(normalized, centralizerElement);
    if image < canonical then
      canonical := image;
      conjugator := transporter * centralizerElement;
    fi;
  od;
  Assert(0, SimultaneousConjugate(tuple, conjugator) = canonical);
  return rec(tuple := canonical, conjugator := conjugator);
end;;

M23Canonical8Tuple := function(tuple)
  return M23Canonical8TupleWithConjugator(tuple).tuple;
end;;

M23PermutationImagesString := function(permutation)
  return JoinStringsWithSeparator(
    List([1..23], point -> String(point^permutation)), ",");
end;;

M23CanonicalOrbit := function(seed, moves)
  local points, position, point, move, image;
  points := [M23Canonical8Tuple(seed)];
  position := 1;
  while position <= Length(points) do
    point := points[position];
    for move in moves do
      image := M23Canonical8Tuple(move(point));
      if not image in points then
        Add(points, image);
      fi;
    od;
    position := position + 1;
  od;
  Sort(points);
  return points;
end;;

M23ActionPermutation := function(points, move)
  return PermList(List(points, point ->
    Position(points, M23Canonical8Tuple(move(point)))));
end;;

M23ActionPermutations := function(points, moves)
  return List(moves, move -> M23ActionPermutation(points, move));
end;;

M23NumberCycles := function(permutation, degree)
  return Length(Cycles(permutation, [1..degree]));
end;;

# For a standard real bouquet of loops, complex conjugation reverses the
# orientation of each loop.  The conjugating prefixes keep their product one.
# Changing the bouquet changes this tuple by a braid, so the induced map on
# full Hurwitz orbits is independent of that choice.
M23ComplexConjugateTuple := function(tuple)
  local prefix, result, entry;
  prefix := One(tuple[1]);
  result := [];
  for entry in tuple do
    Add(result, prefix * entry^-1 * prefix^-1);
    prefix := prefix * entry;
  od;
  return result;
end;;

threePointClasses := List(baseRepresentatives, M23Canonical8Tuple);;
Sort(threePointClasses);
Assert(0, Length(Set(threePointClasses)) = 28);

if IsBound(GAPInfo.SystemEnvironment.M23_THREE_POINT_OUTPUT) then
  threePointOutput := GAPInfo.SystemEnvironment.M23_THREE_POINT_OUTPUT;;
  PrintTo(threePointOutput,
    "# generated_by\tscripts/gap/reproduce_8A_small_orbits.g\n",
    "# gap_version\t", GAPInfo.Version, "\n",
    "# group_construction\tMathieuGroup(23)\n",
    "# class_vector\t8A,8A,2A\n",
    "# fixed_first_tuple_count\t", Length(productTuples), "\n",
    "# inner_class_count\t", Length(productOrbits), "\n",
    "# generating_inner_class_count\t", Length(threePointClasses), "\n",
    "# id_convention\tlexicographic canonical degree-23 representatives\n",
    "class_id\tfirst_images\tsecond_images\tthird_images\t",
    "q2_image_class_id\tcomplex_conjugate_class_id\n");

  for threePointIndex in [1..Length(threePointClasses)] do
    tuple := threePointClasses[threePointIndex];
    q2Tuple := M23Canonical8Tuple(HurwitzMove(tuple, 2));
    q2ImageIndex := Position(threePointClasses, q2Tuple);
    Assert(0, q2ImageIndex <> fail);
    conjugateTuple := M23Canonical8Tuple(M23ComplexConjugateTuple(tuple));
    conjugateImageIndex := Position(threePointClasses, conjugateTuple);
    Assert(0, conjugateImageIndex <> fail);
    AppendTo(threePointOutput, threePointIndex, "\t",
      M23PermutationImagesString(tuple[1]), "\t",
      M23PermutationImagesString(tuple[2]), "\t",
      M23PermutationImagesString(tuple[3]), "\t",
      q2ImageIndex, "\t", conjugateImageIndex, "\n");
  od;
fi;

pureMoves := [
  tuple -> PureBraidMove4Direct(tuple, 12),
  tuple -> PureBraidMove4Direct(tuple, 13),
  tuple -> PureBraidMove4Direct(tuple, 14)
];;
symmetryMoves := Concatenation(pureMoves, [
  tuple -> HurwitzMove(tuple, 3),
  Eta23Move4,
  Eta234Move4
]);;
fullMoves := [
  tuple -> HurwitzMove(tuple, 2),
  tuple -> HurwitzMove(tuple, 3),
  tuple -> HurwitzMove(tuple, 4)
];;

pureOrbits := [];;
symmetricOrbits := [];;
fullOrbits := [];;

for base in baseRepresentatives do
  a := base[1];;
  b := base[2];;
  Assert(0, Order(a * b) = 2);

  seeds := [
    [a, a, b, a * b * a^-1],
    [a, b, a, b],
    [a, b, b, b^-1 * a * b]
  ];

  for seed in seeds do
    Assert(0, IsProductOneTuple(seed));
    Assert(0, IsGeneratingTuple(G, seed));
    Assert(0, ForAll(seed, entry -> entry in class8));
    orbit := M23CanonicalOrbit(seed, pureMoves);
    Assert(0, Length(orbit) = 2);
    generators := M23ActionPermutations(orbit, pureMoves);
    genus := 1 - 2 +
      (6 - Sum(generators, permutation -> M23NumberCycles(permutation, 2))) / 2;
    Assert(0, genus = 0);
    if not orbit in pureOrbits then
      Add(pureOrbits, orbit);
    fi;
  od;

  orbit := M23CanonicalOrbit(seeds[1], symmetryMoves);
  Assert(0, Length(orbit) = 6);
  beta3 := M23ActionPermutation(orbit, tuple -> HurwitzMove(tuple, 3));
  eta23 := M23ActionPermutation(orbit, Eta23Move4);
  eta234 := M23ActionPermutation(orbit, Eta234Move4);
  genus := 1 - 6 +
    (18 - M23NumberCycles(beta3, 6) - M23NumberCycles(eta23, 6) -
      M23NumberCycles(eta234, 6)) / 2;
  Assert(0, genus = 0);
  Assert(0, Size(Group([beta3, eta23, eta234])) = 24);
  if not orbit in symmetricOrbits then
    Add(symmetricOrbits, orbit);
  fi;

  orbit := M23CanonicalOrbit(seeds[1], fullMoves);
  Assert(0, Length(orbit) = 12);
  fullGenerators := M23ActionPermutations(orbit, fullMoves);
  Assert(0, Size(Group(fullGenerators)) = 96);
  if not orbit in fullOrbits then
    Add(fullOrbits, orbit);
  fi;
od;

Assert(0, Length(pureOrbits) = 84);
Assert(0, Length(symmetricOrbits) = 28);
Assert(0, Length(fullOrbits) = 14);

# Give the optional descent audit stable component numbers.  These are
# lexicographic indices of the canonicalized inner Nielsen-class orbits.
Sort(symmetricOrbits);
Sort(fullOrbits);

if not IsBound(GAPInfo.SystemEnvironment.M23_OUTPUT) then
  Error("M23_OUTPUT must name the generated TSV file");
fi;
output := GAPInfo.SystemEnvironment.M23_OUTPUT;;
PrintTo(output,
  "# generated_by\tscripts/gap/reproduce_8A_small_orbits.g\n",
  "# gap_version\t", GAPInfo.Version, "\n",
  "# group_order\t", Size(G), "\n",
  "base_class_vector\tproduct_one_fixed_first_tuples\tproduct_one_inner_classes\tgenerating_inner_nielsen_classes\tderived_class_vector\tpure_orbit_count\tpure_orbit_size\tpure_genus\tsymmetric_orbit_count\tsymmetric_orbit_size\tsymmetric_genus\tfull_hurwitz_orbit_count\tfull_hurwitz_orbit_size\tfull_hurwitz_image_order\n",
  "8A,8A,2A\t", Length(productTuples), "\t", Length(productOrbits), "\t",
  Length(nielsenOrbits), "\t8A,8A,8A,8A\t", Length(pureOrbits),
  "\t2\t0\t", Length(symmetricOrbits), "\t6\t0\t", Length(fullOrbits),
  "\t12\t96\n");

if IsBound(GAPInfo.SystemEnvironment.M23_DESCENT_OUTPUT) then
  descentOutput := GAPInfo.SystemEnvironment.M23_DESCENT_OUTPUT;;
  rationalPowers := ForAll([1, 3, 5, 7], exponent -> first8^exponent in class8);;
  Assert(0, rationalPowers);

  PrintTo(descentOutput,
    "# generated_by\tscripts/gap/reproduce_8A_small_orbits.g\n",
    "# gap_version\t", GAPInfo.Version, "\n",
    "# atlasrep_version\t", GAPInfo.PackagesInfo.atlasrep[1].Version, "\n",
    "# ctbllib_version\t", GAPInfo.PackagesInfo.ctbllib[1].Version, "\n",
    "# group_construction\tMathieuGroup(23)\n",
    "# group_order\t", Size(G), "\n",
    "# class_vector\t8A,8A,8A,8A\n",
    "# input_construction\t28 generating inner classes in (8A,8A,2A)\n",
    "# rational_power_exponents_mod_8\t1,3,5,7\n",
    "# rational_power_test\ttrue\n",
    "# component_id_convention\tlexicographic full-H4 and symmetric-orbit indices\n",
    "full_component_id\tcomplex_conjugate_full_component_id\tcomplex_conjugation_fixed\tsymmetric_half_id\tcomplex_conjugate_symmetric_half_id\tsymmetric_half_complex_conjugation_fixed\tsymmetric_degree\tsymmetric_genus\tsymmetric_monodromy_order\n");

  for symmetricIndex in [1..Length(symmetricOrbits)] do
    symmetricOrbit := symmetricOrbits[symmetricIndex];;
    representative := symmetricOrbit[1];;
    fullIndex := fail;;
    for candidateIndex in [1..Length(fullOrbits)] do
      if representative in fullOrbits[candidateIndex] then
        fullIndex := candidateIndex;;
        break;
      fi;
    od;
    Assert(0, fullIndex <> fail);

    conjugateRepresentative := M23ComplexConjugateTuple(representative);;
    Assert(0, M23ComplexConjugateTuple(conjugateRepresentative) = representative);
    Assert(0, IsProductOneTuple(conjugateRepresentative));
    Assert(0, IsGeneratingTuple(G, conjugateRepresentative));
    Assert(0, ForAll(conjugateRepresentative, entry -> entry in class8));

    conjugateSymmetricOrbit := M23CanonicalOrbit(conjugateRepresentative, symmetryMoves);;
    conjugateSymmetricIndex := Position(symmetricOrbits, conjugateSymmetricOrbit);;
    Assert(0, conjugateSymmetricIndex <> fail);

    conjugateFullOrbit := M23CanonicalOrbit(conjugateRepresentative, fullMoves);;
    conjugateFullIndex := Position(fullOrbits, conjugateFullOrbit);;
    Assert(0, conjugateFullIndex <> fail);

    beta3 := M23ActionPermutation(symmetricOrbit, tuple -> HurwitzMove(tuple, 3));;
    eta23 := M23ActionPermutation(symmetricOrbit, Eta23Move4);;
    eta234 := M23ActionPermutation(symmetricOrbit, Eta234Move4);;
    genus := 1 - Length(symmetricOrbit) +
      (3 * Length(symmetricOrbit) -
        M23NumberCycles(beta3, Length(symmetricOrbit)) -
        M23NumberCycles(eta23, Length(symmetricOrbit)) -
        M23NumberCycles(eta234, Length(symmetricOrbit))) / 2;
    symmetricMonodromyOrder := Size(Group([beta3, eta23, eta234]));;
    Assert(0, genus = 0);
    Assert(0, symmetricMonodromyOrder = 24);

    AppendTo(descentOutput,
      fullIndex, "\t", conjugateFullIndex, "\t", fullIndex = conjugateFullIndex,
      "\t", symmetricIndex, "\t", conjugateSymmetricIndex, "\t",
      symmetricIndex = conjugateSymmetricIndex, "\t", Length(symmetricOrbit),
      "\t", genus, "\t", symmetricMonodromyOrder, "\n");
  od;
fi;

if IsBound(GAPInfo.SystemEnvironment.M23_LEAN_WITNESS_OUTPUT) then
  witnessOutput := GAPInfo.SystemEnvironment.M23_LEAN_WITNESS_OUTPUT;;
  PrintTo(witnessOutput,
    "# generated_by\tscripts/gap/reproduce_8A_small_orbits.g\n",
    "# gap_version\t", GAPInfo.Version, "\n",
    "# atlasrep_version\t", GAPInfo.PackagesInfo.atlasrep[1].Version, "\n",
    "# ctbllib_version\t", GAPInfo.PackagesInfo.ctbllib[1].Version, "\n",
    "# group_construction\tMathieuGroup(23)\n",
    "# group_order\t", Size(G), "\n",
    "# class_vector\t8A,8A,8A,8A\n",
    "# tuple_count\t168\n",
    "# edge_count\t504\n",
    "# complex_conjugation_count\t168\n",
    "# permutation_encoding\timages of points 1..23\n",
    "# records\tT=tuple,E=Hurwitz edge,C=complex conjugation\n");

  for fullIndex in [1..Length(fullOrbits)] do
    fullOrbit := fullOrbits[fullIndex];
    for vertexIndex in [1..Length(fullOrbit)] do
      tuple := fullOrbit[vertexIndex];
      AppendTo(witnessOutput, "T\t", fullIndex, "\t", vertexIndex);
      for entry in tuple do
        AppendTo(witnessOutput, "\t", M23PermutationImagesString(entry));
      od;
      AppendTo(witnessOutput, "\n");

      for generatorIndex in [2..4] do
        moved := HurwitzMove(tuple, generatorIndex);
        canonicalWitness := M23Canonical8TupleWithConjugator(moved);
        targetVertexIndex := Position(fullOrbit, canonicalWitness.tuple);
        Assert(0, targetVertexIndex <> fail);
        Assert(0, SimultaneousConjugate(moved,
          canonicalWitness.conjugator) = fullOrbit[targetVertexIndex]);
        AppendTo(witnessOutput, "E\t", fullIndex, "\t", vertexIndex,
          "\t", generatorIndex, "\t", targetVertexIndex, "\t",
          M23PermutationImagesString(canonicalWitness.conjugator), "\n");
      od;

      conjugateTuple := M23ComplexConjugateTuple(tuple);
      canonicalWitness := M23Canonical8TupleWithConjugator(conjugateTuple);
      targetFullIndex := fail;
      for candidateIndex in [1..Length(fullOrbits)] do
        if canonicalWitness.tuple in fullOrbits[candidateIndex] then
          targetFullIndex := candidateIndex;
          break;
        fi;
      od;
      Assert(0, targetFullIndex <> fail);
      targetVertexIndex := Position(fullOrbits[targetFullIndex],
        canonicalWitness.tuple);
      Assert(0, targetVertexIndex <> fail);
      Assert(0, SimultaneousConjugate(conjugateTuple,
        canonicalWitness.conjugator) =
          fullOrbits[targetFullIndex][targetVertexIndex]);
      AppendTo(witnessOutput, "C\t", fullIndex, "\t", vertexIndex,
        "\t", targetFullIndex, "\t", targetVertexIndex, "\t",
        M23PermutationImagesString(canonicalWitness.conjugator), "\n");
    od;
  od;
fi;

pairPositions := [
  [1, 2], [1, 3], [1, 4], [2, 3], [2, 4], [3, 4]
];

if IsBound(GAPInfo.SystemEnvironment.M23_SIGNATURE_OUTPUT) then
  signatureOutput := GAPInfo.SystemEnvironment.M23_SIGNATURE_OUTPUT;;
  fullGeneratorTriples := List(fullOrbits, fullOrbit ->
    M23ActionPermutations(fullOrbit, fullMoves));;
  symmetricGroup12 := SymmetricGroup(12);;
  tripleClassRepresentatives := [];
  subgroupClassRepresentatives := [];
  pairInnerLabeledClassRepresentatives := [];
  pairInner2ALabeledClassRepresentatives := [];

  M23CycleLengthsString := function(permutation, degree)
    local lengths;
    lengths := List(Cycles(permutation, [1..degree]), Length);
    Sort(lengths);
    return JoinStringsWithSeparator(List(lengths, String), ",");
  end;;

  M23PairProductOrders := function(tuple)
    return List(pairPositions, pair ->
      Order(tuple[pair[1]] * tuple[pair[2]]));
  end;;
  M23PairSubgroupOrders := function(tuple)
    return List(pairPositions, pair ->
      Size(Group([tuple[pair[1]], tuple[pair[2]]])));
  end;;
  M23OrderProfileString := function(values)
    return JoinStringsWithSeparator(List(Collected(values), entry ->
      Concatenation(String(entry[1]), "^", String(entry[2]))), " ");
  end;;
  M23TransporterPreservesPairInnerClasses := function(
      sourceOrbit, targetOrbit, actionTransporter, productOrderFilter)
    local vertexIndex, transportedVertexIndex, pair, sourcePair;
    for vertexIndex in [1..12] do
      transportedVertexIndex := vertexIndex^actionTransporter;
      for pair in pairPositions do
        sourcePair := [sourceOrbit[vertexIndex][pair[1]],
                       sourceOrbit[vertexIndex][pair[2]]];
        if (productOrderFilter = fail or
            Order(Product(sourcePair)) = productOrderFilter) and
            RepresentativeAction(G,
            [sourceOrbit[vertexIndex][pair[1]],
             sourceOrbit[vertexIndex][pair[2]]],
            [targetOrbit[transportedVertexIndex][pair[1]],
             targetOrbit[transportedVertexIndex][pair[2]]],
            OnTuples) = fail then
          return false;
        fi;
      od;
    od;
    return true;
  end;;
  inversePairings := [
    [[1, 2], [3, 4]], [[1, 3], [2, 4]], [[1, 4], [2, 3]]
  ];
  M23HasTwoInversePairs := function(tuple)
    return ForAny(inversePairings, pairing ->
      ForAll(pairing, pair -> tuple[pair[2]] = tuple[pair[1]]^-1));
  end;;

  PrintTo(signatureOutput,
    "# generated_by\tscripts/gap/reproduce_8A_small_orbits.g\n",
    "# gap_version\t", GAPInfo.Version, "\n",
    "# group_construction\tMathieuGroup(23)\n",
    "# class_vector\t8A,8A,8A,8A\n",
    "component_id\timage_group_id\tordered_generator_triple_class\t",
    "ordered_generator_transporter\tpermutation_subgroup_class\t",
    "q2_cycles\tq3_cycles\tq4_cycles\t",
    "q2q3_cycles\tq2q4_cycles\tq3q4_cycles\tq2q3q4_cycles\t",
    "pair_product_order_profile\t",
    "ordered_transporter_preserves_pair_product_orders\t",
    "pair_subgroup_order_profile\t",
    "ordered_transporter_preserves_pair_subgroup_orders\t",
    "ordered_transporter_preserves_pair_inner_classes\t",
    "pair_inner_labeled_action_class\t",
    "pair_inner_2a_labeled_action_class\t",
    "contains_two_inverse_pairs\n");

  for fullIndex in [1..Length(fullOrbits)] do
    fullGenerators := fullGeneratorTriples[fullIndex];
    fullGroup := Group(fullGenerators);
    groupId := IdGroup(fullGroup);

    tripleClass := fail;
    tripleTransporter := fail;
    for candidateIndex in [1..Length(tripleClassRepresentatives)] do
      transporter := RepresentativeAction(symmetricGroup12,
          fullGeneratorTriples[tripleClassRepresentatives[candidateIndex]],
          fullGenerators, OnTuples);
      if transporter <> fail then
        tripleClass := candidateIndex;
        tripleTransporter := transporter;
        break;
      fi;
    od;
    if tripleClass = fail then
      Add(tripleClassRepresentatives, fullIndex);
      tripleClass := Length(tripleClassRepresentatives);
      tripleTransporter := One(symmetricGroup12);
    fi;
    for generatorIndex in [1..3] do
      Assert(0, fullGeneratorTriples[
        tripleClassRepresentatives[tripleClass]][generatorIndex]^
          tripleTransporter = fullGenerators[generatorIndex]);
    od;

    pairProductOrders := Concatenation(List(fullOrbits[fullIndex],
      M23PairProductOrders));
    Assert(0, Collected(pairProductOrders) = [[2, 48], [4, 24]]);
    transporterPreservesPairProductOrders := true;
    for vertexIndex in [1..12] do
      if M23PairProductOrders(fullOrbits[1][vertexIndex]) <>
          M23PairProductOrders(fullOrbits[fullIndex][
            vertexIndex^tripleTransporter]) then
        transporterPreservesPairProductOrders := false;
      fi;
    od;
    Assert(0, transporterPreservesPairProductOrders);
    pairSubgroupOrders := Concatenation(List(fullOrbits[fullIndex],
      M23PairSubgroupOrders));
    transporterPreservesPairSubgroupOrders := true;
    for vertexIndex in [1..12] do
      if M23PairSubgroupOrders(fullOrbits[1][vertexIndex]) <>
          M23PairSubgroupOrders(fullOrbits[fullIndex][
            vertexIndex^tripleTransporter]) then
        transporterPreservesPairSubgroupOrders := false;
      fi;
    od;
    transporterPreservesPairInnerClasses :=
      M23TransporterPreservesPairInnerClasses(fullOrbits[1],
        fullOrbits[fullIndex], tripleTransporter, fail);

    pairInnerLabeledClass := fail;
    for candidateIndex in [1..Length(pairInnerLabeledClassRepresentatives)] do
      sourceIndex := pairInnerLabeledClassRepresentatives[candidateIndex];
      candidateTransporter := RepresentativeAction(symmetricGroup12,
        fullGeneratorTriples[sourceIndex], fullGenerators, OnTuples);
      Assert(0, candidateTransporter <> fail);
      actionCentralizer := Centralizer(symmetricGroup12,
        Group(fullGeneratorTriples[sourceIndex]));
      for centralizerElement in Elements(actionCentralizer) do
        labeledTransporter := centralizerElement * candidateTransporter;
        if M23TransporterPreservesPairInnerClasses(fullOrbits[sourceIndex],
            fullOrbits[fullIndex], labeledTransporter, fail) then
          pairInnerLabeledClass := candidateIndex;
          break;
        fi;
      od;
      if pairInnerLabeledClass <> fail then
        break;
      fi;
    od;
    if pairInnerLabeledClass = fail then
      Add(pairInnerLabeledClassRepresentatives, fullIndex);
      pairInnerLabeledClass := Length(pairInnerLabeledClassRepresentatives);
    fi;

    pairInner2ALabeledClass := fail;
    for candidateIndex in [1..Length(pairInner2ALabeledClassRepresentatives)] do
      sourceIndex := pairInner2ALabeledClassRepresentatives[candidateIndex];
      candidateTransporter := RepresentativeAction(symmetricGroup12,
        fullGeneratorTriples[sourceIndex], fullGenerators, OnTuples);
      Assert(0, candidateTransporter <> fail);
      actionCentralizer := Centralizer(symmetricGroup12,
        Group(fullGeneratorTriples[sourceIndex]));
      for centralizerElement in Elements(actionCentralizer) do
        labeledTransporter := centralizerElement * candidateTransporter;
        if M23TransporterPreservesPairInnerClasses(fullOrbits[sourceIndex],
            fullOrbits[fullIndex], labeledTransporter, 2) then
          pairInner2ALabeledClass := candidateIndex;
          break;
        fi;
      od;
      if pairInner2ALabeledClass <> fail then
        break;
      fi;
    od;
    if pairInner2ALabeledClass = fail then
      Add(pairInner2ALabeledClassRepresentatives, fullIndex);
      pairInner2ALabeledClass := Length(pairInner2ALabeledClassRepresentatives);
    fi;
    containsTwoInversePairs := ForAny(fullOrbits[fullIndex],
      M23HasTwoInversePairs);
    Assert(0, not containsTwoInversePairs);

    subgroupClass := fail;
    for candidateIndex in [1..Length(subgroupClassRepresentatives)] do
      if IsConjugate(symmetricGroup12,
          Group(fullGeneratorTriples[
            subgroupClassRepresentatives[candidateIndex]]), fullGroup) then
        subgroupClass := candidateIndex;
        break;
      fi;
    od;
    if subgroupClass = fail then
      Add(subgroupClassRepresentatives, fullIndex);
      subgroupClass := Length(subgroupClassRepresentatives);
    fi;

    AppendTo(signatureOutput, fullIndex, "\t", groupId[1], ".", groupId[2],
      "\t", tripleClass, "\t",
      JoinStringsWithSeparator(List(ListPerm(tripleTransporter, 12), String),
        ","), "\t",
      subgroupClass, "\t",
      M23CycleLengthsString(fullGenerators[1], 12), "\t",
      M23CycleLengthsString(fullGenerators[2], 12), "\t",
      M23CycleLengthsString(fullGenerators[3], 12), "\t",
      M23CycleLengthsString(fullGenerators[1] * fullGenerators[2], 12), "\t",
      M23CycleLengthsString(fullGenerators[1] * fullGenerators[3], 12), "\t",
      M23CycleLengthsString(fullGenerators[2] * fullGenerators[3], 12), "\t",
      M23CycleLengthsString(fullGenerators[1] * fullGenerators[2] *
        fullGenerators[3], 12), "\t2^48 4^24\t",
      transporterPreservesPairProductOrders, "\t",
      M23OrderProfileString(pairSubgroupOrders), "\t",
      transporterPreservesPairSubgroupOrders, "\t",
      transporterPreservesPairInnerClasses, "\t", pairInnerLabeledClass,
      "\t", pairInner2ALabeledClass, "\t", containsTwoInversePairs, "\n");
  od;
fi;

if IsBound(GAPInfo.SystemEnvironment.M23_BOUNDARY_OUTPUT) then
  boundaryOutput := GAPInfo.SystemEnvironment.M23_BOUNDARY_OUTPUT;;
  pairInnerClasses := [];
  for fullOrbit in fullOrbits do
    for tuple in fullOrbit do
      for pair in pairPositions do
        canonicalPair := M23Canonical8Tuple(
          [tuple[pair[1]], tuple[pair[2]]]);
        if not canonicalPair in pairInnerClasses then
          Add(pairInnerClasses, canonicalPair);
        fi;
      od;
    od;
  od;
  Sort(pairInnerClasses);

  PrintTo(boundaryOutput,
    "# generated_by\tscripts/gap/reproduce_8A_small_orbits.g\n",
    "# gap_version\t", GAPInfo.Version, "\n",
    "# group_construction\tMathieuGroup(23)\n",
    "# class_vector\t8A,8A,8A,8A\n",
    "# component_count\t", Length(fullOrbits), "\n",
    "# pair_inner_class_count\t", Length(pairInnerClasses), "\n",
    "# global_8a_8a_4a_fixed_first_tuple_count\t",
      product4TupleCount, "\n",
    "# global_generating_8a_8a_4a_fixed_first_tuple_count\t",
      generatingProduct4TupleCount, "\n",
    "# global_generating_8a_8a_4a_inner_class_count\t",
      generatingProduct4InnerClassCount, "\n",
    "component_id\tvertex_id\tpair_id\tleft_position\tright_position\t",
    "pair_product_order\tpair_subgroup_order\tpair_inner_class_id\t",
    "three_point_2a_class_id\t",
    "complex_conjugate_pair_inner_class_id\n");

  for fullIndex in [1..Length(fullOrbits)] do
    for vertexIndex in [1..Length(fullOrbits[fullIndex])] do
      tuple := fullOrbits[fullIndex][vertexIndex];
      for pairIndex in [1..Length(pairPositions)] do
        pair := pairPositions[pairIndex];
        canonicalPair := M23Canonical8Tuple(
          [tuple[pair[1]], tuple[pair[2]]]);
        pairInnerClass := Position(pairInnerClasses, canonicalPair);
        Assert(0, pairInnerClass <> fail);

        boundaryTriple := [tuple[pair[1]], tuple[pair[2]],
          (tuple[pair[1]] * tuple[pair[2]])^-1];
        Assert(0, IsProductOneTuple(boundaryTriple));
        conjugateBoundaryTriple := M23ComplexConjugateTuple(boundaryTriple);
        conjugateCanonicalPair := M23Canonical8Tuple(
          conjugateBoundaryTriple{[1, 2]});
        conjugatePairInnerClass := Position(pairInnerClasses,
          conjugateCanonicalPair);
        Assert(0, conjugatePairInnerClass <> fail);
        threePoint2AClass := 0;
        if Order(tuple[pair[1]] * tuple[pair[2]]) = 2 then
          threePoint2AClass := Position(threePointClasses,
            M23Canonical8Tuple(boundaryTriple));
          Assert(0, threePoint2AClass <> fail);
        fi;

        AppendTo(boundaryOutput, fullIndex, "\t", vertexIndex, "\t",
          pairIndex, "\t", pair[1], "\t", pair[2], "\t",
          Order(tuple[pair[1]] * tuple[pair[2]]), "\t",
          Size(Group([tuple[pair[1]], tuple[pair[2]]])), "\t",
          pairInnerClass, "\t", threePoint2AClass, "\t",
          conjugatePairInnerClass, "\n");
      od;
    od;
  od;
fi;
QUIT;
