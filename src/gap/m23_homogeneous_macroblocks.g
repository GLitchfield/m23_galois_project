Read("src/gap/m23_homogeneous_bridge.g");;

M23BoundedPureOrbitWithLedger := function(group, targetClass, seed, limit,
  progress, externalLookup)
  local first, centralizer, transporter, normalizedSeed, state, addClass,
    moves, position, move, image, result, linkedCertificate, status;
  if limit < 1 or not IsProductOneTuple(seed) or
     not IsGeneratingTuple(group, seed) or
     not ForAll(seed, entry -> entry in targetClass) then
    Error("invalid bounded pure-orbit request");
  fi;
  first := Representative(targetClass);
  transporter := RepresentativeAction(group, seed[1], first);
  if transporter = fail then
    Error("could not fix the first coordinate of the orbit seed");
  fi;
  normalizedSeed := SimultaneousConjugate(seed, transporter);
  centralizer := Centralizer(group, first);
  state := rec(
    representatives := [],
    index := NewDictionary(normalizedSeed, true)
  );
  addClass := function(tuple)
    local known, orbit, member, newIndex;
    known := LookupDictionary(state.index, tuple);
    if known <> fail then
      return known;
    fi;
    orbit := Orbit(centralizer, tuple,
      function(point, element)
        return SimultaneousConjugate(point, element);
      end);
    if Length(orbit) <> Size(centralizer) then
      Error("generating tuple has a nontrivial inner stabilizer");
    fi;
    newIndex := Length(state.representatives) + 1;
    Add(state.representatives, tuple);
    for member in orbit do
      if LookupDictionary(state.index, member) <> fail then
        Error("overlapping inner classes in bounded orbit");
      fi;
      AddDictionary(state.index, member, newIndex);
    od;
    return newIndex;
  end;

  addClass(normalizedSeed);
  moves := [
    tuple -> M23NormalizedHomogeneousPureMove(tuple, 12),
    tuple -> M23NormalizedHomogeneousPureMove(tuple, 13),
    tuple -> M23NormalizedHomogeneousPureMove(tuple, 14)
  ];
  position := 1;
  linkedCertificate := fail;
  while position <= Length(state.representatives) and
      Length(state.representatives) <= limit and linkedCertificate = fail do
    for move in moves do
      image := move(state.representatives[position]);
      linkedCertificate := externalLookup(image);
      if linkedCertificate <> fail then
        break;
      fi;
      addClass(image);
      if Length(state.representatives) > limit then
        break;
      fi;
    od;
    if position mod 1000 = 0 then
      progress(position, Length(state.representatives));
    fi;
    position := position + 1;
  od;
  if linkedCertificate <> fail then
    status := "linked";
  elif position > Length(state.representatives) then
    status := "closed";
  else
    status := "overflow";
  fi;
  result := rec(
    status := status,
    closed := status = "closed",
    linked_certificate := linkedCertificate,
    limit := limit,
    checked_count := position - 1,
    discovered_count := Length(state.representatives),
    seed := normalizedSeed,
    representatives := state.representatives
  );
  if result.status = "overflow" and result.discovered_count <> limit + 1 then
    Error("overflow traversal did not stop at the first class above the limit");
  fi;
  progress(result.checked_count, result.discovered_count);
  return result;
end;;

M23BoundedPureOrbit := function(group, targetClass, seed, limit, progress)
  return M23BoundedPureOrbitWithLedger(group, targetClass, seed, limit,
    progress, tuple -> fail);
end;;

M23MacroblockSegments := function(checkpoint)
  local segments, first, record, inverseRecord, count;
  segments := [];
  first := 1;
  for record in checkpoint.classes do
    inverseRecord := checkpoint.classes[record.inverse_class_index];
    count := record.pair_orbit_count * inverseRecord.pair_orbit_count;
    if count > 0 then
      Add(segments, rec(
        natural_class_index := record.natural_class_index,
        inverse_class_index := record.inverse_class_index,
        left_pair_count := record.pair_orbit_count,
        right_pair_count := inverseRecord.pair_orbit_count,
        first_ordinal := first,
        last_ordinal := first + count - 1
      ));
      first := first + count;
    fi;
  od;
  if first - 1 <> checkpoint.macroblock_count then
    Error("macroblock segments do not cover the checkpoint count");
  fi;
  return segments;
end;;

