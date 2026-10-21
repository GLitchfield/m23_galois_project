Read("src/gap/m23_homogeneous_macroblocks.g");;
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
sourceGapTwistId := 1;;
if IsBound(GAPInfo.SystemEnvironment.M23_SOURCE_TWIST) then
  sourceGapTwistId := Int(GAPInfo.SystemEnvironment.M23_SOURCE_TWIST);
fi;
walkLimit := 250;;
if IsBound(GAPInfo.SystemEnvironment.M23_WALK_LIMIT) then
  walkLimit := Int(GAPInfo.SystemEnvironment.M23_WALK_LIMIT);
fi;
if sourceBlockOrdinal < 2 or sourceGapTwistId < 1 or walkLimit < 1 then
  Error("invalid native bounded-walk fixture request");
fi;

M23_PAIR_BLOCK_CHECKPOINT := fail;;
Read(GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT);
checkpoint := M23_PAIR_BLOCK_CHECKPOINT;;
G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
locator := M23BuildDirectPairLocator(G, classes, checkpoint);;

# Native twist IDs order beta12 orbits by their least key-v2 relative index.
# GAP's historical IDs order the corresponding materialized double-coset
# representatives, so every fixture vertex is translated by orbit membership.
twistMapCache := NewDictionary(1, true);;
M23NativeTwistMap := function(block)
  local known, refinement, rows, gapTwistId, relativeIndices, row,
    gapToNative, nativeToGap, nativeTwistId, firstTransport, fixed,
    rightData;
  known := LookupDictionary(twistMapCache, block.ordinal);
  if known <> fail then
    return known;
  fi;
  refinement := M23CachedDirectPairTwistRefinement(locator, block);
  rows := [];
  if block.ordinal = 1 then
    firstTransport :=
      locator.pair_first_transports[block.natural_class_index]
        [block.left_pair_id];
    for gapTwistId in [1..Length(refinement.twist_orbits)] do
      if Length(refinement.twist_orbits[gapTwistId]) <> 1 then
        Error("identity pair-twist block is not a singleton");
      fi;
      fixed := SimultaneousConjugate(
        refinement.materialized.tuples[
          refinement.twist_orbits[gapTwistId][1]], firstTransport);
      if fixed[1] <> locator.target or fixed[4] <> fixed[3]^-1 then
        Error("invalid fixed identity-product representative");
      fi;
      rightData := LookupDictionary(locator.target_pair_transport, fixed[3]);
      if rightData = fail then
        Error("identity representative is absent from target-pair lookup");
      fi;
      Add(rows, rec(
        gap_twist_id := gapTwistId,
        stable_key := [rightData[1], rightData[2]],
        weight := 1
      ));
    od;
  else
    for gapTwistId in [1..Length(refinement.twist_orbits)] do
      relativeIndices := List(refinement.twist_orbits[gapTwistId],
        point -> refinement.materialized_to_relative[point]);
      Sort(relativeIndices);
      Add(rows, rec(
        gap_twist_id := gapTwistId,
        stable_key := [relativeIndices[1]],
        weight := Length(relativeIndices)
      ));
    od;
  fi;
  Sort(rows, function(left, right)
    return left.stable_key < right.stable_key;
  end);
  gapToNative := [];
  nativeToGap := [];
  for nativeTwistId in [1..Length(rows)] do
    row := rows[nativeTwistId];
    gapToNative[row.gap_twist_id] := nativeTwistId;
    nativeToGap[nativeTwistId] := row.gap_twist_id;
  od;
  known := rec(
    refinement := refinement,
    rows := rows,
    gap_to_native := gapToNative,
    native_to_gap := nativeToGap
  );
  AddDictionary(twistMapCache, block.ordinal, known);
  return known;
end;;

M23NativeVertex := function(block, gapTwistId)
  local map, nativeTwistId, row;
  map := M23NativeTwistMap(block);
  if gapTwistId > Length(map.gap_to_native) or
     not IsBound(map.gap_to_native[gapTwistId]) then
    Error("GAP twist ID is absent from the native orbit translation");
  fi;
  nativeTwistId := map.gap_to_native[gapTwistId];
  row := map.rows[nativeTwistId];
  return rec(
    block := block,
    gap_twist_id := gapTwistId,
    native_twist_id := nativeTwistId,
    weight := row.weight
  );
end;;

sourceBlock := M23DecodeMacroblock(checkpoint, sourceBlockOrdinal);;
sourceMap := M23NativeTwistMap(sourceBlock);;
if sourceGapTwistId > Length(sourceMap.gap_to_native) or
   not IsBound(sourceMap.gap_to_native[sourceGapTwistId]) then
  Error("source GAP twist is outside its macroblock refinement");
fi;
source := M23NativeVertex(sourceBlock, sourceGapTwistId);;
sourceRepresentative := sourceMap.refinement.materialized.tuples[
  sourceMap.refinement.twist_orbits[sourceGapTwistId][1]];;
if not IsGeneratingTuple(G, sourceRepresentative) then
  Error("native bounded-walk fixture must start at a generating vertex");
fi;

vertices := [source];;
index := NewDictionary([1, 1], true);;
AddDictionary(index, [source.block.ordinal, source.native_twist_id], 1);
classCount := source.weight;;
position := 1;;
while position <= Length(vertices) and classCount <= walkLimit do
  vertex := vertices[position];
  neighbors := List(
    M23DirectPairTwistNeighbors(locator, vertex.block, vertex.gap_twist_id),
    neighbor -> M23NativeVertex(neighbor.block, neighbor.twist_id));
  Sort(neighbors, function(left, right)
    if left.block.ordinal <> right.block.ordinal then
      return left.block.ordinal < right.block.ordinal;
    fi;
    return left.native_twist_id < right.native_twist_id;
  end);
  for neighbor in neighbors do
    key := [neighbor.block.ordinal, neighbor.native_twist_id];
    if LookupDictionary(index, key) = fail then
      Add(vertices, neighbor);
      AddDictionary(index, key, Length(vertices));
      classCount := classCount + neighbor.weight;
      if classCount > walkLimit then
        break;
      fi;
    fi;
  od;
  position := position + 1;
od;
checkedCount := position - 1;;
if position > Length(vertices) then
  status := "closed";
else
  status := "overflow";
fi;

checkpointHash := "unknown";;
if IsBound(GAPInfo.SystemEnvironment.M23_PAIR_SHA256) then
  checkpointHash := GAPInfo.SystemEnvironment.M23_PAIR_SHA256;
fi;
output := GAPInfo.SystemEnvironment.M23_OUTPUT;;
PrintTo(output,
  "# schema\tm23-native-bounded-walk-fixture-v1\n",
  "# gap_version\t", GAPInfo.Version, "\n",
  "# source_checkpoint_sha256\t", checkpointHash, "\n",
  "# source_gap_vertex\t", source.block.ordinal, "\t",
    source.gap_twist_id, "\n",
  "# limit\t", walkLimit, "\n",
  "# status\t", status, "\n",
  "# checked_vertex_count\t", checkedCount, "\n",
  "# discovered_vertex_count\t", Length(vertices), "\n",
  "# discovered_class_count\t", classCount, "\n");
for position in [1..Length(vertices)] do
  vertex := vertices[position];
  AppendTo(output, "vertex\t", position, "\t", vertex.block.ordinal, "\t",
    vertex.native_twist_id, "\t", vertex.weight, "\n");
od;
QUIT;
