Read("src/gap/m23_homogeneous_macroblocks.g");;
Read("src/gap/m23_quotient_ledger.g");;
SizeScreen([1000000, 1000000]);;

M23_PAIR_BLOCK_CHECKPOINT := fail;;
Read(GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT);
pairCheckpoint := M23_PAIR_BLOCK_CHECKPOINT;;
baseDatabasePath := GAPInfo.SystemEnvironment.M23_BASE_LEDGER_DB;;
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

M23DatabaseDeltaVerifyEvent := function(state, detail)
  AppendTo(progressPath, IO_gettimeofday().tv_sec,
    "\tgap\tverify_quotient_db_delta\tall\t", state, "\t", detail, "\n");
end;;

config := rec(
  target_order := pairCheckpoint.target_order,
  pair_schema := pairCheckpoint.schema_version,
  macroblock_count := pairCheckpoint.macroblock_count,
  first_ordinal := firstOrdinal, last_ordinal := lastOrdinal,
  proof_limit := limit, walk_limit := walkLimit, schedule := schedule,
  start_ordinal := startOrdinal, traversal_order := traversalOrder
);;
baseDatabase := M23OpenReadOnlyQuotientLedger(baseDatabasePath, config);;
database := M23OpenQuotientLedger(databasePath, config);;
baseStats := M23QuotientLedgerStats(baseDatabase);;
stats := M23QuotientLedgerStats(database);;
Assert(0, baseStats.blocks <= stats.blocks and
  baseStats.certificates <= stats.certificates and
  baseStats.vertices <= stats.vertices);
M23DatabaseDeltaVerifyEvent("start", Concatenation("base_certificates=",
  String(baseStats.certificates), ",certificates=", String(stats.certificates),
  ",base_blocks=", String(baseStats.blocks), ",blocks=", String(stats.blocks),
  ",base_vertices=", String(baseStats.vertices), ",vertices=",
  String(stats.vertices)));

G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
locator := M23BuildDirectPairLocator(G, classes, pairCheckpoint);;
locator.traversal_order := traversalOrder;;
ledger := NewDictionary([1, 1], true);;
baseVertices := M23QuotientLedgerVertices(baseDatabase);;
Assert(0, Length(baseVertices) = baseStats.vertices);
for vertex in baseVertices do
  Assert(0, LookupDictionary(ledger, vertex{[1, 2]}) = fail);
  AddDictionary(ledger, vertex{[1, 2]}, vertex[3]);
od;
baseVertices := fail;;
seedCounts := NewDictionary(1, true);;
verifiedDeltaVertices := 0;;
verifiedClosed := 0;; verifiedOverflow := 0;; verifiedLinked := 0;;

for certificateId in [baseStats.certificates + 1..stats.certificates] do
  certificate := M23QuotientLedgerCertificate(database, certificateId);
  Assert(0, certificate.status in ["closed", "overflow", "linked"]);
  Assert(0, certificate.walk_status in ["closed", "overflow", "linked"]);
  Assert(0, certificate.discovered_vertex_count = Length(certificate.vertices));
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
    Assert(0, certificate.linked_certificate < certificateId);
  fi;
  seedCount := LookupDictionary(seedCounts, certificate.seed_vertex[1]);
  if seedCount = fail then seedCount := 0; fi;
  if seedCount > 0 then
    RemoveDictionary(seedCounts, certificate.seed_vertex[1]);
  fi;
  AddDictionary(seedCounts, certificate.seed_vertex[1], seedCount + 1);

  seedBlock := M23DecodeMacroblock(pairCheckpoint, certificate.seed_vertex[1]);
  seedRefinement := M23CachedDirectPairTwistRefinement(locator, seedBlock);
  seedIndex := seedRefinement.twist_orbits[certificate.seed_vertex[2]][1];
  seed := seedRefinement.materialized.tuples[seedIndex];
  Assert(0, IsGeneratingTuple(G, seed));
  replay := M23BoundedDirectPairTwistOrbitWithLedger(locator, seed,
    walkLimit, function(checked, discovered, classesFound) end,
    key -> LookupDictionary(ledger, key));
  replayKeys := List(replay.vertices, item ->
    [item.block.ordinal, item.twist_id]);
  Assert(0, replay.status = certificate.walk_status);
  if replay.status = "linked" then expectedStatus := "linked";
  elif replay.status = "closed" and replay.discovered_class_count <= limit then
    expectedStatus := "closed";
  else expectedStatus := "overflow";
  fi;
  Assert(0, certificate.status = expectedStatus);
  Assert(0, replay.linked_certificate = certificate.linked_certificate);
  Assert(0, replay.checked_vertex_count = certificate.checked_vertex_count);
  Assert(0, replay.discovered_class_count = certificate.discovered_class_count);
  Assert(0, Set(replayKeys) = Set(certificate.vertices));
  for key in certificate.vertices do
    Assert(0, LookupDictionary(ledger, key) = fail);
    AddDictionary(ledger, key, certificateId);
    verifiedDeltaVertices := verifiedDeltaVertices + 1;
  od;
  M23DatabaseDeltaVerifyEvent("progress", Concatenation("certificate=",
    String(certificateId - baseStats.certificates), "/",
    String(stats.certificates - baseStats.certificates), ",ledger=",
    String(baseStats.vertices + verifiedDeltaVertices)));