M23DecodeMacroblock := function(checkpoint, ordinal)
  local segment, offset;
  if ordinal < 1 or ordinal > checkpoint.macroblock_count then
    Error("macroblock ordinal is outside the checkpoint range");
  fi;
  segment := First(M23MacroblockSegments(checkpoint), item ->
    ordinal >= item.first_ordinal and ordinal <= item.last_ordinal);
  offset := ordinal - segment.first_ordinal;
  return rec(
    ordinal := ordinal,
    natural_class_index := segment.natural_class_index,
    inverse_class_index := segment.inverse_class_index,
    left_pair_id := QuoInt(offset, segment.right_pair_count) + 1,
    right_pair_id := RemInt(offset, segment.right_pair_count) + 1
  );
end;;

M23MaterializeMacroblock := function(group, classes, checkpoint, block)
  local classRecord, inverseRecord, product, inverseProduct, aligner,
    leftPair, rightPair, productCentralizer, leftStabilizer,
    rightStabilizer, doubleCosets, tuples, stabilizerOrders, doubleCoset,
    tuple, stabilizerOrder;
  classRecord := checkpoint.classes[block.natural_class_index];
  inverseRecord := checkpoint.classes[block.inverse_class_index];
  product := Representative(classes[block.natural_class_index]);
  inverseProduct := Representative(classes[block.inverse_class_index]);
  aligner := RepresentativeAction(group, inverseProduct, product^-1);
  if aligner = fail then
    Error("inverse product representative could not be aligned");
  fi;
  leftPair := classRecord.normalized_pairs[block.left_pair_id];
  rightPair := SimultaneousConjugate(
    inverseRecord.normalized_pairs[block.right_pair_id], aligner);
  if Product(leftPair) <> product or Product(rightPair) <> product^-1 then
    Error("macroblock factor pairs have incompatible products");
  fi;
  productCentralizer := Centralizer(group, product);
  leftStabilizer := Intersection(Centralizer(group, leftPair[1]),
    Centralizer(group, leftPair[2]));
  rightStabilizer := Intersection(Centralizer(group, rightPair[1]),
    Centralizer(group, rightPair[2]));
  # With the right factor represented as rightPair^h, diagonal conjugacy
  # changes h by S_right on the left and S_left on the right.
  doubleCosets := DoubleCosetRepsAndSizes(productCentralizer,
    rightStabilizer, leftStabilizer);
  tuples := [];
  stabilizerOrders := [];
  for doubleCoset in doubleCosets do
    tuple := Concatenation(leftPair,
      SimultaneousConjugate(rightPair, doubleCoset[1]));
    Assert(0, IsProductOneTuple(tuple));
    stabilizerOrder :=
      Size(rightStabilizer) * Size(leftStabilizer) / doubleCoset[2];
    Assert(0, IsInt(stabilizerOrder) and stabilizerOrder >= 1);
    Add(tuples, tuple);
    Add(stabilizerOrders, stabilizerOrder);
  od;
  return rec(
    block := block,
    product_centralizer_order := Size(productCentralizer),
    left_stabilizer_order := Size(leftStabilizer),
    right_stabilizer_order := Size(rightStabilizer),
    inner_class_count := Length(tuples),
    tuples := tuples,
    stabilizer_orders := stabilizerOrders
  );
end;;

M23BuildMacroblockLocator := function(group, classes, checkpoint)
  local segments, segmentByClass, lookups, segment, classIndex, classRecord,
    inverseRecord, product, inverseProduct, aligner, centralizer, leftIndex,
    rightIndex, pairId, pair, orbit, member;
  segments := M23MacroblockSegments(checkpoint);
  segmentByClass := List(classes, class -> fail);
  for segment in segments do
    segmentByClass[segment.natural_class_index] := segment;
  od;
  lookups := List(classes, class -> fail);
  for classIndex in [1..Length(classes)] do
    classRecord := checkpoint.classes[classIndex];
    if classRecord.pair_orbit_count = 0 then
      continue;
    fi;
    inverseRecord := checkpoint.classes[classRecord.inverse_class_index];
    product := Representative(classes[classIndex]);
    inverseProduct := Representative(classes[classRecord.inverse_class_index]);
    aligner := RepresentativeAction(group, inverseProduct, product^-1);
    centralizer := Centralizer(group, product);
    leftIndex := NewDictionary(classRecord.normalized_pairs[1], true);
    for pairId in [1..Length(classRecord.normalized_pairs)] do
      orbit := Orbit(centralizer, classRecord.normalized_pairs[pairId],
        function(point, element)
          return SimultaneousConjugate(point, element);
        end);
      for member in orbit do
        if LookupDictionary(leftIndex, member) <> fail then
          Error("left pair lookup contains overlapping orbits");
        fi;
        AddDictionary(leftIndex, member, pairId);
      od;
    od;
    pair := SimultaneousConjugate(inverseRecord.normalized_pairs[1], aligner);
    rightIndex := NewDictionary(pair, true);
    for pairId in [1..Length(inverseRecord.normalized_pairs)] do
      pair := SimultaneousConjugate(inverseRecord.normalized_pairs[pairId], aligner);
      orbit := Orbit(centralizer, pair,
        function(point, element)
          return SimultaneousConjugate(point, element);
        end);
      for member in orbit do
        if LookupDictionary(rightIndex, member) <> fail then
          Error("right pair lookup contains overlapping orbits");
        fi;
        AddDictionary(rightIndex, member, pairId);
      od;
    od;
    lookups[classIndex] := rec(
      product := product,
      centralizer := centralizer,
      left_index := leftIndex,
      right_index := rightIndex,
      segment := segmentByClass[classIndex]
    );
  od;
  return rec(
    group := group,
    classes := classes,
    checkpoint := checkpoint,
    lookups := lookups
  );
