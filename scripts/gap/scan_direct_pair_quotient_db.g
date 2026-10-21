Read("src/gap/m23_homogeneous_macroblocks.g");;
Read("src/gap/m23_quotient_ledger.g");;
SizeScreen([1000000, 1000000]);;

pairPath := GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT;;
databasePath := GAPInfo.SystemEnvironment.M23_LEDGER_DB;;
firstOrdinal := Int(GAPInfo.SystemEnvironment.M23_FIRST_ORDINAL);;
lastOrdinal := Int(GAPInfo.SystemEnvironment.M23_LAST_ORDINAL);;
limit := Int(GAPInfo.SystemEnvironment.M23_ORBIT_LIMIT);;
walkLimit := Int(GAPInfo.SystemEnvironment.M23_WALK_LIMIT);;
schedule := GAPInfo.SystemEnvironment.M23_SCAN_SCHEDULE;;
startOrdinal := Int(GAPInfo.SystemEnvironment.M23_START_ORDINAL);;
blockBudget := Int(GAPInfo.SystemEnvironment.M23_BLOCK_BUDGET);;
progressPath := GAPInfo.SystemEnvironment.M23_PROGRESS_FILE;;
workerId := fail;;
leaseSeconds := 300;;
globalBlockTarget := 0;;
shardIndex := 1;;
shardCount := 1;;
profileInterval := 0;;
progressInterval := 1;;
cacheResetInterval := 0;;
cacheResets := 0;;
traversalOrder := "key-v2";;
profile := rec(
  claim_ms := 0,
  refine_ms := 0,
  seed_ms := 0,
  walk_ms := 0,
  commit_ms := 0,
  finish_ms := 0,
  traversals := 0
);;
if IsBound(GAPInfo.SystemEnvironment.M23_WORKER_ID) then
  workerId := GAPInfo.SystemEnvironment.M23_WORKER_ID;
fi;
if IsBound(GAPInfo.SystemEnvironment.M23_LEASE_SECONDS) then
  leaseSeconds := Int(GAPInfo.SystemEnvironment.M23_LEASE_SECONDS);
fi;
if IsBound(GAPInfo.SystemEnvironment.M23_GLOBAL_BLOCK_TARGET) then
  globalBlockTarget := Int(GAPInfo.SystemEnvironment.M23_GLOBAL_BLOCK_TARGET);
fi;
if IsBound(GAPInfo.SystemEnvironment.M23_SHARD_INDEX) then
  shardIndex := Int(GAPInfo.SystemEnvironment.M23_SHARD_INDEX);
fi;
if IsBound(GAPInfo.SystemEnvironment.M23_SHARD_COUNT) then
  shardCount := Int(GAPInfo.SystemEnvironment.M23_SHARD_COUNT);
fi;
if IsBound(GAPInfo.SystemEnvironment.M23_PROFILE_INTERVAL) then
  profileInterval := Int(GAPInfo.SystemEnvironment.M23_PROFILE_INTERVAL);
fi;
if IsBound(GAPInfo.SystemEnvironment.M23_PROGRESS_INTERVAL) then
  progressInterval := Int(GAPInfo.SystemEnvironment.M23_PROGRESS_INTERVAL);
fi;
if IsBound(GAPInfo.SystemEnvironment.M23_CACHE_RESET_INTERVAL) then
  cacheResetInterval :=
    Int(GAPInfo.SystemEnvironment.M23_CACHE_RESET_INTERVAL);
fi;
if IsBound(GAPInfo.SystemEnvironment.M23_TRAVERSAL_ORDER) then
  traversalOrder := GAPInfo.SystemEnvironment.M23_TRAVERSAL_ORDER;
fi;

M23_PAIR_BLOCK_CHECKPOINT := fail;;
Read(pairPath);
pairCheckpoint := M23_PAIR_BLOCK_CHECKPOINT;;
if firstOrdinal < 1 or lastOrdinal < firstOrdinal or
   lastOrdinal > pairCheckpoint.macroblock_count or limit < 1 or
   walkLimit < limit or not schedule in ["sequential", "frontier"] or
   startOrdinal < firstOrdinal or startOrdinal > lastOrdinal or
   blockBudget < 1 or shardCount < 1 or shardIndex < 0 or
   shardIndex > shardCount or profileInterval < 0 or progressInterval < 1 or
   cacheResetInterval < 0 or
   not traversalOrder in ["legacy", "key-v1", "key-v2"] then
  Error("invalid database quotient scan configuration");
fi;

M23DatabaseScanEvent := function(state, detail)
  AppendTo(progressPath, IO_gettimeofday().tv_sec,
    "\tgap\tquotient_db_scan\t", firstOrdinal, "-", lastOrdinal,
    "\t", state, "\t", detail, "\n");
end;;

