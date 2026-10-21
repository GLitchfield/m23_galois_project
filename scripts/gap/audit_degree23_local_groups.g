if NrTransitiveGroups(23) <> 7 then
  Error("unexpected number of degree-23 transitive groups");
fi;

groups := List([1 .. 7], i -> TransitiveGroup(23, i));;
expectedSizes := [23, 46, 253, 506, 10200960,
                  12926008369442488320000,
                  25852016738884976640000];;
if List(groups, Size) <> expectedSizes then
  Error("unexpected degree-23 transitive-group orders");
fi;

m23 := groups[5];;
compatible := [];;
for i in [1 .. 4] do
  if Length(IsomorphicSubgroups(m23, groups[i])) > 0 then
    Add(compatible, i);
  fi;
od;
if compatible <> [1, 3] then
  Error("unexpected solvable transitive subgroups of M23");
fi;
if not IsSubgroup(groups[4], groups[3]) then
  Error("the standard 23T3 representative is not contained in 23T4");
fi;

Print("degree23_transitive_groups=7\n");
Print("23T3_order=", Size(groups[3]), " structure=",
      StructureDescription(groups[3]), "\n");
Print("23T4_order=", Size(groups[4]), " structure=",
      StructureDescription(groups[4]), "\n");
Print("solvable_transitive_subgroups_of_M23=23T1,23T3\n");
QUIT;
