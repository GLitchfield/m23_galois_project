Read("src/gap/m23_cc2a2a_shards.g");;
SizeScreen([1000000, 1000000]);;

classOrder := Int(GAPInfo.SystemEnvironment.M23_CLASS_ORDER);;
shardCount := Int(GAPInfo.SystemEnvironment.M23_SHARD_COUNT);;
paths := SplitString(GAPInfo.SystemEnvironment.M23_CHECKPOINTS, ":");;
output := GAPInfo.SystemEnvironment.M23_OUTPUT;;
context := M23CC2A2AContext(classOrder, shardCount);;
checkpoints := M23ReadShardCheckpoints(paths);;
M23ValidateShardCoverage(context, checkpoints, classOrder, shardCount);

progressPath := fail;;
if IsBound(GAPInfo.SystemEnvironment.M23_PROGRESS_FILE) then
  progressPath := GAPInfo.SystemEnvironment.M23_PROGRESS_FILE;
  LoadPackage("io");
fi;
M23VerificationProgress := function(phase, checkpoint, detail)
  local epoch;
  if progressPath <> fail then
    epoch := IO_gettimeofday().tv_sec;
    AppendTo(progressPath, epoch, "\tgap\t", phase, "\t",
      checkpoint.shard_index, "\tdone\t", detail, "\n");
  fi;
end;;

tupleIndex := fail;;
representativeCount := 0;;
for checkpoint in checkpoints do
  for representative in checkpoint.representatives do
    Assert(0, representative[1] = context.first);
    Assert(0, IsProductOneTuple(representative));
    Assert(0, Order(representative[1]) = classOrder);
    Assert(0, Order(representative[2]) = classOrder);
    Assert(0, Order(representative[3]) = 2);
    Assert(0, Order(representative[4]) = 2);
    Assert(0, IsGeneratingTuple(context.group, representative));
    orbit := Orbit(context.centralizer, representative,
      function(tuple, element)
        return SimultaneousConjugate(tuple, element);
      end);
    Assert(0, Length(orbit) = Size(context.centralizer));
    if tupleIndex = fail then
      tupleIndex := NewDictionary(orbit[1], true);
    fi;
    for member in orbit do
      if LookupDictionary(tupleIndex, member) <> fail then
        Error("duplicate inner class across checkpoint representatives");
      fi;
      AddDictionary(tupleIndex, member, true);
    od;
    representativeCount := representativeCount + 1;
  od;
  M23VerificationProgress("verify_representatives", checkpoint,
    Length(checkpoint.representatives));
od;

# Re-enumerate every assigned candidate independently of the saved counts.
identity := One(context.first);;
for checkpoint in checkpoints do
  assignedThirds := Concatenation(
    context.third_orbits{checkpoint.assigned_orbit_ids});
  recomputedTuples := [];
  for third in assignedThirds do
    for fourth in context.involutions do
      second := context.first^-1 * (third * fourth)^-1;
      if M23HasExactOrder(second, classOrder, identity) then
        Add(recomputedTuples, [context.first, second, third, fourth]);
      fi;
    od;
  od;
  if Length(recomputedTuples) <> checkpoint.product_tuple_count then
    Error("deep product-tuple recount mismatch at shard ",
      checkpoint.shard_index);
  fi;
  recomputedOrbits := OrbitsDomain(context.centralizer, recomputedTuples,
    function(tuple, element)
      return SimultaneousConjugate(tuple, element);
    end);
  if Length(recomputedOrbits) <> checkpoint.product_inner_class_count then
    Error("deep product-orbit recount mismatch at shard ",
      checkpoint.shard_index);
  fi;
  recomputedGenerating := Filtered(recomputedOrbits, orbit ->
    IsGeneratingTuple(context.group, orbit[1]));
  if Length(recomputedGenerating) <>
     checkpoint.generating_inner_class_count then
    Error("deep generating-orbit recount mismatch at shard ",
      checkpoint.shard_index);
  fi;
  for orbit in recomputedGenerating do
    if LookupDictionary(tupleIndex, orbit[1]) = fail then
      Error("deep recount found an uncheckpointed generating class");
    fi;
  od;
  M23VerificationProgress("verify_deep", checkpoint,
    Concatenation(String(Length(recomputedTuples)), ",",
      String(Length(recomputedOrbits)), ",",
      String(Length(recomputedGenerating))));
od;

PrintTo(output,
  "schema_version\tdeep_verified\tclass_order\tshard_count\tcentralizer_orbit_count\tassigned_third_count\tproduct_tuple_count\tproduct_inner_class_count\tgenerating_inner_class_count\tverified_representative_count\n",
  "1\ttrue\t", classOrder, "\t", shardCount, "\t", Length(context.third_orbits),
  "\t", Sum(checkpoints, checkpoint -> checkpoint.assigned_third_count),
  "\t", Sum(checkpoints, checkpoint -> checkpoint.product_tuple_count),
  "\t", Sum(checkpoints, checkpoint -> checkpoint.product_inner_class_count),
  "\t", Sum(checkpoints, checkpoint -> checkpoint.generating_inner_class_count),
  "\t", representativeCount, "\n");
QUIT;
