Read("src/gap/m23_homogeneous_macroblocks.g");;
SizeScreen([1000000, 1000000]);;

path := GAPInfo.SystemEnvironment.M23_CHECKPOINT;;
limit := Int(GAPInfo.SystemEnvironment.M23_ORBIT_LIMIT);;
M23_PAIR_BLOCK_CHECKPOINT := fail;;
Read(path);
checkpoint := M23_PAIR_BLOCK_CHECKPOINT;;
G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
targetClass := First(classes, class ->
  Order(Representative(class)) = checkpoint.target_order);;
segment := First(M23MacroblockSegments(checkpoint), item ->
  Order(Representative(classes[item.natural_class_index])) = 11);;
block := M23DecodeMacroblock(checkpoint, segment.first_ordinal);;
materialized := M23MaterializeMacroblock(G, classes, checkpoint, block);;
seed := First(materialized.tuples, tuple -> IsGeneratingTuple(G, tuple));;
if seed = fail then
  Error("probe macroblock has no generating tuple");
fi;
bounded := M23BoundedPureOrbit(G, targetClass, seed, limit,
  function(checked, discovered) end);;
Print("target=", checkpoint.target_order, " limit=", limit,
  " closed=", bounded.closed, " checked=", bounded.checked_count,
  " discovered=", bounded.discovered_count, "\n");
QUIT;
