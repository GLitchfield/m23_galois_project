LoadPackage("io");;

M23LedgerRequest := function(ledger, line)
  local response, fields;
  IO_WriteLine(ledger.process.stdin, line);
  IO_Flush(ledger.process.stdin);
  response := IO_ReadLine(ledger.process.stdout);
  if response = "" then
    Error("quotient ledger process closed its output");
  fi;
  fields := SplitString(response, "\t", "\n");
  if fields[1] = "ERROR" then
    Error(Concatenation("quotient ledger error: ", JoinStringsWithSeparator(
      fields{[2..Length(fields)]}, ": ")));
  fi;
  return fields;
end;;

M23OpenQuotientLedger := function(path, config)
  local process, ledger, response, initValues, init;
  process := IO_Popen2("python3",
    ["scripts/m23_quotient_ledger.py", path]);
  if process = fail then
    Error("could not start quotient ledger process");
  fi;
  ledger := rec(process := process, path := path);
  response := M23LedgerRequest(ledger, "HELLO");
  if response{[1, 2]} <> ["OK", "1"] then
    Error("quotient ledger protocol version mismatch");
  fi;
  initValues := [
    "INIT", config.target_order, config.pair_schema,
    config.macroblock_count, config.first_ordinal, config.last_ordinal,
    config.proof_limit, config.walk_limit, config.schedule,
    config.start_ordinal
  ];
  if IsBound(config.traversal_order) then
    Add(initValues, config.traversal_order);
  fi;
  init := JoinStringsWithSeparator(List(initValues, String), "\t");
  response := M23LedgerRequest(ledger, init);
  if response[1] <> "OK" then
    Error("quotient ledger initialization failed");
  fi;
  return ledger;
end;;

M23OpenReadOnlyQuotientLedger := function(path, config)
  local process, ledger, response, initValues, init;
  process := IO_Popen2("python3",
    ["scripts/m23_quotient_ledger.py", "--readonly", path]);
  if process = fail then
    Error("could not start read-only quotient ledger process");
  fi;
  ledger := rec(process := process, path := path);
  response := M23LedgerRequest(ledger, "HELLO");
  if response{[1, 2]} <> ["OK", "1"] then
    Error("quotient ledger protocol version mismatch");
  fi;
  initValues := [
    "INIT", config.target_order, config.pair_schema,
    config.macroblock_count, config.first_ordinal, config.last_ordinal,
    config.proof_limit, config.walk_limit, config.schedule,
    config.start_ordinal
  ];
  if IsBound(config.traversal_order) then
    Add(initValues, config.traversal_order);
  fi;
  init := JoinStringsWithSeparator(List(initValues, String), "\t");
  response := M23LedgerRequest(ledger, init);
  if response[1] <> "OK" then
    Error("read-only quotient ledger initialization failed");
  fi;
  return ledger;
end;;

M23QuotientLedgerLookup := function(ledger, key)
  local response;
  response := M23LedgerRequest(ledger, Concatenation("GET\t",
    String(key[1]), "\t", String(key[2])));
  if response[1] = "MISS" then
    return fail;
  elif response[1] = "FOUND" then
    return Int(response[2]);
  fi;
  Error("unexpected quotient ledger lookup response");
end;;

M23QuotientLedgerLookupBefore := function(ledger, key, maxCertificate)
  local response;
  if maxCertificate < 0 then
    Error("maximum certificate must be nonnegative");
  fi;
  response := M23LedgerRequest(ledger, Concatenation("GETBEFORE\t",
    String(key[1]), "\t", String(key[2]), "\t", String(maxCertificate)));
  if response[1] = "MISS" then
    return fail;
  elif response[1] = "FOUND" then
    return Int(response[2]);
  fi;
  Error("unexpected bounded quotient ledger lookup response");
end;;

M23QuotientLedgerAddCertificate := function(ledger, certificate, vertices)
  local linked, header, vertex, response;
  if certificate.linked_certificate = fail then
    linked := 0;
  else
    linked := certificate.linked_certificate;
  fi;
  header := JoinStringsWithSeparator(List([
    "ADD", certificate.status, certificate.walk_status, linked,
    certificate.seed_vertex[1], certificate.seed_vertex[2],
    certificate.checked_vertex_count, certificate.discovered_vertex_count,
    certificate.discovered_class_count, Length(vertices)
  ], String), "\t");
  IO_WriteLine(ledger.process.stdin, header);
  for vertex in vertices do
    IO_WriteLine(ledger.process.stdin, Concatenation("V\t",
      String(vertex[1]), "\t", String(vertex[2])));
  od;
  IO_Flush(ledger.process.stdin);
  response := SplitString(IO_ReadLine(ledger.process.stdout), "\t", "\n");
  if response[1] = "ERROR" then
    Error(Concatenation("quotient ledger add error: ",
      JoinStringsWithSeparator(response{[2..Length(response)]}, ": ")));
  elif response[1] <> "ADDED" then
    Error("unexpected quotient ledger add response");
  fi;
  return Int(response[2]);
