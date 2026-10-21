Read("src/gap/m23_cc2a2a_shards.g");;
SizeScreen([1000000, 1000000]);;

classOrder := Int(GAPInfo.SystemEnvironment.M23_CLASS_ORDER);;
shardCount := Int(GAPInfo.SystemEnvironment.M23_SHARD_COUNT);;
paths := SplitString(GAPInfo.SystemEnvironment.M23_CHECKPOINTS, ":");;
output := GAPInfo.SystemEnvironment.M23_OUTPUT;;
context := M23CC2A2AContext(classOrder, shardCount);;
checkpoints := M23ReadShardCheckpoints(paths);;
M23ValidateShardCoverage(context, checkpoints, classOrder, shardCount);

representatives := Concatenation(List(checkpoints,
  checkpoint -> checkpoint.representatives));;
tupleIndex := NewDictionary(representatives[1], true);;
for orbitNumber in [1..Length(representatives)] do
  orbit := Orbit(context.centralizer, representatives[orbitNumber],
    function(tuple, element)
      return SimultaneousConjugate(tuple, element);
    end);
  for member in orbit do
    if LookupDictionary(tupleIndex, member) <> fail then
      Error("duplicate tuple while building merged class index");
    fi;
    AddDictionary(tupleIndex, member, orbitNumber);
  od;
od;

M23MergedClassIndex := function(tuple)
  local index;
  if tuple[1] <> context.first then
    Error("merge move did not normalize the first coordinate");
  fi;
  index := LookupDictionary(tupleIndex, tuple);
  if index = fail then
    Error("braid image is absent from merged checkpoints");
  fi;
  return index;
end;;

M23NormalizedPureMove := function(tuple, generator)
  local conjugator;
  if generator = 12 then
    conjugator := tuple[3] * tuple[4];
  elif generator = 13 then
    conjugator := tuple[2] * tuple[4];
  elif generator = 14 then
    conjugator := tuple[2] * tuple[3];
  else
    Error("unsupported pure generator");
  fi;
  return SimultaneousConjugate(PureBraidMove4Direct(tuple, generator),
    conjugator^-1);
end;;

M23NormalizedEta34Move := function(tuple)
  return SimultaneousConjugate(Eta34Move4(tuple), tuple[4]);
end;;

M23MergedActionPermutation := function(move)
  return PermList(List(representatives, tuple ->
    M23MergedClassIndex(move(tuple))));
end;;

M23RestrictedPermutation := function(permutation, domain)
  return PermList(List(domain, point -> Position(domain, point^permutation)));
end;;

M23OrbitGenus := function(orbit, first, second, third)
  local degree;
  degree := Length(orbit);
  return 1 - degree +
    (3 * degree - M23NumberCyclesOn(M23RestrictedPermutation(first, orbit), degree) -
      M23NumberCyclesOn(M23RestrictedPermutation(second, orbit), degree) -
      M23NumberCyclesOn(M23RestrictedPermutation(third, orbit), degree)) / 2;
end;;

beta12 := M23MergedActionPermutation(tuple -> M23NormalizedPureMove(tuple, 12));;
beta13 := M23MergedActionPermutation(tuple -> M23NormalizedPureMove(tuple, 13));;
beta14 := M23MergedActionPermutation(tuple -> M23NormalizedPureMove(tuple, 14));;
beta4 := M23MergedActionPermutation(tuple -> HurwitzMove(tuple, 4));;
eta34 := M23MergedActionPermutation(M23NormalizedEta34Move);;
degree := Length(representatives);;
pureGroup := Group([beta12, beta13, beta14]);;
pureOrbits := Orbits(pureGroup, [1..degree]);;
symmetricGroup := Group([beta12, beta13, beta14, beta4, eta34]);;
symmetricOrbits := Orbits(symmetricGroup, [1..degree]);;
pureGenera := List(pureOrbits, orbit ->
  M23OrbitGenus(orbit, beta12, beta13, beta14));;
symmetricGenera := List(symmetricOrbits, orbit ->
  M23OrbitGenus(orbit, beta13, beta4, eta34));;

Assert(0, beta12 * beta13 * beta14 = ());
Assert(0, ForAll(pureGenera, IsInt));
Assert(0, ForAll(symmetricGenera, IsInt));

PrintTo(output,
  "# generated_by\tscripts/gap/merge_cc2a2a_shards.g\n",
  "# gap_version\t", GAPInfo.Version, "\n",
  "# group_order\t", Size(context.group), "\n",
  "class_order\tshard_count\tcentralizer_orbit_count\tassigned_third_count\tproduct_one_fixed_first_tuples\tproduct_one_inner_classes\tgenerating_inner_nielsen_classes\tpure_braid_orbit_count\tpure_braid_orbit_sizes\tpure_braid_orbit_genera\tsymmetric_orbit_count\tsymmetric_orbit_sizes\tsymmetric_orbit_genera\tbeta12_cycle_shape\tbeta13_cycle_shape\tbeta14_cycle_shape\tbeta4_cycle_shape\teta34_cycle_shape\n",
  classOrder, "\t", shardCount, "\t", Length(context.third_orbits), "\t",
  Sum(checkpoints, checkpoint -> checkpoint.assigned_third_count), "\t",
  Sum(checkpoints, checkpoint -> checkpoint.product_tuple_count), "\t",
  Sum(checkpoints, checkpoint -> checkpoint.product_inner_class_count), "\t",
  degree, "\t", Length(pureOrbits), "\t",
  JoinStringsWithSeparator(List(pureOrbits, orbit -> String(Length(orbit))), ","),
  "\t", JoinStringsWithSeparator(List(pureGenera, String), ","), "\t",
  Length(symmetricOrbits), "\t",
  JoinStringsWithSeparator(List(symmetricOrbits, orbit -> String(Length(orbit))), ","),
  "\t", JoinStringsWithSeparator(List(symmetricGenera, String), ","), "\t",
  M23CycleShape(beta12, degree), "\t", M23CycleShape(beta13, degree), "\t",
  M23CycleShape(beta14, degree), "\t", M23CycleShape(beta4, degree), "\t",
  M23CycleShape(eta34, degree), "\n");
QUIT;
