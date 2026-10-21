Read("src/gap/m23_homogeneous_macroblocks.g");;
SizeScreen([1000000, 1000000]);;
LoadPackage("io");;

progressPath := fail;;
if IsBound(GAPInfo.SystemEnvironment.M23_PROGRESS_FILE) then
  progressPath := GAPInfo.SystemEnvironment.M23_PROGRESS_FILE;
fi;
M23VerifyScanEvent := function(state, detail)
  if progressPath <> fail then
    AppendTo(progressPath, IO_gettimeofday().tv_sec,
      "\tgap\tverify_quotient_scan\tall\t", state, "\t", detail, "\n");
  fi;
end;;

M23_PAIR_BLOCK_CHECKPOINT := fail;;
Read(GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT);
pairCheckpoint := M23_PAIR_BLOCK_CHECKPOINT;;
M23_QUOTIENT_SCAN_CHECKPOINT := fail;;
Read(GAPInfo.SystemEnvironment.M23_SCAN_CHECKPOINT);
scan := M23_QUOTIENT_SCAN_CHECKPOINT;;

if scan = fail or not scan.schema_version in [1, 2, 3] or
   scan.target_order <> pairCheckpoint.target_order or
   scan.pair_schema_version <> pairCheckpoint.schema_version or
   scan.macroblock_count <> pairCheckpoint.macroblock_count then
  Error("invalid direct quotient scan checkpoint");
fi;
if scan.schema_version = 1 then
  Assert(0, scan.next_ordinal =
    scan.first_ordinal + scan.scanned_macroblock_count);
  Assert(0, scan.next_ordinal <= scan.last_ordinal + 1);
  if scan.scanned_macroblock_count = 0 then
    processedOrdinals := [];
  else
    processedOrdinals := [scan.first_ordinal..scan.next_ordinal - 1];
  fi;
else
  Assert(0, scan.schedule in ["sequential", "frontier"]);
  Assert(0, Length(scan.processed_ordinals) =
    scan.scanned_macroblock_count);
  Assert(0, Length(scan.processed_sources) =
    scan.scanned_macroblock_count);
  Assert(0, Length(Set(scan.processed_ordinals)) =
    Length(scan.processed_ordinals));
  Assert(0, ForAll(scan.processed_ordinals, ordinal ->
    ordinal >= scan.first_ordinal and ordinal <= scan.last_ordinal));
  Assert(0, ForAll(scan.processed_sources, source ->
    source in ["ordinal", "frontier"]));
  Assert(0, Number(scan.processed_sources, source -> source = "frontier") =
    scan.frontier_macroblock_count);
  Assert(0, scan.covered_macroblock_count = Number(scan.processed_ordinals,
    ordinal -> ForAll(scan.certificates, certificate ->
      certificate.seed_vertex[1] <> ordinal)));
  processedOrdinals := scan.processed_ordinals;
fi;
if scan.schema_version = 3 then
  Assert(0, scan.walk_limit >= scan.limit);
  replayLimit := scan.walk_limit;
else
  replayLimit := scan.limit;
fi;

G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
locator := M23BuildDirectPairLocator(G, classes, pairCheckpoint);;
ledger := NewDictionary([1, 1], true);;
verifiedLedgerCount := 0;;
M23VerifyScanEvent("start", Concatenation("certificates=",
  String(Length(scan.certificates)), ",blocks=",
  String(scan.scanned_macroblock_count)));

