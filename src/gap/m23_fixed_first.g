Read("src/gap/nielsen.g");;

M23CycleShape := function(permutation, degree)
  local lengths;
  lengths := Collected(List(Cycles(permutation, [1..degree]), Length));
  return JoinStringsWithSeparator(List(lengths, pair ->
    Concatenation(String(pair[1]), "^", String(pair[2]))), " ");
end;;

M23NumberCyclesOn := function(permutation, degree)
  return Length(Cycles(permutation, [1..degree]));
end;;

M23EnumerateFixedFirstProductTuples := function(first, involutions)
  local tuples, second, third, fourth;
  tuples := [];
  for second in involutions do
    for third in involutions do
      fourth := (first * second * third)^-1;
      if fourth <> One(first) and fourth^2 = One(first) then
        Add(tuples, [first, second, third, fourth]);
      fi;
    od;
  od;
  return tuples;
end;;

AnalyzeM23FixedFirstInvolutionTriple := function(
    group, involutionClass, specialClass, classNumber, expected)
  local first, involutions, productTuples, centralizer, productOrbits,
    nielsenOrbits, representatives, tuplePositions, orbitIndex, orbitNumber,
    member, NormalizeFirstCoordinate, MoveIndex, beta12, beta13, beta14,
    beta3, eta23, eta234, pureGroup, pureGenus, symmetricGenus, sample;

  first := Representative(specialClass);
  involutions := AsList(involutionClass);
  productTuples := M23EnumerateFixedFirstProductTuples(first, involutions);
  centralizer := Centralizer(group, first);
  productOrbits := OrbitsDomain(centralizer, productTuples,
    function(tuple, element)
      return SimultaneousConjugate(tuple, element);
    end);
  nielsenOrbits := Filtered(productOrbits, orbit ->
    IsGeneratingTuple(group, orbit[1]));
  representatives := List(nielsenOrbits, orbit -> orbit[1]);

  if IsBound(expected.product_tuples) then
    Assert(0, Length(productTuples) = expected.product_tuples);
  fi;
  if IsBound(expected.product_orbits) then
    Assert(0, Length(productOrbits) = expected.product_orbits);
  fi;
  Assert(0, Length(nielsenOrbits) = expected.nielsen_size);
  Assert(0, ForAll(nielsenOrbits, orbit ->
    Length(orbit) = Size(centralizer)));

  tuplePositions := [];
  orbitIndex := [];
  for orbitNumber in [1..Length(nielsenOrbits)] do
    for member in nielsenOrbits[orbitNumber] do
      Add(tuplePositions, member);
      Add(orbitIndex, orbitNumber);
    od;
  od;

  NormalizeFirstCoordinate := function(tuple)
    local transporter;
    transporter := RepresentativeAction(group, tuple[1], first);
    if transporter = fail then
      Error("first coordinate left its conjugacy class");
    fi;
    return SimultaneousConjugate(tuple, transporter);
  end;

  MoveIndex := function(tuple, move)
    local moved, normalized, found;
    moved := move(tuple);
    Assert(0, IsProductOneTuple(moved));
    Assert(0, IsGeneratingTuple(group, moved));
    normalized := NormalizeFirstCoordinate(moved);
    found := Position(tuplePositions, normalized);
    if found = fail then
      Error("normalized braid image is absent from the Nielsen class");
    fi;
    return orbitIndex[found];
  end;

  beta12 := PermList(List(representatives, tuple ->
    MoveIndex(tuple, t -> PureBraidMove4Direct(t, 12))));
  beta13 := PermList(List(representatives, tuple ->
    MoveIndex(tuple, t -> PureBraidMove4Direct(t, 13))));
  beta14 := PermList(List(representatives, tuple ->
    MoveIndex(tuple, t -> PureBraidMove4Direct(t, 14))));
  beta3 := PermList(List(representatives, tuple ->
    MoveIndex(tuple, t -> HurwitzMove(t, 3))));
  eta23 := PermList(List(representatives, tuple ->
    MoveIndex(tuple, Eta23Move4)));
  eta234 := PermList(List(representatives, tuple ->
    MoveIndex(tuple, Eta234Move4)));

  pureGroup := Group([beta12, beta13, beta14]);
  Assert(0, IsTransitive(pureGroup, [1..expected.nielsen_size]));
  Assert(0, beta12 * beta13 * beta14 = ());

  sample := representatives[1];
  Assert(0, ApplyHurwitzWord(sample, PureBraidWords4.beta12) =
    PureBraidMove4Direct(sample, 12));
  Assert(0, ApplyHurwitzWord(sample, PureBraidWords4.beta13) =
    PureBraidMove4Direct(sample, 13));
  Assert(0, ApplyHurwitzWord(sample, PureBraidWords4.beta14) =
    PureBraidMove4Direct(sample, 14));
  Assert(0, InverseHurwitzMove(HurwitzMove(sample, 3), 3) = sample);
  Assert(0, HurwitzMove(HurwitzMove(HurwitzMove(sample, 2), 3), 2) =
    HurwitzMove(HurwitzMove(HurwitzMove(sample, 3), 2), 3));

  Assert(0, M23CycleShape(beta3, expected.nielsen_size) =
    expected.beta3_cycle_shape);
  Assert(0, M23CycleShape(eta23, expected.nielsen_size) =
    expected.eta23_cycle_shape);
  Assert(0, M23CycleShape(eta234, expected.nielsen_size) =
    expected.eta234_cycle_shape);

  pureGenus := 1 - expected.nielsen_size +
    (3 * expected.nielsen_size -
      M23NumberCyclesOn(beta12, expected.nielsen_size) -
      M23NumberCyclesOn(beta13, expected.nielsen_size) -
      M23NumberCyclesOn(beta14, expected.nielsen_size)) / 2;
  symmetricGenus := 1 - expected.nielsen_size +
    (3 * expected.nielsen_size -
      M23NumberCyclesOn(beta3, expected.nielsen_size) -
      M23NumberCyclesOn(eta23, expected.nielsen_size) -
      M23NumberCyclesOn(eta234, expected.nielsen_size)) / 2;
  Assert(0, IsInt(pureGenus));
  Assert(0, symmetricGenus = expected.symmetric_genus);

  return rec(
    computed_class_number := classNumber,
    fixed_first_order := Order(first),
    fixed_first_centralizer_size := Size(centralizer),
    product_one_fixed_first_tuples := Length(productTuples),
    product_one_inner_classes := Length(productOrbits),
    generating_inner_nielsen_classes := Length(nielsenOrbits),
    pure_braid_orbit_size := Size(Orbit(pureGroup, 1)),
    pure_braid_genus := pureGenus,
    symmetric_genus := symmetricGenus,
    beta12_cycle_shape := M23CycleShape(beta12, expected.nielsen_size),
    beta13_cycle_shape := M23CycleShape(beta13, expected.nielsen_size),
    beta14_cycle_shape := M23CycleShape(beta14, expected.nielsen_size),
    beta3_cycle_shape := M23CycleShape(beta3, expected.nielsen_size),
    eta23_cycle_shape := M23CycleShape(eta23, expected.nielsen_size),
    eta234_cycle_shape := M23CycleShape(eta234, expected.nielsen_size)
  );
