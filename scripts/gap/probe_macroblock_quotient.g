Read("src/gap/m23_homogeneous_macroblocks.g");;
SizeScreen([1000000, 1000000]);;

M23_PAIR_BLOCK_CHECKPOINT := fail;;
Read(GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT);
checkpoint := M23_PAIR_BLOCK_CHECKPOINT;;
G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
locator := M23BuildMacroblockLocator(G, classes, checkpoint);;
segment := First(M23MacroblockSegments(checkpoint), item ->
  Order(Representative(classes[item.natural_class_index])) = 11);;

for ordinal in [segment.first_ordinal..segment.first_ordinal + 9] do
  block := M23DecodeMacroblock(checkpoint, ordinal);
  materialized := M23MaterializeMacroblock(G, classes, checkpoint, block);
  Assert(0, ForAll(materialized.tuples, tuple ->
    M23LocateMacroblock(locator, tuple).ordinal = ordinal));
od;

block := M23DecodeMacroblock(checkpoint, segment.first_ordinal);;
neighbors := M23ExactMacroblockNeighbors(locator, block);;
refinement := M23RefineMacroblockPairTwists(locator, block);;
Assert(0, Length(refinement.twist_orbits) = 1);
Print("target=", checkpoint.target_order, " block=", block.ordinal,
  " weight=", M23MaterializeMacroblock(G, classes, checkpoint,
    block).inner_class_count,
  " neighbors=", Length(neighbors), " exact_neighbors=",
  Number(neighbors, neighbor -> M23IsExactPairTwistMacroblock(locator,
    neighbor)), " orders=",
  Collected(List(neighbors, neighbor -> Order(Representative(
    classes[neighbor.natural_class_index])))), "\n");
for neighbor in neighbors do
  if not M23IsExactPairTwistMacroblock(locator, neighbor) then
    refinement := M23RefineMacroblockPairTwists(locator, neighbor);
    Print("refine block=", neighbor.ordinal, " product_order=",
      Order(Representative(classes[neighbor.natural_class_index])),
      " inner_classes=", refinement.materialized.inner_class_count,
      " twist_blocks=", Length(refinement.twist_orbits), " sizes=",
      Collected(refinement.twist_orbit_sizes), "\n");
  fi;
od;
QUIT;
