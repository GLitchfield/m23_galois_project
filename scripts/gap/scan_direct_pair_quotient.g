Read("src/gap/m23_homogeneous_macroblocks.g");;
SizeScreen([1000000, 1000000]);;
LoadPackage("io");;

pairPath := GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT;;
output := GAPInfo.SystemEnvironment.M23_SCAN_CHECKPOINT;;
firstOrdinal := Int(GAPInfo.SystemEnvironment.M23_FIRST_ORDINAL);;
lastOrdinal := Int(GAPInfo.SystemEnvironment.M23_LAST_ORDINAL);;
limit := Int(GAPInfo.SystemEnvironment.M23_ORBIT_LIMIT);;
walkLimit := limit;;
if IsBound(GAPInfo.SystemEnvironment.M23_WALK_LIMIT) then
  walkLimit := Int(GAPInfo.SystemEnvironment.M23_WALK_LIMIT);
fi;
schedule := "sequential";;
if IsBound(GAPInfo.SystemEnvironment.M23_SCAN_SCHEDULE) then
  schedule := GAPInfo.SystemEnvironment.M23_SCAN_SCHEDULE;
fi;
startOrdinal := firstOrdinal;;
if IsBound(GAPInfo.SystemEnvironment.M23_START_ORDINAL) then
  startOrdinal := Int(GAPInfo.SystemEnvironment.M23_START_ORDINAL);
fi;
blockBudget := lastOrdinal - firstOrdinal + 1;;
if IsBound(GAPInfo.SystemEnvironment.M23_BLOCK_BUDGET) then
  blockBudget := Int(GAPInfo.SystemEnvironment.M23_BLOCK_BUDGET);
fi;
progressPath := fail;;
if IsBound(GAPInfo.SystemEnvironment.M23_PROGRESS_FILE) then
  progressPath := GAPInfo.SystemEnvironment.M23_PROGRESS_FILE;
fi;

M23_PAIR_BLOCK_CHECKPOINT := fail;;
Read(pairPath);
pairCheckpoint := M23_PAIR_BLOCK_CHECKPOINT;;
if firstOrdinal < 1 or lastOrdinal < firstOrdinal or
   lastOrdinal > pairCheckpoint.macroblock_count or limit < 1 or
   not schedule in ["sequential", "frontier"] or
   startOrdinal < firstOrdinal or startOrdinal > lastOrdinal or
   blockBudget < 1 or walkLimit < limit then
  Error("invalid direct quotient scan configuration");
fi;

G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
locator := M23BuildDirectPairLocator(G, classes, pairCheckpoint);;
ledger := NewDictionary([1, 1], true);;
processed := NewDictionary(1, true);;
queued := NewDictionary(1, true);;

M23ScanEvent := function(state, detail)
  if progressPath <> fail then
    AppendTo(progressPath, IO_gettimeofday().tv_sec,
      "\tgap\tquotient_scan\t", firstOrdinal, "-", lastOrdinal,
      "\t", state, "\t", detail, "\n");
  fi;
end;;

M23WriteScanCheckpoint := function(checkpoint)
  local temporary;
  temporary := Concatenation(output, ".tmp");
  PrintTo(temporary, "M23_QUOTIENT_SCAN_CHECKPOINT := ", checkpoint, ";;\n");
  if IO_rename(temporary, output) <> true then
    Error("could not atomically replace quotient scan checkpoint");
  fi;
end;;

scan := fail;;
if IsExistingFile(output) then
  M23_QUOTIENT_SCAN_CHECKPOINT := fail;;
  Read(output);
  scan := M23_QUOTIENT_SCAN_CHECKPOINT;
  if scan = fail or scan.schema_version <> 3 or
     scan.target_order <> pairCheckpoint.target_order or
     scan.pair_schema_version <> pairCheckpoint.schema_version or
     scan.macroblock_count <> pairCheckpoint.macroblock_count or
     scan.first_ordinal <> firstOrdinal or scan.last_ordinal <> lastOrdinal or
     scan.limit <> limit or scan.walk_limit <> walkLimit or
     scan.schedule <> schedule or
     scan.start_ordinal <> startOrdinal then
    Error("existing quotient scan checkpoint is incompatible");
  fi;
  for certificateId in [1..Length(scan.certificates)] do
    for key in scan.certificates[certificateId].vertices do
      if LookupDictionary(ledger, key) <> fail then
        Error("resumed quotient scan ledger contains duplicate vertices");
      fi;
      AddDictionary(ledger, key, certificateId);
    od;
  od;
  for ordinal in scan.processed_ordinals do
    AddDictionary(processed, ordinal, true);
  od;
  for ordinal in scan.queued_ordinals do
    AddDictionary(queued, ordinal, true);
  od;
  M23ScanEvent("resume", Concatenation("sequential_next=",
    String(scan.sequential_next), ",pending=",
    String(Length(scan.pending_ordinals) - scan.pending_position + 1),
    ",certificates=", String(Length(scan.certificates)),
    ",ledger=", String(scan.ledger_vertex_count)));
