Read("src/gap/m23_homogeneous_macroblocks.g");;
Read("src/gap/m23_homogeneous_bridge.g");;
SizeScreen([1000000, 1000000]);;

if not IsBound(GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT) then
  Error("M23_PAIR_CHECKPOINT must name a homogeneous pair checkpoint");
fi;
if not IsBound(GAPInfo.SystemEnvironment.M23_OUTPUT) then
  Error("M23_OUTPUT must name the generated TSV file");
fi;

sourceBlockOrdinal := 1633430;;
if IsBound(GAPInfo.SystemEnvironment.M23_SOURCE_BLOCK) then
  sourceBlockOrdinal := Int(GAPInfo.SystemEnvironment.M23_SOURCE_BLOCK);
fi;
sourceTwistId := 1;;
if IsBound(GAPInfo.SystemEnvironment.M23_SOURCE_TWIST) then
  sourceTwistId := Int(GAPInfo.SystemEnvironment.M23_SOURCE_TWIST);
fi;

M23_PAIR_BLOCK_CHECKPOINT := fail;;
Read(GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT);
checkpoint := M23_PAIR_BLOCK_CHECKPOINT;;
G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
locator := M23BuildDirectPairLocator(G, classes, checkpoint);;
sourceSeed := fail;;
if IsBound(GAPInfo.SystemEnvironment.M23_BRIDGE_CHECKPOINT) then
  M23_SHARD_CHECKPOINT := fail;
  Read(GAPInfo.SystemEnvironment.M23_BRIDGE_CHECKPOINT);
  for bridgeRepresentative in M23_SHARD_CHECKPOINT.representatives do
    candidateSeed := M23TranslateBridgeG41(bridgeRepresentative);
    if IsGeneratingTuple(G, candidateSeed) then
      sourceSeed := candidateSeed;
      break;
    fi;
  od;
  if sourceSeed = fail then
    Error("bridge checkpoint has no generating homogeneous translate");
  fi;
  sourceCoordinate := M23DirectPairTwistCoordinate(locator, sourceSeed);
  sourceBlockOrdinal := sourceCoordinate.block.ordinal;
  sourceTwistId := sourceCoordinate.twist_id;
fi;
block := M23DecodeMacroblock(checkpoint, sourceBlockOrdinal);;
refinement := M23CachedDirectPairTwistRefinement(locator, block);;
if sourceTwistId < 1 or
   sourceTwistId > Length(refinement.twist_orbits) then
  Error("M23_SOURCE_TWIST is outside the selected block refinement");
fi;
sourceIndices := refinement.twist_orbits[sourceTwistId];;
sourceWeight := Length(sourceIndices);;
sourceGenerating := IsGeneratingTuple(G,
  refinement.materialized.tuples[sourceIndices[1]]);;
neighbors := M23DirectPairTwistNeighbors(locator, block, sourceTwistId);;
firstTransport :=
  locator.pair_first_transports[block.natural_class_index]
    [block.left_pair_id];;

M23PermutationImages := function(permutation)
  return JoinStringsWithSeparator(
    List([1..23], point -> String(point^permutation)), ",");
end;;

M23TupleFields := function(tuple)
  return JoinStringsWithSeparator(List(tuple, M23PermutationImages), "\t");
end;;

output := GAPInfo.SystemEnvironment.M23_OUTPUT;;
checkpointHash := "unknown";;
if IsBound(GAPInfo.SystemEnvironment.M23_PAIR_SHA256) then
  checkpointHash := GAPInfo.SystemEnvironment.M23_PAIR_SHA256;
fi;
bridgeProvenance := "";;
if IsBound(GAPInfo.SystemEnvironment.M23_BRIDGE_SHA256) then
  bridgeProvenance := Concatenation("# source_bridge_sha256\t",
    GAPInfo.SystemEnvironment.M23_BRIDGE_SHA256, "\n");
fi;
PrintTo(output,
  "# schema\tm23-native-coordinate-fixture-v1\n",
  "# degree\t23\n",
  "# convention\timages 1..23; GAP right-action composition\n",
  "# gap_version\t", GAPInfo.Version, "\n",
  "# group_order\t", checkpoint.group_order, "\n",
  "# target_order\t", checkpoint.target_order, "\n",
  "# target_class_size\t", checkpoint.target_class_size, "\n",
  "# source_checkpoint_sha256\t", checkpointHash, "\n",
  bridgeProvenance,
  "# source_block\t", block.ordinal, "\t", block.natural_class_index,
    "\t", block.inverse_class_index, "\t", block.left_pair_id, "\t",
    block.right_pair_id, "\n",
  "# counts\t", sourceWeight, "\t", 2 * sourceWeight, "\t",
    Length(neighbors), "\n",
  "# source_generating\t", sourceGenerating, "\n",
  "# source_vertex\t", block.ordinal, "\t", sourceTwistId, "\t",
    sourceWeight, "\n");
