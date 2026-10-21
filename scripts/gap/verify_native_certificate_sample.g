Read("src/gap/m23_homogeneous_macroblocks.g");;
Read("src/gap/m23_quotient_ledger.g");;
Read("src/gap/m23_native_coordinates.g");;
SizeScreen([1000000, 1000000]);;

pairPath := GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT;;
databasePath := GAPInfo.SystemEnvironment.M23_LEDGER_DB;;
planPath := GAPInfo.SystemEnvironment.M23_AUDIT_PLAN;;
planId := GAPInfo.SystemEnvironment.M23_AUDIT_PLAN_ID;;
resultPath := GAPInfo.SystemEnvironment.M23_AUDIT_RESULT;;
progressPath := GAPInfo.SystemEnvironment.M23_PROGRESS_FILE;;
segmentIndex := Int(GAPInfo.SystemEnvironment.M23_SEGMENT_INDEX);;
segmentCount := Int(GAPInfo.SystemEnvironment.M23_SEGMENT_COUNT);;
item := Concatenation(String(segmentIndex), "-of-", String(segmentCount));;

lines := SplitString(StringFile(planPath), "\n");;
metadata := NewDictionary("", true);;
rows := [];;
blockRows := [];;
for line in lines do
  if line = "" then
    continue;
  fi;
  fields := SplitString(line, "\t");
  if Length(fields) = 2 and Length(fields[1]) >= 3 and
      fields[1]{[1..2]} = "# " then
    AddDictionary(metadata, fields[1]{[3..Length(fields[1])]}, fields[2]);
  elif Length(fields) = 5 and fields[1] = "C" then
    Add(rows, rec(index := Int(fields[2]), certificate := Int(fields[3]),
      status := fields[4], selection := fields[5]));
  elif Length(fields) = 4 and fields[1] = "B" then
    Add(blockRows, rec(index := Int(fields[2]), ordinal := Int(fields[3]),
      selection := fields[4]));
  else
    Error("invalid independent native GAP audit plan row");
  fi;
od;
if LookupDictionary(metadata, "schema") <>
      "m23-independent-native-gap-audit-plan-v1" or
    LookupDictionary(metadata, "plan_sha256") <> planId or
    Length(rows) <> Int(LookupDictionary(metadata,
      "selected_certificates")) or
    Length(blockRows) <> Int(LookupDictionary(metadata,
      "selected_blocks")) or
    Int(LookupDictionary(metadata, "audit_jobs")) <> segmentCount or
    segmentIndex < 1 or segmentIndex > segmentCount then
  Error("invalid independent native GAP audit plan metadata");
fi;
for position in [1..Length(rows)] do
  if rows[position].index <> position then
    Error("noncontiguous independent native GAP audit plan");
  fi;
od;
for position in [1..Length(blockRows)] do
  if blockRows[position].index <> position then
    Error("noncontiguous independent native GAP block plan");
  fi;
od;

M23_PAIR_BLOCK_CHECKPOINT := fail;;
Read(pairPath);;
pairCheckpoint := M23_PAIR_BLOCK_CHECKPOINT;;
config := rec(
  target_order := Int(LookupDictionary(metadata, "target_order")),
  pair_schema := Int(LookupDictionary(metadata, "pair_schema")),
  macroblock_count := Int(LookupDictionary(metadata, "macroblock_count")),
  first_ordinal := 1,
  last_ordinal := Int(LookupDictionary(metadata, "macroblock_count")),
  proof_limit := Int(LookupDictionary(metadata, "proof_limit")),
  walk_limit := Int(LookupDictionary(metadata, "walk_limit")),
  schedule := LookupDictionary(metadata, "schedule"),
  start_ordinal := Int(LookupDictionary(metadata, "start_ordinal")),
  traversal_order := "native-v1"
);;
database := M23OpenReadOnlyQuotientLedger(databasePath, config);;
stats := M23QuotientLedgerStats(database);;
if stats.certificates <> Int(LookupDictionary(metadata, "certificates")) or
    stats.vertices <> Int(LookupDictionary(metadata, "vertices")) then
  Error("native ledger changed after independent audit planning");
fi;

G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
locator := M23BuildDirectPairLocator(G, classes, pairCheckpoint);;
adapter := M23CreateNativePairTwistAdapter(locator);;
selected := Filtered(rows, row ->
  (row.index - 1) mod segmentCount = segmentIndex - 1);;
selectedBlocks := Filtered(blockRows, row ->
  (row.index - 1) mod segmentCount = segmentIndex - 1);;
verifiedClosed := 0;; verifiedOverflow := 0;; verifiedLinked := 0;;
verifiedVertices := 0;;
verifiedBlocks := 0;; verifiedRefined := 0;; verifiedGenerating := 0;;
prefixLimit := 0;;
PrintTo(resultPath, "M\t", planId, "\t", segmentIndex, "\t",
  segmentCount, "\t", Length(selected), "\t", Length(selectedBlocks),
  "\n");
AppendTo(progressPath, IO_gettimeofday().tv_sec,
  "\tgap\tverify_native_certificate_sample\t", item,
  "\tstart\tplan=", planId, ",certificates=", Length(selected), "\n");