end;;

M23LocateMacroblock := function(locator, tuple)
  local product, classIndex, lookup, transporter, normalized, leftId,
    rightId, ordinal;
  product := tuple[1] * tuple[2];
  classIndex := PositionProperty(locator.classes, class -> product in class);
  lookup := locator.lookups[classIndex];
  transporter := RepresentativeAction(locator.group, product, lookup.product);
  if transporter = fail then
    Error("could not normalize tuple pair product for macroblock lookup");
  fi;
  normalized := SimultaneousConjugate(tuple, transporter);
  leftId := LookupDictionary(lookup.left_index, normalized{[1, 2]});
  rightId := LookupDictionary(lookup.right_index, normalized{[3, 4]});
  if leftId = fail or rightId = fail then
    Error("tuple factor pair is absent from the pair-orbit checkpoint");
  fi;
  ordinal := lookup.segment.first_ordinal +
    (leftId - 1) * lookup.segment.right_pair_count + rightId - 1;
  return M23DecodeMacroblock(locator.checkpoint, ordinal);
end;;

M23IsExactPairTwistMacroblock := function(locator, block)
  local product, centralizer;
  product := Representative(locator.classes[block.natural_class_index]);
  centralizer := locator.lookups[block.natural_class_index].centralizer;
  return IsCyclic(centralizer) and Size(centralizer) = Order(product);
end;;

M23ExactMacroblockNeighbors := function(locator, block)
  local materialized, neighbors, tuple, generator, image, neighbor;
  if not M23IsExactPairTwistMacroblock(locator, block) then
    Error("macroblock requires a noncyclic or non-generating-twist refinement");
  fi;
  materialized := M23MaterializeMacroblock(locator.group, locator.classes,
    locator.checkpoint, block);
  neighbors := [];
  for tuple in materialized.tuples do
    for generator in [13, 14] do
      image := PureBraidMove4Direct(tuple, generator);
      neighbor := M23LocateMacroblock(locator, image);
      if not neighbor.ordinal in List(neighbors, item -> item.ordinal) then
        Add(neighbors, neighbor);
      fi;
    od;
  od;
  return neighbors;
end;;

M23CanonicalInnerTuple := function(locator, point)
  local targetClass, first, centralizer, transporter, normalized;
  targetClass := First(locator.classes, class ->
    Order(Representative(class)) = locator.checkpoint.target_order);
  first := Representative(targetClass);
  centralizer := Centralizer(locator.group, first);
  transporter := RepresentativeAction(locator.group, point[1], first);
  if transporter = fail then
    Error("inner tuple cannot fix its first coordinate");
  fi;
  normalized := SimultaneousConjugate(point, transporter);
  return Minimum(Orbit(centralizer, normalized,
    function(member, element)
      return SimultaneousConjugate(member, element);
    end));
end;;

