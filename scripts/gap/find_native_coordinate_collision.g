Read("src/gap/m23_homogeneous_macroblocks.g");;
SizeScreen([1000000, 1000000]);;

if not IsBound(GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT) then
  Error("M23_PAIR_CHECKPOINT must name a homogeneous pair checkpoint");
fi;
firstOrdinal := 2;;
lastOrdinal := 100;;
candidates := fail;;
if IsBound(GAPInfo.SystemEnvironment.M23_VERTEX_CANDIDATES) then
  candidates := EvalString(GAPInfo.SystemEnvironment.M23_VERTEX_CANDIDATES);
  if not IsList(candidates) or Length(candidates) = 0 or
     not ForAll(candidates, item -> IsList(item) and Length(item) = 2) then
    Error("M23_VERTEX_CANDIDATES must be a nonempty GAP list of pairs");
  fi;
  firstOrdinal := Minimum(List(candidates, item -> item[1]));
  lastOrdinal := Maximum(List(candidates, item -> item[1]));
fi;
if IsBound(GAPInfo.SystemEnvironment.M23_FIRST_BLOCK) then
  firstOrdinal := Int(GAPInfo.SystemEnvironment.M23_FIRST_BLOCK);
fi;
if IsBound(GAPInfo.SystemEnvironment.M23_LAST_BLOCK) then
  lastOrdinal := Int(GAPInfo.SystemEnvironment.M23_LAST_BLOCK);
fi;
if firstOrdinal < 1 or lastOrdinal < firstOrdinal then
  Error("invalid native collision-search interval");
fi;
generatingOnly := true;;
if IsBound(GAPInfo.SystemEnvironment.M23_ALLOW_NONGENERATING) and
   GAPInfo.SystemEnvironment.M23_ALLOW_NONGENERATING = "1" then
  generatingOnly := false;
fi;

M23_PAIR_BLOCK_CHECKPOINT := fail;;
Read(GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT);
checkpoint := M23_PAIR_BLOCK_CHECKPOINT;;
G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
locator := M23BuildDirectPairLocator(G, classes, checkpoint);;

found := false;;
for ordinal in [firstOrdinal..lastOrdinal] do
  if candidates <> fail and
     not ForAny(candidates, item -> item[1] = ordinal) then
    continue;
  fi;
  block := M23DecodeMacroblock(checkpoint, ordinal);
  refinement := M23CachedDirectPairTwistRefinement(locator, block);
  if candidates = fail then
    twistIds := [1..Length(refinement.twist_orbits)];
  else
    twistIds := List(Filtered(candidates, item -> item[1] = ordinal),
      item -> item[2]);
  fi;
  for twistId in twistIds do
    if twistId < 1 or twistId > Length(refinement.twist_orbits) then
      Error("candidate twist is outside its macroblock refinement");
    fi;
    sourceWeight := Length(refinement.twist_orbits[twistId]);
    materializedIndex := refinement.twist_orbits[twistId][1];
    sourceGenerating := IsGeneratingTuple(G,
      refinement.materialized.tuples[materializedIndex]);
    if (not generatingOnly or sourceGenerating) then
      neighbors := M23DirectPairTwistNeighbors(locator, block, twistId);
    else
      neighbors := fail;
    fi;
    if neighbors <> fail and Length(neighbors) < 2 * sourceWeight then
      Print("collision\t", ordinal, "\t", twistId, "\t", sourceWeight,
        "\t", 2 * sourceWeight, "\t", Length(neighbors), "\t",
        sourceGenerating, "\n");
      found := true;
      break;
    fi;
  od;
  if found then
    break;
  fi;
  if (ordinal - firstOrdinal + 1) mod 10 = 0 then
    Print("progress\t", ordinal, "\n");
  fi;
od;
if not found then
  Print("none\t", firstOrdinal, "\t", lastOrdinal, "\n");
fi;
QUIT;
