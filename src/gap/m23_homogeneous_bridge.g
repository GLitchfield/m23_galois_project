Read("src/gap/m23_cc2a2a_shards.g");;

M23TranslateBridgeG41 := function(tuple)
  local s1, s2, s3, s4;
  if Length(tuple) <> 4 or Order(tuple[3]) <> 2 or Order(tuple[4]) <> 2 then
    Error("g41 translation requires a length-4 tuple ending in involutions");
  fi;
  s1 := tuple[1]; s2 := tuple[2]; s3 := tuple[3]; s4 := tuple[4];
  return [s1, s4 * s1 * s4^-1, s4 * s2 * s4^-1,
    s4 * s3 * s2 * s3^-1 * s4^-1];
end;;

M23NormalizedHomogeneousPureMove := function(tuple, generator)
  local conjugator;
  if generator = 12 then
    conjugator := tuple[3] * tuple[4];
  elif generator = 13 then
    conjugator := tuple[2] * tuple[4];
  elif generator = 14 then
    conjugator := tuple[2] * tuple[3];
  else
    Error("unsupported pure generator");
  fi;
  return SimultaneousConjugate(PureBraidMove4Direct(tuple, generator),
    conjugator^-1);
end;;

M23NormalizedHomogeneousEta23Move := function(tuple)
  return SimultaneousConjugate(Eta23Move4(tuple), tuple[2]^-1);
end;;

M23HomogeneousBridgeOrbit := function(context, seed, progress)
  local state, addClass, moves, position, moveNumber, image, index,
    permutations, pureGroup, symmetricGroup, pureOrbits, symmetricOrbits;
  if seed[1] <> context.first or not IsProductOneTuple(seed) or
     not IsGeneratingTuple(context.group, seed) or
     not ForAll(seed, entry -> entry in context.target_class) then
    Error("invalid homogeneous orbit seed");
  fi;

  state := rec(
    representatives := [],
    index := NewDictionary(seed, true),
    transitions := List([1..6], number -> [])
  );
  addClass := function(tuple)
    local known, orbit, member, newIndex;
    known := LookupDictionary(state.index, tuple);
    if known <> fail then
      return known;
    fi;
    orbit := Orbit(context.centralizer, tuple,
      function(point, element)
        return SimultaneousConjugate(point, element);
      end);
    if Length(orbit) <> Size(context.centralizer) then
      Error("homogeneous generating tuple has a nontrivial inner stabilizer");
    fi;
    newIndex := Length(state.representatives) + 1;
    Add(state.representatives, tuple);
    for member in orbit do
      if LookupDictionary(state.index, member) <> fail then
        Error("overlapping homogeneous inner classes");
      fi;
      AddDictionary(state.index, member, newIndex);
    od;
    return newIndex;
  end;

  addClass(seed);
  moves := [
    tuple -> M23NormalizedHomogeneousPureMove(tuple, 12),
    tuple -> M23NormalizedHomogeneousPureMove(tuple, 13),
    tuple -> M23NormalizedHomogeneousPureMove(tuple, 14),
    tuple -> HurwitzMove(tuple, 3),
    M23NormalizedHomogeneousEta23Move,
    Eta234Move4
  ];
  position := 1;
  while position <= Length(state.representatives) do
    for moveNumber in [1..Length(moves)] do
      image := moves[moveNumber](state.representatives[position]);
      if image[1] <> context.first then
        Error("homogeneous move did not preserve the fixed first coordinate");
      fi;
      index := addClass(image);
      state.transitions[moveNumber][position] := index;
    od;
    if position mod 1000 = 0 then
      progress(position, Length(state.representatives));
    fi;
    position := position + 1;
  od;
  progress(position - 1, Length(state.representatives));

  permutations := List(state.transitions, PermList);
  pureGroup := Group(permutations{[1..3]});
  symmetricGroup := Group(permutations);
  pureOrbits := Orbits(pureGroup, [1..Length(state.representatives)]);
  symmetricOrbits := Orbits(symmetricGroup, [1..Length(state.representatives)]);
  return rec(
    representatives := state.representatives,
    index := state.index,
    permutations := permutations,
    pure_orbits := pureOrbits,
    symmetric_orbits := symmetricOrbits
  );
end;;

M23RestrictedPermutationFromOrbit := function(permutation, orbit)
  return PermList(List(orbit, point -> Position(orbit, point^permutation)));
end;;

M23HomogeneousOrbitGenus := function(orbit, first, second, third)
  local degree;
  degree := Length(orbit);
  return 1 - degree +
    (3 * degree -
      M23NumberCyclesOn(M23RestrictedPermutationFromOrbit(first, orbit), degree) -
      M23NumberCyclesOn(M23RestrictedPermutationFromOrbit(second, orbit), degree) -
      M23NumberCyclesOn(M23RestrictedPermutationFromOrbit(third, orbit), degree)) / 2;
end;;