M23RefineMacroblockPairTwists := function(locator, block)
  local materialized, canonicalRepresentatives, index, position, tuple,
    image12, image34, permutation12, permutation34, twistOrbits,
    combinedOrbits, twistIdByIndex, twistId, point;
  materialized := M23MaterializeMacroblock(locator.group, locator.classes,
    locator.checkpoint, block);
  canonicalRepresentatives := List(materialized.tuples,
    point -> M23CanonicalInnerTuple(locator, point));
  index := NewDictionary(canonicalRepresentatives[1], true);
  for position in [1..Length(canonicalRepresentatives)] do
    if LookupDictionary(index, canonicalRepresentatives[position]) <> fail then
      Error("macroblock materializer produced duplicate inner classes");
    fi;
    AddDictionary(index, canonicalRepresentatives[position], position);
  od;
  permutation12 := [];
  permutation34 := [];
  for position in [1..Length(materialized.tuples)] do
    tuple := materialized.tuples[position];
    image12 := M23CanonicalInnerTuple(locator,
      PureBraidMove4Direct(tuple, 12));
    image34 := M23CanonicalInnerTuple(locator,
      ApplyHurwitzWord(tuple, [4, 4]));
    permutation12[position] := LookupDictionary(index, image12);
    permutation34[position] := LookupDictionary(index, image34);
    if permutation12[position] = fail or permutation34[position] = fail then
      Error("pair twist left its symbolic macroblock");
    fi;
  od;
  twistOrbits := Orbits(Group(PermList(permutation12)),
    [1..Length(materialized.tuples)]);
  combinedOrbits := Orbits(Group([PermList(permutation12),
    PermList(permutation34)]), [1..Length(materialized.tuples)]);
  if Set(List(twistOrbits, Set)) <> Set(List(combinedOrbits, Set)) then
    Error("beta34 enlarges the beta12 pair-twist blocks");
  fi;
  twistIdByIndex := [];
  for twistId in [1..Length(twistOrbits)] do
    for point in twistOrbits[twistId] do
      twistIdByIndex[point] := twistId;
    od;
  od;
  return rec(
    block := block,
    materialized := materialized,
    inner_index := index,
    canonical_representatives := canonicalRepresentatives,
    twist_orbits := twistOrbits,
    twist_orbit_sizes := List(twistOrbits, Length),
    twist_id_by_index := twistIdByIndex
  );
end;;

M23CachedMacroblockRefinement := function(locator, cache, block)
  local refinement;
  refinement := LookupDictionary(cache, block.ordinal);
  if refinement = fail then
    refinement := M23RefineMacroblockPairTwists(locator, block);
    AddDictionary(cache, block.ordinal, refinement);
  fi;
  return refinement;
end;;

M23LocatePairTwistBlock := function(locator, cache, tuple)
  local block, refinement, canonical, innerIndex, twistId;
  block := M23LocateMacroblock(locator, tuple);
  refinement := M23CachedMacroblockRefinement(locator, cache, block);
  canonical := M23CanonicalInnerTuple(locator, tuple);
  innerIndex := LookupDictionary(refinement.inner_index, canonical);
  if innerIndex = fail then
    Error("tuple is absent from its refined macroblock");
  fi;
  twistId := refinement.twist_id_by_index[innerIndex];
  return rec(
    block := block,
    twist_id := twistId,
    weight := Length(refinement.twist_orbits[twistId])
  );
end;;