end;;

M23QuotientLedgerTryAddCertificate := function(ledger, worker, ordinal,
  certificate, vertices)
  local linked, header, vertex, response;
  if certificate.linked_certificate = fail then linked := 0;
  else linked := certificate.linked_certificate; fi;
  header := JoinStringsWithSeparator(List([
    "TRYADD", worker, ordinal, certificate.status, certificate.walk_status,
    linked, certificate.seed_vertex[1], certificate.seed_vertex[2],
    certificate.checked_vertex_count, certificate.discovered_vertex_count,
    certificate.discovered_class_count, Length(vertices)
  ], String), "\t");
  IO_WriteLine(ledger.process.stdin, header);
  for vertex in vertices do
    IO_WriteLine(ledger.process.stdin, Concatenation("V\t",
      String(vertex[1]), "\t", String(vertex[2])));
  od;
  IO_Flush(ledger.process.stdin);
  response := SplitString(IO_ReadLine(ledger.process.stdout), "\t", "\n");
  if response[1] = "ERROR" then
    Error(Concatenation("quotient ledger try-add error: ",
      JoinStringsWithSeparator(response{[2..Length(response)]}, ": ")));
  elif not response[1] in ["ADDED", "CONFLICT"] then
    Error("unexpected quotient ledger try-add response");
  fi;
  return rec(status := LowercaseString(response[1]),
    certificate_id := Int(response[2]));
end;;

M23QuotientLedgerNextBlock := function(ledger)
  local response;
  response := M23LedgerRequest(ledger, "NEXT");
  if response[1] = "DONE" then
    return fail;
  elif response[1] = "BLOCK" then
    return [Int(response[2]), response[3]];
  fi;
  Error("unexpected quotient ledger next-block response");
end;;

M23QuotientLedgerEnqueueSpecialBlock := function(ledger, ordinal)
  local response;
  response := M23LedgerRequest(ledger, Concatenation("ENQUEUE_SPECIAL\t",
    String(ordinal)));
  if response[1] <> "OK" then
    Error("unexpected special-block enqueue response");
  fi;
end;;

M23QuotientLedgerClaimBlock := function(ledger, worker, leaseSeconds,
  blockTarget, shardIndex, shardCount)
  local response;
  response := M23LedgerRequest(ledger, Concatenation("CLAIM\t", worker,
    "\t", String(leaseSeconds), "\t", String(blockTarget), "\t",
    String(shardIndex), "\t", String(shardCount)));
  if response[1] = "DONE" then return fail;
  elif response[1] = "WAIT" then return "wait";
  elif response[1] = "BLOCK" then
    return [Int(response[2]), response[3]];
  fi;
  Error("unexpected quotient ledger claim response");
end;;

M23QuotientLedgerRenewLease := function(ledger, worker, ordinal, leaseSeconds)
  local response;
  response := M23LedgerRequest(ledger, Concatenation("RENEW\t", worker,
    "\t", String(ordinal), "\t", String(leaseSeconds)));
  if response[1] <> "OK" then
    Error("unexpected quotient ledger lease-renewal response");
  fi;
end;;

M23QuotientLedgerFinishBlock := function(ledger, ordinal, source, refined,
  generating)
  local response;
  response := M23LedgerRequest(ledger, JoinStringsWithSeparator(List([
    "FINISH", ordinal, source, refined, generating
  ], String), "\t"));
  if response[1] <> "OK" then
    Error("unexpected quotient ledger finish-block response");
  fi;
end;;

M23QuotientLedgerFinishWorkerBlock := function(ledger, worker, ordinal,
  source, refined, generating)
  local response;
  response := M23LedgerRequest(ledger, JoinStringsWithSeparator(List([
    "FINISHW", worker, ordinal, source, refined, generating
  ], String), "\t"));
  if response[1] <> "OK" then
    Error("unexpected quotient ledger worker finish response");
  fi;