for position in [1..Length(selected)] do
  row := selected[position];
  certificate := M23QuotientLedgerCertificate(database, row.certificate);
  if certificate.status <> row.status or
      certificate.seed_vertex <> certificate.vertices[1] or
      M23QuotientLedgerLookupBefore(database, certificate.seed_vertex,
        row.certificate - 1) <> fail then
    Error("invalid native certificate seed or planned status");
  fi;
  seed := M23NativePairTwistSeed(adapter, certificate.seed_vertex[1],
    certificate.seed_vertex[2]);
  if not IsGeneratingTuple(G, seed) then
    Error("native certificate seed fails independent GAP generation");
  fi;
  prefixLimit := row.certificate - 1;
  replay := M23BoundedNativePairTwistOrbitWithLedger(adapter, seed,
    config.walk_limit, function(checked, discovered, classesFound) end,
    key -> M23QuotientLedgerLookupBefore(database, key,
      prefixLimit));
  replayKeys := List(replay.vertices, vertex ->
    [vertex.block.ordinal, vertex.native_twist_id]);
  if replay.status = "linked" then
    expectedStatus := "linked";
  elif replay.status = "closed" and
      replay.discovered_class_count <= config.proof_limit then
    expectedStatus := "closed";
  else
    expectedStatus := "overflow";
  fi;
  if expectedStatus <> certificate.status or
      replay.status <> certificate.walk_status or
      replay.linked_certificate <> certificate.linked_certificate or
      replay.checked_vertex_count <> certificate.checked_vertex_count or
      replay.discovered_vertex_count <> certificate.discovered_vertex_count or
      replay.discovered_class_count <> certificate.discovered_class_count or
      replayKeys <> certificate.vertices then
    Error(Concatenation("independent native GAP mismatch at certificate ",
      String(row.certificate)));
  fi;
  if certificate.status = "closed" then
    verifiedClosed := verifiedClosed + 1;
  elif certificate.status = "overflow" then
    verifiedOverflow := verifiedOverflow + 1;
  else
    verifiedLinked := verifiedLinked + 1;
  fi;
  verifiedVertices := verifiedVertices + Length(replayKeys);
  if certificate.linked_certificate = fail then
    linkedOutput := 0;
  else
    linkedOutput := certificate.linked_certificate;
  fi;
  AppendTo(resultPath, "V\t", row.index, "\t", row.certificate, "\t",
    certificate.status, "\t", Length(replayKeys), "\t",
    replay.discovered_class_count, "\t", linkedOutput, "\n");
  AppendTo(progressPath, IO_gettimeofday().tv_sec,
    "\tgap\tverify_native_certificate_sample\t", item,
    "\tprogress\tplan=", planId, ",certificate=", row.certificate,
    ",done=", position, ",total=", Length(selected), "\n");
od;

for position in [1..Length(selectedBlocks)] do
  row := selectedBlocks[position];
  storedBlock := M23QuotientLedgerBlock(database, row.ordinal);
  block := M23DecodeMacroblock(pairCheckpoint, row.ordinal);
  nativeMap := M23NativePairTwistMap(adapter, block);
  refinedCount := Length(nativeMap.rows);
  generatingCount := 0;
  for nativeTwistId in [1..refinedCount] do
    gapTwistId := nativeMap.native_to_gap[nativeTwistId];
    materializedIndex := nativeMap.refinement.twist_orbits[gapTwistId][1];
    representative :=
      nativeMap.refinement.materialized.tuples[materializedIndex];
    if IsGeneratingTuple(G, representative) then
      generatingCount := generatingCount + 1;
      if M23QuotientLedgerLookup(database,
          [row.ordinal, nativeTwistId]) = fail then
        Error("sampled generating native vertex has no final ownership");
      fi;
    fi;
  od;
  if storedBlock.refined_vertices <> refinedCount or
      storedBlock.generating_vertices <> generatingCount or
      storedBlock.actual_seed_certificates <> storedBlock.new_certificates or
      storedBlock.new_certificates + storedBlock.ledger_hits <>
        generatingCount then
    Error(Concatenation("independent native GAP block mismatch at ordinal ",
      String(row.ordinal)));
  fi;
  verifiedBlocks := verifiedBlocks + 1;
  verifiedRefined := verifiedRefined + refinedCount;
  verifiedGenerating := verifiedGenerating + generatingCount;
  AppendTo(resultPath, "B\t", row.index, "\t", row.ordinal, "\t",
    refinedCount, "\t", generatingCount, "\t",
    storedBlock.new_certificates, "\t", storedBlock.ledger_hits, "\n");
  AppendTo(progressPath, IO_gettimeofday().tv_sec,
    "\tgap\tverify_native_certificate_sample\t", item,
    "\tprogress\tplan=", planId, ",block=", row.ordinal,
    ",block_done=", position, ",block_total=", Length(selectedBlocks),
    "\n");
od;
M23CloseQuotientLedger(database);;
AppendTo(resultPath, "R\t", planId, "\t", segmentIndex, "\t",
  segmentCount, "\t", Length(selected), "\t", verifiedClosed, "\t",
  verifiedOverflow, "\t", verifiedLinked, "\t", verifiedVertices, "\t",
  verifiedBlocks, "\t", verifiedRefined, "\t", verifiedGenerating, "\n");
AppendTo(progressPath, IO_gettimeofday().tv_sec,
  "\tgap\tverify_native_certificate_sample\t", item,
  "\tdone\tplan=", planId, ",certificates=", Length(selected),
  ",vertices=", verifiedVertices, "\n");
Print("verified independent native GAP sample ", item,
  " certificates=", Length(selected), " vertices=", verifiedVertices, "\n");
QUIT;