config := rec(
  target_order := pairCheckpoint.target_order,
  pair_schema := pairCheckpoint.schema_version,
  macroblock_count := pairCheckpoint.macroblock_count,
  first_ordinal := firstOrdinal,
  last_ordinal := lastOrdinal,
  proof_limit := limit,
  walk_limit := walkLimit,
  schedule := schedule,
  start_ordinal := startOrdinal,
  traversal_order := traversalOrder
);;
ledger := M23OpenQuotientLedger(databasePath, config);;
initialStats := M23QuotientLedgerStats(ledger);;
M23DatabaseScanEvent("start", Concatenation("schedule=", schedule,
  ",start=", String(startOrdinal), ",budget=", String(blockBudget),
  ",proof_limit=", String(limit), ",walk_limit=", String(walkLimit),
  ",profile_interval=", String(profileInterval),
  ",progress_interval=", String(progressInterval),
  ",cache_reset_interval=", String(cacheResetInterval),
  ",traversal_order=", traversalOrder,
  ",worker=", String(workerId),
  ",shard=", String(shardIndex), "/", String(shardCount),
  ",prior_blocks=", String(initialStats.blocks), ",prior_vertices=",
  String(initialStats.vertices)));

G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
locator := M23BuildDirectPairLocator(G, classes, pairCheckpoint);;
locator.traversal_order := traversalOrder;;
invocationCount := 0;;
exhausted := false;;
ordinal := fail;;