else
  scan := rec(
    schema_version := 3,
    gap_version := GAPInfo.Version,
    target_order := pairCheckpoint.target_order,
    pair_schema_version := pairCheckpoint.schema_version,
    macroblock_count := pairCheckpoint.macroblock_count,
    first_ordinal := firstOrdinal,
    last_ordinal := lastOrdinal,
    limit := limit,
    walk_limit := walkLimit,
    schedule := schedule,
    start_ordinal := startOrdinal,
    sequential_next := startOrdinal,
    sequential_wrapped := false,
    pending_ordinals := [],
    pending_position := 1,
    queued_ordinals := [],
    processed_ordinals := [],
    processed_sources := [],
    scanned_macroblock_count := 0,
    frontier_macroblock_count := 0,
    covered_macroblock_count := 0,
    refined_vertex_count := 0,
    generating_vertex_count := 0,
    ledger_hit_count := 0,
    ledger_vertex_count := 0,
    certificates := []
  );
  M23WriteScanCheckpoint(scan);
  M23ScanEvent("start", Concatenation("start=", String(startOrdinal),
    ",schedule=", schedule, ",budget=", String(blockBudget),
    ",limit=", String(limit), ",walk_limit=", String(walkLimit)));
fi;

M23NextScanOrdinal := function()
  local candidate;
  if scan.schedule = "frontier" then
    while scan.pending_position <= Length(scan.pending_ordinals) do
      candidate := scan.pending_ordinals[scan.pending_position];
      scan.pending_position := scan.pending_position + 1;
      if LookupDictionary(processed, candidate) = fail then
        return [candidate, "frontier"];
      fi;
    od;
  fi;
  while true do
    if not scan.sequential_wrapped then
      if scan.sequential_next <= scan.last_ordinal then
        candidate := scan.sequential_next;
        scan.sequential_next := scan.sequential_next + 1;
      elif scan.start_ordinal > scan.first_ordinal then
        scan.sequential_wrapped := true;
        scan.sequential_next := scan.first_ordinal;
        continue;
      else
        return fail;
      fi;
    else
      if scan.sequential_next < scan.start_ordinal then
        candidate := scan.sequential_next;
        scan.sequential_next := scan.sequential_next + 1;
      else
        return fail;
      fi;
    fi;
    if LookupDictionary(processed, candidate) = fail then
      return [candidate, "ordinal"];
    fi;
  od;
end;;

