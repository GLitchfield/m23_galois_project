# Adversarial model review

`scripts/m23_adversarial_review.py` asks Claude Fable and Codex to review the
same explicit evidence packet independently, then optionally gives each model
one opportunity to criticize the other's answer. The output is advisory. It
is not a mathematical proof, a reproduced computation, a literature source, or
an exhaustiveness certificate.

The Wayfinder documents call one run of this harness a
"Codex/Fable review". During development the Codex reviewer was nicknamed
"Sol", so commit messages in the private history say "Sol/Fable".

## Trust boundary

The harness does not give either reviewer a writable repository. Instead it
copies the requested UTF-8 text files into a prompt with stable displayed line
numbers and SHA-256 provenance. Claude runs with safe mode, no tools, no MCP
servers, and no session persistence. Codex runs ephemerally in a temporary
directory with its read-only sandbox and no web search. Both are told to use
only the packet. The harness rejects citations to files outside the packet and
line ranges outside the cited file.

This is a narrower boundary than granting an agent general read access, but it
is not a claim that the vendor clients or model providers are offline. Both
clients must contact their providers, and the packet is transmitted to those
providers. Do not include secrets, credentials, private correspondence, or
material that is not permitted to leave the machine.

Claude is invoked through the installed `claude` CLI, using whatever
authentication that CLI already has. The harness does not read, request,
store, or prefer an Anthropic API key. Check the local state without
displaying account identifiers:

```console
python3 scripts/m23_adversarial_review.py doctor
```

## Review protocol

1. Commit the code and evidence to be reviewed. Dirty repositories are
   rejected unless `--allow-dirty` is given explicitly.
2. Put one precise question in a text file. A question under ignored `runs/`
   is convenient for a local review; commit it when it is part of a published
   review protocol.
3. Name every evidence file explicitly. Directories, binary files, paths
   outside the repository, and packets over the configured byte limit are
   rejected.
4. Pin both model identifiers. The default Claude identifier is
   `claude-fable-5`; Codex has no default because an implicit moving model would
   weaken provenance.
5. Inspect both initial answers before using the critique answers. Agreement
   after reciprocal criticism is still only a suggestion for independent
   checking.

For example:

```console
python3 scripts/m23_adversarial_review.py run \
  --question-file runs/reviews/0072-0073-question.txt \
  --evidence docs/tests/0072-8a-projective-continuation-pilot.md \
  --evidence docs/tests/0073-8a-five-factor-saturated-continuation.md \
  --evidence data/derived/m23_8a_coefficient_continuation_pilot.tsv \
  --evidence data/derived/m23_8a_root_saturated_continuation_pilot.tsv \
  --codex-model MODEL_ID \
  --output runs/reviews/0072-0073
```

The default is one reciprocal critique round, requiring four model calls: two
blind reviews followed by two revisions. Use `--rounds 0` for a cheaper blind
comparison. The two calls in each stage run concurrently.

## Outputs and restart behavior

Outputs remain under ignored `runs/` unless deliberately curated. A run
contains:

- `manifest.json`: Git state, models, file hashes, packet hash, timestamps, and
  result hashes;
- `evidence-packet.txt`: the exact common input;
- `claude.initial.json` and `codex.initial.json`: blind structured reviews;
- optional `claude.round1.json` and `codex.round1.json`: revised reviews;
- `raw/`: provider-client stdout and stderr for diagnosis; and
- `REPORT.md`: a compact human-readable index with an explicit interpretation
  boundary.

Each completed stage is written atomically. Repeating the same command with
the same output directory validates the manifest and skips valid completed
stages, so an interrupted review can resume. A changed question, evidence
packet, Git state (including hashes of explicitly allowed dirty content), model,
timeout, or round count is rejected rather than mixed with old results.

Raw model output can be large and can contain misleading or sensitive text.
Do not commit a whole local run automatically. If a review materially informs
a project decision, summarize the checked objection and its resolution in the
appropriate numbered experiment note. A small transcript may be published
only when its provenance is complete and its advisory status is unmistakable.

## Recommended prompts

Ask about a bounded claim and name the decision the review should inform. Good
questions include:

- Does this evidence establish the exact sentence we propose to publish?
- Which conclusion depends on an unstated mathematical or computational
  assumption?
- What counterexample or independent calculation would most efficiently
  falsify the interpretation?
- Does the verifier check a different property from the generator or search?

Avoid asking whether the project is simply "correct." Broad questions blur
the evidence boundary and make model agreement especially uninformative.
