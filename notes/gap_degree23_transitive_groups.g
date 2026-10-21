Print("Number of transitive groups of degree 23: ", NrTransitiveGroups(23), "\n");
for i in [1..NrTransitiveGroups(23)] do
  G := TransitiveGroup(23, i);;
  Print("23T", i,
        " size=", Size(G),
        " primitive=", IsPrimitive(G, [1..23]),
        " solvable=", IsSolvableGroup(G),
        " simple=", IsSimpleGroup(G),
        " transitivity=", Transitivity(G, [1..23]),
        "\n");
od;
QUIT;
