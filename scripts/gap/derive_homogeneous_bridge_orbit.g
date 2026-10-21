Read("src/gap/m23_homogeneous_bridge.g");;
SizeScreen([1000000, 1000000]);;

classOrder := Int(GAPInfo.SystemEnvironment.M23_CLASS_ORDER);;
shardCount := Int(GAPInfo.SystemEnvironment.M23_SHARD_COUNT);;
paths := SplitString(GAPInfo.SystemEnvironment.M23_CHECKPOINTS, ":");;
output := GAPInfo.SystemEnvironment.M23_OUTPUT;;
context := M23CC2A2AContext(classOrder, shardCount);;
checkpoints := M23ReadShardCheckpoints(paths);;
M23ValidateShardCoverage(context, checkpoints, classOrder, shardCount);
bridgeRepresentatives := Concatenation(List(checkpoints,
  checkpoint -> checkpoint.representatives));;

progressPath := fail;;
if IsBound(GAPInfo.SystemEnvironment.M23_PROGRESS_FILE) then
  progressPath := GAPInfo.SystemEnvironment.M23_PROGRESS_FILE;
  LoadPackage("io");
fi;
M23HomogeneousProgress := function(processed, discovered)
  local epoch;
  if progressPath <> fail then
    epoch := IO_gettimeofday().tv_sec;
    AppendTo(progressPath, epoch, "\tgap\thomogeneous_orbit\tall\tprogress\t",
      processed, "/", discovered, "\n");
  fi;
end;;

seed := fail;;
for bridge in bridgeRepresentatives do
  translated := M23TranslateBridgeG41(bridge);
  Assert(0, IsProductOneTuple(translated));
  Assert(0, ForAll(translated, entry -> entry in context.target_class));
  if IsGeneratingTuple(context.group, translated) then
    seed := translated;
    break;
  fi;
od;
if seed = fail then
  Error("no bridge representative satisfied the g41 generation condition");
fi;

homogeneous := M23HomogeneousBridgeOrbit(context, seed, M23HomogeneousProgress);;
degree := Length(homogeneous.representatives);;
beta12 := homogeneous.permutations[1];;
beta13 := homogeneous.permutations[2];;
beta14 := homogeneous.permutations[3];;
beta3 := homogeneous.permutations[4];;
eta23 := homogeneous.permutations[5];;
eta234 := homogeneous.permutations[6];;
pureGenera := List(homogeneous.pure_orbits, orbit ->
  M23HomogeneousOrbitGenus(orbit, beta12, beta13, beta14));;
symmetricGenera := List(homogeneous.symmetric_orbits, orbit ->
  M23HomogeneousOrbitGenus(orbit, beta3, eta23, eta234));;

translatedIndices := [];;
for bridge in bridgeRepresentatives do
  translated := M23TranslateBridgeG41(bridge);
  if IsGeneratingTuple(context.group, translated) then
    index := LookupDictionary(homogeneous.index, translated);
    if index = fail then
      Error("a generating bridge translate lies outside the homogeneous orbit");
    fi;
    Add(translatedIndices, index);
  fi;
od;
translatedPureOrbitIds := Set(List(translatedIndices, index ->
  PositionProperty(homogeneous.pure_orbits, orbit -> index in orbit)));;

Assert(0, beta12 * beta13 * beta14 = ());
Assert(0, Length(homogeneous.symmetric_orbits) = 1);
Assert(0, ForAll(pureGenera, IsInt));
Assert(0, ForAll(symmetricGenera, IsInt));

PrintTo(output,
  "# generated_by\tscripts/gap/derive_homogeneous_bridge_orbit.g\n",
  "# gap_version\t", GAPInfo.Version, "\n",
  "# group_order\t", Size(context.group), "\n",
  "class_order\tbridge_class_count\tbridge_translate_count\ttranslated_pure_orbit_count\thomogeneous_class_count\tpure_braid_orbit_count\tpure_braid_orbit_sizes\tpure_braid_orbit_genera\tsymmetric_orbit_count\tsymmetric_orbit_sizes\tsymmetric_orbit_genera\tbeta12_cycle_shape\tbeta13_cycle_shape\tbeta14_cycle_shape\tbeta3_cycle_shape\teta23_cycle_shape\teta234_cycle_shape\n",
  classOrder, "\t", Length(bridgeRepresentatives), "\t",
  Length(translatedIndices), "\t", Length(translatedPureOrbitIds), "\t",
  degree, "\t", Length(homogeneous.pure_orbits), "\t",
  JoinStringsWithSeparator(List(homogeneous.pure_orbits,
    orbit -> String(Length(orbit))), ","), "\t",
  JoinStringsWithSeparator(List(pureGenera, String), ","), "\t",
  Length(homogeneous.symmetric_orbits), "\t",
  JoinStringsWithSeparator(List(homogeneous.symmetric_orbits,
    orbit -> String(Length(orbit))), ","), "\t",
  JoinStringsWithSeparator(List(symmetricGenera, String), ","), "\t",
  M23CycleShape(beta12, degree), "\t", M23CycleShape(beta13, degree), "\t",
  M23CycleShape(beta14, degree), "\t", M23CycleShape(beta3, degree), "\t",
  M23CycleShape(eta23, degree), "\t", M23CycleShape(eta234, degree), "\n");
QUIT;