od;
Assert(0, baseStats.vertices + verifiedDeltaVertices = stats.vertices);
Assert(0, [verifiedClosed, verifiedOverflow, verifiedLinked] =
  [stats.closed - baseStats.closed, stats.overflow - baseStats.overflow,
   stats.linked - baseStats.linked]);

blocks := M23QuotientLedgerBlocks(database);;
Assert(0, Length(blocks) = stats.blocks);
verifiedRefined := 0;; verifiedGenerating := 0;; verifiedHits := 0;;
for blockRecord in blocks{[baseStats.blocks + 1..stats.blocks]} do
  block := M23DecodeMacroblock(pairCheckpoint, blockRecord.ordinal);
  refinement := M23CachedDirectPairTwistRefinement(locator, block);
  Assert(0, Length(refinement.twist_orbits) = blockRecord.refined_vertices);
  blockGenerating := 0;;
  for twistId in [1..Length(refinement.twist_orbits)] do
    materializedIndex := refinement.twist_orbits[twistId][1];
    seed := refinement.materialized.tuples[materializedIndex];
    if IsGeneratingTuple(G, seed) then
      blockGenerating := blockGenerating + 1;
      Assert(0, LookupDictionary(ledger, [blockRecord.ordinal, twistId]) <> fail);
    fi;
  od;
  Assert(0, blockGenerating = blockRecord.generating_vertices);
  seedCount := LookupDictionary(seedCounts, blockRecord.ordinal);
  if seedCount = fail then seedCount := 0; fi;
  Assert(0, seedCount = blockRecord.new_certificates);
  Assert(0, blockRecord.ledger_hits = blockGenerating - seedCount);
  verifiedRefined := verifiedRefined + blockRecord.refined_vertices;
  verifiedGenerating := verifiedGenerating + blockGenerating;
  verifiedHits := verifiedHits + blockRecord.ledger_hits;
od;
Assert(0, baseStats.refined_vertices + verifiedRefined = stats.refined_vertices);
Assert(0, baseStats.generating_vertices + verifiedGenerating =
  stats.generating_vertices);
Assert(0, baseStats.ledger_hits + verifiedHits = stats.ledger_hits);

M23CloseQuotientLedger(baseDatabase);;
M23CloseQuotientLedger(database);;
M23DatabaseDeltaVerifyEvent("done", Concatenation("certificates=",
  String(stats.certificates), ",blocks=", String(stats.blocks), ",vertices=",
  String(stats.vertices), ",base_certificates=",
  String(baseStats.certificates), ",base_blocks=", String(baseStats.blocks),
  ",base_vertices=", String(baseStats.vertices)));
Print("verified database quotient delta base_blocks=", baseStats.blocks,
  " blocks=", stats.blocks, " base_certificates=", baseStats.certificates,
  " certificates=", stats.certificates, " vertices=", stats.vertices, "\n");
QUIT;