M23BuildDirectPairLocator := function(group, classes, checkpoint)
  local segments, segmentByClass, lookups, classIndex, classRecord,
    inverseRecord, product, centralizer, elements, inverseProduct, aligner,
    rightTransport, pairId, basePair, element, member, alignedPair,
    targetClassIndex, target, targetCentralizer, targetElements,
    targetPairTransport, pairFirstTransports, normalizer, fixedSecond,
    firstTransport, fixedPair, known, targetMemberCount;
  segments := M23MacroblockSegments(checkpoint);
  segmentByClass := List(classes, class -> fail);
  for element in segments do
    segmentByClass[element.natural_class_index] := element;
  od;
  targetClassIndex := PositionProperty(classes, class ->
    Order(Representative(class)) = checkpoint.target_order);
  target := Representative(classes[targetClassIndex]);
  targetCentralizer := Centralizer(group, target);
  targetElements := Elements(targetCentralizer);
  targetPairTransport := NewDictionary(target, true);
  pairFirstTransports := List(classes, class -> []);
  targetMemberCount := 0;
  for classIndex in [1..Length(classes)] do
    classRecord := checkpoint.classes[classIndex];
    for pairId in [1..Length(classRecord.normalized_pairs)] do
      basePair := classRecord.normalized_pairs[pairId];
      if IsBound(classRecord.fixed_seconds) and
         IsBound(classRecord.normalizing_transporters) then
        fixedSecond := classRecord.fixed_seconds[pairId];
        normalizer := classRecord.normalizing_transporters[pairId];
        if SimultaneousConjugate([target, fixedSecond], normalizer) <>
           basePair then
          Error("stored fixed-pair normalizer does not reproduce its pair");
        fi;
        firstTransport := normalizer^-1;
      else
        firstTransport := RepresentativeAction(group, basePair[1], target);
        fixedPair := SimultaneousConjugate(basePair, firstTransport);
        fixedSecond := fixedPair[2];
        normalizer := firstTransport^-1;
      fi;
      pairFirstTransports[classIndex][pairId] := firstTransport;
      for element in targetElements do
        member := fixedSecond^element;
        known := LookupDictionary(targetPairTransport, member);
        if known = fail then
          AddDictionary(targetPairTransport, member,
            [classIndex, pairId, element^-1 * normalizer]);
          targetMemberCount := targetMemberCount + 1;
        elif known{[1, 2]} <> [classIndex, pairId] then
          Error("target-pair centralizer orbits overlap");
        fi;
      od;
    od;
  od;
  if targetMemberCount <> Size(classes[targetClassIndex]) then
    Error("target-pair lookup does not cover the target class");
  fi;
  lookups := List(classes, class -> fail);
  for classIndex in [1..Length(classes)] do
    classRecord := checkpoint.classes[classIndex];
    if classRecord.pair_orbit_count = 0 then
      continue;
    fi;
    product := Representative(classes[classIndex]);
    centralizer := Centralizer(group, product);
    if Size(centralizer) = Size(group) then
      continue;
    fi;
    elements := Elements(centralizer);
    inverseRecord := checkpoint.classes[classRecord.inverse_class_index];
    inverseProduct := Representative(classes[classRecord.inverse_class_index]);
    aligner := RepresentativeAction(group, inverseProduct, product^-1);
    alignedPair := SimultaneousConjugate(
      inverseRecord.normalized_pairs[1], aligner);
    rightTransport := NewDictionary(alignedPair, true);
    for pairId in [1..Length(inverseRecord.normalized_pairs)] do
      basePair := SimultaneousConjugate(
        inverseRecord.normalized_pairs[pairId], aligner);
      for element in elements do
        member := SimultaneousConjugate(basePair, element);
        if LookupDictionary(rightTransport, member) = fail then
          AddDictionary(rightTransport, member, [pairId, element]);
        fi;
      od;
    od;
    lookups[classIndex] := rec(
      product := product,
      centralizer := centralizer,
      inverse_aligner := aligner,
      right_transport := rightTransport,
      segment := segmentByClass[classIndex]
    );
  od;
  return rec(
    group := group,
    classes := classes,
    checkpoint := checkpoint,
    target := target,
    target_pair_transport := targetPairTransport,
    pair_first_transports := pairFirstTransports,
    lookups := lookups,
    relative_cache := NewDictionary(1, true),
    identity_cache := NewDictionary(1, true),
    refinement_cache := NewDictionary(1, true),
    traversal_order := "key-v2"
  );
end;;

M23ResetDirectPairBlockCaches := function(locator)
  locator.relative_cache := NewDictionary(1, true);
  locator.refinement_cache := NewDictionary(1, true);
end;;

M23DirectIdentityMap := function(locator, block)
  local cached, materialized, representatives, index, position, result;
  cached := LookupDictionary(locator.identity_cache, block.ordinal);
  if cached <> fail then
    return cached;
  fi;
  materialized := M23MaterializeMacroblock(locator.group, locator.classes,
    locator.checkpoint, block);
  representatives := List(materialized.tuples,
    tuple -> M23CanonicalInnerTuple(locator, tuple));
  index := NewDictionary(representatives[1], true);
  for position in [1..Length(representatives)] do
    if LookupDictionary(index, representatives[position]) <> fail then
      Error("identity macroblock produced duplicate inner classes");
    fi;
    AddDictionary(index, representatives[position], position);
  od;
  result := rec(
    block := block,
    materialized := materialized,
    canonical_representatives := representatives,
    canonical_index := index,
    relative_count := Length(representatives)
  );
  AddDictionary(locator.identity_cache, block.ordinal, result);
  return result;
end;;

