Read("src/gap/m23_fixed_first.g");;
SizeScreen([100000, 100000]);;

G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
class2 := First(classes, class -> Order(Representative(class)) = 2);;
class4 := First(classes, class -> Order(Representative(class)) = 4);;
first4 := Representative(class4);;
centralizer4 := Centralizer(G, first4);;
identity := One(first4);;

Assert(0, Size(class2) = 3795);
Assert(0, Size(class4) = 318780);
Assert(0, Size(centralizer4) = 32);

involutions := AsList(class2);;
productTuples := [];;
for third in involutions do
  for fourth in involutions do
    second := first4^-1 * (third * fourth)^-1;
    if second^2 <> identity and second^4 = identity then
      Add(productTuples, [first4, second, third, fourth]);
    fi;
  od;
od;

productOrbits := OrbitsDomain(centralizer4, productTuples,
  function(tuple, element)
    return SimultaneousConjugate(tuple, element);
  end);;
nielsenOrbits := Filtered(productOrbits, orbit ->
  IsGeneratingTuple(G, orbit[1]));;
representatives := List(nielsenOrbits, orbit -> orbit[1]);;

Assert(0, Length(nielsenOrbits) = 2456);
Assert(0, ForAll(nielsenOrbits, orbit -> Length(orbit) = 32));

tupleIndex := NewDictionary(nielsenOrbits[1][1], true);;
for orbitNumber in [1..Length(nielsenOrbits)] do
  for member in nielsenOrbits[orbitNumber] do
    AddDictionary(tupleIndex, member, orbitNumber);
  od;
od;

M23ClassIndex := function(tuple)
  local transporter, normalized, index;
  transporter := RepresentativeAction(G, tuple[1], first4);
  if transporter = fail then
    Error("first coordinate left class 4A");
  fi;
  normalized := SimultaneousConjugate(tuple, transporter);
  index := LookupDictionary(tupleIndex, normalized);
  if index = fail then
    Error("normalized tuple is absent from the generating Nielsen class");
  fi;
  return index;
end;;

M23ActionPermutation2456 := function(move)
  return PermList(List(representatives, tuple -> M23ClassIndex(move(tuple))));
end;;

beta12 := M23ActionPermutation2456(tuple -> PureBraidMove4Direct(tuple, 12));;
beta13 := M23ActionPermutation2456(tuple -> PureBraidMove4Direct(tuple, 13));;
beta14 := M23ActionPermutation2456(tuple -> PureBraidMove4Direct(tuple, 14));;
beta4 := M23ActionPermutation2456(tuple -> HurwitzMove(tuple, 4));;
eta34 := M23ActionPermutation2456(Eta34Move4);;

pureGroup := Group([beta12, beta13, beta14]);;
Assert(0, IsTransitive(pureGroup, [1..2456]));
Assert(0, beta12 * beta13 * beta14 = ());

pureGenus := 1 - 2456 +
  (3 * 2456 - M23NumberCyclesOn(beta12, 2456) -
    M23NumberCyclesOn(beta13, 2456) -
    M23NumberCyclesOn(beta14, 2456)) / 2;;
symmetricGenus := 1 - 2456 +
  (3 * 2456 - M23NumberCyclesOn(beta13, 2456) -
    M23NumberCyclesOn(beta4, 2456) -
    M23NumberCyclesOn(eta34, 2456)) / 2;;

Assert(0, pureGenus = 447);
Assert(0, symmetricGenus = 169);
Assert(0, IsTransitive(Group([beta12, beta13, beta14, beta4, eta34]),
  [1..2456]));

sample := representatives[1];;
Assert(0, ApplyHurwitzWord(sample, PureBraidWords4.beta12) =
  PureBraidMove4Direct(sample, 12));
Assert(0, ApplyHurwitzWord(sample, PureBraidWords4.beta13) =
  PureBraidMove4Direct(sample, 13));
Assert(0, ApplyHurwitzWord(sample, PureBraidWords4.beta14) =
  PureBraidMove4Direct(sample, 14));

if not IsBound(GAPInfo.SystemEnvironment.M23_OUTPUT) then
  Error("M23_OUTPUT must name the generated TSV file");
fi;
output := GAPInfo.SystemEnvironment.M23_OUTPUT;;
PrintTo(output,
  "# generated_by\tscripts/gap/reproduce_4A_4A_2A_2A.g\n",
  "# gap_version\t", GAPInfo.Version, "\n",
  "# group_order\t", Size(G), "\n",
  "class_vector\tproduct_one_fixed_first_tuples\tproduct_one_inner_classes\tgenerating_inner_nielsen_classes\tpure_braid_orbit_count\tpure_braid_orbit_size\tpure_genus\tsymmetric_orbit_size\tsymmetric_genus\tbeta12_cycle_shape\tbeta13_cycle_shape\tbeta14_cycle_shape\tbeta4_cycle_shape\teta34_cycle_shape\n",
  "4A,4A,2A,2A\t", Length(productTuples), "\t", Length(productOrbits),
  "\t", Length(nielsenOrbits), "\t1\t2456\t", pureGenus, "\t2456\t",
  symmetricGenus, "\t", M23CycleShape(beta12, 2456), "\t",
  M23CycleShape(beta13, 2456), "\t", M23CycleShape(beta14, 2456), "\t",
  M23CycleShape(beta4, 2456), "\t", M23CycleShape(eta34, 2456), "\n");
QUIT;
