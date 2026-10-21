Read("src/gap/m23_cc2a2a_shards.g");;
SizeScreen([1000000, 1000000]);;

classOrder := Int(GAPInfo.SystemEnvironment.M23_CLASS_ORDER);;
shardCount := Int(GAPInfo.SystemEnvironment.M23_SHARD_COUNT);;
shardIndex := Int(GAPInfo.SystemEnvironment.M23_SHARD_INDEX);;
output := GAPInfo.SystemEnvironment.M23_OUTPUT;;

if shardCount < 1 or shardIndex < 1 or shardIndex > shardCount then
  Error("invalid shard index/count");
fi;

context := M23CC2A2AContext(classOrder, shardCount);;
assignedOrbitIds := context.assignments.orbit_ids[shardIndex];;
assignedThirds := Concatenation(context.third_orbits{assignedOrbitIds});;
identity := One(context.first);;
productTuples := [];;

for third in assignedThirds do
  for fourth in context.involutions do
    second := context.first^-1 * (third * fourth)^-1;
    if M23HasExactOrder(second, classOrder, identity) then
      Add(productTuples, [context.first, second, third, fourth]);
    fi;
  od;
od;

productOrbits := OrbitsDomain(context.centralizer, productTuples,
  function(tuple, element)
    return SimultaneousConjugate(tuple, element);
  end);;
nielsenOrbits := Filtered(productOrbits, orbit ->
  IsGeneratingTuple(context.group, orbit[1]));;
representatives := List(nielsenOrbits, orbit -> orbit[1]);;

Assert(0, ForAll(nielsenOrbits, orbit ->
  Length(orbit) = Size(context.centralizer)));

checkpoint := rec(
  schema_version := 1,
  gap_version := GAPInfo.Version,
  group_order := Size(context.group),
  class_order := classOrder,
  shard_count := shardCount,
  shard_index := shardIndex,
  centralizer_orbit_count := Length(context.third_orbits),
  assigned_orbit_ids := assignedOrbitIds,
  assigned_third_count := Length(assignedThirds),
  product_tuple_count := Length(productTuples),
  product_inner_class_count := Length(productOrbits),
  generating_inner_class_count := Length(nielsenOrbits),
  representatives := representatives
);;

PrintTo(output, "M23_SHARD_CHECKPOINT := ", checkpoint, ";;\n");
QUIT;