end;;

WriteM23FixedFirstResults := function(output, generator, group, results)
  local result;
  PrintTo(output,
    "# generated_by\t", generator, "\n",
    "# gap_version\t", GAPInfo.Version, "\n",
    "# group_order\t", Size(group), "\n",
    "computed_class_number\tfixed_first_order\tfixed_first_centralizer_size\tproduct_one_fixed_first_tuples\tproduct_one_inner_classes\tgenerating_inner_nielsen_classes\tpure_braid_orbit_size\tpure_braid_genus\tsymmetric_genus\tbeta12_cycle_shape\tbeta13_cycle_shape\tbeta14_cycle_shape\tbeta3_cycle_shape\teta23_cycle_shape\teta234_cycle_shape\n");
  for result in results do
    AppendTo(output,
      result.computed_class_number, "\t",
      result.fixed_first_order, "\t",
      result.fixed_first_centralizer_size, "\t",
      result.product_one_fixed_first_tuples, "\t",
      result.product_one_inner_classes, "\t",
      result.generating_inner_nielsen_classes, "\t",
      result.pure_braid_orbit_size, "\t",
      result.pure_braid_genus, "\t",
      result.symmetric_genus, "\t",
      result.beta12_cycle_shape, "\t",
      result.beta13_cycle_shape, "\t",
      result.beta14_cycle_shape, "\t",
      result.beta3_cycle_shape, "\t",
      result.eta23_cycle_shape, "\t",
      result.eta234_cycle_shape, "\n");
  od;
end;;