M23DirectRelativeMap := function(locator, block)
  local cached, lookup, classRecord, inverseRecord, leftPair, rightPair,
    leftStabilizer, rightStabilizer, doubleCosets, canonicalDoubleCosets,
    canonicalRepresentative, relativeIndex, doubleCoset, member,
    elementToIndex, result;
  cached := LookupDictionary(locator.relative_cache, block.ordinal);
  if cached <> fail then
    return cached;
  fi;
  lookup := locator.lookups[block.natural_class_index];
  if lookup = fail then
    Error("identity-product macroblock requires its dedicated coordinate path");
  fi;
  classRecord := locator.checkpoint.classes[block.natural_class_index];
  inverseRecord := locator.checkpoint.classes[block.inverse_class_index];
  leftPair := classRecord.normalized_pairs[block.left_pair_id];
  rightPair := SimultaneousConjugate(
    inverseRecord.normalized_pairs[block.right_pair_id],
    lookup.inverse_aligner);
  leftStabilizer := Intersection(Centralizer(locator.group, leftPair[1]),
    Centralizer(locator.group, leftPair[2]));
  rightStabilizer := Intersection(Centralizer(locator.group, rightPair[1]),
    Centralizer(locator.group, rightPair[2]));
  doubleCosets := DoubleCosetRepsAndSizes(lookup.centralizer,
    rightStabilizer, leftStabilizer);
  if locator.traversal_order = "key-v2" then
    canonicalDoubleCosets := [];
    for doubleCoset in doubleCosets do
      canonicalRepresentative := fail;
      for member in DoubleCoset(rightStabilizer, doubleCoset[1],
          leftStabilizer) do
        if canonicalRepresentative = fail or
            member < canonicalRepresentative then
          canonicalRepresentative := member;
        fi;
      od;
      Add(canonicalDoubleCosets,
        [canonicalRepresentative, doubleCoset[2]]);
    od;
    Sort(canonicalDoubleCosets, function(left, right)
      return left[1] < right[1];
    end);
    doubleCosets := canonicalDoubleCosets;
  elif not locator.traversal_order in ["legacy", "key-v1"] then
    Error("unsupported direct-pair traversal order");
  fi;
  elementToIndex := NewDictionary(One(lookup.centralizer), true);
  for relativeIndex in [1..Length(doubleCosets)] do
    doubleCoset := DoubleCoset(rightStabilizer,
      doubleCosets[relativeIndex][1], leftStabilizer);
    for member in doubleCoset do
      if LookupDictionary(elementToIndex, member) <> fail then
        Error("relative double cosets overlap");
      fi;
      AddDictionary(elementToIndex, member, relativeIndex);
    od;
  od;
  result := rec(
    block := block,
    double_cosets := doubleCosets,
    element_to_index := elementToIndex,
    relative_count := Length(doubleCosets)
  );
  AddDictionary(locator.relative_cache, block.ordinal, result);
  return result;
end;;

M23DirectRelativeCoordinateWithFirstTransport := function(locator, tuple,
  firstTransport)
  local classIndex, lookup, normalized, fixed, leftData, rightData, segment,
    ordinal, block, relativeMap,
    relativeIndex, identityMap, canonical;
  fixed := SimultaneousConjugate(tuple, firstTransport);
  if fixed[1] <> locator.target then
    Error("direct first-coordinate transporter does not reach the target");
  fi;
  leftData := LookupDictionary(locator.target_pair_transport, fixed[2]);
  if leftData = fail then
    Error("fixed left pair is absent from the target-pair lookup");
  fi;
  classIndex := leftData[1];
  lookup := locator.lookups[classIndex];
  normalized := SimultaneousConjugate(fixed, leftData[3]);
  if normalized{[1, 2]} <>
     locator.checkpoint.classes[classIndex].normalized_pairs[leftData[2]] then
    Error("target-pair transporter did not reproduce its normalized pair");
  fi;
  if lookup = fail then
    if Order(normalized[1] * normalized[2]) <> 1 then
      Error("pair-product class is absent from the direct locator");
    fi;
    segment := First(M23MacroblockSegments(locator.checkpoint), item ->
      item.natural_class_index = classIndex);
    if segment = fail or segment.first_ordinal <> segment.last_ordinal then
      Error("identity pair product does not have one symbolic macroblock");
    fi;
    block := M23DecodeMacroblock(locator.checkpoint,
      segment.first_ordinal);
    identityMap := M23DirectIdentityMap(locator, block);
    canonical := M23CanonicalInnerTuple(locator, normalized);
    relativeIndex := LookupDictionary(identityMap.canonical_index, canonical);
    if relativeIndex = fail then
      Error("identity-product tuple is absent from its direct coordinate map");
    fi;
    return rec(
      block := block,
      relative_index := relativeIndex,
      relative_count := identityMap.relative_count
    );
  fi;
  rightData := LookupDictionary(lookup.right_transport,
    normalized{[3, 4]});
  if rightData = fail then
    Error("right pair is absent from the direct transporter lookup");
  fi;
  segment := lookup.segment;
  ordinal := segment.first_ordinal +
    (leftData[2] - 1) * segment.right_pair_count + rightData[1] - 1;
  block := M23DecodeMacroblock(locator.checkpoint, ordinal);
  relativeMap := M23DirectRelativeMap(locator, block);
  relativeIndex := LookupDictionary(relativeMap.element_to_index, rightData[2]);
  if relativeIndex = fail then
    Error("relative transporter is absent from its double-coset partition");
  fi;
  return rec(
    block := block,
    relative_index := relativeIndex,
    relative_count := relativeMap.relative_count
  );