end;;

M23QuotientLedgerStats := function(ledger)
  local response, values;
  response := M23LedgerRequest(ledger, "STATS");
  if response[1] <> "STATS" or Length(response) <> 14 then
    Error("unexpected quotient ledger stats response");
  fi;
  values := List(response{[2..14]}, Int);
  return rec(
    blocks := values[1], frontier_blocks := values[2],
    covered_blocks := values[3], refined_vertices := values[4],
    generating_vertices := values[5], ledger_hits := values[6],
    certificates := values[7], closed := values[8], overflow := values[9],
    linked := values[10], vertices := values[11], pending := values[12],
    database_bytes := values[13]
  );
end;;

M23QuotientLedgerCertificate := function(ledger, certificateId)
  local response, count, vertices, index, vertex, ending, linked;
  response := M23LedgerRequest(ledger, Concatenation("CERT\t",
    String(certificateId)));
  if response[1] <> "CERT" or Length(response) <> 11 or
     Int(response[2]) <> certificateId then
    Error("unexpected quotient ledger certificate response");
  fi;
  count := Int(response[11]);
  vertices := [];
  for index in [1..count] do
    vertex := SplitString(IO_ReadLine(ledger.process.stdout), "\t", "\n");
    if vertex[1] <> "V" or Length(vertex) <> 3 then
      Error("invalid quotient ledger certificate vertex");
    fi;
    Add(vertices, [Int(vertex[2]), Int(vertex[3])]);
  od;
  ending := SplitString(IO_ReadLine(ledger.process.stdout), "\t", "\n");
  if ending[1] <> "END" then
    Error("quotient ledger certificate response did not terminate");
  fi;
  linked := Int(response[5]);
  if linked = 0 then linked := fail; fi;
  return rec(
    certificate_id := Int(response[2]),
    status := response[3], walk_status := response[4],
    linked_certificate := linked,
    seed_vertex := [Int(response[6]), Int(response[7])],
    checked_vertex_count := Int(response[8]),
    discovered_vertex_count := Int(response[9]),
    discovered_class_count := Int(response[10]),
    vertices := vertices
  );
end;;

M23QuotientLedgerBlocks := function(ledger)
  local response, count, blocks, index, row, ending;
  response := M23LedgerRequest(ledger, "BLOCKS");
  if response[1] <> "BLOCKS" then
    Error("unexpected quotient ledger block-list response");
  fi;
  count := Int(response[2]);
  blocks := [];
  for index in [1..count] do
    row := SplitString(IO_ReadLine(ledger.process.stdout), "\t", "\n");
    if row[1] <> "B" or Length(row) <> 7 then
      Error("invalid quotient ledger block row");
    fi;
    Add(blocks, rec(
      ordinal := Int(row[2]), source := row[3],
      refined_vertices := Int(row[4]), generating_vertices := Int(row[5]),
      new_certificates := Int(row[6]), ledger_hits := Int(row[7])
    ));
  od;
  ending := SplitString(IO_ReadLine(ledger.process.stdout), "\t", "\n");
  if ending[1] <> "END" then
    Error("quotient ledger block list did not terminate");
  fi;
  return blocks;
end;;

M23QuotientLedgerBlock := function(ledger, ordinal)
  local response;
  response := M23LedgerRequest(ledger, Concatenation("BLOCK\t",
    String(ordinal)));
  if response[1] <> "BLOCK" or Length(response) <> 8 or
      Int(response[2]) <> ordinal then
    Error("unexpected quotient ledger block response");
  fi;
  return rec(
    ordinal := Int(response[2]),
    source := response[3],
    refined_vertices := Int(response[4]),
    generating_vertices := Int(response[5]),
    new_certificates := Int(response[6]),
    ledger_hits := Int(response[7]),
    actual_seed_certificates := Int(response[8])
  );
end;;

