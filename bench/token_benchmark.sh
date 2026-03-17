#!/usr/bin/env bash
# bench/token_benchmark.sh
#
# Reproduce the Google Flights SIN→TYO token benchmark from the README.
#
# Requirements:
#   - Chrome running with --remote-debugging-port=9222
#   - kuri-agent built: zig build -Doptimize=ReleaseFast
#   - agent-browser installed: bun install -g agent-browser  (optional)
#   - lightpanda at /tmp/lightpanda or $LIGHTPANDA_BIN       (optional)
#   - python3 + tiktoken: pip install tiktoken
#
# Usage:
#   ./bench/token_benchmark.sh [url]
#
# Defaults to the Google Flights SIN→TYO search used in the README benchmark.

set -euo pipefail

URL="${1:-https://www.google.com/travel/flights/search?tfs=CBwQAhoeEgoyMDI2LTA1LTAxagcIARIDU0lOcgcIARIDVFlPQAFIAXABggELCP___________wGYAQI}"
AGENT="${KURI_AGENT:-./zig-out/bin/kuri-agent}"
OUT="$(mktemp -d)"

echo "=== kuri token benchmark ==="
echo "URL: $URL"
echo ""

# ── Attach kuri-agent to first Chrome tab ────────────────────────────────────
WS=$(curl -s http://127.0.0.1:9222/json | python3 -c \
  "import sys,json; tabs=json.load(sys.stdin); print(tabs[0]['webSocketDebuggerUrl'])" 2>/dev/null || true)

if [[ -z "$WS" ]]; then
  echo "ERROR: Chrome not found on port 9222."
  echo "Start it with: google-chrome --remote-debugging-port=9222"
  exit 1
fi

"$AGENT" use "$WS" >/dev/null
"$AGENT" go "$URL" >/dev/null
sleep 3  # let the SPA render

# ── Capture kuri snap modes ───────────────────────────────────────────────────
echo "Capturing kuri snapshots..."
"$AGENT" snap               > "$OUT/kuri_compact.txt"
"$AGENT" snap --interactive > "$OUT/kuri_interactive.txt"
"$AGENT" snap --semantic    > "$OUT/kuri_semantic.txt"
"$AGENT" snap --all         > "$OUT/kuri_all.txt"
"$AGENT" snap --json        > "$OUT/kuri_json.txt"
"$AGENT" snap --text        > "$OUT/kuri_text.txt"

# ── Capture agent-browser (optional) ─────────────────────────────────────────
if command -v agent-browser &>/dev/null; then
  echo "Capturing agent-browser snapshots..."
  agent-browser --cdp 9222 snapshot    > "$OUT/ab_full.txt"        2>/dev/null || true
  agent-browser --cdp 9222 snapshot -i > "$OUT/ab_interactive.txt" 2>/dev/null || true
fi

# ── Capture lightpanda (optional) ────────────────────────────────────────────
LP="${LIGHTPANDA_BIN:-/tmp/lightpanda}"
if [[ -x "$LP" ]]; then
  echo "Capturing lightpanda snapshots..."
  "$LP" fetch --dump semantic_tree      --http_timeout 15000 "$URL" > "$OUT/lp_tree.txt" 2>/dev/null || true
  "$LP" fetch --dump semantic_tree_text --http_timeout 15000 "$URL" > "$OUT/lp_text.txt" 2>/dev/null || true
fi

# ── Token counts via tiktoken ─────────────────────────────────────────────────
echo ""
python3 - "$OUT" << 'PYEOF'
import sys, os, tiktoken

out = sys.argv[1]
enc = tiktoken.encoding_for_model("gpt-4o")  # cl100k_base

files = [
    ("kuri snap (compact, DEFAULT)",  "kuri_compact.txt",     ""),
    ("kuri snap --interactive",       "kuri_interactive.txt", ""),
    ("kuri snap --semantic",          "kuri_semantic.txt",    ""),
    ("kuri snap --all",               "kuri_all.txt",         ""),
    ("kuri snap --json",              "kuri_json.txt",        "old default"),
    ("kuri snap --text",              "kuri_text.txt",        ""),
    ("agent-browser snapshot",        "ab_full.txt",          ""),
    ("agent-browser snapshot -i",     "ab_interactive.txt",   ""),
    ("lightpanda semantic_tree",      "lp_tree.txt",          "⚠ no JS on SPAs"),
    ("lightpanda semantic_tree_text", "lp_text.txt",          "⚠ no JS on SPAs"),
]

baseline = None
print(f"{'Tool / Mode':<38} {'Bytes':>9} {'Tokens':>8}  {'vs kuri default':>16}  Note")
print("─" * 88)

prev_tool = None
for label, fname, note in files:
    path = os.path.join(out, fname)
    if not os.path.exists(path):
        continue
    tool = label.split()[0]
    if prev_tool and tool != prev_tool:
        print()
    prev_tool = tool
    text  = open(path).read()
    toks  = len(enc.encode(text))
    size  = os.path.getsize(path)
    if baseline is None:
        baseline = toks
        ratio = "← baseline"
    else:
        ratio = f"{toks/baseline:.1f}x"
    print(f"  {label:<36} {size:>9,} {toks:>8,}  {ratio:>16}  {note}")

PYEOF
