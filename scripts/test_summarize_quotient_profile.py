#!/usr/bin/env python3

import tempfile
from pathlib import Path

from summarize_quotient_profile import summarize


def main() -> None:
    with tempfile.TemporaryDirectory() as directory:
        progress = Path(directory) / "progress.tsv"
        progress.write_text(
            "1\tgap\tquotient_db_scan\t2-10\tprogress\tblock=2\n"
            "2\tgap\tquotient_db_scan\t2-10\tprofile\t"
            "worker=worker-1,blocks=10,traversals=2,claim_ms=10,refine_ms=20,"
            "seed_ms=30,walk_ms=100,commit_ms=20,finish_ms=20\n"
            "3\tgap\tquotient_db_scan\t2-10\tprofile\t"
            "worker=worker-1,blocks=20,traversals=3,claim_ms=20,refine_ms=40,"
            "seed_ms=60,walk_ms=200,commit_ms=40,finish_ms=40\n",
            encoding="utf-8",
        )
        rows = summarize(progress)
    assert len(rows) == 1
    assert rows[0]["blocks"] == 20
    assert rows[0]["profiled_ms"] == 400
    assert rows[0]["walk_percent"] == 50.0
    print("quotient profile summary test passed")


if __name__ == "__main__":
    main()