end;;

M23DirectRelativeCoordinate := function(locator, tuple)
  local firstTransport;
  firstTransport := RepresentativeAction(locator.group, tuple[1],
    locator.target);
  if firstTransport = fail then
    Error("tuple first entry is outside the target class");
  fi;
  return M23DirectRelativeCoordinateWithFirstTransport(locator, tuple,
    firstTransport);
end;;

M23DirectPairTwistRefinement := function(locator, block)
  local materialized, relativeMap, permutation12, permutation34, index,
    tuple, coordinate, coordinate12, coordinate34, twistOrbits,
    combinedOrbits, materializedToRelative, relativeToMaterialized,
    product, identityMap, twistIdByIndex, twistId, point, firstTransport,
    conjugator;
  product := Representative(locator.classes[block.natural_class_index]);
  if Order(product) = 1 then
    identityMap := M23DirectIdentityMap(locator, block);
    twistOrbits := List([1..identityMap.relative_count], point -> [point]);
    return rec(
      block := block,
      materialized := identityMap.materialized,
      relative_map := identityMap,
      materialized_to_relative := [1..identityMap.relative_count],
      relative_to_materialized := [1..identityMap.relative_count],
      twist_orbits := twistOrbits,
      twist_orbit_sizes := List(twistOrbits, Length),
      twist_id_by_index := [1..identityMap.relative_count]
    );
  fi;
  materialized := M23MaterializeMacroblock(locator.group, locator.classes,
    locator.checkpoint, block);
  relativeMap := M23DirectRelativeMap(locator, block);
  if materialized.inner_class_count <> relativeMap.relative_count then
    Error("materialized and direct relative class counts disagree");
  fi;
  permutation12 := [];
  permutation34 := [];
  materializedToRelative := [];
  relativeToMaterialized := [];
  firstTransport :=
    locator.pair_first_transports[block.natural_class_index]
      [block.left_pair_id];
  for index in [1..Length(materialized.tuples)] do
    coordinate := M23DirectRelativeCoordinateWithFirstTransport(locator,
      materialized.tuples[index], firstTransport);
    if coordinate.block.ordinal <> block.ordinal or
       IsBound(relativeToMaterialized[coordinate.relative_index]) then
      Error("direct relative coordinates do not biject the materialized block");
    fi;
    materializedToRelative[index] := coordinate.relative_index;
    relativeToMaterialized[coordinate.relative_index] := index;
  od;
  for index in [1..Length(materialized.tuples)] do
    tuple := materialized.tuples[index];
    conjugator := tuple[3] * tuple[4];
    coordinate12 := M23DirectRelativeCoordinateWithFirstTransport(locator,
      PureBraidMove4Direct(tuple, 12), conjugator^-1 * firstTransport);
    coordinate34 := M23DirectRelativeCoordinateWithFirstTransport(locator,
      ApplyHurwitzWord(tuple, [4, 4]), firstTransport);
    if coordinate12.block.ordinal <> block.ordinal or
       coordinate34.block.ordinal <> block.ordinal then
      Error("direct pair twist left its macroblock");
    fi;
    permutation12[index] := relativeToMaterialized[coordinate12.relative_index];
    permutation34[index] := relativeToMaterialized[coordinate34.relative_index];
  od;
  twistOrbits := Orbits(Group(PermList(permutation12)),
    [1..Length(materialized.tuples)]);
  combinedOrbits := Orbits(Group([PermList(permutation12),
    PermList(permutation34)]), [1..Length(materialized.tuples)]);
  if Set(List(twistOrbits, Set)) <> Set(List(combinedOrbits, Set)) then
    Error("direct beta34 action enlarges beta12 pair-twist blocks");
  fi;
  twistIdByIndex := [];
  for twistId in [1..Length(twistOrbits)] do
    for point in twistOrbits[twistId] do
      twistIdByIndex[point] := twistId;
    od;
  od;
  return rec(
    block := block,
    materialized := materialized,
    relative_map := relativeMap,
    materialized_to_relative := materializedToRelative,
    relative_to_materialized := relativeToMaterialized,
    twist_orbits := twistOrbits,
    twist_orbit_sizes := List(twistOrbits, Length),
    twist_id_by_index := twistIdByIndex
  );
end;;

M23CachedDirectPairTwistRefinement := function(locator, block)
  local refinement;
  refinement := LookupDictionary(locator.refinement_cache, block.ordinal);
  if refinement = fail then
    refinement := M23DirectPairTwistRefinement(locator, block);
    AddDictionary(locator.refinement_cache, block.ordinal, refinement);
  fi;
  return refinement;
