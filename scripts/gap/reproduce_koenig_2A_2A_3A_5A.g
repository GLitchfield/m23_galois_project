Read("src/gap/m23_fixed_first.g");;
SizeScreen([100000, 100000]);;

# Put the two equal classes last.  This is the ordering used by the existing
# symmetric-genus convention: (3A,5A,2A,2A).
G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
class2 := First(classes, class -> Order(Representative(class)) = 2);;
class3 := First(classes, class -> Order(Representative(class)) = 3);;
class5 := First(classes, class -> Order(Representative(class)) = 5);;
first3 := Representative(class3);;
centralizer3 := Centralizer(G, first3);;
identity := One(first3);;

Assert(0, Size(class2) = 3795);
Assert(0, Size(class3) = 56672);
Assert(0, Size(class5) = 680064);
Assert(0, Size(centralizer3) = 180);

involutions := AsList(class2);;
productTuples := [];;
for third in involutions do
  for fourth in involutions do
    second := first3^-1 * (third * fourth)^-1;
    if second <> identity and second^5 = identity then
      Add(productTuples, [first3, second, third, fourth]);
    fi;
  od;
od;

productOrbits := OrbitsDomain(centralizer3, productTuples,
  function(tuple, element)
    return SimultaneousConjugate(tuple, element);
  end);;
nielsenOrbits := Filtered(productOrbits, orbit ->
  IsGeneratingTuple(G, orbit[1]));;
representatives := List(nielsenOrbits, orbit -> orbit[1]);;

Assert(0, Length(nielsenOrbits) = 980);
Assert(0, ForAll(nielsenOrbits, orbit -> Length(orbit) = 180));

tupleIndex := NewDictionary(nielsenOrbits[1][1], true);;
for orbitNumber in [1..Length(nielsenOrbits)] do
  for member in nielsenOrbits[orbitNumber] do
    AddDictionary(tupleIndex, member, orbitNumber);
  od;
od;

M23KoenigClassIndex := function(tuple)
  local transporter, normalized, index;
  transporter := RepresentativeAction(G, tuple[1], first3);
  if transporter = fail then
    Error("first coordinate left class 3A");
  fi;
  normalized := SimultaneousConjugate(tuple, transporter);
  index := LookupDictionary(tupleIndex, normalized);
  if index = fail then
    Error("normalized tuple is absent from the generating Nielsen class");
  fi;
  return index;
end;;

M23KoenigActionPermutation := function(move)
  return PermList(List(representatives,
    tuple -> M23KoenigClassIndex(move(tuple))));
end;;

beta12 := M23KoenigActionPermutation(
  tuple -> PureBraidMove4Direct(tuple, 12));;
beta13 := M23KoenigActionPermutation(
  tuple -> PureBraidMove4Direct(tuple, 13));;
beta14 := M23KoenigActionPermutation(
  tuple -> PureBraidMove4Direct(tuple, 14));;
beta4 := M23KoenigActionPermutation(tuple -> HurwitzMove(tuple, 4));;
eta34 := M23KoenigActionPermutation(Eta34Move4);;

pureGroup := Group([beta12, beta13, beta14]);;
symmetricGroup := Group([beta12, beta13, beta14, beta4, eta34]);;
pureOrbits := Orbits(pureGroup, [1..980]);;
symmetricOrbits := Orbits(symmetricGroup, [1..980]);;

Assert(0, beta12 * beta13 * beta14 = ());
Assert(0, beta13 * eta34 * beta4 = ());
Assert(0, eta34^2 = ());
Assert(0, Length(symmetricOrbits) = 1);

pureGenus := 1 - 980 +
  (3 * 980 - M23NumberCyclesOn(beta12, 980) -
    M23NumberCyclesOn(beta13, 980) -
    M23NumberCyclesOn(beta14, 980)) / 2;;
symmetricGenus := 1 - 980 +
  (3 * 980 - M23NumberCyclesOn(beta13, 980) -
    M23NumberCyclesOn(beta4, 980) -
    M23NumberCyclesOn(eta34, 980)) / 2;;

Assert(0, IsInt(pureGenus));
Assert(0, symmetricGenus = 43);

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
  "# generated_by\tscripts/gap/reproduce_koenig_2A_2A_3A_5A.g\n",
  "# code_revision\t", GAPInfo.SystemEnvironment.M23_CODE_REVISION, "\n",
  "# gap_version\t", GAPInfo.Version, "\n",
  "# atlasrep_version\t", GAPInfo.PackagesInfo.atlasrep[1].Version, "\n",
  "# ctbllib_version\t", GAPInfo.PackagesInfo.ctbllib[1].Version, "\n",
  "# transgrp_version\t", GAPInfo.PackagesInfo.transgrp[1].Version, "\n",
  "# group_order\t", Size(G), "\n",
  "class_vector\tproduct_one_fixed_first_tuples\tproduct_one_inner_classes\tgenerating_inner_nielsen_classes\tpure_braid_orbit_count\tpure_braid_orbit_sizes\tpure_genus\tsymmetric_orbit_count\tsymmetric_orbit_size\tsymmetric_genus\tbeta12_cycle_shape\tbeta13_cycle_shape\tbeta14_cycle_shape\tbeta4_cycle_shape\teta34_cycle_shape\n",
  "3A,5A,2A,2A\t", Length(productTuples), "\t", Length(productOrbits),
  "\t", Length(nielsenOrbits), "\t", Length(pureOrbits), "\t",
  JoinStringsWithSeparator(List(pureOrbits, orbit -> String(Length(orbit))),
    ","), "\t", pureGenus, "\t", Length(symmetricOrbits), "\t",
  Length(symmetricOrbits[1]), "\t", symmetricGenus, "\t",
  M23CycleShape(beta12, 980), "\t", M23CycleShape(beta13, 980), "\t",
  M23CycleShape(beta14, 980), "\t", M23CycleShape(beta4, 980), "\t",
  M23CycleShape(eta34, 980), "\n");
QUIT;
