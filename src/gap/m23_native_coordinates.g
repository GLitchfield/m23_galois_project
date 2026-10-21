# Independent GAP translation between historical pair-twist IDs and the
# stable native-v1 IDs.  This file deliberately builds from GAP pair orbits;
# it does not read the C++ coordinate or generation-mask checkpoints.

M23CreateNativePairTwistAdapter := function(locator)
  return rec(
    locator := locator,
    twist_map_cache := NewDictionary(1, true)
  );
end;;

M23NativePairTwistMap := function(adapter, block)
  local known, locator, refinement, rows, gapTwistId, relativeIndices,
    row, gapToNative, nativeToGap, nativeTwistId, firstTransport, fixed,
    rightData;
  known := LookupDictionary(adapter.twist_map_cache, block.ordinal);
  if known <> fail then
    return known;
  fi;
  locator := adapter.locator;
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
  AddDictionary(adapter.twist_map_cache, block.ordinal, known);
  return known;
end;;

M23NativePairTwistVertex := function(adapter, block, gapTwistId)
  local map, nativeTwistId, row;
  map := M23NativePairTwistMap(adapter, block);
  if gapTwistId > Length(map.gap_to_native) or
     not IsBound(map.gap_to_native[gapTwistId]) then
    Error("GAP twist ID is absent from native-v1 translation");
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

M23NativePairTwistSeed := function(adapter, ordinal, nativeTwistId)
  local block, map, gapTwistId, materializedIndex;
  block := M23DecodeMacroblock(adapter.locator.checkpoint, ordinal);
  map := M23NativePairTwistMap(adapter, block);
  if nativeTwistId > Length(map.native_to_gap) or
     not IsBound(map.native_to_gap[nativeTwistId]) then
    Error("native-v1 twist ID is outside its macroblock refinement");
  fi;
  gapTwistId := map.native_to_gap[nativeTwistId];
  materializedIndex := map.refinement.twist_orbits[gapTwistId][1];
  return map.refinement.materialized.tuples[materializedIndex];
end;;

M23NativePairTwistNeighbors := function(adapter, vertex)
  local neighbors;
  neighbors := List(
    M23DirectPairTwistNeighbors(adapter.locator, vertex.block,
      vertex.gap_twist_id),
    neighbor -> M23NativePairTwistVertex(adapter, neighbor.block,
      neighbor.twist_id));
  Sort(neighbors, function(left, right)
    if left.block.ordinal <> right.block.ordinal then
      return left.block.ordinal < right.block.ordinal;
    fi;
    return left.native_twist_id < right.native_twist_id;
  end);
  return neighbors;
end;;

M23BoundedNativePairTwistOrbitWithLedger := function(adapter, seed, limit,
  progress, externalLookup)
  local locator, firstGapVertex, firstVertex, vertices, index, classCount,
    position, vertex, neighbor, key, status, linkedCertificate;
  locator := adapter.locator;
  if limit < 1 or not IsProductOneTuple(seed) or
     not IsGeneratingTuple(locator.group, seed) then
    Error("invalid bounded native-v1 quotient request");
  fi;
  firstGapVertex := M23DirectPairTwistCoordinate(locator, seed);
  firstVertex := M23NativePairTwistVertex(adapter, firstGapVertex.block,
    firstGapVertex.twist_id);
  vertices := [firstVertex];
  index := NewDictionary([1, 1], true);
  AddDictionary(index,
    [firstVertex.block.ordinal, firstVertex.native_twist_id], 1);
  classCount := firstVertex.weight;
  position := 1;
  linkedCertificate := fail;
  while position <= Length(vertices) and classCount <= limit and
      linkedCertificate = fail do
    vertex := vertices[position];
    for neighbor in M23NativePairTwistNeighbors(adapter, vertex) do
      key := [neighbor.block.ordinal, neighbor.native_twist_id];
      if LookupDictionary(index, key) = fail then
        linkedCertificate := externalLookup(key);
        if linkedCertificate <> fail then
          break;
        fi;
        Add(vertices, neighbor);
        AddDictionary(index, key, Length(vertices));
        classCount := classCount + neighbor.weight;
        if classCount > limit then
          break;
        fi;
      fi;
    od;
    if position mod 100 = 0 then
      progress(position, Length(vertices), classCount);
    fi;
    position := position + 1;
  od;
  if linkedCertificate <> fail then
    status := "linked";
  elif position > Length(vertices) then
    status := "closed";
  else
    status := "overflow";
  fi;
  progress(position - 1, Length(vertices), classCount);
  return rec(
    status := status,
    linked_certificate := linkedCertificate,
    checked_vertex_count := position - 1,
    discovered_vertex_count := Length(vertices),
    discovered_class_count := classCount,
    vertices := vertices
  );
end;;