while invocationCount < blockBudget do
  if profileInterval > 0 then phaseStarted := Runtime(); fi;
  if workerId = fail then
    scheduled := M23QuotientLedgerNextBlock(ledger);
  else
    scheduled := M23QuotientLedgerClaimBlock(ledger, workerId, leaseSeconds,
      globalBlockTarget, shardIndex, shardCount);
  fi;
  if profileInterval > 0 then
    profile.claim_ms := profile.claim_ms + Runtime() - phaseStarted;
  fi;
  if scheduled = "wait" then
    IO_select([], [], [], 1, 0);
    continue;
  fi;
  if scheduled = fail then
    exhausted := true;
    break;
  fi;
  ordinal := scheduled[1];
  source := scheduled[2];
  if profileInterval > 0 then phaseStarted := Runtime(); fi;
  block := M23DecodeMacroblock(pairCheckpoint, ordinal);
  refinement := M23CachedDirectPairTwistRefinement(locator, block);
  # Dense refinement and generation-only stretches can outlive a lease even
  # when the later orbit walk renews correctly. Keep ownership alive across
  # every phase of a long block, not only while traversing a new component.
  if workerId <> fail then
    M23QuotientLedgerRenewLease(ledger, workerId, ordinal, leaseSeconds);
  fi;
  if profileInterval > 0 then
    profile.refine_ms := profile.refine_ms + Runtime() - phaseStarted;
  fi;
  refinedCount := Length(refinement.twist_orbits);
  generatingCount := 0;
  for twistId in [1..Length(refinement.twist_orbits)] do
    if workerId <> fail and twistId mod 100 = 1 then
      M23QuotientLedgerRenewLease(ledger, workerId, ordinal, leaseSeconds);
    fi;
    key := [ordinal, twistId];
    materializedIndex := refinement.twist_orbits[twistId][1];
    seed := refinement.materialized.tuples[materializedIndex];
    if profileInterval > 0 then phaseStarted := Runtime(); fi;
    if IsGeneratingTuple(G, seed) then
      generatingCount := generatingCount + 1;
      knownCertificate := M23QuotientLedgerLookup(ledger, key);
      if profileInterval > 0 then
        profile.seed_ms := profile.seed_ms + Runtime() - phaseStarted;
      fi;
      if knownCertificate = fail then
        retry := true;
        while retry do
        knownCertificate := M23QuotientLedgerLookup(ledger, key);
        if knownCertificate <> fail then
          retry := false;
          break;
        fi;
        if workerId <> fail then
          M23QuotientLedgerRenewLease(ledger, workerId, ordinal, leaseSeconds);
        fi;
        if profileInterval > 0 then phaseStarted := Runtime(); fi;
        traversal := M23BoundedDirectPairTwistOrbitWithLedger(locator, seed,
          walkLimit,
          function(checked, discovered, classesFound)
            if checked mod 100 = 0 then
              if workerId <> fail then
                M23QuotientLedgerRenewLease(ledger, workerId, ordinal,
                  leaseSeconds);
              fi;
              M23DatabaseScanEvent("walk", Concatenation("block=",
                String(ordinal), ",twist=", String(twistId), ",checked=",
                String(checked), ",vertices=", String(discovered),
                ",classes=", String(classesFound)));
            fi;
          end,
          candidate -> M23QuotientLedgerLookup(ledger, candidate));
        if profileInterval > 0 then
          profile.walk_ms := profile.walk_ms + Runtime() - phaseStarted;
          profile.traversals := profile.traversals + 1;
        fi;
        if traversal.status = "linked" then
          certificateStatus := "linked";
        elif traversal.status = "closed" and
             traversal.discovered_class_count <= limit then
          certificateStatus := "closed";
        else
          certificateStatus := "overflow";
        fi;
        vertexKeys := List(traversal.vertices, vertex ->
          [vertex.block.ordinal, vertex.twist_id]);
        certificate := rec(
          status := certificateStatus,
          walk_status := traversal.status,
          linked_certificate := traversal.linked_certificate,
          seed_vertex := key,
          checked_vertex_count := traversal.checked_vertex_count,
          discovered_vertex_count := traversal.discovered_vertex_count,
          discovered_class_count := traversal.discovered_class_count
        );
        if profileInterval > 0 then phaseStarted := Runtime(); fi;
        if workerId = fail then
          certificateId := M23QuotientLedgerAddCertificate(ledger,
            certificate, vertexKeys);
          retry := false;
        else
          commit := M23QuotientLedgerTryAddCertificate(ledger, workerId,
            ordinal, certificate, vertexKeys);
          if profileInterval > 0 then
            profile.commit_ms := profile.commit_ms + Runtime() - phaseStarted;
          fi;
          if commit.status = "conflict" then
            M23DatabaseScanEvent("conflict", Concatenation("block=",
              String(ordinal), ",twist=", String(twistId),
              ",certificate=", String(commit.certificate_id)));
            continue;
          fi;
          certificateId := commit.certificate_id;
          retry := false;
        fi;
        if workerId = fail and profileInterval > 0 then
          profile.commit_ms := profile.commit_ms + Runtime() - phaseStarted;
        fi;
        M23DatabaseScanEvent("certificate", Concatenation("id=",
          String(certificateId), ",status=", certificateStatus,
          ",vertices=", String(Length(vertexKeys)), ",classes=",
          String(traversal.discovered_class_count)));
        od;
      fi;
    else
      if profileInterval > 0 then
        profile.seed_ms := profile.seed_ms + Runtime() - phaseStarted;
      fi;
    fi;
  od;
  if workerId <> fail then
    M23QuotientLedgerRenewLease(ledger, workerId, ordinal, leaseSeconds);
  fi;
  if profileInterval > 0 then phaseStarted := Runtime(); fi;
  if workerId = fail then
    M23QuotientLedgerFinishBlock(ledger, ordinal, source, refinedCount,
      generatingCount);
  else
    M23QuotientLedgerFinishWorkerBlock(ledger, workerId, ordinal, source,
      refinedCount, generatingCount);
  fi;
  invocationCount := invocationCount + 1;
  if cacheResetInterval > 0 and
      invocationCount mod cacheResetInterval = 0 then
    M23ResetDirectPairBlockCaches(locator);
    GASMAN("collect");
    cacheResets := cacheResets + 1;
  fi;
  if profileInterval > 0 then
    profile.finish_ms := profile.finish_ms + Runtime() - phaseStarted;
  fi;
  if invocationCount mod progressInterval = 0 then
    stats := M23QuotientLedgerStats(ledger);
    M23DatabaseScanEvent("progress", Concatenation("block=", String(ordinal),
      ",source=", source, ",scanned=", String(stats.blocks), ",frontier=",
      String(stats.frontier_blocks), ",covered=", String(stats.covered_blocks),
      ",pending=", String(stats.pending), ",generating=",
      String(stats.generating_vertices), ",certificates=",
      String(stats.certificates), ",hits=", String(stats.ledger_hits),
      ",ledger=", String(stats.vertices)));
  fi;
  if profileInterval > 0 and invocationCount mod profileInterval = 0 then
    M23DatabaseScanEvent("profile", Concatenation("worker=",
      String(workerId), ",blocks=", String(invocationCount),
      ",traversals=", String(profile.traversals),
      ",claim_ms=", String(profile.claim_ms),
      ",refine_ms=", String(profile.refine_ms),
      ",seed_ms=", String(profile.seed_ms),
      ",walk_ms=", String(profile.walk_ms),
      ",commit_ms=", String(profile.commit_ms),
      ",finish_ms=", String(profile.finish_ms)));
  fi;
od;

stats := M23QuotientLedgerStats(ledger);;
if stats.blocks = lastOrdinal - firstOrdinal + 1 then
  exhausted := true;
fi;
if exhausted then state := "done"; else state := "paused"; fi;
M23DatabaseScanEvent(state, Concatenation("scanned=", String(stats.blocks),
  ",frontier=", String(stats.frontier_blocks), ",covered=",
  String(stats.covered_blocks), ",certificates=", String(stats.certificates),
  ",hits=", String(stats.ledger_hits), ",ledger=", String(stats.vertices),
  ",cache_resets=", String(cacheResets),
  ",database_bytes=", String(stats.database_bytes)));
M23CloseQuotientLedger(ledger);;
Print("target=", pairCheckpoint.target_order, " range=", firstOrdinal, "-",
  lastOrdinal, " schedule=", schedule, " state=", state, " scanned=",
  stats.blocks, " frontier=", stats.frontier_blocks, " covered=",
  stats.covered_blocks, " refined=", stats.refined_vertices,
  " generating=", stats.generating_vertices, " certificates=",
  stats.certificates, " hits=", stats.ledger_hits, " ledger=",
  stats.vertices, "\n");
QUIT;
