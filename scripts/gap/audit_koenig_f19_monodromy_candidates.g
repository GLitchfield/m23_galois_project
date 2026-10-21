Read("src/gap/m23_fixed_first.g");;
SizeScreen([100000, 100000]);;

requiredShapes := ["1^7 2^8", "1^5 3^6", "1^3 5^4"];;
alternating := AlternatingGroup(23);;
rows := [];;

for identifier in [1..6] do
  group := TransitiveGroup(23, identifier);;
  classShapes := Set(List(ConjugacyClasses(group), class ->
    M23CycleShape(Representative(class), 23)));;
  compatible := Length(Intersection(requiredShapes, classShapes)) =
    Length(requiredShapes);;
  containedInAlternating := IsSubgroup(alternating, group);;
  Add(rows, [
    identifier,
    StructureDescription(group),
    Size(group),
    Transitivity(group, [1..23]),
    containedInAlternating,
    compatible
  ]);
od;

Assert(0, Filtered(rows, row -> row[5] and row[6]) =
  [rows[5], rows[6]]);

if not IsBound(GAPInfo.SystemEnvironment.M23_OUTPUT) then
  Error("M23_OUTPUT must name the generated TSV file");
fi;
output := GAPInfo.SystemEnvironment.M23_OUTPUT;;
PrintTo(output,
  "# generated_by\tscripts/gap/audit_koenig_f19_monodromy_candidates.g\n",
  "# code_revision\t", GAPInfo.SystemEnvironment.M23_CODE_REVISION, "\n",
  "# gap_version\t", GAPInfo.Version, "\n",
  "# transgrp_version\t", GAPInfo.PackagesInfo.transgrp[1].Version, "\n",
  "# required_shapes\t1^7 2^8;1^5 3^6;1^3 5^4\n",
  "transitive_id\tstructure\torder\ttransitivity\tcontained_in_A23\tcontains_required_inertia_shapes\n");
for row in rows do
  AppendTo(output,
    "23T", row[1], "\t", row[2], "\t", row[3], "\t", row[4], "\t",
    LowercaseString(String(row[5])), "\t",
    LowercaseString(String(row[6])), "\n");
od;
QUIT;
