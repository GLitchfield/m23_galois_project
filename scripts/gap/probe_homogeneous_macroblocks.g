Read("src/gap/m23_homogeneous_macroblocks.g");;
SizeScreen([1000000, 1000000]);;

path := GAPInfo.SystemEnvironment.M23_CHECKPOINT;;
M23_PAIR_BLOCK_CHECKPOINT := fail;;
Read(path);
checkpoint := M23_PAIR_BLOCK_CHECKPOINT;;
G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
segments := M23MacroblockSegments(checkpoint);;

Print("target=", checkpoint.target_order, " pair_orbits=",
  checkpoint.pair_orbit_count, " macroblocks=", checkpoint.macroblock_count,
  " segments=", Length(segments), "\n");
for segment in segments do
  if Order(Representative(classes[segment.natural_class_index])) in
      [8, 11, 14, 15, 23] then
    block := M23DecodeMacroblock(checkpoint, segment.first_ordinal);
    materialized := M23MaterializeMacroblock(G, classes, checkpoint, block);
    Assert(0, ForAll(materialized.tuples, tuple ->
      ForAll(tuple, entry -> Order(entry) = checkpoint.target_order)));
    Print("product_order=",
      Order(Representative(classes[segment.natural_class_index])),
      " ordinal=", block.ordinal, " inner_classes=",
      materialized.inner_class_count, " generating=",
      Number(materialized.tuples, tuple -> IsGeneratingTuple(G, tuple)), "\n");
  fi;
od;
QUIT;
