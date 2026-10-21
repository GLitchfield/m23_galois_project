Read("src/gap/nielsen.g");;
SizeScreen([1000000, 1000000]);;

if not IsBound(GAPInfo.SystemEnvironment.M23_OUTPUT) then
  Error("M23_OUTPUT must name the generated TSV file");
fi;
output := GAPInfo.SystemEnvironment.M23_OUTPUT;;
orders := [4, 5];;
if IsBound(GAPInfo.SystemEnvironment.M23_CLASS_ORDERS) then
  orders := List(SplitString(GAPInfo.SystemEnvironment.M23_CLASS_ORDERS, ","), Int);
fi;

G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
table := CharacterTable("M23");;
tableNames := ClassNames(table);;
tableOrders := OrdersClassRepresentatives(table);;
tableSizes := SizesConjugacyClasses(table);;
inverseTableClasses := InverseClasses(table);;

M23FamilyName := function(order)
  if Length(Filtered(classes, class -> Order(Representative(class)) = order)) = 1 then
    return Concatenation(String(order), "A");
  fi;
  return Concatenation(String(order), "AB");
end;;

M23ShapeString := function(values)
  return JoinStringsWithSeparator(List(Collected(values), item ->
    Concatenation(String(item[1]), "^", String(item[2]))), " ");
end;;

M23RationalString := function(value)
  if DenominatorRat(value) = 1 then
    return String(NumeratorRat(value));
  fi;
  return Concatenation(String(NumeratorRat(value)), "/",
    String(DenominatorRat(value)));
end;;

PrintTo(output,
  "# generated_by\tscripts/gap/generate_homogeneous_pair_block_census.g\n",
  "# gap_version\t", GAPInfo.Version, "\n",
  "# group_order\t", Size(G), "\n",
  "target_class\tproduct_family\tfamily_class_count\tproduct_class_size\tcentralizer_order\tcentralizer_structure\tpair_orbit_count\tpair_stabilizer_shape\tmacroblock_count\ttwist_order\tcyclic_centralizer\ttwist_index\tnormalized_inner_weight\ttotal_pair_orbit_count\ttotal_macroblock_count\ttotal_normalized_inner_weight\n");

M23WriteTargetCensus := function(targetOrder)
  local targetClass, target, targetCentralizer, doubleCosets, pairCounts,
    pairStabilizers, doubleCoset, product, classIndex, inverseNaturalClasses,
    macroblockTotal, targetTableIndex, normalizedTotal, familyRows,
    productOrder, naturalIndices, pairCount, stabilizers, macroblockCount,
    representative, productCentralizer, cyclic, twistIndex, tableIndices,
    normalizedWeight, row;
  targetClass := First(classes, class -> Order(Representative(class)) = targetOrder);
  if targetClass = fail or Length(Filtered(classes, class ->
      Order(Representative(class)) = targetOrder)) <> 1 then
    Error("target order must identify a unique natural-action class");
  fi;
  target := Representative(targetClass);
  targetCentralizer := Centralizer(G, target);
  doubleCosets := DoubleCosetRepsAndSizes(G, targetCentralizer,
    targetCentralizer);
  pairCounts := List(classes, class -> 0);
  pairStabilizers := List(classes, class -> []);
  for doubleCoset in doubleCosets do
    product := target * target^doubleCoset[1];
    classIndex := PositionProperty(classes, class -> product in class);
    if classIndex = fail then
      Error("pair product was not assigned to a conjugacy class");
    fi;
    pairCounts[classIndex] := pairCounts[classIndex] + 1;
    Add(pairStabilizers[classIndex],
      Size(targetCentralizer)^2 / doubleCoset[2]);
  od;

  inverseNaturalClasses := List([1..Length(classes)], index ->
    PositionProperty(classes, class -> Representative(classes[index])^-1 in class));
  macroblockTotal := Sum([1..Length(classes)], index ->
    pairCounts[index] * pairCounts[inverseNaturalClasses[index]]);

  targetTableIndex := Position(tableNames,
    Concatenation(String(targetOrder), "a"));
  normalizedTotal := 0;
  familyRows := [];
  for productOrder in Set(List(classes, class -> Order(Representative(class)))) do
    naturalIndices := Filtered([1..Length(classes)], index ->
      Order(Representative(classes[index])) = productOrder);
    pairCount := Sum(naturalIndices, index -> pairCounts[index]);
    if pairCount = 0 then
      continue;
    fi;
    stabilizers := Concatenation(List(naturalIndices,
      index -> pairStabilizers[index]));
    macroblockCount := Sum(naturalIndices, index ->
      pairCounts[index] * pairCounts[inverseNaturalClasses[index]]);
    representative := Representative(classes[naturalIndices[1]]);
    productCentralizer := Centralizer(G, representative);
    cyclic := IsCyclic(productCentralizer);
    twistIndex := "-";
    if cyclic then
      twistIndex := String(Size(productCentralizer) / productOrder);
    fi;

    tableIndices := Filtered([1..Length(tableNames)], index ->
      tableOrders[index] = productOrder);
    normalizedWeight := Sum(tableIndices, index ->
      tableSizes[index] *
      ClassMultiplicationCoefficient(table, targetTableIndex,
        targetTableIndex, index) *
      ClassMultiplicationCoefficient(table, targetTableIndex,
        targetTableIndex, inverseTableClasses[index]) / Size(G));
    normalizedTotal := normalizedTotal + normalizedWeight;
    Add(familyRows, rec(
      order := productOrder,
      family := M23FamilyName(productOrder),
      class_count := Length(naturalIndices),
      class_size := Size(classes[naturalIndices[1]]),
      centralizer_order := Size(productCentralizer),
      centralizer_structure := StructureDescription(productCentralizer),
      pair_count := pairCount,
      stabilizer_shape := M23ShapeString(stabilizers),
      macroblock_count := macroblockCount,
      cyclic := cyclic,
      twist_index := twistIndex,
      normalized_weight := normalizedWeight
    ));
  od;

  for row in familyRows do
    AppendTo(output,
      targetOrder, "A\t", row.family, "\t", row.class_count, "\t",
      row.class_size, "\t", row.centralizer_order, "\t",
      row.centralizer_structure, "\t",
      row.pair_count, "\t", row.stabilizer_shape, "\t",
      row.macroblock_count, "\t", row.order, "\t", row.cyclic, "\t",
      row.twist_index, "\t", M23RationalString(row.normalized_weight), "\t",
      Length(doubleCosets), "\t", macroblockTotal, "\t",
      M23RationalString(normalizedTotal), "\n");
  od;
end;;

for targetOrder in orders do
  M23WriteTargetCensus(targetOrder);
od;
QUIT;