M23QuotientLedgerForEachBlockSegment := function(ledger, baseBlocks,
  baseCertificates, segmentIndex, segmentCount, handler)
  local response, count, index, row, ending;
  response := M23LedgerRequest(ledger, JoinStringsWithSeparator(List([
    "BLOCKSEGMENT", baseBlocks, baseCertificates, segmentIndex, segmentCount
  ], String), "\t"));
  if response[1] <> "BLOCKSEGMENT" then
    Error("unexpected quotient ledger block-segment response");
  fi;
  count := Int(response[2]);
  for index in [1..count] do
    row := SplitString(IO_ReadLine(ledger.process.stdout), "\t", "\n");
    if row[1] <> "B" or Length(row) <> 8 then
      Error("invalid quotient ledger block-segment row");
    fi;
    handler(rec(
      ordinal := Int(row[2]), source := row[3],
      refined_vertices := Int(row[4]), generating_vertices := Int(row[5]),
      new_certificates := Int(row[6]), ledger_hits := Int(row[7]),
      actual_new_certificates := Int(row[8])
    ));
  od;
  ending := SplitString(IO_ReadLine(ledger.process.stdout), "\t", "\n");
  if ending[1] <> "END" then
    Error("quotient ledger block-segment response did not terminate");
  fi;
  return count;
end;;

M23QuotientLedgerVertices := function(ledger)
  local response, count, vertices, index, row, ending;
  response := M23LedgerRequest(ledger, "VERTICES");
  if response[1] <> "VERTICES" then
    Error("unexpected quotient ledger vertex-list response");
  fi;
  count := Int(response[2]);
  vertices := [];
  for index in [1..count] do
    row := SplitString(IO_ReadLine(ledger.process.stdout), "\t", "\n");
    if row[1] <> "V" or Length(row) <> 4 then
      Error("invalid quotient ledger vertex row");
    fi;
    Add(vertices, [Int(row[2]), Int(row[3]), Int(row[4])]);
  od;
  ending := SplitString(IO_ReadLine(ledger.process.stdout), "\t", "\n");
  if ending[1] <> "END" then
    Error("quotient ledger vertex list did not terminate");
  fi;
  return vertices;
end;;

M23QuotientLedgerVerticesThrough := function(ledger, maxCertificate)
  local response, count, vertices, index, row, ending;
  response := M23LedgerRequest(ledger, Concatenation("VERTICES\t",
    String(maxCertificate)));
  if response[1] <> "VERTICES" then
    Error("unexpected quotient ledger bounded vertex-list response");
  fi;
  count := Int(response[2]);
  vertices := [];
  for index in [1..count] do
    row := SplitString(IO_ReadLine(ledger.process.stdout), "\t", "\n");
    if row[1] <> "V" or Length(row) <> 4 then
      Error("invalid quotient ledger bounded vertex row");
    fi;
    Add(vertices, [Int(row[2]), Int(row[3]), Int(row[4])]);
  od;
  ending := SplitString(IO_ReadLine(ledger.process.stdout), "\t", "\n");
  if ending[1] <> "END" then
    Error("quotient ledger bounded vertex list did not terminate");
  fi;
  return vertices;
end;;

M23QuotientLedgerCertificatePrefixStats := function(ledger, maxCertificate)
  local response, values;
  response := M23LedgerRequest(ledger, Concatenation("PREFIX\t",
    String(maxCertificate)));
  if response[1] <> "PREFIX" or Length(response) <> 6 then
    Error("unexpected quotient ledger certificate-prefix response");
  fi;
  values := List(response{[2..6]}, Int);
  return rec(certificates := values[1], closed := values[2],
    overflow := values[3], linked := values[4], vertices := values[5]);
end;;

M23QuotientLedgerSeedCounts := function(ledger, firstCertificate,
  lastCertificate)
  local response, count, result, index, row, ending;
  response := M23LedgerRequest(ledger, Concatenation("SEEDCOUNTS\t",
    String(firstCertificate), "\t", String(lastCertificate)));
  if response[1] <> "SEEDCOUNTS" then
    Error("unexpected quotient ledger seed-count response");
  fi;
  count := Int(response[2]);
  result := [];
  for index in [1..count] do
    row := SplitString(IO_ReadLine(ledger.process.stdout), "\t", "\n");
    if row[1] <> "S" or Length(row) <> 3 then
      Error("invalid quotient ledger seed-count row");
    fi;
    Add(result, [Int(row[2]), Int(row[3])]);
  od;
  ending := SplitString(IO_ReadLine(ledger.process.stdout), "\t", "\n");
  if ending[1] <> "END" then
    Error("quotient ledger seed-count list did not terminate");
  fi;
  return result;
end;;

M23CloseQuotientLedger := function(ledger)
  local response;
  response := M23LedgerRequest(ledger, "QUIT");
  if response[1] <> "BYE" then
    Error("unexpected quotient ledger close response");
  fi;
  IO_Close(ledger.process.stdin);
  IO_Close(ledger.process.stdout);
end;;
