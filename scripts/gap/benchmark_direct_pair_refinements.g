Read("src/gap/m23_homogeneous_macroblocks.g");;
SizeScreen([1000000, 1000000]);;

if not IsBound(GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT) or
    not IsBound(GAPInfo.SystemEnvironment.M23_OUTPUT) then
  Error("M23_PAIR_CHECKPOINT and M23_OUTPUT are required");
fi;
samplesPerSegment := 10;;
if IsBound(GAPInfo.SystemEnvironment.M23_SAMPLES_PER_SEGMENT) then
  samplesPerSegment :=
    Int(GAPInfo.SystemEnvironment.M23_SAMPLES_PER_SEGMENT);
fi;
if samplesPerSegment < 1 then
  Error("M23_SAMPLES_PER_SEGMENT must be positive");
fi;

M23_PAIR_BLOCK_CHECKPOINT := fail;;
Read(GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT);
checkpoint := M23_PAIR_BLOCK_CHECKPOINT;;
G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
started := Runtime();;
locator := M23BuildDirectPairLocator(G, classes, checkpoint);;
locatorMs := Runtime() - started;;
segments := M23MacroblockSegments(checkpoint);;
output := GAPInfo.SystemEnvironment.M23_OUTPUT;;
PrintTo(output,
  "# schema\tm23-direct-pair-refinement-benchmark-v1\n",
  "# gap_version\t", GAPInfo.Version, "\n",
  "# target_order\t", checkpoint.target_order, "\n",
  "# macroblock_count\t", checkpoint.macroblock_count, "\n",
  "# samples_per_segment\t", samplesPerSegment, "\n",
  "# locator_ms\t", locatorMs, "\n",
  "segment\tclass_index\tproduct_order\tsegment_blocks\tsample\tordinal\t",
  "refined_vertices\tgenerating_vertices\trefine_ms\tgeneration_ms\n");

for segmentIndex in [1..Length(segments)] do
  segment := segments[segmentIndex];
  segmentBlocks := segment.last_ordinal - segment.first_ordinal + 1;
  sampleCount := Minimum(samplesPerSegment, segmentBlocks);
  for sampleIndex in [1..sampleCount] do
    offset := QuoInt((2 * sampleIndex - 1) * segmentBlocks,
      2 * sampleCount);
    ordinal := segment.first_ordinal + offset;
    if ordinal > segment.last_ordinal then ordinal := segment.last_ordinal; fi;
    block := M23DecodeMacroblock(checkpoint, ordinal);
    started := Runtime();
    refinement := M23CachedDirectPairTwistRefinement(locator, block);
    refineMs := Runtime() - started;
    generatingCount := 0;
    started := Runtime();
    for twistId in [1..Length(refinement.twist_orbits)] do
      materializedIndex := refinement.twist_orbits[twistId][1];
      if IsGeneratingTuple(G,
          refinement.materialized.tuples[materializedIndex]) then
        generatingCount := generatingCount + 1;
      fi;
    od;
    generationMs := Runtime() - started;
    AppendTo(output, segmentIndex, "\t", segment.natural_class_index,
      "\t", Order(Representative(classes[segment.natural_class_index])),
      "\t", segmentBlocks, "\t", sampleIndex, "\t", ordinal, "\t",
      Length(refinement.twist_orbits), "\t", generatingCount, "\t",
      refineMs, "\t", generationMs, "\n");
    M23ResetDirectPairBlockCaches(locator);
  od;
od;
QUIT;
