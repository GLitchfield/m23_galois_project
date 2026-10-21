Read("src/gap/nielsen.g");;
SizeScreen([1000000, 1000000]);;

targetOrder := Int(GAPInfo.SystemEnvironment.M23_CLASS_ORDER);;
output := GAPInfo.SystemEnvironment.M23_OUTPUT;;
G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
M23NaturalClassIndex := function(element)
  return PositionProperty(classes, class -> element in class);
end;;
targetClass := First(classes, class -> Order(Representative(class)) = targetOrder);;
if targetClass = fail or Length(Filtered(classes, class ->
    Order(Representative(class)) = targetOrder)) <> 1 then
  Error("target order must identify a unique natural-action class");
fi;
target := Representative(targetClass);;
targetCentralizer := Centralizer(G, target);;
doubleCosets := DoubleCosetRepsAndSizes(G, targetCentralizer,
  targetCentralizer);;
classPairs := List(classes, class -> []);;

progressPath := fail;;
if IsBound(GAPInfo.SystemEnvironment.M23_PROGRESS_FILE) then
  progressPath := GAPInfo.SystemEnvironment.M23_PROGRESS_FILE;
  LoadPackage("io");
fi;
M23PairOrbitProgress := function(processed)
  local epoch;
  if progressPath <> fail then
    epoch := IO_gettimeofday().tv_sec;
    AppendTo(progressPath, epoch, "\tgap\tpair_orbits\t", targetOrder,
      "\tprogress\t", processed, "/", Length(doubleCosets), "\n");
  fi;
end;;

processed := 0;;
for doubleCoset in doubleCosets do
  pair := [target, target^doubleCoset[1]];
  product := Product(pair);
  classIndex := M23NaturalClassIndex(product);
  productRepresentative := Representative(classes[classIndex]);
  transporter := RepresentativeAction(G, product, productRepresentative);
  if transporter = fail then
    Error("could not normalize pair product");
  fi;
  normalizedPair := SimultaneousConjugate(pair, transporter);
  Assert(0, Product(normalizedPair) = productRepresentative);
  Add(classPairs[classIndex], rec(
    normalized_pair := normalizedPair,
    fixed_second := pair[2],
    normalizing_transporter := transporter
  ));
  processed := processed + 1;
  if processed mod 1000 = 0 then
    M23PairOrbitProgress(processed);
  fi;
od;
M23PairOrbitProgress(processed);

classRecords := [];;
coverageWeight := 0;;
for classIndex in [1..Length(classes)] do
  Sort(classPairs[classIndex], function(left, right)
    return left.normalized_pair < right.normalized_pair;
  end);
  inverseIndex := PositionProperty(classes, class ->
    Representative(classes[classIndex])^-1 in class);
  stabilizerSizes := [];
  for pairRecord in classPairs[classIndex] do
    pair := pairRecord.normalized_pair;
    stabilizer := Intersection(Centralizer(G, pair[1]),
      Centralizer(G, pair[2]));
    Add(stabilizerSizes, Size(stabilizer));
    coverageWeight := coverageWeight + Size(G) / Size(stabilizer);
  od;
  Add(classRecords, rec(
    natural_class_index := classIndex,
    element_order := Order(Representative(classes[classIndex])),
    class_size := Size(classes[classIndex]),
    inverse_class_index := inverseIndex,
    pair_orbit_count := Length(classPairs[classIndex]),
    stabilizer_sizes := stabilizerSizes,
    normalized_pairs := List(classPairs[classIndex], record ->
      record.normalized_pair),
    fixed_seconds := List(classPairs[classIndex], record ->
      record.fixed_second),
    normalizing_transporters := List(classPairs[classIndex], record ->
      record.normalizing_transporter)
  ));
od;

if coverageWeight <> Size(targetClass)^2 then
  Error("pair-orbit coverage weight does not equal the complete class square");
fi;

checkpoint := rec(
  schema_version := 2,
  gap_version := GAPInfo.Version,
  group_order := Size(G),
  target_order := targetOrder,
  target_class_size := Size(targetClass),
  target_centralizer_order := Size(targetCentralizer),
  pair_orbit_count := Length(doubleCosets),
  pair_orbit_coverage_weight := coverageWeight,
  macroblock_count := Sum(classRecords, record ->
    record.pair_orbit_count *
    classRecords[record.inverse_class_index].pair_orbit_count),
  classes := classRecords
);;
PrintTo(output, "M23_PAIR_BLOCK_CHECKPOINT := ", checkpoint, ";\n");
QUIT;
