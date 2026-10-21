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
firstCertificate := Int(GAPInfo.SystemEnvironment.M23_FIRST_CERTIFICATE);;
lastCertificate := Int(GAPInfo.SystemEnvironment.M23_LAST_CERTIFICATE);;
planId := GAPInfo.SystemEnvironment.M23_VERIFICATION_PLAN;;
progressPath := GAPInfo.SystemEnvironment.M23_PROGRESS_FILE;;
item := Concatenation(String(segmentIndex), "-of-", String(segmentCount));;
cacheResetInterval := 1000;;
cacheResets := 0;;
lookupMode := "database";;
traversalOrder := "key-v2";;
if IsBound(GAPInfo.SystemEnvironment.M23_CACHE_RESET_INTERVAL) then
  cacheResetInterval :=
    Int(GAPInfo.SystemEnvironment.M23_CACHE_RESET_INTERVAL);
fi;
if IsBound(GAPInfo.SystemEnvironment.M23_REPLAY_LOOKUP_MODE) then
  lookupMode := GAPInfo.SystemEnvironment.M23_REPLAY_LOOKUP_MODE;
fi;
if IsBound(GAPInfo.SystemEnvironment.M23_TRAVERSAL_ORDER) then
  traversalOrder := GAPInfo.SystemEnvironment.M23_TRAVERSAL_ORDER;
fi;
Assert(0, cacheResetInterval >= 0);
Assert(0, lookupMode in ["database", "memory"]);
Assert(0, traversalOrder in ["legacy", "key-v1", "key-v2"]);

M23CertificateSegmentEvent := function(state, detail)
  AppendTo(progressPath, IO_gettimeofday().tv_sec,
    "\tgap\tverify_quotient_certificate_segment\t", item, "\t", state,
    "\tplan=", planId, ",", detail, "\n");
end;;

config := rec(target_order := pairCheckpoint.target_order,
  pair_schema := pairCheckpoint.schema_version,
  macroblock_count := pairCheckpoint.macroblock_count,
  first_ordinal := firstOrdinal, last_ordinal := lastOrdinal,
  proof_limit := limit, walk_limit := walkLimit, schedule := schedule,
  start_ordinal := startOrdinal, traversal_order := traversalOrder);;
database := M23OpenReadOnlyQuotientLedger(databasePath, config);;
stats := M23QuotientLedgerStats(database);;
Assert(0, segmentIndex >= 1 and segmentIndex <= segmentCount and
  firstCertificate >= 1 and lastCertificate >= firstCertificate and
  lastCertificate <= stats.certificates);
prefix := M23QuotientLedgerCertificatePrefixStats(database,
  firstCertificate - 1);;
target := M23QuotientLedgerCertificatePrefixStats(database, lastCertificate);;
Assert(0, prefix.certificates = firstCertificate - 1 and
  target.certificates = lastCertificate);
M23CertificateSegmentEvent("start", Concatenation("first=",
  String(firstCertificate), ",last=", String(lastCertificate),
  ",prefix_vertices=", String(prefix.vertices), ",cache_reset_interval=",
  String(cacheResetInterval), ",lookup_mode=", lookupMode,
  ",traversal_order=", traversalOrder));

G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
locator := M23BuildDirectPairLocator(G, classes, pairCheckpoint);;
locator.traversal_order := traversalOrder;;
if lookupMode = "memory" then
  ledger := NewDictionary([1, 1], true);;
  prefixVertices := M23QuotientLedgerVerticesThrough(database,
    firstCertificate - 1);;
  Assert(0, Length(prefixVertices) = prefix.vertices);
  for vertex in prefixVertices do
    AddDictionary(ledger, vertex{[1, 2]}, vertex[3]);
  od;
  prefixVertices := fail;;
else
  ledger := fail;;
fi;
verifiedVertices := 0;; verifiedClosed := 0;;
verifiedOverflow := 0;; verifiedLinked := 0;;

