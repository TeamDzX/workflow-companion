#!/bin/bash
# The companion's side of the shared rule cases (WorkFlow's Swift side runs
# in WorkFlow's own repo, against the same cases.json).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
{ SERVER="$HERE/../../src/index.js" node "$HERE/rules.js" Jarvis; SERVER="$HERE/../../src/index.js" node "$HERE/rules.js" Claude; } > /tmp/rules-js.out || exit 1
python3 - "$HERE/cases.json" /tmp/rules-js.out <<'PY'
import json, sys
want = {c["name"]: c["trigger"] for c in json.load(open(sys.argv[1]))["cases"]}
got = {}
for line in open(sys.argv[2]):
    for r in json.loads(line): got[r["name"]] = r["trigger"]
bad = [n for n in want if got.get(n, "missing") != want[n]]
for n in want: print(("FAIL  " if n in bad else "pass  ") + n + (f": expected {want[n]}, got {got.get(n, 'missing')}" if n in bad else ""))
print(f"\n{len(want) - len(bad)}/{len(want)} shared rule cases")
sys.exit(1 if bad else 0)
PY
