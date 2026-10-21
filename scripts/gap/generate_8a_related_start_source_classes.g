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
sourceOutput := "data/derived/m23_4a_3a_8a_inner_classes.tsv";;
linkOutput := "data/derived/m23_8a_related_start_links.tsv";;
if IsBound(GAPInfo.SystemEnvironment.M23_RELATED_START_INPUT) then
  inputPath := GAPInfo.SystemEnvironment.M23_RELATED_START_INPUT;;
fi;
if IsBound(GAPInfo.SystemEnvironment.M23_RELATED_SOURCE_OUTPUT) then
  sourceOutput := GAPInfo.SystemEnvironment.M23_RELATED_SOURCE_OUTPUT;;
fi;
if IsBound(GAPInfo.SystemEnvironment.M23_RELATED_LINK_OUTPUT) then
  linkOutput := GAPInfo.SystemEnvironment.M23_RELATED_LINK_OUTPUT;;
fi;

G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
classNames := List(ClassNames(CharacterTable(G)), UppercaseString);;
Class := name -> classes[Position(classNames, name)];;
class2 := Class("2A");;
class3 := Class("3A");;
class4 := Class("4A");;
class8 := Class("8A");;
fixed8 := Representative(class8);;
centralizer8 := Centralizer(G, fixed8);;

PermutationFromField := function(field)
  return PermList(List(SplitString(field, ","), Int));
end;;
PermutationImagesString := function(permutation)
  return JoinStringsWithSeparator(
    List([1..23], point -> String(point^permutation)), ",");
end;;
CanonicalSource := function(tuple)
  local transporter, normalized, images;
  transporter := RepresentativeAction(G, tuple[3], fixed8);
  Assert(0, transporter <> fail);
  normalized := SimultaneousConjugate(tuple, transporter);
  images := List(Elements(centralizer8), element ->
    SimultaneousConjugate(normalized, element));
  return Minimum(images);
end;;

lines := SplitString(StringFile(inputPath), "\n");;
targets := [];;
for line in lines do
  if Length(line) > 0 and line[1] <> '#' and
      not StartsWith(line, "class_id\t") then
    fields := SplitString(line, "\t");
    Add(targets, rec(id := Int(fields[1]), tuple := [
      PermutationFromField(fields[2]), PermutationFromField(fields[3]),
      PermutationFromField(fields[4])]));
  fi;
od;
Assert(0, Length(targets) = 28);

fixedSourceTuples := [];;
for middle in class3 do
  first := (middle * fixed8)^-1;
  if first in class4 then
    Add(fixedSourceTuples, [first, middle, fixed8]);
  fi;
od;
Assert(0, Length(fixedSourceTuples) = 1764);
sourceOrbits := OrbitsDomain(centralizer8, fixedSourceTuples,
  function(tuple, element)
    return SimultaneousConjugate(tuple, element);
  end);;
generatingSourceOrbits := Filtered(sourceOrbits,
  orbit -> Group(orbit[1]) = G);;
sourceRepresentatives := List(generatingSourceOrbits,
  orbit -> Minimum(orbit));;
Sort(sourceRepresentatives);
Assert(0, Length(sourceOrbits) = 227);
Assert(0, Length(sourceRepresentatives) = 54);
Assert(0, Length(Set(sourceRepresentatives)) = 54);
sourceStats := List([1..54], id -> rec(
  id := id, link_count := 0, target_ids := [], class22_count := 0));;
links := [];;

for target in targets do
  a := target.tuple[1];;
  b := target.tuple[2];;
  c := target.tuple[3];;
  factorIndex := 0;;
  for h in class2 do
    k := h^-1 * a;
    if k in class3 then
      factorIndex := factorIndex + 1;
      boundary := [c*h, k, b];
      if boundary[1] in class4 and Group(boundary) = G then
        canonical := CanonicalSource(boundary);
        sourceId := Position(sourceRepresentatives, canonical);
        Assert(0, sourceId <> fail);
        sourceStats[sourceId].link_count :=
          sourceStats[sourceId].link_count + 1;
        AddSet(sourceStats[sourceId].target_ids, target.id);
        if target.id = 22 then
          sourceStats[sourceId].class22_count :=
            sourceStats[sourceId].class22_count + 1;
        fi;
        Add(links, rec(target_id := target.id, source_id := sourceId,
          factor_index := factorIndex, four_tuple := [h, k, b, c],
          source_tuple := boundary, canonical_source_tuple := canonical));
      fi;
    fi;
  od;
  Assert(0, factorIndex = 20);
od;
SortBy(links, link -> [link.target_id, link.factor_index, link.source_id]);
Assert(0, Length(links) = 88);
Assert(0, Length(Set(List(links, link -> link.target_id))) = 26);
Assert(0, Number(links, link -> link.target_id = 22) = 3);

PrintTo(sourceOutput,
  "# generated_by\tscripts/gap/generate_8a_related_start_source_classes.g\n",
  "# code_revision\t", revision, "\n",
  "# gap_version\t", GAPInfo.Version, "\n",
  "# group_construction\tMathieuGroup(23)\n",
  "# target_source\t", inputPath, "\n",
  "# target_source_sha256\t", targetSha256, "\n",
  "# class_vector\t4A,3A,8A\n",
  "# fixed_third_tuple_count\t1764\n",
  "# inner_class_count\t227\n",
  "# generating_inner_class_count\t54\n",
  "# id_convention\tlexicographic canonical degree-23 representatives with third entry fixed\n",
  "source_class_id\tfirst_images\tsecond_images\tthird_images\t",
  "boundary_link_count\ttarget_class_coverage\tclass22_link_count\n");
for sourceId in [1..54] do
  tuple := sourceRepresentatives[sourceId];
  stats := sourceStats[sourceId];
  AppendTo(sourceOutput, sourceId, "\t",
    PermutationImagesString(tuple[1]), "\t",
    PermutationImagesString(tuple[2]), "\t",
    PermutationImagesString(tuple[3]), "\t",
    stats.link_count, "\t", Length(stats.target_ids), "\t",
    stats.class22_count, "\n");
od;

PrintTo(linkOutput,
  "# generated_by\tscripts/gap/generate_8a_related_start_source_classes.g\n",
  "# code_revision\t", revision, "\n",
  "# gap_version\t", GAPInfo.Version, "\n",
  "# group_construction\tMathieuGroup(23)\n",
  "# target_source\t", inputPath, "\n",
  "# target_source_sha256\t", targetSha256, "\n",
  "# four_point_class_vector\t2A,3A,8A,2A\n",
  "# target_boundary\tmerge entries 1,2 to obtain 8A,8A,2A\n",
  "# source_boundary\tcyclically merge entries 4,1 to obtain 4A,3A,8A\n",
  "# interpretation\texact branch-cycle correspondence; not equations or a solved source fibre\n",
  "target_class_id\tsource_class_id\tfactor_index\t",
  "h_2A_images\tk_3A_images\tb_8A_images\tc_2A_images\t",
  "source_4A_images\tsource_3A_images\tsource_8A_images\t",
  "canonical_source_4A_images\tcanonical_source_3A_images\t",
  "canonical_source_8A_images\n");
for link in links do
  AppendTo(linkOutput, link.target_id, "\t", link.source_id, "\t",
    link.factor_index, "\t",
    JoinStringsWithSeparator(List(link.four_tuple,
      PermutationImagesString), "\t"), "\t",
    JoinStringsWithSeparator(List(link.source_tuple,
      PermutationImagesString), "\t"), "\t",
    JoinStringsWithSeparator(List(link.canonical_source_tuple,
      PermutationImagesString), "\t"), "\n");
od;

QUIT;