end;;

M23DirectPairTwistCoordinate := function(locator, tuple)
  local coordinate, refinement, materializedIndex, twistId;
  coordinate := M23DirectRelativeCoordinate(locator, tuple);
  refinement := M23CachedDirectPairTwistRefinement(locator,
    coordinate.block);
  materializedIndex :=
    refinement.relative_to_materialized[coordinate.relative_index];
  twistId := refinement.twist_id_by_index[materializedIndex];
  return rec(
    block := coordinate.block,
    twist_id := twistId,
    weight := Length(refinement.twist_orbits[twistId])
  );
end;;

M23DirectPairTwistCoordinateWithFirstTransport := function(locator, tuple,
  firstTransport)
  local coordinate, refinement, materializedIndex, twistId;
  coordinate := M23DirectRelativeCoordinateWithFirstTransport(locator, tuple,
    firstTransport);
  refinement := M23CachedDirectPairTwistRefinement(locator,
    coordinate.block);
  materializedIndex :=
    refinement.relative_to_materialized[coordinate.relative_index];
  twistId := refinement.twist_id_by_index[materializedIndex];
  return rec(
    block := coordinate.block,
    twist_id := twistId,
    weight := Length(refinement.twist_orbits[twistId])
  );
end;;

M23DirectPairTwistNeighbors := function(locator, block, twistId)
  local refinement, neighbors, seen, materializedIndex, tuple, generator,
    neighbor, key, firstTransport, conjugator;
  refinement := M23CachedDirectPairTwistRefinement(locator, block);
  if twistId < 1 or twistId > Length(refinement.twist_orbits) then
    Error("pair-twist vertex is outside its macroblock refinement");
  fi;
  neighbors := [];
  seen := NewDictionary([1, 1], true);
  firstTransport :=
    locator.pair_first_transports[block.natural_class_index]
      [block.left_pair_id];
  for materializedIndex in refinement.twist_orbits[twistId] do
    tuple := refinement.materialized.tuples[materializedIndex];
    for generator in [13, 14] do
      if generator = 13 then
        conjugator := tuple[2] * tuple[4];
      else
        conjugator := tuple[2] * tuple[3];
      fi;
      neighbor := M23DirectPairTwistCoordinateWithFirstTransport(locator,
        PureBraidMove4Direct(tuple, generator),
        conjugator^-1 * firstTransport);
      key := [neighbor.block.ordinal, neighbor.twist_id];
      if LookupDictionary(seen, key) = fail then
        AddDictionary(seen, key, true);
        Add(neighbors, neighbor);
      fi;
    od;
  od;
  if locator.traversal_order in ["key-v1", "key-v2"] then
    Sort(neighbors, function(left, right)
      if left.block.ordinal <> right.block.ordinal then
        return left.block.ordinal < right.block.ordinal;
      fi;
      return left.twist_id < right.twist_id;
    end);
  elif locator.traversal_order <> "legacy" then
    Error("unsupported direct-pair traversal order");
  fi;
  return neighbors;
end;;

M23BoundedDirectPairTwistOrbitWithLedger := function(locator, seed, limit,
  progress, externalLookup)
  local firstVertex, vertices, index, classCount, position, vertex,
    neighbor, key, status, linkedCertificate;
  if limit < 1 or not IsProductOneTuple(seed) or
     not IsGeneratingTuple(locator.group, seed) then
    Error("invalid bounded direct quotient request");
  fi;
  firstVertex := M23DirectPairTwistCoordinate(locator, seed);
  vertices := [firstVertex];
  index := NewDictionary([1, 1], true);
  AddDictionary(index,
    [firstVertex.block.ordinal, firstVertex.twist_id], 1);
  classCount := firstVertex.weight;
  position := 1;
  linkedCertificate := fail;
  while position <= Length(vertices) and classCount <= limit and
      linkedCertificate = fail do
    vertex := vertices[position];
    for neighbor in M23DirectPairTwistNeighbors(locator, vertex.block,
        vertex.twist_id) do
      key := [neighbor.block.ordinal, neighbor.twist_id];
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
    closed := status = "closed",
    linked_certificate := linkedCertificate,
    limit := limit,
    checked_vertex_count := position - 1,
    discovered_vertex_count := Length(vertices),
    discovered_class_count := classCount,
    seed := seed,
    vertices := vertices
  );
end;;

M23BoundedDirectPairTwistOrbit := function(locator, seed, limit, progress)
  return M23BoundedDirectPairTwistOrbitWithLedger(locator, seed, limit,
    progress, key -> fail);
end;;
