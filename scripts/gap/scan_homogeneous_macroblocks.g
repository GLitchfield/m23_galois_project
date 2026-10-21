Read("src/gap/m23_homogeneous_macroblocks.g");;
SizeScreen([1000000, 1000000]);;

path := GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT;;
limit := Int(GAPInfo.SystemEnvironment.M23_ORBIT_LIMIT);;
firstOrdinal := Int(GAPInfo.SystemEnvironment.M23_FIRST_ORDINAL);;
blockCount := Int(GAPInfo.SystemEnvironment.M23_BLOCK_COUNT);;
output := GAPInfo.SystemEnvironment.M23_OUTPUT;;
M23_PAIR_BLOCK_CHECKPOINT := fail;;
Read(path);
checkpoint := M23_PAIR_BLOCK_CHECKPOINT;;
lastOrdinal := Minimum(checkpoint.macroblock_count,
  firstOrdinal + blockCount - 1);;
if firstOrdinal < 1 or firstOrdinal > lastOrdinal then
  Error("invalid macroblock scan range");
fi;

G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
targetClass := First(classes, class ->
  Order(Representative(class)) = checkpoint.target_order);;
first := Representative(targetClass);;
firstCentralizer := Centralizer(G, first);;
ledger := NewDictionary([first, first, first, first], true);;
ledgerClassCount := 0;;
ledgerOverlapCount := 0;;

M23LedgerIndex := function(tuple)
  local transporter, normalized;
  if tuple[1] = first then
    normalized := tuple;
  else
    transporter := RepresentativeAction(G, tuple[1], first);
    if transporter = fail then
      Error("ledger tuple is outside the target class");
    fi;
    normalized := SimultaneousConjugate(tuple, transporter);
  fi;
  return LookupDictionary(ledger, normalized);
end;;

M23LedgerAddOrbit := function(representatives, certificateId)
  local representative, orbit, member, isNew;
  for representative in representatives do
    isNew := LookupDictionary(ledger, representative) = fail;
    orbit := Orbit(firstCentralizer, representative,
      function(point, element)
        return SimultaneousConjugate(point, element);
      end);
    for member in orbit do
      if LookupDictionary(ledger, member) = fail then
        AddDictionary(ledger, member, certificateId);
      fi;
    od;
    if isNew then
      ledgerClassCount := ledgerClassCount + 1;
    else
      ledgerOverlapCount := ledgerOverlapCount + 1;
    fi;
  od;
end;;

progressPath := fail;;
if IsBound(GAPInfo.SystemEnvironment.M23_PROGRESS_FILE) then
  progressPath := GAPInfo.SystemEnvironment.M23_PROGRESS_FILE;
  LoadPackage("io");
fi;
M23ScanProgress := function(ordinal, searches, reused)
  local epoch;
  if progressPath <> fail then
    epoch := IO_gettimeofday().tv_sec;
    AppendTo(progressPath, epoch, "\tgap\tmacroblock_scan\t",
      checkpoint.target_order, "\tprogress\t", ordinal, ",", searches,
      ",", reused, "\n");
  fi;
end;;

started := Runtime();;
processedBlocks := 0;;
innerClasses := 0;;
generatingClasses := 0;;
nongeneratingClasses := 0;;
reusedSeeds := 0;;
newSearches := 0;;
closedSearches := 0;;
overflowSearches := 0;;
linkedSearches := 0;;
certificateId := 0;;

for ordinal in [firstOrdinal..lastOrdinal] do
  block := M23DecodeMacroblock(checkpoint, ordinal);
  materialized := M23MaterializeMacroblock(G, classes, checkpoint, block);
  processedBlocks := processedBlocks + 1;
  innerClasses := innerClasses + materialized.inner_class_count;
  for tuple in materialized.tuples do
    if not IsGeneratingTuple(G, tuple) then
      nongeneratingClasses := nongeneratingClasses + 1;
      continue;
    fi;
    generatingClasses := generatingClasses + 1;
    if M23LedgerIndex(tuple) <> fail then
      reusedSeeds := reusedSeeds + 1;
      continue;
    fi;
    newSearches := newSearches + 1;
    bounded := M23BoundedPureOrbitWithLedger(G, targetClass, tuple, limit,
      function(checked, discovered) end, M23LedgerIndex);
    if bounded.status = "linked" then
      linkedSearches := linkedSearches + 1;
      M23LedgerAddOrbit(bounded.representatives,
        bounded.linked_certificate);
    else
      certificateId := certificateId + 1;
      M23LedgerAddOrbit(bounded.representatives, certificateId);
    fi;
    if bounded.status = "closed" then
      closedSearches := closedSearches + 1;
    elif bounded.status = "overflow" then
      overflowSearches := overflowSearches + 1;
    fi;
  od;
  M23ScanProgress(ordinal, newSearches, reusedSeeds);
od;

PrintTo(output,
  "# generated_by\tscripts/gap/scan_homogeneous_macroblocks.g\n",
  "target_order\torbit_limit\tfirst_ordinal\tlast_ordinal\tprocessed_macroblocks\tinner_classes\tgenerating_classes\tnongenerating_classes\treused_generating_seeds\tnew_bounded_searches\tclosed_searches\toverflow_searches\tlinked_searches\tledger_class_count\tledger_overlap_count\truntime_ms\n",
  checkpoint.target_order, "\t", limit, "\t", firstOrdinal, "\t",
  lastOrdinal, "\t", processedBlocks, "\t", innerClasses, "\t",
  generatingClasses, "\t", nongeneratingClasses, "\t", reusedSeeds, "\t",
  newSearches, "\t", closedSearches, "\t", overflowSearches, "\t",
  linkedSearches, "\t", ledgerClassCount, "\t", ledgerOverlapCount, "\t",
  Runtime() - started, "\n");
QUIT;
