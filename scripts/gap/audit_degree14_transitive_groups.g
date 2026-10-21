if LoadPackage("transgrp") <> true then
  Error("the GAP transgrp package is required");
fi;

if not IsBound(GAPInfo.SystemEnvironment.M23_GROUP_AUDIT_OUTPUT) then
  Error("set M23_GROUP_AUDIT_OUTPUT");
fi;
if not IsBound(GAPInfo.SystemEnvironment.M23_CODE_REVISION) then
  Error("set M23_CODE_REVISION");
fi;

outputPath := GAPInfo.SystemEnvironment.M23_GROUP_AUDIT_OUTPUT;;
codeRevision := GAPInfo.SystemEnvironment.M23_CODE_REVISION;;
degree := 14;;
requiredShapes := [[14], [13, 1], [11, 2, 1]];;

CycleShape := function(permutation)
  local lengths;
  lengths := ShallowCopy(CycleLengths(permutation, [1 .. degree]));
  Sort(lengths, function(left, right) return left > right; end);
  return lengths;
end;;

HasShape := function(classes, shape)
  return ForAny(
    classes,
    class -> CycleShape(Representative(class)) = shape
  );
end;;

BoolText := function(value)
  if value then
    return "true";
  fi;
  return "false";
end;;

if NrTransitiveGroups(degree) <> 63 then
  Error("unexpected number of transitive degree-14 groups");
fi;

PrintTo(
  outputPath,
  "# format\tm23_degree14_transitive_group_audit_v1\n",
  "# code_revision\t", codeRevision, "\n",
  "# gap_version\t", GAPInfo.Version, "\n",
  "# transgrp_version\t", PackageInfo("transgrp")[1].Version, "\n",
  "# degree\t14\n",
  "# transitive_group_count\t63\n",
  "# required_cycle_shapes\t14;13,1;11,2,1\n",
  "# method\texhaustive conjugacy-class audit of GAP TransitiveGroup(14,i)\n",
  "# interpretation\tgroups compatible with all exact Frobenius cycle types\n",
  "transitive_group_id\torder\tstructure\thas_14\thas_13_1\thas_11_2_1\tsurvives\n"
);

survivors := [];;
for id in [1 .. 63] do
  group := TransitiveGroup(degree, id);;
  classes := ConjugacyClasses(group);;
  flags := [];;
  for shape in requiredShapes do
    Add(flags, HasShape(classes, shape));
  od;
  survives := ForAll(flags, flag -> flag);;
  if survives then
    Add(survivors, id);
    structure := StructureDescription(group);
  else
    structure := "-";
  fi;
  AppendTo(
    outputPath,
    id, "\t",
    Size(group), "\t",
    structure, "\t",
    BoolText(flags[1]), "\t",
    BoolText(flags[2]), "\t",
    BoolText(flags[3]), "\t",
    BoolText(survives), "\n"
  );
od;

if survivors <> [63] then
  Error("Frobenius cycle shapes do not isolate 14T63");
fi;
if Size(TransitiveGroup(14, 63)) <> Factorial(14) then
  Error("14T63 does not have order 14!");
fi;
if StructureDescription(TransitiveGroup(14, 63)) <> "S14" then
  Error("14T63 is not identified as S14");
fi;

Print(
  "degree14_transitive_groups=63 survivor=14T63",
  " order=", Size(TransitiveGroup(14, 63)),
  " structure=", StructureDescription(TransitiveGroup(14, 63)), "\n"
);
QUIT;