AppendTo(output, "target\t", M23PermutationImages(locator.target), "\n",
  "first_transport\t", M23PermutationImages(firstTransport), "\n");

for sourcePosition in [1..Length(sourceIndices)] do
  materializedIndex := sourceIndices[sourcePosition];
  tuple := refinement.materialized.tuples[materializedIndex];
  AppendTo(output, "source\t", sourcePosition, "\t",
    M23TupleFields(tuple), "\n");
  for generator in [13, 14] do
    moved := PureBraidMove4Direct(tuple, generator);
    if generator = 13 then
      conjugator := tuple[2] * tuple[4];
    else
      conjugator := tuple[2] * tuple[3];
    fi;
    coordinate := M23DirectPairTwistCoordinateWithFirstTransport(locator,
      moved, conjugator^-1 * firstTransport);
    AppendTo(output, "image\t", sourcePosition, "\t", generator, "\t",
      M23TupleFields(moved), "\t", coordinate.block.ordinal, "\t",
      coordinate.twist_id, "\t", coordinate.weight, "\n");

    movedFirstTransport := conjugator^-1 * firstTransport;
    fixed := SimultaneousConjugate(moved, movedFirstTransport);
    Assert(0, fixed[1] = locator.target);
    leftData := LookupDictionary(locator.target_pair_transport, fixed[2]);
    Assert(0, leftData <> fail);
    normalized := SimultaneousConjugate(fixed, leftData[3]);
    normalizedPair :=
      checkpoint.classes[leftData[1]].normalized_pairs[leftData[2]];
    Assert(0, normalized{[1, 2]} = normalizedPair);
    lookup := locator.lookups[leftData[1]];
    Assert(0, lookup <> fail);
    rightData := LookupDictionary(lookup.right_transport,
      normalized{[3, 4]});
    Assert(0, rightData <> fail);
    segment := lookup.segment;
    destinationOrdinal := segment.first_ordinal +
      (leftData[2] - 1) * segment.right_pair_count + rightData[1] - 1;
    Assert(0, destinationOrdinal = coordinate.block.ordinal);
    destinationBlock := M23DecodeMacroblock(checkpoint,
      destinationOrdinal);
    relativeMap := M23DirectRelativeMap(locator, destinationBlock);
    relativeIndex := LookupDictionary(relativeMap.element_to_index,
      rightData[2]);
    Assert(0, relativeIndex <> fail);
    destinationRefinement := M23CachedDirectPairTwistRefinement(locator,
      destinationBlock);
    materializedIndex :=
      destinationRefinement.relative_to_materialized[relativeIndex];
    Assert(0,
      destinationRefinement.twist_id_by_index[materializedIndex] =
        coordinate.twist_id);

    AppendTo(output,
      "target_pair\t", M23PermutationImages(fixed[2]), "\t",
        leftData[1], "\t", leftData[2], "\t",
        M23PermutationImages(leftData[3]), "\t",
        M23PermutationImages(normalizedPair[1]), "\t",
        M23PermutationImages(normalizedPair[2]), "\n",
      "right_pair\t", leftData[1], "\t",
        M23PermutationImages(normalized[3]), "\t",
        M23PermutationImages(normalized[4]), "\t", rightData[1], "\t",
        M23PermutationImages(rightData[2]), "\n",
      "segment\t", leftData[1], "\t", segment.first_ordinal, "\t",
        segment.right_pair_count, "\n",
      "relative\t", destinationOrdinal, "\t",
        M23PermutationImages(rightData[2]), "\t", relativeIndex, "\n",
      "refinement\t", destinationOrdinal, "\t", relativeIndex, "\t",
        coordinate.twist_id, "\t", coordinate.weight, "\n");
  od;
od;

for position in [1..Length(neighbors)] do
  neighbor := neighbors[position];
  AppendTo(output, "neighbor\t", position, "\t",
    neighbor.block.ordinal, "\t", neighbor.twist_id, "\t",
    neighbor.weight, "\n");
od;
QUIT;
