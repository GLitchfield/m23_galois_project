#!/usr/bin/env bash
set -euo pipefail

command -v gap >/dev/null || { echo "error: GAP is not installed" >&2; exit 1; }
command -v sha256sum >/dev/null || { echo "error: sha256sum is not installed" >&2; exit 1; }
command -v g++ >/dev/null || { echo "error: a C++20 compiler (g++) is not installed" >&2; exit 1; }

gap -q <<'GAP'
required := [
  ["atlasrep", "2.1.8"],
  ["ctbllib", "1.3.7"],
  ["transgrp", "3.6.5"]
];;
Print("GAP ", GAPInfo.Version, "\n");
for requirement in required do
  name := requirement[1];;
  minimum := requirement[2];;
  info := GAPInfo.PackagesInfo.(name);;
  if Length(info) = 0 then
    Error("required GAP package is missing: ", name);
  fi;
  version := info[1].Version;;
  if CompareVersionNumbers(version, minimum) < 0 then
    Error(name, " ", version, " is older than required version ", minimum);
  fi;
  Print(name, " ", version, "\n");
od;
QUIT;
GAP
