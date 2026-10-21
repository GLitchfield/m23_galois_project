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
progressPath := GAPInfo.SystemEnvironment.M23_PROGRESS_FILE;;
traversalOrder := "key-v2";;
if IsBound(GAPInfo.SystemEnvironment.M23_TRAVERSAL_ORDER) then
  traversalOrder := GAPInfo.SystemEnvironment.M23_TRAVERSAL_ORDER;
fi;
Assert(0, traversalOrder in ["legacy", "key-v1", "key-v2"]);

M23DatabaseVerifyEvent := function(state, detail)
  AppendTo(progressPath, IO_gettimeofday().tv_sec,
    "\tgap\tverify_quotient_db\tall\t", state, "\t", detail, "\n");
end;;

config := rec(
  target_order := pairCheckpoint.target_order,
  pair_schema := pairCheckpoint.schema_version,
  macroblock_count := pairCheckpoint.macroblock_count,
  first_ordinal := firstOrdinal, last_ordinal := lastOrdinal,
  proof_limit := limit, walk_limit := walkLimit, schedule := schedule,
  start_ordinal := startOrdinal, traversal_order := traversalOrder
);;
database := M23OpenQuotientLedger(databasePath, config);;
stats := M23QuotientLedgerStats(database);;
blocks := M23QuotientLedgerBlocks(database);;
Assert(0, Length(blocks) = stats.blocks);
M23DatabaseVerifyEvent("start", Concatenation("certificates=",
  String(stats.certificates), ",blocks=", String(stats.blocks),
  ",vertices=", String(stats.vertices)));

G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
locator := M23BuildDirectPairLocator(G, classes, pairCheckpoint);;
locator.traversal_order := traversalOrder;;
ledger := NewDictionary([1, 1], true);;
seedCounts := NewDictionary(1, true);;
verifiedLedgerCount := 0;;
verifiedClosed := 0;; verifiedOverflow := 0;; verifiedLinked := 0;;

for certificateId in [1..stats.certificates] do
  certificate := M23QuotientLedgerCertificate(database, certificateId);
  Assert(0, certificate.status in ["closed", "overflow", "linked"]);
  Assert(0, certificate.walk_status in ["closed", "overflow", "linked"]);
  Assert(0, certificate.discovered_vertex_count =
    Length(certificate.vertices));
  Assert(0, certificate.seed_vertex = certificate.vertices[1]);
  if certificate.status = "closed" then
    verifiedClosed := verifiedClosed + 1;
    Assert(0, certificate.linked_certificate = fail);
    Assert(0, certificate.discovered_class_count <= limit);
  elif certificate.status = "overflow" then
    verifiedOverflow := verifiedOverflow + 1;
    Assert(0, certificate.linked_certificate = fail);
    Assert(0, certificate.discovered_class_count > limit);
  else
    verifiedLinked := verifiedLinked + 1;
    Assert(0, IsInt(certificate.linked_certificate));
    Assert(0, certificate.linked_certificate >= 1 and
      certificate.linked_certificate < certificateId);
  fi;
  seedCount := LookupDictionary(seedCounts, certificate.seed_vertex[1]);
  if seedCount = fail then
    AddDictionary(seedCounts, certificate.seed_vertex[1], 1);
  else
    RemoveDictionary(seedCounts, certificate.seed_vertex[1]);
    AddDictionary(seedCounts, certificate.seed_vertex[1], seedCount + 1);
  fi;

  seedBlock := M23DecodeMacroblock(pairCheckpoint,
    certificate.seed_vertex[1]);
  seedRefinement := M23CachedDirectPairTwistRefinement(locator, seedBlock);
  seedIndex := seedRefinement.twist_orbits[certificate.seed_vertex[2]][1];
  seed := seedRefinement.materialized.tuples[seedIndex];
  Assert(0, IsGeneratingTuple(G, seed));
  replay := M23BoundedDirectPairTwistOrbitWithLedger(locator, seed,
    walkLimit, function(checked, discovered, classesFound) end,
    key -> LookupDictionary(ledger, key));
  replayKeys := List(replay.vertices, vertex ->
    [vertex.block.ordinal, vertex.twist_id]);
  Assert(0, replay.status = certificate.walk_status);
  if replay.status = "linked" then
    expectedStatus := "linked";
  elif replay.status = "closed" and replay.discovered_class_count <= limit then
    expectedStatus := "closed";
  else
    expectedStatus := "overflow";
  fi;
  Assert(0, certificate.status = expectedStatus);
  Assert(0, replay.linked_certificate = certificate.linked_certificate);
  Assert(0, replay.checked_vertex_count = certificate.checked_vertex_count);
  Assert(0, replay.discovered_class_count = certificate.discovered_class_count);
  Assert(0, Set(replayKeys) = Set(certificate.vertices));
  for key in certificate.vertices do
    Assert(0, LookupDictionary(ledger, key) = fail);
    AddDictionary(ledger, key, certificateId);
    verifiedLedgerCount := verifiedLedgerCount + 1;
  od;
  M23DatabaseVerifyEvent("progress", Concatenation("certificate=",
    String(certificateId), "/", String(stats.certificates), ",ledger=",
    String(verifiedLedgerCount)));
od;
Assert(0, verifiedLedgerCount = stats.vertices);
Assert(0, [verifiedClosed, verifiedOverflow, verifiedLinked] =
  [stats.closed, stats.overflow, stats.linked]);

verifiedRefined := 0;;
verifiedGenerating := 0;;
verifiedHits := 0;;
for blockRecord in blocks do
  block := M23DecodeMacroblock(pairCheckpoint, blockRecord.ordinal);
  refinement := M23CachedDirectPairTwistRefinement(locator, block);
  Assert(0, Length(refinement.twist_orbits) = blockRecord.refined_vertices);
  verifiedRefined := verifiedRefined + Length(refinement.twist_orbits);
  blockGenerating := 0;
  blockSeedCertificates := 0;
  for twistId in [1..Length(refinement.twist_orbits)] do
    materializedIndex := refinement.twist_orbits[twistId][1];
    seed := refinement.materialized.tuples[materializedIndex];
    if IsGeneratingTuple(G, seed) then
      blockGenerating := blockGenerating + 1;
      Assert(0, LookupDictionary(ledger,
        [blockRecord.ordinal, twistId]) <> fail);
    fi;
  od;
  Assert(0, blockGenerating = blockRecord.generating_vertices);
  seedCount := LookupDictionary(seedCounts, blockRecord.ordinal);
  if seedCount = fail then seedCount := 0; fi;
  Assert(0, seedCount = blockRecord.new_certificates);
  Assert(0, blockRecord.ledger_hits = blockGenerating - seedCount);
  verifiedGenerating := verifiedGenerating + blockGenerating;
  verifiedHits := verifiedHits + blockRecord.ledger_hits;
od;
Assert(0, verifiedRefined = stats.refined_vertices);
Assert(0, verifiedGenerating = stats.generating_vertices);
Assert(0, verifiedHits = stats.ledger_hits);

M23CloseQuotientLedger(database);;
M23DatabaseVerifyEvent("done", Concatenation("certificates=",
  String(stats.certificates), ",blocks=", String(stats.blocks),
  ",vertices=", String(stats.vertices)));
Print("verified database quotient scan blocks=", stats.blocks,
  " certificates=", stats.certificates, " vertices=", stats.vertices, "\n");
QUIT;
