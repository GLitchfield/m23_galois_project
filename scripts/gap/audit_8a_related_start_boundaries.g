Read("src/gap/nielsen.g");;
SizeScreen([100000, 100000]);;

if not IsBound(GAPInfo.SystemEnvironment.M23_CODE_REVISION) then
  Error("set M23_CODE_REVISION to the generating Git revision");
fi;
if not IsBound(GAPInfo.SystemEnvironment.M23_TARGET_SHA256) then
  Error("set M23_TARGET_SHA256 to the SHA-256 of the target input");
fi;
revision := GAPInfo.SystemEnvironment.M23_CODE_REVISION;;
targetSha256 := GAPInfo.SystemEnvironment.M23_TARGET_SHA256;;
inputPath := "data/derived/m23_8a_8a_2a_inner_classes.tsv";;
if IsBound(GAPInfo.SystemEnvironment.M23_RELATED_START_INPUT) then
  inputPath := GAPInfo.SystemEnvironment.M23_RELATED_START_INPUT;;
fi;
outputPath := "data/derived/m23_8a_related_start_boundaries.tsv";;
if IsBound(GAPInfo.SystemEnvironment.M23_RELATED_START_OUTPUT) then
  outputPath := GAPInfo.SystemEnvironment.M23_RELATED_START_OUTPUT;;
fi;
coveragePath := "data/derived/m23_8a_related_start_target_coverage.tsv";;
if IsBound(GAPInfo.SystemEnvironment.M23_RELATED_START_COVERAGE_OUTPUT) then
  coveragePath := GAPInfo.SystemEnvironment.M23_RELATED_START_COVERAGE_OUTPUT;;
fi;

G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
classNames := List(ClassNames(CharacterTable(G)), UppercaseString);;
classIndices := List(classes, class ->
  23 - Length(Cycles(Representative(class), [1..23])));;

ClassPosition := function(element)
  return PositionProperty(classes, class -> element in class);
end;;

PermutationFromField := function(field)
  return PermList(List(SplitString(field, ","), Int));
end;;

lines := SplitString(StringFile(inputPath), "\n");;
targets := [];;
for line in lines do
  if Length(line) > 0 and line[1] <> '#' and
      not StartsWith(line, "class_id\t") then
    fields := SplitString(line, "\t");
    Add(targets, rec(
      id := Int(fields[1]),
      tuple := [PermutationFromField(fields[2]),
                PermutationFromField(fields[3]),
                PermutationFromField(fields[4])]));
  fi;
od;
Assert(0, Length(targets) = 28);

class2Position := Position(classNames, "2A");;
class3Position := Position(classNames, "3A");;
class2 := classes[class2Position];;
class3 := classes[class3Position];;
records := [];;
totalLifts := 0;;
targetCoverage := List([1..28], id -> rec(
  id := id, factor_count := 0, boundary_4a_count := 0,
  boundary_5a_count := 0, boundary_6a_count := 0));;

AddBoundary := function(pair, triple, targetId)
  local positions, names, genusNumerator, existing;
  positions := List(triple, ClassPosition);
  names := List(positions, position -> classNames[position]);
  genusNumerator := Sum(positions, position -> classIndices[position]) - 44;
  Assert(0, IsEvenInt(genusNumerator));
  existing := First(records, record ->
    record.pair = pair and record.classes = names);
  if existing = fail then
    existing := rec(pair := pair, classes := names,
      riemann_hurwitz_genus := genusNumerator / 2,
      lift_count := 0, generating_count := 0, target_ids := [],
      generating_target_ids := []);
    Add(records, existing);
  fi;
  existing.lift_count := existing.lift_count + 1;
  if Group(triple) = G then
    existing.generating_count := existing.generating_count + 1;
    AddSet(existing.generating_target_ids, targetId);
    if pair = "41" and names[2] = "3A" and names[3] = "8A" then
      if names[1] = "4A" then
        targetCoverage[targetId].boundary_4a_count :=
          targetCoverage[targetId].boundary_4a_count + 1;
      elif names[1] = "5A" then
        targetCoverage[targetId].boundary_5a_count :=
          targetCoverage[targetId].boundary_5a_count + 1;
      elif names[1] = "6A" then
        targetCoverage[targetId].boundary_6a_count :=
          targetCoverage[targetId].boundary_6a_count + 1;
      fi;
    fi;
  fi;
  AddSet(existing.target_ids, targetId);
end;;

for target in targets do
  a := target.tuple[1];;
  b := target.tuple[2];;
  c := target.tuple[3];;
  Assert(0, a * b * c = One(G));
  factorCount := 0;;
  for h in class2 do
    k := h^-1 * a;
    if k in class3 then
      factorCount := factorCount + 1;
      targetCoverage[target.id].factor_count :=
        targetCoverage[target.id].factor_count + 1;
      totalLifts := totalLifts + 1;
      Assert(0, h * k = a);
      Assert(0, h * k * b * c = One(G));
      Assert(0, Group([h, k, b, c]) = G);
      AddBoundary("12", [h*k, b, c], target.id);
      AddBoundary("23", [h, k*b, c], target.id);
      AddBoundary("34", [h, k, b*c], target.id);
      AddBoundary("41", [c*h, k, b], target.id);
    fi;
  od;
  Assert(0, factorCount = 20);
od;
Assert(0, totalLifts = 560);

SortBy(records, record -> [record.pair, record.classes]);
PrintTo(outputPath,
  "# generated_by\tscripts/gap/audit_8a_related_start_boundaries.g\n",
  "# code_revision\t", revision, "\n",
  "# gap_version\t", GAPInfo.Version, "\n",
  "# group_construction\tMathieuGroup(23)\n",
  "# target_source\t", inputPath, "\n",
  "# target_source_sha256\t", targetSha256, "\n",
  "# target_class_vector\t8A,8A,2A\n",
  "# four_point_class_vector\t2A,3A,8A,2A\n",
  "# factorization\tfirst 8A = 2A * 3A\n",
  "# factorizations_per_target\t20\n",
  "# target_count\t28\n",
  "# total_boundary_lifts\t", totalLifts, "\n",
  "# interpretation\tfinite branch-cycle audit; not equations or a solved source fibre\n",
  "merged_pair\tboundary_class_vector\triemann_hurwitz_genus\t",
  "lift_count\tgenerating_count\ttarget_class_coverage\t",
  "generating_target_coverage\n");
for record in records do
  AppendTo(outputPath,
    record.pair, "\t", JoinStringsWithSeparator(record.classes, ","), "\t",
    record.riemann_hurwitz_genus, "\t", record.lift_count, "\t",
    record.generating_count, "\t", Length(record.target_ids), "\t",
    Length(record.generating_target_ids), "\n");
od;

PrintTo(coveragePath,
  "# generated_by\tscripts/gap/audit_8a_related_start_boundaries.g\n",
  "# code_revision\t", revision, "\n",
  "# gap_version\t", GAPInfo.Version, "\n",
  "# group_construction\tMathieuGroup(23)\n",
  "# target_source\t", inputPath, "\n",
  "# target_source_sha256\t", targetSha256, "\n",
  "# interpretation\tgenerating opposite-boundary counts among the 20 class-2A*3A lifts of each target\n",
  "target_class_id\tfactor_count\tgenerating_4A_3A_8A\t",
  "generating_5A_3A_8A\tgenerating_6A_3A_8A\n");
for coverage in targetCoverage do
  AppendTo(coveragePath, coverage.id, "\t", coverage.factor_count, "\t",
    coverage.boundary_4a_count, "\t", coverage.boundary_5a_count, "\t",
    coverage.boundary_6a_count, "\n");
od;

QUIT;
