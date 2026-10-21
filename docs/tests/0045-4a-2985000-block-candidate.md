# Test 0045: certified 2,985,000-block 4A candidate

## Question

Does the next deterministic 500,000-block 4A quotient-ledger delta preserve the
verified base, reproduce every new block and certificate exactly, and introduce
any new closed or overflow braid component?

## Inputs and provenance

- implementation revision used by the operational run: the revision recorded
  in its SQLite metadata and manifests;
- pair-orbit checkpoint SHA-256
  `add26b95401d74fbaf29167782667080275d848b8cddabceecef40c2051c75c4`;
- verified 2,485,000-block base SHA-256
  `6e5e60fe69fc35327c52caf863164d18356842840ea9cb5a6ade08a32208020c`;
- frozen 2,985,000-block candidate SHA-256
  `d570724040954113c2300fbc2f5a05b81e0769e6c68500f9dd66476e87e9bca7`;
- eight deterministic scan shards over macroblocks 2 through 7,928,185;
- four certificate-replay and four block-replay segments;
- replay plan ID
  `e090b12a881a75b5510ea457876b946750bdcfbd46ff96fe04319af2fe577475`;
- GAP 4.12.1 and the package versions checked by `make test` on the 24-thread,
  32 GiB WSL2 host.

The ignored ledger, manifests, segment logs, progress stream, exact replay
summary, and ownership audit are under
`runs/4a-db-candidate-2985000/`. The matching live scan is under
`runs/4a-db-live-1985000/`.

## Result

The frozen candidate contains:

- 2,985,000 processed macroblocks;
- 1,851,230 certificates;
- 6,309,515 uniquely owned pair-twist vertices.

Relative to the verified base, the exact delta contains:

- 500,000 blocks;
- 847,781 refined and 765,112 generating vertices;
- 224,662 new certificates and 540,450 ledger hits;
- 411,904 new owned vertices;
- 224,662 linked certificates, zero closed, and zero overflow certificates.

All four block segments and all four certificate segments passed. The final
read-only ownership audit reports `base_preserved = true`,
`deterministic_ownership = true`, and `exact_replay = true`, with the expected
base and candidate hashes and eight-shard assignment.

Several original scan workers let their 300-second leases expire during dense
refinement/generation stretches; replacement workers then reached `state=done`
and the exact target count. The result is accepted because freezing, full delta
replay, base preservation, deterministic ownership, hashes, and final audit all
pass; the failed original processes are not used as evidence. The implementation
containing this note adds lease renewal after refinement, periodically through
seed testing, and before the final block commit so the next unattended wave does
not depend on replacement workers.

## Verdict

Passed. No new closed or overflow 4A braid component appears in this
500,000-block delta. This is incremental evidence only: 4,943,185 of the
7,928,185 symbolic macroblocks remain unprocessed, and absence of a further
component is not proved until the full deterministic enumeration and final
audit finish.
