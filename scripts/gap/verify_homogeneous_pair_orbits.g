Read("src/gap/nielsen.g");;
SizeScreen([1000000, 1000000]);;

path := GAPInfo.SystemEnvironment.M23_CHECKPOINT;;
M23_PAIR_BLOCK_CHECKPOINT := fail;;
Read(path);
checkpoint := M23_PAIR_BLOCK_CHECKPOINT;;
if checkpoint = fail or not checkpoint.schema_version in [1, 2] then
  Error("invalid pair-block checkpoint");
fi;

G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
targetClass := First(classes, class ->
  Order(Representative(class)) = checkpoint.target_order);;
Assert(0, checkpoint.gap_version = GAPInfo.Version);
Assert(0, checkpoint.group_order = Size(G));
Assert(0, checkpoint.target_class_size = Size(targetClass));
Assert(0, checkpoint.target_centralizer_order =
  Size(Centralizer(G, Representative(targetClass))));
Assert(0, Length(checkpoint.classes) = Length(classes));

progressPath := fail;;
if IsBound(GAPInfo.SystemEnvironment.M23_PROGRESS_FILE) then
  progressPath := GAPInfo.SystemEnvironment.M23_PROGRESS_FILE;
  LoadPackage("io");
fi;
M23PairVerificationProgress := function(processed)
  local epoch;
  if progressPath <> fail then
    epoch := IO_gettimeofday().tv_sec;
    AppendTo(progressPath, epoch, "\tgap\tverify_pair_orbits\t",
      checkpoint.target_order, "\tprogress\t", processed, "/",
      checkpoint.pair_orbit_count, "\n");
  fi;
end;;

pairCount := 0;;
coverageWeight := 0;;
for record in checkpoint.classes do
  classIndex := record.natural_class_index;
  Assert(0, record.element_order = Order(Representative(classes[classIndex])));
  Assert(0, record.class_size = Size(classes[classIndex]));
  Assert(0, Representative(classes[classIndex])^-1 in
    classes[record.inverse_class_index]);
  Assert(0, record.pair_orbit_count = Length(record.normalized_pairs));
  Assert(0, Length(record.stabilizer_sizes) = Length(record.normalized_pairs));
  if checkpoint.schema_version = 2 then
    Assert(0, Length(record.fixed_seconds) = Length(record.normalized_pairs));
    Assert(0, Length(record.normalizing_transporters) =
      Length(record.normalized_pairs));
    for pairId in [1..Length(record.normalized_pairs)] do
      Assert(0, record.fixed_seconds[pairId] in targetClass);
      Assert(0, SimultaneousConjugate(
        [Representative(targetClass), record.fixed_seconds[pairId]],
        record.normalizing_transporters[pairId]) =
        record.normalized_pairs[pairId]);
    od;
  fi;
  productCentralizer := Centralizer(G, Representative(classes[classIndex]));
  if Length(record.normalized_pairs) > 0 then
    seenPairs := NewDictionary(record.normalized_pairs[1], true);
  fi;
  for index in [1..Length(record.normalized_pairs)] do
    pair := record.normalized_pairs[index];
    Assert(0, pair[1] in targetClass and pair[2] in targetClass);
    Assert(0, Product(pair) = Representative(classes[classIndex]));
    stabilizer := Intersection(Centralizer(G, pair[1]),
      Centralizer(G, pair[2]));
    Assert(0, Size(stabilizer) = record.stabilizer_sizes[index]);
    pairOrbit := Orbit(productCentralizer, pair,
      function(point, element)
        return SimultaneousConjugate(point, element);
      end);
    Assert(0, Length(pairOrbit) = Size(productCentralizer) / Size(stabilizer));
    for member in pairOrbit do
      if LookupDictionary(seenPairs, member) <> fail then
        Error("duplicate product-centralizer orbit of normalized pairs");
      fi;
      AddDictionary(seenPairs, member, true);
    od;
    pairCount := pairCount + 1;
    coverageWeight := coverageWeight + Size(G) / Size(stabilizer);
    if pairCount mod 1000 = 0 then
      M23PairVerificationProgress(pairCount);
    fi;
  od;
od;
M23PairVerificationProgress(pairCount);

Assert(0, pairCount = checkpoint.pair_orbit_count);
Assert(0, coverageWeight = checkpoint.pair_orbit_coverage_weight);
Assert(0, coverageWeight = Size(targetClass)^2);
Assert(0, checkpoint.macroblock_count = Sum(checkpoint.classes, record ->
  record.pair_orbit_count *
  checkpoint.classes[record.inverse_class_index].pair_orbit_count));
Print("verified ", pairCount, " pair orbits and ",
  checkpoint.macroblock_count, " symbolic macroblocks\n");
QUIT;
