Read("src/gap/m23_quotient_ledger.g");;

databasePath := GAPInfo.SystemEnvironment.M23_LEDGER_DB;;
ordinal := Int(GAPInfo.SystemEnvironment.M23_SPECIAL_ORDINAL);;
config := rec(
  target_order := Int(GAPInfo.SystemEnvironment.M23_TARGET_ORDER),
  pair_schema := Int(GAPInfo.SystemEnvironment.M23_PAIR_SCHEMA),
  macroblock_count := Int(GAPInfo.SystemEnvironment.M23_MACROBLOCK_COUNT),
  first_ordinal := Int(GAPInfo.SystemEnvironment.M23_FIRST_ORDINAL),
  last_ordinal := Int(GAPInfo.SystemEnvironment.M23_LAST_ORDINAL),
  proof_limit := Int(GAPInfo.SystemEnvironment.M23_ORBIT_LIMIT),
  walk_limit := Int(GAPInfo.SystemEnvironment.M23_WALK_LIMIT),
  schedule := GAPInfo.SystemEnvironment.M23_SCAN_SCHEDULE,
  start_ordinal := Int(GAPInfo.SystemEnvironment.M23_START_ORDINAL),
  traversal_order := GAPInfo.SystemEnvironment.M23_TRAVERSAL_ORDER
);;
ledger := M23OpenQuotientLedger(databasePath, config);;
M23QuotientLedgerEnqueueSpecialBlock(ledger, ordinal);;
M23CloseQuotientLedger(ledger);;
Print("queued special quotient block ", ordinal, "\n");
QUIT;
