if not IsBound(GAPInfo.SystemEnvironment.M23_OUTPUT) then
  Error("M23_OUTPUT must name the generated TSV file");
fi;
output := GAPInfo.SystemEnvironment.M23_OUTPUT;;
SizeScreen([100000, 100000]);;
G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
table := CharacterTable("M23");;
names := ClassNames(table);;
orders := OrdersClassRepresentatives(table);;
sizes := SizesConjugacyClasses(table);;
groupOrder := Size(table);;
inverseMap := PowerMap(table, -1);;

IsRationalClass := function(position)
  local exponent;
  for exponent in [1..orders[position]] do
    if Gcd(exponent, orders[position]) = 1 and
       PowerMap(table, exponent)[position] <> position then
      return false;
    fi;
  od;
  return true;
end;;

CycleStructureFor := function(position)
  local matches, structures;
  matches := Filtered(classes, class ->
    Order(Representative(class)) = orders[position] and
    Size(class) = sizes[position]);;
  if Length(matches) = 0 then
    Error("no natural-action class matches table position ", position);
  fi;
  structures := Set(matches, class ->
    CycleStructurePerm(Representative(class)));
  if Length(structures) <> 1 then
    Error("ambiguous cycle structures at table position ", position);
  fi;
  return structures[1];
end;;

CycleShapeString := function(structure)
  local degreeUsed, pieces, cycleLength, fixedPoints;
  degreeUsed := 0;
  pieces := [];
  for cycleLength in [2..Length(structure) + 1] do
    if IsBound(structure[cycleLength - 1]) then
      degreeUsed := degreeUsed + cycleLength * structure[cycleLength - 1];
      Add(pieces, Concatenation(String(cycleLength), "^",
        String(structure[cycleLength - 1])));
    fi;
  od;
  fixedPoints := 23 - degreeUsed;
  if fixedPoints > 0 then
    Add(pieces, Concatenation("1^", String(fixedPoints)), 1);
  fi;
  return JoinStringsWithSeparator(pieces, " ");
end;;

PrintTo(output,
  "# generated_by\tscripts/gap/generate_m23_class_atlas.g\n",
  "# gap_version\t", GAPInfo.Version, "\n",
  "# character_table\t", Identifier(table), "\n",
  "# group_order\t", groupOrder, "\n",
  "class\torder\tsize\tcentralizer_size\tcycle_structure\tinverse_class\trational\n");

for position in [1..Length(names)] do
  AppendTo(output,
    UppercaseString(names[position]), "\t",
    orders[position], "\t",
    sizes[position], "\t",
    groupOrder / sizes[position], "\t",
    CycleShapeString(CycleStructureFor(position)), "\t",
    UppercaseString(names[inverseMap[position]]), "\t",
    IsRationalClass(position), "\n");
od;

QUIT;
