Read("src/gap/m23_homogeneous_macroblocks.g");;
LoadPackage("io");;
SizeScreen([1000000, 1000000]);;

for name in ["M23_PAIR_CHECKPOINT", "M23_PAIR_SHA256", "M23_GIT_REVISION",
    "M23_OUTPUT"] do
  if not IsBound(GAPInfo.SystemEnvironment.(name)) then
    Error(name, " must be set for native coordinate export");
  fi;
od;

M23PackUnsignedLittle := function(value, width)
  local bytes, index;
  if value < 0 then Error("cannot pack a negative unsigned integer"); fi;
  bytes := [];
  for index in [1..width] do
    Add(bytes, CharInt(value mod 256));
    value := QuoInt(value, 256);
  od;
  if value <> 0 then Error("unsigned integer exceeds packed width"); fi;
  return bytes;
end;;

M23PackPermutation := permutation ->
  List([1..23], point -> CharInt(point^permutation - 1));;

M23PackFixedString := function(value, width)
  if Length(value) > width then Error("provenance string exceeds field"); fi;
  return Concatenation(value,
    List([1..width - Length(value)], index -> CharInt(0)));
end;;

M23WriteNativeExportProgress := function(targetOrder, phase, count, total)
  local path;
  if IsBound(GAPInfo.SystemEnvironment.M23_PROGRESS_FILE) then
    path := GAPInfo.SystemEnvironment.M23_PROGRESS_FILE;
    AppendTo(path, IO_gettimeofday().tv_sec,
      "\tgap\tnative_coordinate_export\t", targetOrder,
      "A\tprogress\tphase=", phase,
      ",rows=", count, ",total=", total, "\n");
  fi;
end;;

M23_PAIR_BLOCK_CHECKPOINT := fail;;
Read(GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT);
checkpoint := M23_PAIR_BLOCK_CHECKPOINT;;
if checkpoint.schema_version <> 2 then
  Error("native export requires pair checkpoint schema 2");
fi;
pairHash := GAPInfo.SystemEnvironment.M23_PAIR_SHA256;;
gitRevision := GAPInfo.SystemEnvironment.M23_GIT_REVISION;;
if Length(pairHash) <> 64 or Length(gitRevision) <> 40 then
  Error("native export provenance hashes have invalid lengths");
fi;

G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
targetClassIndex := PositionProperty(classes, class ->
  Order(Representative(class)) = checkpoint.target_order);
target := Representative(classes[targetClassIndex]);;
targetCentralizer := Centralizer(G, target);;
targetElements := Elements(targetCentralizer);;
segments := M23MacroblockSegments(checkpoint);;

rightPairRows := 0;;
for classRecord in checkpoint.classes do
  inverseRecord := checkpoint.classes[classRecord.inverse_class_index];
  if classRecord.pair_orbit_count > 0 and classRecord.class_size <> 1 then
    centralizerOrder := checkpoint.group_order / classRecord.class_size;
    for stabilizerOrder in inverseRecord.stabilizer_sizes do
      rightPairRows := rightPairRows + centralizerOrder / stabilizerOrder;
    od;
  fi;
od;

output := IO_File(GAPInfo.SystemEnvironment.M23_OUTPUT, "w", 1048576);;
if output = fail then Error("cannot open native checkpoint output"); fi;
IO_Write(output, "M23COORD",
  M23PackUnsignedLittle(1, 4),
  M23PackUnsignedLittle(16909060, 4),
  M23PackUnsignedLittle(23, 4),
  M23PackUnsignedLittle(checkpoint.target_order, 4),
  M23PackUnsignedLittle(checkpoint.target_class_size, 8),
  M23PackUnsignedLittle(checkpoint.target_class_size, 8),
  M23PackUnsignedLittle(rightPairRows, 8),
  M23PackUnsignedLittle(Length(segments), 8),
  M23PackUnsignedLittle(0, 8),
  M23PackUnsignedLittle(0, 8),
  M23PackPermutation(target),
  M23PackFixedString(pairHash, 64),
  M23PackFixedString(gitRevision, 40),
  M23PackFixedString(checkpoint.gap_version, 16));

