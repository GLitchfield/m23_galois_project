Read("src/gap/m23_fixed_first.g");;
M23_SHARD_CHECKPOINT := fail;;

M23HasExactOrder := function(element, order, identity)
  local prime;
  if element^order <> identity then
    return false;
  fi;
  for prime in Set(FactorsInt(order)) do
    if element^(order / prime) = identity then
      return false;
    fi;
  od;
  return true;
end;;

M23BalancedOrbitAssignments := function(orbits, shardCount)
  local orbitIds, weights, assignments, orbitId, shardIndex;
  orbitIds := [1..Length(orbits)];
  Sort(orbitIds, function(left, right)
    if Length(orbits[left]) = Length(orbits[right]) then
      return left < right;
    fi;
    return Length(orbits[left]) > Length(orbits[right]);
  end);
  weights := List([1..shardCount], index -> 0);
  assignments := List([1..shardCount], index -> []);
  for orbitId in orbitIds do
    shardIndex := Position(weights, Minimum(weights));
    Add(assignments[shardIndex], orbitId);
    weights[shardIndex] := weights[shardIndex] + Length(orbits[orbitId]);
  od;
  for orbitIds in assignments do
    Sort(orbitIds);
  od;
  return rec(orbit_ids := assignments, third_counts := weights);
end;;

M23CC2A2AContext := function(classOrder, shardCount)
  local group, classes, involutionClass, targetClass, first, centralizer,
    involutions, thirdOrbits;
  group := MathieuGroup(23);
  classes := ConjugacyClasses(group);
  involutionClass := First(classes, class ->
    Order(Representative(class)) = 2);
  targetClass := First(classes, class ->
    Order(Representative(class)) = classOrder);
  if targetClass = fail then
    Error("M23 has no conjugacy class of order ", classOrder);
  fi;
  if Length(Filtered(classes, class ->
      Order(Representative(class)) = classOrder)) <> 1 then
    Error("the sharded C,C,2A,2A engine requires a unique class of order ",
      classOrder);
  fi;
  first := Representative(targetClass);
  centralizer := Centralizer(group, first);
  involutions := AsList(involutionClass);
  thirdOrbits := OrbitsDomain(centralizer, involutions,
    function(element, conjugator)
      return element^conjugator;
    end);
  return rec(
    group := group,
    classes := classes,
    involution_class := involutionClass,
    target_class := targetClass,
    first := first,
    centralizer := centralizer,
    involutions := involutions,
    third_orbits := thirdOrbits,
    assignments := M23BalancedOrbitAssignments(thirdOrbits, shardCount)
  );
end;;

M23ReadShardCheckpoints := function(paths)
  local checkpoints, path;
  checkpoints := [];
  for path in paths do
    M23_SHARD_CHECKPOINT := fail;
    Read(path);
    if M23_SHARD_CHECKPOINT = fail then
      Error("checkpoint did not bind M23_SHARD_CHECKPOINT: ", path);
    fi;
    Add(checkpoints, M23_SHARD_CHECKPOINT);
  od;
  return checkpoints;
end;;

M23ValidateShardCoverage := function(context, checkpoints, classOrder, shardCount)
  local indices, assigned, checkpoint, expected;
  if Length(checkpoints) <> shardCount then
    Error("expected ", shardCount, " checkpoints, got ", Length(checkpoints));
  fi;
  indices := List(checkpoints, checkpoint -> checkpoint.shard_index);
  if Set(indices) <> [1..shardCount] then
    Error("checkpoint shard indices are incomplete or duplicated: ", indices);
  fi;
  assigned := [];
  for checkpoint in checkpoints do
    if checkpoint.schema_version <> 1 or
       checkpoint.gap_version <> GAPInfo.Version or
       checkpoint.group_order <> Size(context.group) or
       checkpoint.class_order <> classOrder or
       checkpoint.shard_count <> shardCount or
       checkpoint.centralizer_orbit_count <> Length(context.third_orbits) then
      Error("checkpoint configuration mismatch at shard ",
        checkpoint.shard_index);
    fi;
    expected := context.assignments.orbit_ids[checkpoint.shard_index];
    if checkpoint.assigned_orbit_ids <> expected then
      Error("checkpoint assignment mismatch at shard ",
        checkpoint.shard_index);
    fi;
    if checkpoint.assigned_third_count <>
       context.assignments.third_counts[checkpoint.shard_index] or
       checkpoint.generating_inner_class_count <>
       Length(checkpoint.representatives) or
       checkpoint.product_inner_class_count <
       checkpoint.generating_inner_class_count then
      Error("checkpoint count mismatch at shard ", checkpoint.shard_index);
    fi;
    Append(assigned, checkpoint.assigned_orbit_ids);
  od;
  if Set(assigned) <> [1..Length(context.third_orbits)] or
     Length(assigned) <> Length(context.third_orbits) then
    Error("checkpoint assignments are not an exact orbit partition");
  fi;
end;;
