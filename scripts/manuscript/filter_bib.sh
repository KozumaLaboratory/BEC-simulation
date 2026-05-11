#!/usr/bin/env bash
# filter_bib.sh — extract bibtex entries matching keys in references.txt
#
# Usage:
#   scripts/manuscript/filter_bib.sh paper1_F2_cyclic
#
# Reads docs/manuscript/papers/<paper>/references.txt (one cite-key per line,
# # comments allowed) and writes docs/manuscript/papers/<paper>/build/<paper>.bib
# containing only the entries matching those keys from the shared bib.

set -euo pipefail

PAPER="${1:?usage: $0 <paper_dir>}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PAPER_DIR="$ROOT/docs/manuscript/papers/$PAPER"
KEYS_FILE="$PAPER_DIR/references.txt"
SHARED_BIB="$ROOT/docs/manuscript/shared/references.bib"
BUILD_DIR="$PAPER_DIR/build"
OUT_BIB="$BUILD_DIR/${PAPER}.bib"

if [[ ! -f "$KEYS_FILE" ]]; then
    echo "ERROR: $KEYS_FILE not found"; exit 1
fi
if [[ ! -f "$SHARED_BIB" ]]; then
    echo "ERROR: $SHARED_BIB not found"; exit 1
fi

mkdir -p "$BUILD_DIR"

# Extract cite-keys: strip comments + blank lines, keep first whitespace-separated token
KEYS=$(grep -v '^\s*#' "$KEYS_FILE" | awk '{print $1}' | grep -v '^\s*$' || true)
N_KEYS=$(echo "$KEYS" | wc -l)
echo "Extracting $N_KEYS keys from $SHARED_BIB → $OUT_BIB"

# Awk-based extraction: walk entries delimited by @ at column 0
awk -v keys_str="$KEYS" '
BEGIN {
    n = split(keys_str, keys_arr, "\n")
    for (i = 1; i <= n; i++) wanted[keys_arr[i]] = 1
    in_entry = 0
    capture = 0
    entry = ""
    brace_depth = 0
}
/^@/ {
    # New entry start
    if (in_entry && capture) print entry
    in_entry = 1
    capture = 0
    entry = ""
    brace_depth = 0
    # Try to match @TYPE{KEY,
    if (match($0, /^@[a-zA-Z]+\{([^,]+),/, m)) {
        if (m[1] in wanted) {
            capture = 1
        }
    }
}
in_entry {
    entry = entry $0 "\n"
    # Count braces to know when entry ends
    for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)
        if (c == "{") brace_depth++
        else if (c == "}") brace_depth--
    }
    if (brace_depth == 0 && in_entry) {
        if (capture) print entry
        in_entry = 0
        capture = 0
        entry = ""
    }
}
' "$SHARED_BIB" > "$OUT_BIB"

N_OUT=$(grep -c '^@' "$OUT_BIB" || true)
echo "OK: $N_OUT entries written to $OUT_BIB (wanted $N_KEYS)"

# Report missing keys
if [[ "$N_OUT" -lt "$N_KEYS" ]]; then
    echo "Missing keys (in references.txt but not found in shared bib):"
    while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        if ! grep -q "^@.*{${key}," "$OUT_BIB"; then
            echo "  - $key"
        fi
    done <<< "$KEYS"
fi
