Read("src/gap/m23_homogeneous_macroblocks.g");;
SizeScreen([1000000, 1000000]);;

M23_PAIR_BLOCK_CHECKPOINT := fail;;
Read(GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT);
checkpoint := M23_PAIR_BLOCK_CHECKPOINT;;
G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
direct := M23BuildDirectPairLocator(G, classes, checkpoint);;
useOracle := true;;
if IsBound(GAPInfo.SystemEnvironment.M23_SKIP_ORACLE) and
   GAPInfo.SystemEnvironment.M23_SKIP_ORACLE = "1" then
  useOracle := false;
fi;
oracle := fail;;
if useOracle then
  oracle := M23BuildMacroblockLocator(G, classes, checkpoint);
fi;
segments := M23MacroblockSegments(checkpoint);;

orders := [2, 3, 4, 5, 6, 7, 8, 11, 14, 15, 23];;
for order in orders do
  segment := First(segments, item ->
    Order(Representative(classes[item.natural_class_index])) = order);
  block := M23DecodeMacroblock(checkpoint, segment.first_ordinal);
  materialized := M23MaterializeMacroblock(G, classes, checkpoint, block);
  for index in [1..Length(materialized.tuples)] do
    coordinate := M23DirectRelativeCoordinate(direct,
      materialized.tuples[index]);
    Assert(0, coordinate.block.ordinal = block.ordinal);
  od;
  directRefinement := M23DirectPairTwistRefinement(direct, block);
  if useOracle and order > 3 then
    oracleRefinement := M23RefineMacroblockPairTwists(oracle, block);
    Assert(0, Set(List(directRefinement.twist_orbits, Set)) =
      Set(List(oracleRefinement.twist_orbits, Set)));
  fi;
  Print("order=", order, " relative=", materialized.inner_class_count,
    " twist_blocks=", Length(directRefinement.twist_orbits), " sizes=",
    Collected(directRefinement.twist_orbit_sizes), "\n");
od;

identitySegment := First(segments, item ->
  Order(Representative(classes[item.natural_class_index])) = 1);;
identityBlock := M23DecodeMacroblock(checkpoint,
  identitySegment.first_ordinal);;
identityRefinement := M23CachedDirectPairTwistRefinement(direct,
  identityBlock);;
Assert(0, Length(identityRefinement.twist_orbits) =
  checkpoint.pair_orbit_count);
Assert(0, ForAll(identityRefinement.twist_orbit_sizes, size -> size = 1));
for index in [1, Length(identityRefinement.materialized.tuples)] do
  coordinate := M23DirectPairTwistCoordinate(direct,
    identityRefinement.materialized.tuples[index]);
  Assert(0, coordinate.block.ordinal = identityBlock.ordinal);
  Assert(0, coordinate.twist_id = index);
  coordinate12 := M23DirectPairTwistCoordinate(direct,
    PureBraidMove4Direct(identityRefinement.materialized.tuples[index], 12));
  coordinate34 := M23DirectPairTwistCoordinate(direct,
    ApplyHurwitzWord(identityRefinement.materialized.tuples[index], [4, 4]));
  Assert(0, coordinate12.block.ordinal = identityBlock.ordinal);
  Assert(0, coordinate12.twist_id = index);
  Assert(0, coordinate34.block.ordinal = identityBlock.ordinal);
  Assert(0, coordinate34.twist_id = index);
od;
Print("identity relative=", Length(identityRefinement.twist_orbits),
  " twist_blocks=", Length(identityRefinement.twist_orbits), "\n");

segment := First(segments, item ->
  Order(Representative(classes[item.natural_class_index])) = 11);;
block := M23DecodeMacroblock(checkpoint, segment.first_ordinal);;
cachedRefinement := M23CachedDirectPairTwistRefinement(direct, block);;
directNeighbors := M23DirectPairTwistNeighbors(direct, block, 1);;
savedNeighborKeys := List(directNeighbors,
  item -> [item.block.ordinal, item.twist_id]);;
Assert(0, savedNeighborKeys = Set(savedNeighborKeys));
M23ResetDirectPairBlockCaches(direct);
resetRefinement := M23CachedDirectPairTwistRefinement(direct, block);;
Assert(0, resetRefinement.twist_orbit_sizes =
  cachedRefinement.twist_orbit_sizes);
resetNeighborKeys := List(M23DirectPairTwistNeighbors(direct, block, 1),
  item -> [item.block.ordinal, item.twist_id]);;
Assert(0, resetNeighborKeys = savedNeighborKeys);
if useOracle then
  oracleNeighbors := M23ExactMacroblockNeighbors(oracle, block);;
  Assert(0, Set(List(directNeighbors, item -> item.block.ordinal)) =
    Set(List(oracleNeighbors, item -> item.ordinal)));
  Print("order=11 direct_refined_neighbors=", Length(directNeighbors),
    " macroblock_neighbors=", Length(oracleNeighbors), "\n");
else
  Print("order=11 direct_refined_neighbors=", Length(directNeighbors), "\n");
fi;
QUIT;
