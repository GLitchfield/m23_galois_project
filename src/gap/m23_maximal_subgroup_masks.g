Read("src/gap/nielsen.g");;

M23OrderElementCount := function(group, targetOrder)
  return Sum(Filtered(ConjugacyClasses(group), class ->
    Order(Representative(class)) = targetOrder), Size);
end;;

# Return all maximal-subgroup conjugates containing one fixed target element.
# The double-counting identity
#
#   |H^G containing t| = [G:N_G(H)] * |t^G intersect H| / |t^G|
#
# is checked independently against explicit subgroup containment.
M23BuildFixedTargetMaximalSubgroups := function(group, targetClass, target)
  local representatives, rows, subgroups, representativeIndex,
    representative, subgroupClass, conjugates, orderCount, predicted,
    firstBit, lastBit, subgroup, known;
  if not target in targetClass then
    Error("fixed target is outside its declared conjugacy class");
  fi;
  representatives := MaximalSubgroupClassReps(group);
  rows := [];
  subgroups := [];
  for representativeIndex in [1..Length(representatives)] do
    representative := representatives[representativeIndex];
    subgroupClass := ConjugacyClassSubgroups(group, representative);
    orderCount := M23OrderElementCount(representative, Order(target));
    predicted := Size(subgroupClass) * orderCount / Size(targetClass);
    if not IsInt(predicted) then
      Error("maximal-subgroup incidence count is not integral");
    fi;
    conjugates := Filtered(AsList(subgroupClass), subgroup ->
      target in subgroup);
    if Length(conjugates) <> predicted then
      Error("explicit and double-counted maximal-subgroup incidences disagree");
    fi;
    if Length(conjugates) = 0 then
      firstBit := 0;
    else
      firstBit := Length(subgroups) + 1;
    fi;
    for subgroup in conjugates do
      if Size(subgroup) = Size(group) or not target in subgroup then
        Error("invalid fixed-target maximal subgroup");
      fi;
      known := First(subgroups, item -> item = subgroup);
      if known <> fail then
        Error("fixed-target maximal subgroup was enumerated twice");
      fi;
      Add(subgroups, subgroup);
    od;
    if Length(conjugates) = 0 then
      lastBit := 0;
    else
      lastBit := Length(subgroups);
    fi;
    Add(rows, rec(
      maximal_class := representativeIndex,
      subgroup_order := Size(representative),
      conjugacy_class_size := Size(subgroupClass),
      order_element_count := orderCount,
      predicted_target_incidence := predicted,
      enumerated_target_incidence := Length(conjugates),
      first_bit := firstBit,
      last_bit := lastBit
    ));
  od;
  return rec(
    group := group,
    target_class := targetClass,
    target := target,
    rows := rows,
    subgroups := subgroups
  );
end;;

M23FixedTargetIncidenceMask := function(incidence, element)
  local mask, bit;
  mask := 0;
  for bit in [1..Length(incidence.subgroups)] do
    if element in incidence.subgroups[bit] then
      mask := mask + 2 ^ (bit - 1);
    fi;
  od;
  return mask;
end;;

M23FixedTargetMaskGenerates := function(incidence, tuple)
  return not ForAny(incidence.subgroups, subgroup ->
    ForAll(tuple, element -> element in subgroup));
end;;