seenTarget := NewDictionary(target, true);;
targetRows := 0;;
for classIndex in [1..Length(classes)] do
  classRecord := checkpoint.classes[classIndex];
  for pairId in [1..Length(classRecord.normalized_pairs)] do
    basePair := classRecord.normalized_pairs[pairId];
    fixedSecond := classRecord.fixed_seconds[pairId];
    normalizer := classRecord.normalizing_transporters[pairId];
    if SimultaneousConjugate([target, fixedSecond], normalizer) <> basePair then
      Error("stored target-pair normalizer is inconsistent");
    fi;
    for element in targetElements do
      member := fixedSecond^element;
      if LookupDictionary(seenTarget, member) = fail then
        AddDictionary(seenTarget, member, true);
        IO_Write(output,
          M23PackPermutation(member),
          M23PackUnsignedLittle(classIndex, 4),
          M23PackUnsignedLittle(pairId, 4),
          M23PackPermutation(element^-1 * normalizer),
          M23PackPermutation(basePair[1]),
          M23PackPermutation(basePair[2]));
        targetRows := targetRows + 1;
        if targetRows mod 10000 = 0 then
          M23WriteNativeExportProgress(checkpoint.target_order, "target", targetRows,
            checkpoint.target_class_size);
        fi;
      fi;
    od;
  od;
od;
if targetRows <> checkpoint.target_class_size then
  Error("target-pair export count disagrees with checkpoint");
fi;

writtenRightRows := 0;;
for classIndex in [1..Length(classes)] do
  classRecord := checkpoint.classes[classIndex];
  if classRecord.pair_orbit_count = 0 or classRecord.class_size = 1 then
    continue;
  fi;
  product := Representative(classes[classIndex]);
  centralizer := Centralizer(G, product);
  elements := Elements(centralizer);
  inverseRecord := checkpoint.classes[classRecord.inverse_class_index];
  inverseProduct := Representative(classes[classRecord.inverse_class_index]);
  aligner := RepresentativeAction(G, inverseProduct, product^-1);
  seenRight := NewDictionary(
    SimultaneousConjugate(inverseRecord.normalized_pairs[1], aligner), true);
  for pairId in [1..Length(inverseRecord.normalized_pairs)] do
    basePair := SimultaneousConjugate(
      inverseRecord.normalized_pairs[pairId], aligner);
    for element in elements do
      member := SimultaneousConjugate(basePair, element);
      if LookupDictionary(seenRight, member) = fail then
        AddDictionary(seenRight, member, true);
        IO_Write(output,
          M23PackUnsignedLittle(classIndex, 4),
          M23PackPermutation(member[1]),
          M23PackPermutation(member[2]),
          M23PackUnsignedLittle(pairId, 4),
          M23PackPermutation(element));
        writtenRightRows := writtenRightRows + 1;
        if writtenRightRows mod 10000 = 0 then
          M23WriteNativeExportProgress(checkpoint.target_order, "right", writtenRightRows,
            rightPairRows);
        fi;
      fi;
    od;
  od;
od;
if writtenRightRows <> rightPairRows then
  Error("right-pair export count disagrees with census");
fi;

for segment in segments do
  IO_Write(output,
    M23PackUnsignedLittle(segment.natural_class_index, 4),
    M23PackUnsignedLittle(segment.first_ordinal, 8),
    M23PackUnsignedLittle(segment.right_pair_count, 4));
od;
if IO_Close(output) <> true then Error("native checkpoint close failed"); fi;
M23WriteNativeExportProgress(checkpoint.target_order, "done",
  targetRows + writtenRightRows,
  targetRows + rightPairRows);
Print("exported native coordinate checkpoint: target_rows=", targetRows,
  " right_rows=", writtenRightRows, " segments=", Length(segments), "\n");
QUIT;
