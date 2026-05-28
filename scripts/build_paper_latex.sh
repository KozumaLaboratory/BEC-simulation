#!/usr/bin/env bash
# build_paper_latex.sh — convert a paper main.md → RevTeX LaTeX
#
# Usage:
#   scripts/build_paper_latex.sh paper1_F2_cyclic
#   scripts/build_paper_latex.sh paper2_F6_icosahedral
#   scripts/build_paper_latex.sh paper3_universal_theorem
#   scripts/build_paper_latex.sh paper4_chaotic_dynamics
#
# Output:
#   docs/manuscript/papers/<paper>/build/<paper>.tex
#   docs/manuscript/papers/<paper>/build/<paper>.pdf  (if lualatex available)

set -euo pipefail

PAPER="${1:?usage: $0 <paper_dir>}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PAPER_DIR="$ROOT/docs/manuscript/papers/$PAPER"
BUILD_DIR="$PAPER_DIR/build"
BIB="$ROOT/docs/manuscript/shared/references.bib"

if [[ ! -d "$PAPER_DIR" ]]; then
    echo "ERROR: $PAPER_DIR not found"
    exit 1
fi

mkdir -p "$BUILD_DIR"

# Locate pandoc (system or nix-store; require it to be a regular file)
PANDOC="$(command -v pandoc 2>/dev/null || find /nix/store -type f -name pandoc -executable 2>/dev/null | head -1 || echo '')"
if [[ -z "$PANDOC" ]]; then
    echo "ERROR: pandoc not found (system or /nix/store)"
    exit 1
fi
echo "Using pandoc: $PANDOC"
"$PANDOC" --version | head -1

# md → tex (generic LaTeX; RevTeX-specific class to be applied manually
# until pandoc revtex4-2 template lands in the repo)
TEX_OUT="$BUILD_DIR/${PAPER}.tex"
echo "Converting $PAPER_DIR/main.md → $TEX_OUT"
"$PANDOC" "$PAPER_DIR/main.md" \
    -t latex \
    -s \
    --bibliography="$BIB" \
    --citeproc \
    -o "$TEX_OUT"

echo "OK: $(wc -l < "$TEX_OUT") lines written to $TEX_OUT"

# PDF compile (if lualatex is on PATH)
LUALATEX="$(command -v lualatex 2>/dev/null || echo '')"
if [[ -n "$LUALATEX" ]]; then
    echo "Compiling PDF via $LUALATEX"
    (cd "$BUILD_DIR" && "$LUALATEX" -interaction=nonstopmode "${PAPER}.tex" >/dev/null) || {
        echo "WARN: lualatex compile had warnings/errors, see $BUILD_DIR/${PAPER}.log"
    }
    echo "PDF: $BUILD_DIR/${PAPER}.pdf"
else
    echo "NOTE: lualatex not on PATH; skipping PDF compile."
    echo "      Run manually: cd $BUILD_DIR && lualatex ${PAPER}.tex"
fi
