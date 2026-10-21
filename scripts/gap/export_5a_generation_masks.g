Read("src/gap/m23_homogeneous_macroblocks.g");;
Read("src/gap/m23_maximal_subgroup_masks.g");;
LoadPackage("io");;
SizeScreen([1000000, 1000000]);;

for name in ["M23_PAIR_CHECKPOINT", "M23_PAIR_SHA256", "M23_GIT_REVISION",
    "M23_OUTPUT"] do
  if not IsBound(GAPInfo.SystemEnvironment.(name)) then
    Error(name, " must be set for the 5A mask export");
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

M23WriteMaskProgress := function(count, total)
  local path;
  if IsBound(GAPInfo.SystemEnvironment.M23_PROGRESS_FILE) then
    path := GAPInfo.SystemEnvironment.M23_PROGRESS_FILE;
    AppendTo(path, IO_gettimeofday().tv_sec,
      "\tgap\tnative_5a_generation_masks\t5A\tprogress\trows=", count,
      ",total=", total, "\n");
  fi;
end;;

M23UpdateRowFingerprint := function(fingerprint, permutation)
  local point;
  for point in [1..23] do
    fingerprint :=
      (fingerprint * 1099511628211 + point^permutation) mod 2 ^ 64;
  od;
  return fingerprint;
end;;

M23_PAIR_BLOCK_CHECKPOINT := fail;;
Read(GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT);
checkpoint := M23_PAIR_BLOCK_CHECKPOINT;;
if checkpoint.schema_version <> 2 or checkpoint.target_order <> 5 then
  Error("5A mask export requires a schema-v2 5A pair checkpoint");
fi;
pairHash := GAPInfo.SystemEnvironment.M23_PAIR_SHA256;;
gitRevision := GAPInfo.SystemEnvironment.M23_GIT_REVISION;;
if Length(pairHash) <> 64 or Length(gitRevision) <> 40 then
  Error("5A mask export provenance hashes have invalid lengths");
fi;

G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
classNames := AtlasClassNames(CharacterTable(G));;
targetClassIndex := Position(classNames, "5A");;
targetClass := classes[targetClassIndex];;
target := Representative(targetClass);;
if Size(targetClass) <> checkpoint.target_class_size then
  Error("5A mask export class size disagrees with pair checkpoint");
fi;
incidence := M23BuildFixedTargetMaximalSubgroups(G, targetClass, target);;
maskBits := Length(incidence.subgroups);;
if maskBits <> 14 then
  Error("5A mask export expected exactly 14 incidence bits");
fi;

output := IO_File(GAPInfo.SystemEnvironment.M23_OUTPUT, "w", 1048576);;
if output = fail then Error("cannot open 5A mask checkpoint output"); fi;
IO_Write(output, "M235AMSK",
  M23PackUnsignedLittle(1, 4),
  M23PackUnsignedLittle(16909060, 4),
  M23PackUnsignedLittle(23, 4),
  M23PackUnsignedLittle(maskBits, 4),
  M23PackUnsignedLittle(checkpoint.target_class_size, 8),
  M23PackPermutation(target),
  M23PackFixedString(pairHash, 64),
  M23PackFixedString(gitRevision, 40),
  M23PackFixedString(checkpoint.gap_version, 16));

targetElements := Elements(Centralizer(G, target));;
seenTarget := NewDictionary(target, true);;
rows := 0;;
nonzeroRows := 0;;
rowFingerprint := 14695981039346656037;;
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
        mask := M23FixedTargetIncidenceMask(incidence, member);
        if mask < 0 or mask >= 2 ^ maskBits then
          Error("5A incidence mask exceeds its declared bit width");
        fi;
        IO_Write(output, M23PackUnsignedLittle(mask, 2));
        rowFingerprint := M23UpdateRowFingerprint(rowFingerprint, member);
        rows := rows + 1;
        if mask <> 0 then nonzeroRows := nonzeroRows + 1; fi;
        if rows mod 10000 = 0 then
          M23WriteMaskProgress(rows, checkpoint.target_class_size);
        fi;
      fi;
    od;
  od;
od;
if rows <> checkpoint.target_class_size then
  Error("5A mask row count disagrees with pair checkpoint");
fi;
IO_Write(output, M23PackUnsignedLittle(rowFingerprint, 8));
if IO_Close(output) <> true then Error("5A mask checkpoint close failed"); fi;
M23WriteMaskProgress(rows, rows);
Print("exported native 5A generation masks: rows=", rows,
  " nonzero=", nonzeroRows, " bits=", maskBits, "\n");
QUIT;
