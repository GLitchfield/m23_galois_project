Read("src/gap/m23_homogeneous_macroblocks.g");;
SizeScreen([1000000, 1000000]);;

M23_PAIR_BLOCK_CHECKPOINT := fail;;
Read(GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT);
pairCheckpoint := M23_PAIR_BLOCK_CHECKPOINT;;
M23_SHARD_CHECKPOINT := fail;;
Read(GAPInfo.SystemEnvironment.M23_BRIDGE_CHECKPOINT);
bridgeCheckpoint := M23_SHARD_CHECKPOINT;;

G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
targetClass := First(classes, class -> Order(Representative(class)) = 4);;

knownSeed := M23TranslateBridgeG41(bridgeCheckpoint.representatives[1]);;
known := M23BoundedPureOrbit(G, targetClass, knownSeed, 2500,
  function(checked, discovered) end);;
Assert(0, known.closed);
Assert(0, known.discovered_count = 2456);

segment := First(M23MacroblockSegments(pairCheckpoint), item ->
  Order(Representative(classes[item.natural_class_index])) = 11);;
block := M23DecodeMacroblock(pairCheckpoint, segment.first_ordinal);;
materialized := M23MaterializeMacroblock(G, classes, pairCheckpoint, block);;
overflowSeed := First(materialized.tuples, tuple -> IsGeneratingTuple(G, tuple));;
overflow := M23BoundedPureOrbit(G, targetClass, overflowSeed, 2500,
  function(checked, discovered) end);;
Assert(0, not overflow.closed);
Assert(0, overflow.discovered_count = 2501);

Print("verified closed 2456-class component and 2501-class overflow witness\n");
QUIT;