for certificateId in [1..Length(scan.certificates)] do
  certificate := scan.certificates[certificateId];
  Assert(0, certificate.certificate_id = certificateId);
  Assert(0, certificate.status in ["closed", "overflow", "linked"]);
  Assert(0, certificate.discovered_vertex_count =
    Length(certificate.vertices));
  Assert(0, certificate.seed_vertex = certificate.vertices[1]);
  if certificate.status = "closed" then
    Assert(0, certificate.linked_certificate = fail);
    Assert(0, certificate.discovered_class_count <= scan.limit);
  elif certificate.status = "overflow" then
    Assert(0, certificate.linked_certificate = fail);
    Assert(0, certificate.discovered_class_count > scan.limit);
  else
    Assert(0, IsInt(certificate.linked_certificate));
    Assert(0, certificate.linked_certificate >= 1 and
      certificate.linked_certificate < certificateId);
  fi;

  seedBlock := M23DecodeMacroblock(pairCheckpoint,
    certificate.seed_vertex[1]);
  seedRefinement := M23CachedDirectPairTwistRefinement(locator, seedBlock);
  seedIndex := seedRefinement.twist_orbits[certificate.seed_vertex[2]][1];
  seed := seedRefinement.materialized.tuples[seedIndex];
  Assert(0, IsGeneratingTuple(G, seed));
  replay := M23BoundedDirectPairTwistOrbitWithLedger(locator, seed,
    replayLimit, function(checked, discovered, classesFound) end,
    key -> LookupDictionary(ledger, key));
  replayKeys := List(replay.vertices, vertex ->
    [vertex.block.ordinal, vertex.twist_id]);
  if scan.schema_version = 3 then
    Assert(0, replay.status = certificate.walk_status);
    if replay.status = "linked" then
      expectedStatus := "linked";
    elif replay.status = "closed" and
         replay.discovered_class_count <= scan.limit then
      expectedStatus := "closed";
    else
      expectedStatus := "overflow";
    fi;
    Assert(0, certificate.status = expectedStatus);
  else
    Assert(0, replay.status = certificate.status);
  fi;
  Assert(0, replay.linked_certificate = certificate.linked_certificate);
  Assert(0, replay.checked_vertex_count = certificate.checked_vertex_count);
  Assert(0, replay.discovered_class_count =
    certificate.discovered_class_count);
  Assert(0, Set(replayKeys) = Set(certificate.vertices));

  for key in certificate.vertices do
    Assert(0, LookupDictionary(ledger, key) = fail);
    AddDictionary(ledger, key, certificateId);
    verifiedLedgerCount := verifiedLedgerCount + 1;
  od;
  M23VerifyScanEvent("progress", Concatenation("certificate=",
    String(certificateId), "/", String(Length(scan.certificates)),
    ",ledger=", String(verifiedLedgerCount)));
od;
Assert(0, verifiedLedgerCount = scan.ledger_vertex_count);

verifiedRefinedCount := 0;;
verifiedGeneratingCount := 0;;
verifiedHitCount := 0;;
if scan.scanned_macroblock_count > 0 then
  for ordinal in processedOrdinals do
    block := M23DecodeMacroblock(pairCheckpoint, ordinal);
    refinement := M23CachedDirectPairTwistRefinement(locator, block);
    verifiedRefinedCount := verifiedRefinedCount +
      Length(refinement.twist_orbits);
    for twistId in [1..Length(refinement.twist_orbits)] do
      materializedIndex := refinement.twist_orbits[twistId][1];
      seed := refinement.materialized.tuples[materializedIndex];
      if IsGeneratingTuple(G, seed) then
        verifiedGeneratingCount := verifiedGeneratingCount + 1;
        Assert(0, LookupDictionary(ledger, [ordinal, twistId]) <> fail);
        verifiedHitCount := verifiedHitCount + 1;
      fi;
    od;
  od;
fi;
Assert(0, verifiedRefinedCount = scan.refined_vertex_count);
Assert(0, verifiedGeneratingCount = scan.generating_vertex_count);
Assert(0, verifiedHitCount =
  scan.generating_vertex_count);

Print("verified quotient scan processed=", scan.scanned_macroblock_count,
  " certificates=", Length(scan.certificates),
  " ledger=", scan.ledger_vertex_count, "\n");
M23VerifyScanEvent("done", Concatenation("certificates=",
  String(Length(scan.certificates)), ",blocks=",
  String(scan.scanned_macroblock_count), ",ledger=",
  String(scan.ledger_vertex_count)));
QUIT;