for certificateId in [firstCertificate..lastCertificate] do
  certificate := M23QuotientLedgerCertificate(database, certificateId);
  Assert(0, certificate.discovered_vertex_count = Length(certificate.vertices));
  Assert(0, certificate.seed_vertex = certificate.vertices[1]);
  if certificate.status = "closed" then
    verifiedClosed := verifiedClosed + 1;
    Assert(0, certificate.linked_certificate = fail and
      certificate.discovered_class_count <= limit);
  elif certificate.status = "overflow" then
    verifiedOverflow := verifiedOverflow + 1;
    Assert(0, certificate.linked_certificate = fail and
      certificate.discovered_class_count > limit);
  else
    verifiedLinked := verifiedLinked + 1;
    Assert(0, certificate.status = "linked" and
      IsInt(certificate.linked_certificate) and
      certificate.linked_certificate < certificateId);
  fi;
  seedBlock := M23DecodeMacroblock(pairCheckpoint, certificate.seed_vertex[1]);
  seedRefinement := M23CachedDirectPairTwistRefinement(locator, seedBlock);
  seedIndex := seedRefinement.twist_orbits[certificate.seed_vertex[2]][1];
  seed := seedRefinement.materialized.tuples[seedIndex];
  Assert(0, IsGeneratingTuple(G, seed));
  if lookupMode = "memory" then
    replay := M23BoundedDirectPairTwistOrbitWithLedger(locator, seed,
      walkLimit, function(checked, discovered, classesFound) end,
      key -> LookupDictionary(ledger, key));
  else
    Assert(0, M23QuotientLedgerLookupBefore(database,
      certificate.seed_vertex, certificateId - 1) = fail);
    replay := M23BoundedDirectPairTwistOrbitWithLedger(locator, seed,
      walkLimit, function(checked, discovered, classesFound) end,
      key -> M23QuotientLedgerLookupBefore(database, key,
        certificateId - 1));
  fi;
  replayKeys := List(replay.vertices, vertex ->
    [vertex.block.ordinal, vertex.twist_id]);
  Assert(0, replay.status = certificate.walk_status);
  if replay.status = "linked" then expectedStatus := "linked";
  elif replay.status = "closed" and replay.discovered_class_count <= limit then
    expectedStatus := "closed";
  else expectedStatus := "overflow";
  fi;
  Assert(0, certificate.status = expectedStatus and
    replay.linked_certificate = certificate.linked_certificate and
    replay.checked_vertex_count = certificate.checked_vertex_count and
    replay.discovered_class_count = certificate.discovered_class_count);
  if Set(replayKeys) <> Set(certificate.vertices) then
    Error(Concatenation("certificate replay vertex mismatch at certificate ",
      String(certificateId), " in lookup mode ", lookupMode));
  fi;
  if lookupMode = "memory" then
    for key in certificate.vertices do
      Assert(0, LookupDictionary(ledger, key) = fail);
      AddDictionary(ledger, key, certificateId);
    od;
  fi;
  verifiedVertices := verifiedVertices + Length(certificate.vertices);
  if cacheResetInterval > 0 and
      (certificateId - firstCertificate + 1) mod cacheResetInterval = 0 then
    M23ResetDirectPairBlockCaches(locator);
    GASMAN("collect");
    cacheResets := cacheResets + 1;
  fi;
  if certificateId mod 100 = 0 then
    M23CertificateSegmentEvent("progress", Concatenation("certificate=",
      String(certificateId), ",vertices=", String(verifiedVertices)));
  fi;
od;
Assert(0, verifiedVertices = target.vertices - prefix.vertices and
  verifiedClosed = target.closed - prefix.closed and
  verifiedOverflow = target.overflow - prefix.overflow and
  verifiedLinked = target.linked - prefix.linked);
M23CloseQuotientLedger(database);;
M23CertificateSegmentEvent("done", Concatenation("first=",
  String(firstCertificate), ",last=", String(lastCertificate),
  ",certificates=", String(lastCertificate - firstCertificate + 1),
  ",closed=", String(verifiedClosed), ",overflow=",
  String(verifiedOverflow), ",linked=", String(verifiedLinked),
  ",vertices=", String(verifiedVertices), ",cache_resets=",
  String(cacheResets), ",lookup_mode=", lookupMode,
  ",traversal_order=", traversalOrder));
Print("verified certificate segment ", item, " first=", firstCertificate,
  " last=", lastCertificate, " vertices=", verifiedVertices, "\n");
QUIT;
