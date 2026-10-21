Read("src/gap/m23_homogeneous_macroblocks.g");;
Read("src/gap/m23_quotient_ledger.g");;
SizeScreen([1000000, 1000000]);;

M23_PAIR_BLOCK_CHECKPOINT := fail;;
Read(GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT);
pairCheckpoint := M23_PAIR_BLOCK_CHECKPOINT;;
databasePath := GAPInfo.SystemEnvironment.M23_LEDGER_DB;;
firstOrdinal := Int(GAPInfo.SystemEnvironment.M23_FIRST_ORDINAL);;
lastOrdinal := Int(GAPInfo.SystemEnvironment.M23_LAST_ORDINAL);;
limit := Int(GAPInfo.SystemEnvironment.M23_ORBIT_LIMIT);;
walkLimit := Int(GAPInfo.SystemEnvironment.M23_WALK_LIMIT);;
schedule := GAPInfo.SystemEnvironment.M23_SCAN_SCHEDULE;;
startOrdinal := Int(GAPInfo.SystemEnvironment.M23_START_ORDINAL);;
segmentIndex := Int(GAPInfo.SystemEnvironment.M23_SEGMENT_INDEX);;
segmentCount := Int(GAPInfo.SystemEnvironment.M23_SEGMENT_COUNT);;
baseBlocks := Int(GAPInfo.SystemEnvironment.M23_BASE_BLOCKS);;
baseCertificates := Int(GAPInfo.SystemEnvironment.M23_BASE_CERTIFICATES);;
planId := GAPInfo.SystemEnvironment.M23_VERIFICATION_PLAN;;
progressPath := GAPInfo.SystemEnvironment.M23_PROGRESS_FILE;;
item := Concatenation(String(segmentIndex), "-of-", String(segmentCount));;
cacheResetInterval := 1000;;
cacheResets := 0;;
traversalOrder := "key-v2";;
if IsBound(GAPInfo.SystemEnvironment.M23_CACHE_RESET_INTERVAL) then
  cacheResetInterval :=
    Int(GAPInfo.SystemEnvironment.M23_CACHE_RESET_INTERVAL);
fi;
if IsBound(GAPInfo.SystemEnvironment.M23_TRAVERSAL_ORDER) then
  traversalOrder := GAPInfo.SystemEnvironment.M23_TRAVERSAL_ORDER;
fi;
Assert(0, cacheResetInterval >= 0);
Assert(0, traversalOrder in ["legacy", "key-v1", "key-v2"]);

M23BlockSegmentEvent := function(state, detail)
  AppendTo(progressPath, IO_gettimeofday().tv_sec,
    "\tgap\tverify_quotient_block_segment\t", item, "\t", state,
    "\tplan=", planId, ",", detail, "\n");
end;;

config := rec(target_order := pairCheckpoint.target_order,
  pair_schema := pairCheckpoint.schema_version,
  macroblock_count := pairCheckpoint.macroblock_count,
  first_ordinal := firstOrdinal, last_ordinal := lastOrdinal,
  proof_limit := limit, walk_limit := walkLimit, schedule := schedule,
  start_ordinal := startOrdinal, traversal_order := traversalOrder);;
database := M23OpenReadOnlyQuotientLedger(databasePath, config);;
lookupDatabase := M23OpenReadOnlyQuotientLedger(databasePath, config);;
stats := M23QuotientLedgerStats(database);;
Assert(0, baseBlocks < stats.blocks and
  baseCertificates < stats.certificates and segmentIndex >= 1 and
  segmentIndex <= segmentCount);
M23BlockSegmentEvent("start", Concatenation("base_blocks=",
  String(baseBlocks), ",blocks=", String(stats.blocks),
  ",cache_reset_interval=", String(cacheResetInterval),
  ",block_mode=stream,traversal_order=", traversalOrder));

G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
locator := M23BuildDirectPairLocator(G, classes, pairCheckpoint);;
locator.traversal_order := traversalOrder;;
verifiedBlocks := 0;; verifiedRefined := 0;; verifiedGenerating := 0;;
verifiedHits := 0;;
M23VerifyStreamedBlock := function(blockRecord)
  local block, refinement, blockGenerating, twistId, materializedIndex, seed;
  block := M23DecodeMacroblock(pairCheckpoint, blockRecord.ordinal);
  refinement := M23CachedDirectPairTwistRefinement(locator, block);
  Assert(0, Length(refinement.twist_orbits) = blockRecord.refined_vertices);
  blockGenerating := 0;
  for twistId in [1..Length(refinement.twist_orbits)] do
    materializedIndex := refinement.twist_orbits[twistId][1];
    seed := refinement.materialized.tuples[materializedIndex];
    if IsGeneratingTuple(G, seed) then
      blockGenerating := blockGenerating + 1;
      Assert(0, M23QuotientLedgerLookup(lookupDatabase,
        [blockRecord.ordinal, twistId]) <> fail);
    fi;
  od;
  Assert(0, blockGenerating = blockRecord.generating_vertices and
    blockRecord.actual_new_certificates = blockRecord.new_certificates and
    blockRecord.ledger_hits = blockGenerating -
      blockRecord.actual_new_certificates);
  verifiedBlocks := verifiedBlocks + 1;
  verifiedRefined := verifiedRefined + blockRecord.refined_vertices;
  verifiedGenerating := verifiedGenerating + blockGenerating;
  verifiedHits := verifiedHits + blockRecord.ledger_hits;
  if cacheResetInterval > 0 and
      verifiedBlocks mod cacheResetInterval = 0 then
    M23ResetDirectPairBlockCaches(locator);
    GASMAN("collect");
    cacheResets := cacheResets + 1;
  fi;
end;;
streamedBlocks := M23QuotientLedgerForEachBlockSegment(database, baseBlocks,
  baseCertificates, segmentIndex, segmentCount, M23VerifyStreamedBlock);;
Assert(0, streamedBlocks = verifiedBlocks);
M23CloseQuotientLedger(database);;
M23CloseQuotientLedger(lookupDatabase);;
M23BlockSegmentEvent("done", Concatenation("blocks=",
  String(verifiedBlocks), ",refined=", String(verifiedRefined),
  ",generating=", String(verifiedGenerating), ",hits=",
  String(verifiedHits), ",cache_resets=", String(cacheResets)));
Print("verified block segment ", item, " blocks=", verifiedBlocks,
  " refined=", verifiedRefined, " generating=", verifiedGenerating, "\n");
QUIT;
