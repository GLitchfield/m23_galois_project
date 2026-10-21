Read("src/gap/m23_homogeneous_macroblocks.g");;
Read("src/gap/m23_quotient_ledger.g");;
SizeScreen([1000000, 1000000]);;

M23_PAIR_BLOCK_CHECKPOINT := fail;;
Read(GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT);
pairCheckpoint := M23_PAIR_BLOCK_CHECKPOINT;;
databasePath := GAPInfo.SystemEnvironment.M23_LEDGER_DB;;
outputPath := GAPInfo.SystemEnvironment.M23_AUDIT_OUTPUT;;
closedCertificateIds := List(
  SplitString(GAPInfo.SystemEnvironment.M23_CLOSED_CERTIFICATES, ","), Int);;

config := rec(
  target_order := pairCheckpoint.target_order,
  pair_schema := pairCheckpoint.schema_version,
  macroblock_count := pairCheckpoint.macroblock_count,
  first_ordinal := 2,
  last_ordinal := pairCheckpoint.macroblock_count,
  proof_limit := 2500,
  walk_limit := 25000,
  schedule := "frontier",
  start_ordinal := 1633430,
  traversal_order := "legacy"
);;
database := M23OpenReadOnlyQuotientLedger(databasePath, config);;
stats := M23QuotientLedgerStats(database);;
Assert(0, stats.blocks = pairCheckpoint.macroblock_count);
Assert(0, stats.closed = Length(closedCertificateIds));

G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
targetClass := First(classes,
  class -> Order(Representative(class)) = pairCheckpoint.target_order);;
locator := M23BuildDirectPairLocator(G, classes, pairCheckpoint);;
locator.traversal_order := "legacy";;

identitySegment := First(M23MacroblockSegments(pairCheckpoint), item ->
  Order(Representative(classes[item.natural_class_index])) = 1);;
Assert(0, identitySegment.first_ordinal = 1 and
  identitySegment.last_ordinal = 1);
identityBlock := M23DecodeMacroblock(pairCheckpoint, 1);;
identityRefinement := M23CachedDirectPairTwistRefinement(locator,
  identityBlock);;
identityVertices := Length(identityRefinement.twist_orbits);;
Assert(0, identityVertices = 10099);
Assert(0, ForAll(identityRefinement.twist_orbit_sizes, size -> size = 1));

identityGenerating := 0;;
identityOwned := 0;;
identityMissing := 0;;
identityNongeneratingOwned := 0;;
identityOwnerCertificates := [];;
for twistId in [1..identityVertices] do
  materializedIndex := identityRefinement.twist_orbits[twistId][1];
  seed := identityRefinement.materialized.tuples[materializedIndex];
  Assert(0, IsProductOneTuple(seed));
  Assert(0, ForAll(seed, entry -> entry in targetClass));
  generating := IsGeneratingTuple(G, seed);
  owner := M23QuotientLedgerLookup(database, [1, twistId]);
  if generating then
    identityGenerating := identityGenerating + 1;
  fi;
  if owner <> fail then
    identityOwned := identityOwned + 1;
    AddSet(identityOwnerCertificates, owner);
  fi;
  if generating and owner = fail then
    identityMissing := identityMissing + 1;
  elif not generating and owner <> fail then
    identityNongeneratingOwned := identityNongeneratingOwned + 1;
  fi;
  if twistId mod 1000 = 0 then
    Print("identity audit ", twistId, "/", identityVertices,
      " generating=", identityGenerating, " owned=", identityOwned, "\n");
  fi;
od;
Print("identity totals vertices=", identityVertices,
  " generating=", identityGenerating, " owned=", identityOwned,
  " missing=", identityMissing, " nongenerating_owned=",
  identityNongeneratingOwned, " owner_certificates=",
  Length(identityOwnerCertificates), "\n");
Assert(0, identityMissing = 0 and identityNongeneratingOwned = 0);
Assert(0, identityGenerating = identityOwned);

componentTupleIndex := NewDictionary(
  identityRefinement.materialized.tuples[1], true);;
directComponentSizes := [];;
for certificateId in closedCertificateIds do
  certificate := M23QuotientLedgerCertificate(database, certificateId);
  Assert(0, certificate.status = "closed");
  Assert(0, certificate.linked_certificate = fail);
  block := M23DecodeMacroblock(pairCheckpoint, certificate.seed_vertex[1]);
  refinement := M23CachedDirectPairTwistRefinement(locator, block);
  twistId := certificate.seed_vertex[2];
  Assert(0, twistId >= 1 and twistId <= Length(refinement.twist_orbits));
  materializedIndex := refinement.twist_orbits[twistId][1];
  seed := refinement.materialized.tuples[materializedIndex];
  directOrbit := M23BoundedPureOrbit(G, targetClass, seed, 2500,
    function(checked, discovered)
      if checked > 0 and checked mod 1000 = 0 then
        Print("certificate ", certificateId, " direct orbit checked=",
          checked, " discovered=", discovered, "\n");
      fi;
    end);
  Assert(0, directOrbit.closed);
  Assert(0, directOrbit.discovered_count = 2456);
  Assert(0, certificate.discovered_class_count = 2456);
  for tuple in directOrbit.representatives do
    Assert(0, LookupDictionary(componentTupleIndex, tuple) = fail);
    AddDictionary(componentTupleIndex, tuple, certificateId);
  od;
  Add(directComponentSizes, directOrbit.discovered_count);
  Print("certificate ", certificateId, " seed=",
    certificate.seed_vertex, " direct_classes=",
    directOrbit.discovered_count, " quotient_vertices=",
    certificate.discovered_vertex_count, "\n");
  M23ResetDirectPairBlockCaches(locator);
  GASMAN("collect");
od;
Assert(0, directComponentSizes = List(closedCertificateIds, id -> 2456));

PrintTo(outputPath,
  "metric\tvalue\n",
  "pair_checkpoint_macroblocks\t", pairCheckpoint.macroblock_count, "\n",
  "ledger_blocks\t", stats.blocks, "\n",
  "ledger_certificates\t", stats.certificates, "\n",
  "ledger_vertices\t", stats.vertices, "\n",
  "ledger_closed\t", stats.closed, "\n",
  "ledger_overflow\t", stats.overflow, "\n",
  "ledger_linked\t", stats.linked, "\n",
  "identity_vertices\t", identityVertices, "\n",
  "identity_generating\t", identityGenerating, "\n",
  "identity_owned\t", identityOwned, "\n",
  "identity_missing\t", identityMissing, "\n",
  "identity_nongenerating_owned\t", identityNongeneratingOwned, "\n",
  "identity_owner_certificates\t", Length(identityOwnerCertificates), "\n",
  "closed_certificate_ids\t",
    JoinStringsWithSeparator(List(closedCertificateIds, String), ","), "\n",
  "direct_component_sizes\t",
    JoinStringsWithSeparator(List(directComponentSizes, String), ","), "\n",
  "direct_components_pairwise_disjoint\t1\n"
);
M23CloseQuotientLedger(database);;
Print("complete 4A bounded-search audit passed; output=", outputPath, "\n");
QUIT;
