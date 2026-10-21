Read("src/gap/m23_quotient_ledger.g");;
SizeScreen([1000000, 1000000]);;

path := GAPInfo.SystemEnvironment.M23_LEDGER_DB;;
config := rec(
  target_order := 4, pair_schema := 2, macroblock_count := 100,
  first_ordinal := 2, last_ordinal := 100, proof_limit := 2500,
  walk_limit := 25000, schedule := "frontier", start_ordinal := 10
);;
ledger := M23OpenQuotientLedger(path, config);;
Assert(0, M23QuotientLedgerNextBlock(ledger) = [10, "ordinal"]);
certificate := rec(
  status := "overflow", walk_status := "overflow",
  linked_certificate := fail, seed_vertex := [10, 1],
  checked_vertex_count := 2, discovered_vertex_count := 3,
  discovered_class_count := 2501
);;
Assert(0, M23QuotientLedgerAddCertificate(ledger, certificate,
  [[10, 1], [30, 2], [20, 1]]) = 1);
Assert(0, M23QuotientLedgerLookup(ledger, [30, 2]) = 1);
Assert(0, M23QuotientLedgerLookup(ledger, [99, 1]) = fail);
M23QuotientLedgerFinishBlock(ledger, 10, "ordinal", 1, 1);;
Assert(0, M23QuotientLedgerNextBlock(ledger) = [30, "frontier"]);
M23QuotientLedgerFinishBlock(ledger, 30, "frontier", 2, 1);;
stats := M23QuotientLedgerStats(ledger);;
Assert(0, stats.blocks = 2 and stats.frontier_blocks = 1 and
  stats.certificates = 1 and stats.vertices = 3 and stats.pending = 1);
M23CloseQuotientLedger(ledger);;
Print("verified GAP/Python quotient ledger protocol\n");
QUIT;
