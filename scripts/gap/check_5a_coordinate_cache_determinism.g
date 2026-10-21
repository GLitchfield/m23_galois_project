Read("src/gap/m23_homogeneous_macroblocks.g");;
SizeScreen([1000000, 1000000]);;

if not IsBound(GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT) then
  Error("M23_PAIR_CHECKPOINT is required");
fi;
M23_PAIR_BLOCK_CHECKPOINT := fail;;
Read(GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT);
checkpoint := M23_PAIR_BLOCK_CHECKPOINT;;
if checkpoint.target_order <> 5 then
  Error("cache-determinism fixture requires the 5A pair checkpoint");
fi;

G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
locator := M23BuildDirectPairLocator(G, classes, checkpoint);;
locator.traversal_order := "key-v2";;

# These real keys occur near the beginning of the certified key-v1 block-840
# pilot.  They cover several product-class segments and exposed the former
# dependence on the order in which relative-map caches were constructed.
samples := [
  [840, 10],
  [13637401, 1],
  [62007370, 1],
  [102680805, 1],
  [113648379, 1]
];;

M23CacheSignature := function(locator, key)
  local block, refinement, neighbors;
  block := M23DecodeMacroblock(locator.checkpoint, key[1]);
  refinement := M23CachedDirectPairTwistRefinement(locator, block);
  if key[2] > Length(refinement.twist_orbits) then
    Error("cache-determinism sample twist is outside its refinement");
  fi;
  neighbors := M23DirectPairTwistNeighbors(locator, block, key[2]);
  return rec(
    key := key,
    weight := Length(refinement.twist_orbits[key[2]]),
    neighbors := List(neighbors,
      item -> [item.block.ordinal, item.twist_id, item.weight])
  );
end;;

forward := List(samples, key -> M23CacheSignature(locator, key));;
M23ResetDirectPairBlockCaches(locator);
GASMAN("collect");
backward := Reversed(List(Reversed(samples),
  key -> M23CacheSignature(locator, key)));;
Assert(0, forward = backward);
Print("verified key-v2 5A coordinate signatures across cache orders: ",
  Length(samples), " samples\n");
QUIT;