invocationCount := 0;;
exhausted := false;;
ordinal := fail;;
while invocationCount < blockBudget do
  scheduled := M23NextScanOrdinal();
  if scheduled = fail then
    exhausted := true;
    break;
  fi;
  ordinal := scheduled[1];
  source := scheduled[2];
  blockCertificateStart := Length(scan.certificates);
  block := M23DecodeMacroblock(pairCheckpoint, ordinal);
  refinement := M23CachedDirectPairTwistRefinement(locator, block);
  scan.refined_vertex_count := scan.refined_vertex_count +
    Length(refinement.twist_orbits);
  for twistId in [1..Length(refinement.twist_orbits)] do
    key := [ordinal, twistId];
    materializedIndex := refinement.twist_orbits[twistId][1];
    seed := refinement.materialized.tuples[materializedIndex];
    if IsGeneratingTuple(G, seed) then
      scan.generating_vertex_count := scan.generating_vertex_count + 1;
      knownCertificate := LookupDictionary(ledger, key);
      if knownCertificate <> fail then
        scan.ledger_hit_count := scan.ledger_hit_count + 1;
      else
        traversal := M23BoundedDirectPairTwistOrbitWithLedger(locator, seed,
          walkLimit,
          function(checked, discovered, classesFound)
            if checked mod 100 = 0 then
              M23ScanEvent("walk", Concatenation("block=", String(ordinal),
                ",twist=", String(twistId), ",checked=", String(checked),
                ",vertices=", String(discovered), ",classes=",
                String(classesFound)));
            fi;
          end,
          candidate -> LookupDictionary(ledger, candidate));
        certificateId := Length(scan.certificates) + 1;
        vertexKeys := List(traversal.vertices, vertex ->
          [vertex.block.ordinal, vertex.twist_id]);
        if traversal.status = "linked" then
          certificateStatus := "linked";
        elif traversal.status = "closed" and
             traversal.discovered_class_count <= limit then
          certificateStatus := "closed";
        else
          certificateStatus := "overflow";
        fi;
        certificate := rec(
          certificate_id := certificateId,
          status := certificateStatus,
          walk_status := traversal.status,
          linked_certificate := traversal.linked_certificate,
          seed_vertex := key,
          checked_vertex_count := traversal.checked_vertex_count,
          discovered_vertex_count := traversal.discovered_vertex_count,
          discovered_class_count := traversal.discovered_class_count,
          vertices := vertexKeys
        );
        Add(scan.certificates, certificate);
        for vertexKey in vertexKeys do
          if LookupDictionary(ledger, vertexKey) <> fail then
            Error("new quotient certificate overlaps the existing ledger");
          fi;
          AddDictionary(ledger, vertexKey, certificateId);
          if scan.schedule = "frontier" and
             vertexKey[1] >= scan.first_ordinal and
             vertexKey[1] <= scan.last_ordinal and
             LookupDictionary(processed, vertexKey[1]) = fail and
             LookupDictionary(queued, vertexKey[1]) = fail then
            Add(scan.pending_ordinals, vertexKey[1]);
            Add(scan.queued_ordinals, vertexKey[1]);
            AddDictionary(queued, vertexKey[1], true);
          fi;
        od;
        scan.ledger_vertex_count := scan.ledger_vertex_count +
          Length(vertexKeys);
        M23ScanEvent("certificate", Concatenation("id=",
          String(certificateId), ",status=", certificateStatus,
          ",vertices=", String(Length(vertexKeys)), ",classes=",
          String(traversal.discovered_class_count)));
      fi;
    fi;
  od;
  Add(scan.processed_ordinals, ordinal);
  Add(scan.processed_sources, source);
  AddDictionary(processed, ordinal, true);
  scan.scanned_macroblock_count := scan.scanned_macroblock_count + 1;
  if source = "frontier" then
    scan.frontier_macroblock_count := scan.frontier_macroblock_count + 1;
  fi;
  if Length(scan.certificates) = blockCertificateStart then
    scan.covered_macroblock_count := scan.covered_macroblock_count + 1;
  fi;
  invocationCount := invocationCount + 1;
  M23WriteScanCheckpoint(scan);
  M23ScanEvent("progress", Concatenation("block=", String(ordinal),
    ",source=", source, ",scanned=", String(scan.scanned_macroblock_count),
    ",frontier=", String(scan.frontier_macroblock_count), ",covered=",
    String(scan.covered_macroblock_count), ",pending=",
    String(Length(scan.pending_ordinals) - scan.pending_position + 1),
    ",generating=", String(scan.generating_vertex_count), ",certificates=",
    String(Length(scan.certificates)), ",hits=",
    String(scan.ledger_hit_count), ",ledger=",
    String(scan.ledger_vertex_count)));
od;

if scan.scanned_macroblock_count =
   scan.last_ordinal - scan.first_ordinal + 1 then
  exhausted := true;
fi;
if exhausted then
  state := "done";
else
  state := "paused";
fi;
M23ScanEvent(state, Concatenation("scanned=",
  String(scan.scanned_macroblock_count), ",frontier=",
  String(scan.frontier_macroblock_count), ",covered=",
  String(scan.covered_macroblock_count), ",certificates=",
  String(Length(scan.certificates)), ",hits=", String(scan.ledger_hit_count),
  ",ledger=", String(scan.ledger_vertex_count)));
Print("target=", scan.target_order, " range=", firstOrdinal, "-",
  lastOrdinal, " schedule=", scan.schedule, " state=", state,
  " scanned=", scan.scanned_macroblock_count, " frontier=",
  scan.frontier_macroblock_count, " covered=", scan.covered_macroblock_count,
  " refined=", scan.refined_vertex_count, " generating=",
  scan.generating_vertex_count, " certificates=", Length(scan.certificates),
  " hits=", scan.ledger_hit_count, " ledger=", scan.ledger_vertex_count, "\n");
QUIT;
